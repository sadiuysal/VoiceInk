import Foundation
import AppKit
import ApplicationServices
import os

/// Advanced chat connectors with system integration for Cursor and Claude Code
/// These implementations use Apple Events, Accessibility APIs, and process monitoring

private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "AdvancedChatConnectors")

// Global callback function for accessibility notifications (required for C function pointers)
private func globalAccessibilityCallback(observer: AXObserver, element: AXUIElement, notification: CFString, context: UnsafeMutableRawPointer?) {
    // This is a simplified implementation - in production you'd need to properly handle the notifications
    // For now, we'll just log them
    let notificationName = notification as String
    logger.debug("Accessibility notification: \(notificationName)")
}

// MARK: - Advanced Cursor Connector

actor AdvancedCursorConnector: ChatConnector {
    private var cursorApplication: NSRunningApplication?
    private var accessibilityObserver: AXObserver?
    private var windowMonitor: WindowMonitor?
    private var chatDetector: CursorChatDetector?
    
    let connectorType: ChatConnectorType = .cursor
    let displayName: String = "Advanced Cursor Chat"
    
    private var isConnected = false
    private var currentBinding: ChatStreamBinding?
    private var monitoringTask: Task<Void, Never>?
    private var messageCallback: ((ChatStreamMessage) -> Void)?
    
    func isAvailable() async -> Bool {
        let cursorAvailable = await checkCursorAvailability()
        let permissionsAvailable = await checkAccessibilityPermissions()
        return cursorAvailable && permissionsAvailable
    }
    
    func connect(binding: ChatStreamBinding) async throws {
        guard await isAvailable() else {
            throw ChatConnectorError.connectorNotAvailable
        }
        
        guard !isConnected else {
            return
        }
        
        currentBinding = binding
        isConnected = true
        
        // Find Cursor application
        cursorApplication = findCursorApplication()
        
        guard let app = cursorApplication else {
            throw ChatConnectorError.connectionFailed("Cursor application not found")
        }
        
        // Set up accessibility monitoring
        try await setupAccessibilityMonitoring(for: app)
        
        // Initialize chat detection
        chatDetector = CursorChatDetector(application: app)
        
        // Set up window monitoring
        windowMonitor = WindowMonitor(application: app) { [weak self] event in
            Task {
                await self?.handleWindowEvent(event)
            }
        }
        
        await windowMonitor?.start()
    }
    
    func disconnect() async {
        await windowMonitor?.stop()
        windowMonitor = nil
        
        if let observer = accessibilityObserver {
            // Note: AXObserverRemoveNotification requires proper AXUIElement, not processIdentifier
            // This is a simplified cleanup - in production, you'd need to track the actual AXUIElement
            // CFRunLoopRemoveSource can't be used from async contexts
        }
        accessibilityObserver = nil
        
        chatDetector = nil
        cursorApplication = nil
    }
    
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async {
        guard isConnected else { return }
        
        messageCallback = onMessage
        
        monitoringTask = Task {
            await performMonitoring()
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        messageCallback = nil
    }
    
    private func performMonitoring() async {
        guard let detector = chatDetector else { return }
        
        while !Task.isCancelled {
            do {
                if let messages = await detector.detectNewMessages() {
                    for message in messages {
                        emitMessage(message)
                    }
                }
                
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                break
            }
        }
    }
    
    func sendMessage(_ content: String) async throws {
        guard let app = cursorApplication else {
            throw ChatConnectorError.notConnected
        }
        
        // Use multiple methods to send message to Cursor
        try await sendMessageToCursor(content, application: app)
    }
    
    func getAvailableSessions() async -> [ChatSessionInfo] {
        guard let app = cursorApplication else { return [] }
        
        return await getCursorChatSessions(application: app)
    }
    
    func validateConnection(_ connectionString: String) async -> Bool {
        return !connectionString.isEmpty
    }
    
    func getConnectionStatus() async -> ChatConnectionStatus {
        return ChatConnectionStatus(
            isConnected: isConnected,
            connectorType: connectorType,
            connectionString: currentBinding?.connectionString,
            lastActivity: Date(),
            messageCount: 0
        )
    }
    
    private func emitMessage(_ message: ChatStreamMessage) {
        messageCallback?(message)
    }
    
    // MARK: - Cursor-Specific Implementation
    
    private func checkCursorAvailability() async -> Bool {
        return findCursorApplication() != nil
    }
    
    private func checkAccessibilityPermissions() async -> Bool {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ] as CFDictionary)
        
        return trusted
    }
    
    private func findCursorApplication() -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Look for Cursor by bundle identifier
        if let cursorApp = runningApps.first(where: { $0.bundleIdentifier == "com.todesktop.230313mzl4w4u92" }) {
            return cursorApp
        }
        
        // Fallback: look by localized name
        return runningApps.first { app in
            app.localizedName?.lowercased().contains("cursor") == true
        }
    }
    
    private func setupAccessibilityMonitoring(for app: NSRunningApplication) async throws {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        var observer: AXObserver?
        // Use a global callback function that doesn't capture context
        let result = AXObserverCreate(app.processIdentifier, globalAccessibilityCallback, &observer)
        
        guard result == .success, let observer = observer else {
            throw ChatConnectorError.connectionFailed("Failed to create accessibility observer")
        }
        
        self.accessibilityObserver = observer
        
        // Add notifications for text changes and window events
        AXObserverAddNotification(observer, axApp, kAXValueChangedNotification as CFString, nil)
        AXObserverAddNotification(observer, axApp, kAXWindowCreatedNotification as CFString, nil)
        AXObserverAddNotification(observer, axApp, kAXWindowResizedNotification as CFString, nil)
        
        // Add observer to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }
    
    private func handleAccessibilityNotification(element: AXUIElement, notification: CFString) async {
        let notificationName = notification as String
        
        switch notificationName {
        case kAXValueChangedNotification as String:
            await handleTextValueChanged(element: element)
        case kAXWindowCreatedNotification as String:
            await handleWindowCreated(element: element)
        default:
            break
        }
    }
    
    private func handleTextValueChanged(element: AXUIElement) async {
        // Check if this is a chat-related text change
        guard let value = getElementValue(element),
              await chatDetector?.isChatElement(element) == true else {
            return
        }
        
        // Process the text change for potential chat messages
        await chatDetector?.processTextChange(value, element: element)
    }
    
    private func handleWindowCreated(element: AXUIElement) async {
        // Check if a new chat window was created
        if await chatDetector?.isChatWindow(element) == true {
            await chatDetector?.registerChatWindow(element)
        }
    }
    
    private func handleWindowEvent(_ event: WindowEvent) async {
        switch event.type {
        case .focused:
            await chatDetector?.setActiveWindow(event.windowId)
        case .closed:
            await chatDetector?.removeWindow(event.windowId)
        case .textChanged:
            if let text = event.text {
                await chatDetector?.processWindowTextChange(text, windowId: event.windowId)
            }
        }
    }
    
    private func sendMessageToCursor(_ content: String, application: NSRunningApplication) async throws {
        // Method 1: Try AppleScript
        do {
            try await sendViaCursorAppleScript(content)
            return
        } catch {
            logger.warning("AppleScript method failed: \(error.localizedDescription)")
        }
        
        // Method 2: Try Accessibility API
        do {
            try await sendViaAccessibilityAPI(content, application: application)
            return
        } catch {
            logger.warning("Accessibility API method failed: \(error.localizedDescription)")
        }
        
        // Method 3: Try keyboard simulation
        try await sendViaKeyboardSimulation(content, application: application)
    }
    
    private func sendViaCursorAppleScript(_ content: String) async throws {
        let script = """
        tell application "Cursor"
            activate
            delay 0.2
            tell application "System Events"
                tell process "Cursor"
                    set chatInput to text field 1 of group 1 of window 1
                    set value of chatInput to "\(content.replacingOccurrences(of: "\"", with: "\\\""))"
                    key code 36 -- Enter
                end tell
            end tell
        end tell
        """
        
        try await executeAppleScript(script)
    }
    
    private func sendViaAccessibilityAPI(_ content: String, application: NSRunningApplication) async throws {
        let axApp = AXUIElementCreateApplication(application.processIdentifier)
        
        // Find chat input field
        guard let chatInput = await findChatInputField(in: axApp) else {
            throw ChatConnectorError.connectionFailed("Could not find chat input field")
        }
        
        // Set the value
        let result = AXUIElementSetAttributeValue(chatInput, kAXValueAttribute as CFString, content as CFString)
        guard result == .success else {
            throw ChatConnectorError.connectionFailed("Failed to set chat input value")
        }
        
        // Simulate Enter key
        try await simulateKeyPress(.return, for: application)
    }
    
    private func sendViaKeyboardSimulation(_ content: String, application: NSRunningApplication) async throws {
        // Focus the application
        application.activate(options: .activateIgnoringOtherApps)
        
        try await Task.sleep(for: .milliseconds(200))
        
        // Type the content
        for character in content {
            try await simulateKeyPress(.character(character), for: application)
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // Press Enter
        try await simulateKeyPress(.return, for: application)
    }
    
    private func simulateKeyPress(_ key: KeyCode, for application: NSRunningApplication) async throws {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key.cgKeyCode, keyDown: true)
        event?.flags = []
        event?.post(tap: .cghidEventTap)
        
        try await Task.sleep(for: .milliseconds(10))
        
        let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: key.cgKeyCode, keyDown: false)
        upEvent?.post(tap: .cghidEventTap)
    }
    
    private func findChatInputField(in axApp: AXUIElement) async -> AXUIElement? {
        // Recursively search for chat input field
        return await searchForChatInput(element: axApp, depth: 0, maxDepth: 10)
    }
    
    private func searchForChatInput(element: AXUIElement, depth: Int, maxDepth: Int) async -> AXUIElement? {
        guard depth < maxDepth else { return nil }
        
        // Check if this element is a text field with chat-related attributes
        if await isChatInputElement(element) {
            return element
        }
        
        // Recursively search children
        guard let children = getElementChildren(element) else { return nil }
        
        for child in children {
            if let found = await searchForChatInput(element: child, depth: depth + 1, maxDepth: maxDepth) {
                return found
            }
        }
        
        return nil
    }
    
    private func isChatInputElement(_ element: AXUIElement) async -> Bool {
        guard let role = getElementRole(element),
              role == kAXTextFieldRole as String else {
            return false
        }
        
        // Check for chat-related identifiers
        if let identifier = getElementIdentifier(element) {
            let chatKeywords = ["chat", "input", "message", "prompt"]
            return chatKeywords.contains { identifier.lowercased().contains($0) }
        }
        
        // Check placeholder text
        if let placeholder = getElementPlaceholder(element) {
            let chatPhrases = ["type a message", "ask claude", "chat", "prompt"]
            return chatPhrases.contains { placeholder.lowercased().contains($0) }
        }
        
        return false
    }
    
    private func getCursorChatSessions(application: NSRunningApplication) async -> [ChatSessionInfo] {
        let axApp = AXUIElementCreateApplication(application.processIdentifier)
        
        guard let windows = getElementChildren(axApp) else { return [] }
        
        var sessions: [ChatSessionInfo] = []
        
        for (index, window) in windows.enumerated() {
            if let title = getElementTitle(window) {
                sessions.append(ChatSessionInfo(
                    id: "cursor_window_\(index)",
                    name: title,
                    type: .cursor,
                    isActive: index == 0,
                    lastActivity: Date()
                ))
            }
        }
        
        return sessions
    }
    
    // MARK: - Accessibility Utilities
    
    private func getElementValue(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success else { return nil }
        return value as? String
    }
    
    private func getElementRole(_ element: AXUIElement) -> String? {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard result == .success else { return nil }
        return role as? String
    }
    
    private func getElementTitle(_ element: AXUIElement) -> String? {
        var title: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        guard result == .success else { return nil }
        return title as? String
    }
    
    private func getElementIdentifier(_ element: AXUIElement) -> String? {
        var identifier: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        
        guard result == .success else { return nil }
        return identifier as? String
    }
    
    private func getElementPlaceholder(_ element: AXUIElement) -> String? {
        var placeholder: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholder)
        
        guard result == .success else { return nil }
        return placeholder as? String
    }
    
    private func getElementChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success,
              let childrenArray = children as? [AXUIElement] else {
            return nil
        }
        
        return childrenArray
    }
    
    private func executeAppleScript(_ script: String) async throws {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            throw ChatConnectorError.connectionFailed("AppleScript error: \(error)")
        }
    }
}

