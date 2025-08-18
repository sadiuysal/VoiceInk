import Foundation
import SwiftData
import os

struct ContextPayload: Codable {
    let dictionaryEntries: [DictionaryEntry]
    let chatSnippets: [ChatSnippet]
    let clipboardContext: String?
    let screenCaptureContext: String?
    let filesystemTerms: [String]
    let metadata: ContextMetadata
    
    init(
        dictionaryEntries: [DictionaryEntry] = [],
        chatSnippets: [ChatSnippet] = [],
        clipboardContext: String? = nil,
        screenCaptureContext: String? = nil,
        filesystemTerms: [String] = [],
        metadata: ContextMetadata = ContextMetadata()
    ) {
        self.dictionaryEntries = dictionaryEntries
        self.chatSnippets = chatSnippets
        self.clipboardContext = clipboardContext
        self.screenCaptureContext = screenCaptureContext
        self.filesystemTerms = filesystemTerms
        self.metadata = metadata
    }
}

struct ContextMetadata: Codable {
    let composedAt: Date
    let activeProfileId: UUID?
    let boundPackIds: [UUID]
    let chatHarvestAttempted: Bool
    let chatHarvestSuccessful: Bool
    let totalTokenCount: Int
    
    init(
        composedAt: Date = Date(),
        activeProfileId: UUID? = nil,
        boundPackIds: [UUID] = [],
        chatHarvestAttempted: Bool = false,
        chatHarvestSuccessful: Bool = false,
        totalTokenCount: Int = 0
    ) {
        self.composedAt = composedAt
        self.activeProfileId = activeProfileId
        self.boundPackIds = boundPackIds
        self.chatHarvestAttempted = chatHarvestAttempted
        self.chatHarvestSuccessful = chatHarvestSuccessful
        self.totalTokenCount = totalTokenCount
    }
}

@MainActor
final class ContextBindingService: ObservableObject {
    static let shared = ContextBindingService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ContextBinding")
    private let contextStore = ContextIndexStore.shared
    
    private init() {}
    
    // MARK: - Main Context Composition
    
    /// Composes a complete context payload for the given profile and settings
    func composeContextPayload(
        for profile: PowerModeConfig?,
        includeTraditionalSources: Bool = true,
        harvestChat: Bool = true
    ) async -> ContextPayload {
        let startTime = Date()
        
        // Collect bound pack entries
        let boundPackIds = profile?.boundPackIds ?? []
        let dictionaryEntries = await getDictionaryEntries(for: boundPackIds)
        
        // Attempt chat harvest if enabled
        var chatSnippets: [ChatSnippet] = []
        var chatHarvestAttempted = false
        var chatHarvestSuccessful = false
        
        if harvestChat && UserDefaults.standard.autoCaptureChat {
            chatHarvestAttempted = true
            if let chatSnippet = await harvestChatIfApplicable() {
                chatSnippets = [chatSnippet]
                chatHarvestSuccessful = true
            }
        }
        
        // Collect traditional context sources if enabled
        var clipboardContext: String?
        var screenCaptureContext: String?
        var filesystemTerms: [String] = []
        
        if includeTraditionalSources {
            // Get clipboard context (from existing enhancement service)
            if UserDefaults.standard.bool(forKey: "useClipboardContext") {
                clipboardContext = getClipboardContext()
            }
            
            // Get screen capture context (from existing enhancement service)
            if UserDefaults.standard.bool(forKey: "useScreenCaptureContext") {
                screenCaptureContext = await getScreenCaptureContext()
            }
            
            // Get filesystem terms (from existing service)
            if UserDefaults.standard.useFilesystemContext {
                filesystemTerms = FilesystemContextService.shared.currentGlossary(topK: 15)
            }
        }
        
        // Calculate total token count
        let totalTokenCount = calculateTokenCount(
            dictionaryEntries: dictionaryEntries,
            chatSnippets: chatSnippets,
            clipboardContext: clipboardContext,
            screenCaptureContext: screenCaptureContext,
            filesystemTerms: filesystemTerms
        )
        
        let metadata = ContextMetadata(
            composedAt: Date(),
            activeProfileId: profile?.id,
            boundPackIds: boundPackIds,
            chatHarvestAttempted: chatHarvestAttempted,
            chatHarvestSuccessful: chatHarvestSuccessful,
            totalTokenCount: totalTokenCount
        )
        
        let payload = ContextPayload(
            dictionaryEntries: dictionaryEntries,
            chatSnippets: chatSnippets,
            clipboardContext: clipboardContext,
            screenCaptureContext: screenCaptureContext,
            filesystemTerms: filesystemTerms,
            metadata: metadata
        )
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        logger.info("Context composition completed in \(elapsedTime * 1000, specifier: "%.1f")ms - tokens: \(totalTokenCount)")
        
        return payload
    }
    
    // MARK: - Dictionary Entries
    
