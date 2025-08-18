import Foundation

enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .user:
            return "person.circle"
        case .assistant:
            return "brain.head.profile"
        case .system:
            return "gear.circle"
        }
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date?
    let tokenCount: Int?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date? = nil,
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenCount = tokenCount
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Content Processing
extension ChatMessage {
    var isCodeOnly: Bool {
        let codeBlockPattern = #"```[\s\S]*?```"#
        let inlineCodePattern = #"`[^`\n]+`"#
        
        let codeContent = content.extractMatches(pattern: codeBlockPattern) +
                         content.extractMatches(pattern: inlineCodePattern)
        
        let totalCodeLength = codeContent.joined().count
        let totalContentLength = content.count
        
        // Consider it code-only if more than 80% is code
        return totalCodeLength > Int(Double(totalContentLength) * 0.8)
    }
    
    var extractedCode: [String] {
        let codeBlockPattern = #"```(?:\w+\n)?([\s\S]*?)```"#
        let inlineCodePattern = #"`([^`\n]+)`"#
        
        return content.extractMatches(pattern: codeBlockPattern) +
               content.extractMatches(pattern: inlineCodePattern)
    }
    
    var displayContent: String {
        content.count > 200 ? String(content.prefix(200)) + "..." : content
    }
    
    var estimatedTokens: Int {
        tokenCount ?? Int(Double(content.count) / 4.0) // Rough estimation: 4 chars per token
    }
}

struct ChatSnippet: Codable, Identifiable, Equatable {
    let id: UUID
    let threadTitle: String?
    let messages: [ChatMessage]
    let capturedAt: Date
    let sourceApp: String // "cursor", "vscode", etc.
    let totalTokenCount: Int
    
    init(
        id: UUID = UUID(),
        threadTitle: String? = nil,
        messages: [ChatMessage],
        capturedAt: Date = Date(),
        sourceApp: String = "cursor"
    ) {
        self.id = id
        self.threadTitle = threadTitle
        self.messages = messages
        self.capturedAt = capturedAt
        self.sourceApp = sourceApp
        self.totalTokenCount = messages.reduce(0) { $0 + $1.estimatedTokens }
    }
    
    static func == (lhs: ChatSnippet, rhs: ChatSnippet) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat Processing
extension ChatSnippet {
    var lastUserMessage: ChatMessage? {
        messages.last { $0.role == .user }
    }
    
    var lastAssistantMessage: ChatMessage? {
        messages.last { $0.role == .assistant }
    }
    
    var userMessageCount: Int {
        messages.filter { $0.role == .user }.count
    }
    
    var assistantMessageCount: Int {
        messages.filter { $0.role == .assistant }.count
    }
    
    func filterToCodeOnly() -> ChatSnippet {
        let codeMessages = messages.compactMap { message -> ChatMessage? in
            let codeContent = message.extractedCode.joined(separator: "\n")
            guard !codeContent.isEmpty else { return nil }
            
            return ChatMessage(
                id: message.id,
                role: message.role,
                content: codeContent,
                timestamp: message.timestamp,
                tokenCount: message.tokenCount
            )
        }
        
        return ChatSnippet(
            id: id,
            threadTitle: threadTitle,
            messages: codeMessages,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        )
    }
    
    func truncateToTokenLimit(_ limit: Int) -> ChatSnippet {
        var truncatedMessages: [ChatMessage] = []
        var currentTokenCount = 0
        
        // Process messages in reverse order to keep the most recent
        for message in messages.reversed() {
            let messageTokens = message.estimatedTokens
            if currentTokenCount + messageTokens <= limit {
                truncatedMessages.insert(message, at: 0)
                currentTokenCount += messageTokens
            } else {
                break
            }
        }
        
        return ChatSnippet(
            id: id,
            threadTitle: threadTitle,
            messages: truncatedMessages,
            capturedAt: capturedAt,
            sourceApp: sourceApp
        )
    }
    
    func formatForPrompt() -> String {
        var result = ""
        
        if let title = threadTitle, !title.isEmpty {
            result += "Thread: \"\(title)\"\n\n"
        }
        
        for message in messages {
            result += "\(message.role.displayName): \(message.content)\n\n"
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - String Extension for Pattern Matching
private extension String {
    func extractMatches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: count))
        return matches.compactMap { match in
            let range = match.range(at: match.numberOfRanges > 1 ? 1 : 0)
            guard range.location != NSNotFound else { return nil }
            return String(self[Range(range, in: self)!])
        }
    }
}