// MARK: - Advanced Claude Code Connector

actor AdvancedClaudeCodeConnector: ChatConnector {
    private var terminalMonitor: TerminalMonitor?
    private var claudeProcess: Process?
    private var claudeSession: ClaudeCodeSession?
    
    let connectorType: ChatConnectorType = .claudeCode
    let displayName: String = "Advanced Claude Code"
    
    private var isConnected = false
    private var currentBinding: ChatStreamBinding?
    private var monitoringTask: Task<Void, Never>?
    private var messageCallback: ((ChatStreamMessage) -> Void)?
    
    func isAvailable() async -> Bool {
        let hasInstallation = await checkClaudeCodeInstallation()
        let hasTerminalAccess = await checkTerminalAccess()
        return hasInstallation && hasTerminalAccess
    }
    
    func connect(binding: ChatStreamBinding) async throws {
        guard await isAvailable() else {
            throw ChatConnectorError.connectorNotAvailable
        }
        
        guard !isConnected else {
            return
        }
        
        currentBinding = binding
        isConnected = true
        
        // Parse connection parameters
        let params = try parseClaudeCodeConnection(binding.connectionString)
        
        // Create Claude Code session
        claudeSession = try await ClaudeCodeSession.create(params: params)
        
        // Set up terminal monitoring
        terminalMonitor = TerminalMonitor(session: claudeSession!) { [weak self] output in
            Task {
                await self?.processTerminalOutput(output)
            }
        }
        
        await terminalMonitor?.start()
    }
    
    func disconnect() async {
        guard isConnected else { return }
        
        await stopMonitoring()
        
        await terminalMonitor?.stop()
        terminalMonitor = nil
        
        await claudeSession?.terminate()
        claudeSession = nil
        
        claudeProcess?.terminate()
        claudeProcess = nil
        
        isConnected = false
        currentBinding = nil
    }
    
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async {
        guard isConnected else { return }
        
        messageCallback = onMessage
        
        monitoringTask = Task {
            await performMonitoring()
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        messageCallback = nil
    }
    
    private func performMonitoring() async {
        guard let session = claudeSession else { return }
        
        while !Task.isCancelled {
            do {
                if let messages = await session.readNewMessages() {
                    for message in messages {
                        emitMessage(message)
                    }
                }
                
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                break
            }
        }
    }
    
    func sendMessage(_ content: String) async throws {
        guard isConnected else {
            throw ChatConnectorError.notConnected
        }
        
        guard let session = claudeSession else {
            throw ChatConnectorError.notConnected
        }
        
        try await session.sendMessage(content)
    }
    
    func getAvailableSessions() async -> [ChatSessionInfo] {
        return await getClaudeCodeSessions()
    }
    
    func validateConnection(_ connectionString: String) async -> Bool {
        return !connectionString.isEmpty
    }
    
    func getConnectionStatus() async -> ChatConnectionStatus {
        return ChatConnectionStatus(
            isConnected: isConnected,
            connectorType: connectorType,
            connectionString: currentBinding?.connectionString,
            lastActivity: Date(),
            messageCount: 0
        )
    }
    
    private func emitMessage(_ message: ChatStreamMessage) {
        messageCallback?(message)
    }
    
    // MARK: - Claude Code Specific Implementation
    
    private func checkClaudeCodeInstallation() async -> Bool {
        // Check for Claude Code CLI
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func checkTerminalAccess() async -> Bool {
        // Check if we can access terminal applications
        let terminalApps = ["com.apple.Terminal", "com.googlecode.iterm2"]
        
        for bundleId in terminalApps {
            if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId }) {
                return true
            }
        }
        
        return true // Assume we can launch a terminal if needed
    }
    
    private func parseClaudeCodeConnection(_ connectionString: String) throws -> ClaudeCodeParams {
        // Parse "claude://mode?session=id&model=model"
        guard let url = URL(string: connectionString) else {
            throw ChatConnectorError.invalidConnectionString("Invalid URL format")
        }
        
        let mode = url.host ?? "interactive"
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        var sessionId: String?
        var model: String?
        
        for item in queryItems {
            switch item.name {
            case "session":
                sessionId = item.value
            case "model":
                model = item.value
            default:
                break
            }
        }
        
        return ClaudeCodeParams(
            mode: mode,
            sessionId: sessionId,
            model: model
        )
    }
    
    private func processTerminalOutput(_ output: String) async {
        // Parse terminal output for Claude Code messages
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if let message = parseClaudeCodeLine(line) {
                emitMessage(message)
            }
        }
    }
    
    private func parseClaudeCodeLine(_ line: String) -> ChatStreamMessage? {
        // Parse different Claude Code output formats
        
        // Assistant response pattern
        if line.hasPrefix("Claude:") || line.contains("🤖") {
            let content = extractMessageContent(from: line, prefix: "Claude:")
            return ChatStreamMessage(
                role: .assistant,
                content: content,
                timestamp: Date(),
                metadata: ["source": "claude_code", "raw": line]
            )
        }
        
        // User input pattern
        if line.hasPrefix(">") || line.hasPrefix("You:") {
            let content = extractMessageContent(from: line, prefix: ">")
            return ChatStreamMessage(
                role: .user,
                content: content,
                timestamp: Date(),
                metadata: ["source": "claude_code", "raw": line]
            )
        }
        
        // System message pattern
        if line.contains("[system]") || line.contains("[info]") {
            let content = extractMessageContent(from: line, prefix: "[system]")
            return ChatStreamMessage(
                role: .system,
                content: content,
                timestamp: Date(),
                metadata: ["source": "claude_code", "raw": line]
            )
        }
        
        return nil
    }
    
    private func extractMessageContent(from line: String, prefix: String) -> String {
        var content = line
        
        // Remove emoji indicators
        content = content.replacingOccurrences(of: "🤖", with: "")
        content = content.replacingOccurrences(of: "👤", with: "")
        
        // Remove prefixes
        if content.hasPrefix(prefix) {
            content = String(content.dropFirst(prefix.count))
        }
        
        if content.hasPrefix(">") {
            content = String(content.dropFirst(1))
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func getClaudeCodeSessions() async -> [ChatSessionInfo] {
        // Get available Claude Code sessions
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/claude")
        process.arguments = ["sessions", "--list", "--format", "json"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            // Parse JSON output
            if let data = output.data(using: .utf8),
               let sessions = try? JSONDecoder().decode([ClaudeCodeSessionInfo].self, from: data) {
                
                return sessions.map { session in
                    ChatSessionInfo(
                        id: session.id,
                        name: session.name,
                        type: .claudeCode,
                        isActive: session.active,
                        lastActivity: session.lastActivity
                    )
                }
            }
            
        } catch {
            logger.error("Failed to get Claude Code sessions: \(error.localizedDescription)")
        }
        
        return []
    }
}

// MARK: - Supporting Classes

actor CursorChatDetector {
    private let application: NSRunningApplication
    private var chatWindows: Set<String> = []
    private var lastSeenMessages: [String: String] = [:]
    
    init(application: NSRunningApplication) {
        self.application = application
    }
    
    func detectNewMessages() async -> [ChatStreamMessage]? {
        // Implementation for detecting new chat messages in Cursor
        return nil
    }
    
    func isChatElement(_ element: AXUIElement) async -> Bool {
        // Check if accessibility element is related to chat
        return false
    }
    
    func isChatWindow(_ element: AXUIElement) async -> Bool {
        // Check if window contains chat interface
        return false
    }
    
    func registerChatWindow(_ element: AXUIElement) async {
        // Register a new chat window for monitoring
    }
    
    func setActiveWindow(_ windowId: String) async {
        // Set the currently active chat window
    }
    
    func removeWindow(_ windowId: String) async {
        chatWindows.remove(windowId)
    }
    
    func processTextChange(_ text: String, element: AXUIElement) async {
        // Process text changes for potential chat messages
    }
    
    func processWindowTextChange(_ text: String, windowId: String) async {
        // Process text changes in specific window
    }
}

actor WindowMonitor {
    private let application: NSRunningApplication
    private let callback: (WindowEvent) -> Void
    private var isRunning = false
    
    init(application: NSRunningApplication, callback: @escaping (WindowEvent) -> Void) {
        self.application = application
        self.callback = callback
    }
    
    func start() async {
        isRunning = true
        // Start monitoring window events
    }
    
    func stop() async {
        isRunning = false
        // Stop monitoring
    }
}

actor ClaudeCodeSession {
    private let params: ClaudeCodeParams
    private var process: Process?
    private var messageBuffer: [String] = []
    
    init(params: ClaudeCodeParams) {
        self.params = params
    }
    
    static func create(params: ClaudeCodeParams) async throws -> ClaudeCodeSession {
        let session = ClaudeCodeSession(params: params)
        try await session.initialize()
        return session
    }
    
    private func initialize() async throws {
        // Initialize Claude Code session
        process = Process()
        process?.executableURL = URL(fileURLWithPath: "/usr/bin/claude")
        
        var arguments = ["chat"]
        
        if let sessionId = params.sessionId {
            arguments.append(contentsOf: ["--session", sessionId])
        }
        
        if let model = params.model {
            arguments.append(contentsOf: ["--model", model])
        }
        
        process?.arguments = arguments
        
        try process?.run()
    }
    
    func readNewMessages() async -> [ChatStreamMessage]? {
        // Read new messages from Claude Code session
        return nil
    }
    
    func sendMessage(_ content: String) async throws {
        // Send message to Claude Code session
        guard let process = process else {
            throw ChatConnectorError.notConnected
        }
        
        // Write to process stdin
        let data = (content + "\n").data(using: .utf8) ?? Data()
        if let pipe = process.standardInput as? Pipe {
            try pipe.fileHandleForWriting.write(data)
        }
    }
    
    func terminate() async {
        process?.terminate()
        process = nil
    }
}

actor TerminalMonitor {
    private let session: ClaudeCodeSession
    private let callback: (String) -> Void
    private var isRunning = false
    
    init(session: ClaudeCodeSession, callback: @escaping (String) -> Void) {
        self.session = session
        self.callback = callback
    }
    
    func start() async {
        isRunning = true
        // Start monitoring terminal output
    }
    
    func stop() async {
        isRunning = false
        // Stop monitoring
    }
}

// MARK: - Supporting Types

struct ClaudeCodeParams {
    let mode: String
    let sessionId: String?
    let model: String?
}

struct ClaudeCodeSessionInfo: Codable {
    let id: String
    let name: String
    let active: Bool
    let lastActivity: Date
}

struct WindowEvent {
    let type: WindowEventType
    let windowId: String
    let text: String?
    
    enum WindowEventType {
        case focused
        case closed
        case textChanged
    }
}

enum KeyCode {
    case `return`
    case space
    case character(Character)
    
    var cgKeyCode: CGKeyCode {
        switch self {
        case .return: return 36
        case .space: return 49
        case .character(let char):
            // Convert character to key code (simplified)
            return CGKeyCode(char.asciiValue ?? 0)
        }
    }
}