    private func getDictionaryEntries(for packIds: [UUID]) async -> [DictionaryEntry] {
        guard !packIds.isEmpty else { return [] }
        
        do {
            return try await contextStore.getDictionaryEntries(for: packIds)
        } catch {
            logger.error("Failed to get dictionary entries: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Chat Harvest
    
    private func harvestChatIfApplicable() async -> ChatSnippet? {
        return await ChatHarvestService.shared.harvestLastMessagesIfCursorContext(
            maxMessages: UserDefaults.standard.chatLastMessages,
            tokenCap: UserDefaults.standard.chatTokenCap,
            codeOnly: UserDefaults.standard.chatCodeOnly
        )
    }
    
    // MARK: - Traditional Context Sources
    
    private func getClipboardContext() -> String? {
        guard let clipboardString = NSPasteboard.general.string(forType: .string),
              !clipboardString.isEmpty else {
            return nil
        }
        
        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func getScreenCaptureContext() async -> String? {
        // This integrates with the existing ScreenCaptureService
        // Implementation would depend on existing service structure
        return nil
    }
    
    // MARK: - Token Counting
    
    private func calculateTokenCount(
        dictionaryEntries: [DictionaryEntry],
        chatSnippets: [ChatSnippet],
        clipboardContext: String?,
        screenCaptureContext: String?,
        filesystemTerms: [String]
    ) -> Int {
        var tokenCount = 0
        
        // Dictionary entries (estimate 1 token per term + some overhead)
        tokenCount += dictionaryEntries.count * 2
        
        // Chat snippets
        tokenCount += chatSnippets.reduce(0) { $0 + $1.totalTokenCount }
        
        // Clipboard context (rough estimate: 4 chars per token)
        if let clipboard = clipboardContext {
            tokenCount += max(1, clipboard.count / 4)
        }
        
        // Screen capture context
        if let screenCapture = screenCaptureContext {
            tokenCount += max(1, screenCapture.count / 4)
        }
        
        // Filesystem terms
        tokenCount += filesystemTerms.count
        
        return tokenCount
    }
    
    // MARK: - Context Formatting for Prompts
    
    func formatContextForPrompt(_ payload: ContextPayload) -> String {
        var sections: [String] = []
        
        // Project Context Section
        if !payload.dictionaryEntries.isEmpty || !payload.filesystemTerms.isEmpty {
            var projectSection = "<PROJECT_CONTEXT>\n"
            
            if !payload.dictionaryEntries.isEmpty {
                let terms = payload.dictionaryEntries.map { $0.term }.joined(separator: ", ")
                projectSection += "Dictionary Terms: \(terms)\n"
            }
            
            if !payload.filesystemTerms.isEmpty {
                projectSection += "Project Terms: \(payload.filesystemTerms.joined(separator: ", "))\n"
            }
            
            projectSection += "</PROJECT_CONTEXT>"
            sections.append(projectSection)
        }
        
        // Chat Context Section
        if !payload.chatSnippets.isEmpty {
            var chatSection = "<CONVERSATION_CONTEXT>\n"
            chatSection += "Recent Chat from Cursor IDE:\n\n"
            
            for snippet in payload.chatSnippets {
                chatSection += snippet.formatForPrompt()
                chatSection += "\n"
            }
            
            chatSection += "</CONVERSATION_CONTEXT>"
            sections.append(chatSection)
        }
        
        // Additional Context Section
        if payload.clipboardContext != nil || payload.screenCaptureContext != nil {
            var additionalSection = "<ADDITIONAL_CONTEXT>\n"
            
            if let clipboard = payload.clipboardContext {
                additionalSection += "Clipboard: \(clipboard)\n"
            }
            
            if let screenCapture = payload.screenCaptureContext {
                additionalSection += "Screen: \(screenCapture)\n"
            }
            
            additionalSection += "</ADDITIONAL_CONTEXT>"
            sections.append(additionalSection)
        }
        
        return sections.joined(separator: "\n\n")
    }
}

// MARK: - ContextIndexStore Extensions

extension ContextIndexStore {
    func getDictionaryEntries(for packIds: [UUID]) async throws -> [DictionaryEntry] {
        guard let modelContext = modelContext else {
            throw ContextError.storeNotAvailable
        }
        
        let packIdStrings = packIds.map { $0.uuidString }
        let descriptor = FetchDescriptor<ContextPack>(
            predicate: #Predicate<ContextPack> { pack in
                packIdStrings.contains(pack.id.uuidString) && pack.isActive
            }
        )
        
        let packs = try modelContext.fetch(descriptor)
        let allEntries = packs.flatMap { $0.entries }
        
        // Sort by importance and frequency
        return allEntries.sorted { first, second in
            if first.importance != second.importance {
                return first.importance > second.importance
            }
            return first.frequency > second.frequency
        }
    }
}

enum ContextError: LocalizedError {
    case storeNotAvailable
    case invalidPackId(UUID)
    case harvestTimeout
    
    var errorDescription: String? {
        switch self {
        case .storeNotAvailable:
            return "Context store is not available"
        case .invalidPackId(let id):
            return "Invalid context pack ID: \(id)"
        case .harvestTimeout:
            return "Context harvest timed out"
        }
    }
}