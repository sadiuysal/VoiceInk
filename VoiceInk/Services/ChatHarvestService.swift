import Foundation
import AppKit
import ApplicationServices
import os

@MainActor
final class ChatHarvestService: ObservableObject {
    static let shared = ChatHarvestService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ChatHarvest")
    
    @Published var isHarvesting = false
    @Published var lastHarvestedAt: Date?
    
    // Cursor app bundle identifier
    private let cursorBundleId = "com.todesktop.230313mzl4w4u92"
    
    private init() {}
    
    // MARK: - Main Chat Harvest Function
    
    /// Harvests chat messages from Cursor if it's the frontmost app and contains a chat interface
    /// Returns nil if Cursor is not active, no chat is found, or harvest fails
    func harvestLastMessagesIfCursorContext(
        maxMessages: Int = 8,
        tokenCap: Int = 512,
        codeOnly: Bool = false
    ) async -> ChatSnippet? {
        logger.info("Starting chat harvest - maxMessages: \(maxMessages), tokenCap: \(tokenCap), codeOnly: \(codeOnly)")
        
        guard UserDefaults.standard.autoCaptureChat else {
            logger.info("Chat harvest disabled in settings")
            return nil
        }
        
        isHarvesting = true
        defer { isHarvesting = false }
        
        let timeoutMs = UserDefaults.standard.chatHarvestTimeout
        let startTime = Date()
        
        do {
            // Check if Cursor is the frontmost application
            guard isCursorFrontmost() else {
                logger.info("Cursor is not the frontmost application")
                return nil
            }
            
            // Get Cursor application reference
            guard let cursorApp = getCursorApplication() else {
                logger.error("Failed to get Cursor application reference")
                return nil
            }
            
            // Attempt to harvest chat messages with timeout
            let messages = try await withTimeout(timeoutMs: timeoutMs) {
                return await harvestChatMessages(from: cursorApp, maxMessages: maxMessages)
            }
            
            guard !messages.isEmpty else {
                logger.info("No chat messages found in Cursor")
                return nil
            }
            
            // Apply filtering and token limits
            var filteredMessages = messages
            
            if codeOnly {
                filteredMessages = filteredMessages.filter { $0.isCodeOnly }
            }
            
            // Apply token cap by removing oldest messages if needed
            var totalTokens = 0
            var finalMessages: [ChatMessage] = []
            
            for message in filteredMessages.reversed() { // Process from newest to oldest
                let messageTokens = message.estimatedTokens
                if totalTokens + messageTokens <= tokenCap {
                    finalMessages.insert(message, at: 0) // Insert at beginning to maintain order
                    totalTokens += messageTokens
                } else {
                    break
                }
            }
            
            guard !finalMessages.isEmpty else {
                logger.info("No messages remaining after filtering and token limits")
                return nil
            }
            
            // Create chat snippet
            let snippet = ChatSnippet(
                threadTitle: extractThreadTitle(from: cursorApp),
                messages: finalMessages,
                capturedAt: Date(),
                sourceApp: "cursor"
            )
            
            lastHarvestedAt = Date()
            
            let elapsedTime = Date().timeIntervalSince(startTime) * 1000
            logger.info("Chat harvest completed in \(elapsedTime, specifier: "%.1f")ms - \(finalMessages.count) messages, \(totalTokens) tokens")
            
            return snippet
            
        } catch {
            let elapsedTime = Date().timeIntervalSince(startTime) * 1000
            logger.error("Chat harvest failed after \(elapsedTime, specifier: "%.1f")ms: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Application Detection
    
    private func isCursorFrontmost() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            return false
        }
        return bundleId == cursorBundleId
    }
    
    private func getCursorApplication() -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let cursorApp = runningApps.first(where: { $0.bundleIdentifier == cursorBundleId }) else {
            return nil
        }
        
        return AXUIElementCreateApplication(cursorApp.processIdentifier)
    }
    
    // MARK: - Chat Message Harvesting
    
    private func harvestChatMessages(from cursorApp: AXUIElement, maxMessages: Int) async -> [ChatMessage] {
        do {
            // Get all windows from Cursor
            guard let windows = try getWindows(from: cursorApp) else {
                logger.debug("No windows found in Cursor")
                return []
            }
            
            // Look for chat interface in each window
            for window in windows {
                if let messages = try await extractChatFromWindow(window, maxMessages: maxMessages) {
                    return messages
                }
            }
            
            logger.debug("No chat interface found in any Cursor window")
            return []
            
        } catch {
            logger.error("Failed to harvest chat messages: \(error.localizedDescription)")
            return []
        }
    }
    
    private func getWindows(from app: AXUIElement) throws -> [AXUIElement]? {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return nil
        }
        
        return windows
    }
    
    private func extractChatFromWindow(_ window: AXUIElement, maxMessages: Int) async -> [ChatMessage]? {
        do {
            // Look for text areas that might contain chat content
            let textElements = try findTextElements(in: window)
            
            var chatMessages: [ChatMessage] = []
            
            for textElement in textElements {
                if let text = try getText(from: textElement),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    
                    // Try to parse as chat conversation
                    let messages = parseChatText(text)
                    if !messages.isEmpty {
                        chatMessages.append(contentsOf: messages)
                        
                        // If we found enough messages, return them
                        if chatMessages.count >= maxMessages {
                            break
                        }
                    }
                }
            }
            
            // Return last N messages
            return Array(chatMessages.suffix(maxMessages))
            
        } catch {
            logger.debug("Failed to extract chat from window: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func findTextElements(in element: AXUIElement) throws -> [AXUIElement] {
        var textElements: [AXUIElement] = []
        
        // Get the role of this element
        if let role = try getRole(of: element) {
            // Look for text areas, text fields, and static text
            if role == kAXTextAreaRole || role == kAXTextFieldRole || role == kAXStaticTextRole {
                textElements.append(element)
            }
        }
        
        // Recursively search children
        if let children = try getChildren(of: element) {
            for child in children {
                textElements.append(contentsOf: try findTextElements(in: child))
            }
        }
        
        return textElements
    }
    
    private func getRole(of element: AXUIElement) throws -> String? {
        var roleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        
        guard result == .success else {
            return nil
        }
        
        return roleRef as? String
    }
    
    private func getChildren(of element: AXUIElement) throws -> [AXUIElement]? {
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        
        return children
    }
    
    private func getText(from element: AXUIElement) throws -> String? {
        var textRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textRef)
        
        guard result == .success else {
            return nil
        }
        
        return textRef as? String
    }
    
    // MARK: - Chat Text Parsing
    
    private func parseChatText(_ text: String) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        // Split by common chat patterns
        let lines = text.components(separatedBy: .newlines)
        var currentMessage = ""
        var currentRole: MessageRole = .user
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !trimmedLine.isEmpty else { continue }
            
            // Detect role changes based on common patterns
            if isAssistantMessage(trimmedLine) {
                // Save previous message if any
                if !currentMessage.isEmpty {
                    messages.append(ChatMessage(
                        role: currentRole,
                        content: currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                
                currentRole = .assistant
                currentMessage = cleanMessageContent(trimmedLine)
            } else if isUserMessage(trimmedLine) {
                // Save previous message if any
                if !currentMessage.isEmpty {
                    messages.append(ChatMessage(
                        role: currentRole,
                        content: currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                
                currentRole = .user
                currentMessage = cleanMessageContent(trimmedLine)
            } else {
                // Continue current message
                if !currentMessage.isEmpty {
                    currentMessage += "\n"
                }
                currentMessage += trimmedLine
            }
        }
        
        // Add final message
        if !currentMessage.isEmpty {
            messages.append(ChatMessage(
                role: currentRole,
                content: currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        
        // Filter out very short messages
        return messages.filter { $0.content.count > 5 }
    }
    
    private func isAssistantMessage(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let assistantPatterns = [
            "assistant:", "ai:", "claude:", "gpt:", "copilot:",
            "🤖", "🧠", "💭", "assistant said", "ai said"
        ]
        
        return assistantPatterns.contains { lowercased.hasPrefix($0) || lowercased.contains($0) }
    }
    
    private func isUserMessage(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let userPatterns = [
            "user:", "you:", "me:", "human:", "i:",
            "👤", "🧑", "user said", "you said"
        ]
        
        return userPatterns.contains { lowercased.hasPrefix($0) || lowercased.contains($0) }
    }
    
    private func cleanMessageContent(_ line: String) -> String {
        // Remove common prefixes
        let prefixes = ["assistant:", "user:", "ai:", "claude:", "gpt:", "copilot:", "you:", "me:", "human:", "i:"]
        var cleaned = line
        
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Remove emojis at the start
        let emojiPattern = "^[🤖🧠💭👤🧑\\s]+"
        if let regex = try? NSRegularExpression(pattern: emojiPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.count),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return cleaned
    }
    
    // MARK: - Thread Title Extraction
    
    private func extractThreadTitle(from cursorApp: AXUIElement) -> String? {
        do {
            // Try to get window title which might contain thread info
            if let windows = try getWindows(from: cursorApp),
               let firstWindow = windows.first {
                
                var titleRef: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(firstWindow, kAXTitleAttribute as CFString, &titleRef)
                
                if result == .success, let title = titleRef as? String, !title.isEmpty {
                    return title
                }
            }
        } catch {
            logger.debug("Failed to extract thread title: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // MARK: - Timeout Helper
    
    private func withTimeout<T>(timeoutMs: Int, operation: @escaping () async -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                return await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
                throw ChatHarvestError.timeout
            }
            
            // Return the first completed task result
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

// MARK: - Errors

enum ChatHarvestError: LocalizedError {
    case timeout
    case accessibilityDenied
    case cursorNotFound
    case noChatFound
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Chat harvest timed out"
        case .accessibilityDenied:
            return "Accessibility access denied"
        case .cursorNotFound:
            return "Cursor application not found"
        case .noChatFound:
            return "No chat interface found"
        }
    }
}