import Foundation
import SwiftData
import os

/// Chat stream service foundation for real-time chat bindings with Cursor and Claude Code
@MainActor
final class ChatStreamService: ObservableObject {
    static let shared = ChatStreamService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ChatStreamService")
    
    // Service state
    @Published var activeStreams: [ChatStreamBinding] = []
    @Published var isInitialized = false
    
    // Active connectors
    private var connectors: [UUID: any ChatConnector] = [:]
    private var modelContext: ModelContext?
    
    // Configuration
    private var globalConfig = ChatStreamConfiguration()
    
    // Performance tracking
    private var streamMetrics: [UUID: ChatStreamMetrics] = [:]
    
    private init() {}
    
    // MARK: - Service Lifecycle
    
    func initialize(with modelContext: ModelContext) async throws {
        guard !isInitialized else {
            logger.info("Chat stream service already initialized")
            return
        }
        
        self.modelContext = modelContext
        
        do {
            // Load existing stream bindings
            try await loadExistingStreams()
            
            // Initialize available connectors
            await initializeConnectors()
            
            // Start monitoring for active chat sessions
            await startChatSessionMonitoring()
            
            isInitialized = true
            logger.info("Chat stream service initialized with \(self.activeStreams.count) active streams")
            
        } catch {
            logger.error("Failed to initialize chat stream service: \(error.localizedDescription)")
            throw error
        }
    }
    
    func shutdown() async {
        logger.info("Shutting down chat stream service")
        
        // Stop all active streams
        for stream in activeStreams {
            await stopStream(stream.id)
        }
        
        // Cleanup connectors
        for connector in connectors.values {
            await connector.disconnect()
        }
        connectors.removeAll()
        
        isInitialized = false
        activeStreams.removeAll()
    }
    
    // MARK: - Stream Management
    
    func createStreamBinding(
        for project: Project,
        config: ChatStreamBindingConfig
    ) async throws -> ChatStreamBinding {
        guard isInitialized else {
            throw ChatStreamError.serviceNotInitialized
        }
        
        guard let modelContext = modelContext else {
            throw ChatStreamError.modelContextNotAvailable
        }
        
        // Validate configuration
        try validateStreamConfig(config)
        
        // Create stream model
        let streamModel = ChatStreamModel(
            projectId: project.id,
            name: config.name,
            streamType: config.streamType.rawValue,
            connectionString: config.connectionString,
            isActive: false,
            isEphemeral: config.isEphemeral,
            maxMessages: config.maxMessages,
            maxBytes: config.maxBytes,
            timeWindowMinutes: config.timeWindowMinutes,
            retentionPolicy: config.retentionPolicy.rawValue,
            project: project
        )
        
        modelContext.insert(streamModel)
        
        // Create stream binding
        let binding = ChatStreamBinding(
            id: streamModel.id,
            projectId: project.id,
            name: config.name,
            streamType: config.streamType,
            connectionString: config.connectionString,
            isActive: false,
            config: config,
            model: streamModel
        )
        
        activeStreams.append(binding)
        
        logger.info("Created chat stream binding: \(config.name) for project: \(project.name)")
        return binding
    }
    
    func startStream(_ streamId: UUID) async throws {
        guard let binding = getStreamBinding(streamId) else {
            throw ChatStreamError.streamNotFound(streamId)
        }
        
        guard !binding.isActive else {
            logger.info("Stream \(streamId) is already active")
            return
        }
        
        do {
            // Get or create connector
            let connector = try await getOrCreateConnector(for: binding)
            
            // Start the connection
            try await connector.connect(binding: binding)
            
            // Start message monitoring
            await startMessageMonitoring(for: binding, connector: connector)
            
            // Update binding state
            binding.isActive = true
            binding.model.isActive = true
            binding.model.lastConnectedAt = Date()
            
            // Initialize metrics tracking
            streamMetrics[streamId] = ChatStreamMetrics()
            
            logger.info("Started chat stream: \(binding.name)")
            
        } catch {
            logger.error("Failed to start stream \(streamId): \(error.localizedDescription)")
            throw ChatStreamError.connectionFailed(error.localizedDescription)
        }
    }
    
    func stopStream(_ streamId: UUID) async {
        guard let binding = getStreamBinding(streamId) else {
            logger.warning("Attempted to stop non-existent stream: \(streamId)")
            return
        }
        
        // Stop connector
        if let connector = connectors[streamId] {
            await connector.disconnect()
            connectors.removeValue(forKey: streamId)
        }
        
        // Update binding state
        binding.isActive = false
        binding.model.isActive = false
        
        // Clean up metrics
        streamMetrics.removeValue(forKey: streamId)
        
        logger.info("Stopped chat stream: \(binding.name)")
    }
    
    func deleteStreamBinding(_ streamId: UUID) async throws {
        guard let modelContext = modelContext else {
            throw ChatStreamError.modelContextNotAvailable
        }
        
        // Stop stream if active
        await stopStream(streamId)
        
        // Remove from active streams
        activeStreams.removeAll { $0.id == streamId }
        
        // Delete from database
        if let streamModel = try? await getStreamModel(streamId) {
            modelContext.delete(streamModel)
        }
        
        logger.info("Deleted chat stream binding: \(streamId)")
    }
    
    // MARK: - Message Processing
    
    func processIncomingMessage(
        streamId: UUID,
        message: ChatStreamMessage
    ) async throws {
        guard let binding = getStreamBinding(streamId) else {
            throw ChatStreamError.streamNotFound(streamId)
        }
        
        guard let modelContext = modelContext else {
            throw ChatStreamError.modelContextNotAvailable
        }
        
        // Apply retention policy
        await applyRetentionPolicy(for: binding)
        
        // Create message model
        let messageModel = ChatMessageModel(
            streamId: streamId,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            metadata: try JSONEncoder().encode(message.metadata),
            stream: binding.model
        )
        
        modelContext.insert(messageModel)
        binding.model.addMessage(messageModel)
        
        // Update metrics
        if var metrics = streamMetrics[streamId] {
            metrics.messageCount += 1
            metrics.totalBytes += message.content.count
            metrics.lastMessageAt = Date()
            streamMetrics[streamId] = metrics
        }
        
        // Process message for context extraction
        await processMessageForContext(message, in: binding)
        
        logger.debug("Processed message for stream \(binding.name): \(message.content.prefix(50))...")
    }
    
    private func processMessageForContext(
        _ message: ChatStreamMessage,
        in binding: ChatStreamBinding
    ) async {
        // Extract context-relevant information from chat messages
        // This could include:
        // - File references
        // - Error messages
        // - Code snippets
        // - Project-specific terminology
        
        // For now, just track message patterns
        await trackMessagePatterns(message, in: binding)
    }
    
    private func trackMessagePatterns(
        _ message: ChatStreamMessage,
        in binding: ChatStreamBinding
    ) async {
        // Analyze message content for patterns that could enhance context
        let content = message.content.lowercased()
        
        // Track file references
        if content.contains("file:") || content.contains(".swift") || content.contains(".js") {
            logger.debug("Detected file reference in chat: \(binding.name)")
        }
        
        // Track error patterns
        if content.contains("error") || content.contains("failed") || content.contains("exception") {
            logger.debug("Detected error discussion in chat: \(binding.name)")
        }
        
        // Track code discussions
        if content.contains("function") || content.contains("class") || content.contains("variable") {
            logger.debug("Detected code discussion in chat: \(binding.name)")
        }
    }
    
    // MARK: - Context Export
    
    func exportStreamContext(
        _ streamId: UUID,
        format: ChatContextFormat = .markdown
    ) async throws -> ChatContextExport {
        guard let binding = getStreamBinding(streamId) else {
            throw ChatStreamError.streamNotFound(streamId)
        }
        
        let messages = binding.model.messages.sorted { $0.timestamp < $1.timestamp }
        let exportContent = try await formatMessagesForExport(messages, format: format)
        
        let export = ChatContextExport(
            streamId: streamId,
            streamName: binding.name,
            projectId: binding.projectId,
            format: format,
            content: exportContent,
            messageCount: messages.count,
            timeRange: ChatTimeRange(
                start: messages.first?.timestamp ?? Date(),
                end: messages.last?.timestamp ?? Date()
            ),
            exportedAt: Date()
        )
        
        logger.info("Exported context for stream \(binding.name): \(messages.count) messages")
        return export
    }
    
    func getActiveContextSummary(
        for projectId: UUID
    ) async throws -> ProjectChatContextSummary {
        let projectStreams = activeStreams.filter { $0.projectId == projectId && $0.isActive }
        
        var summaries: [StreamContextSummary] = []
        var totalMessages = 0
        var totalBytes = 0
        
        for stream in projectStreams {
            let messageCount = stream.model.messageCount
            let bytes = stream.model.totalBytes
            
            summaries.append(StreamContextSummary(
                streamId: stream.id,
                streamName: stream.name,
                messageCount: messageCount,
                totalBytes: bytes,
                isActive: stream.isActive,
                lastActivity: stream.model.lastMessageAt
            ))
            
            totalMessages += messageCount
            totalBytes += bytes
        }
        
        return ProjectChatContextSummary(
            projectId: projectId,
            activeStreams: summaries,
            totalMessages: totalMessages,
            totalBytes: totalBytes,
            generatedAt: Date()
        )
    }
    
    // MARK: - Configuration
    
    func updateGlobalConfig(_ config: ChatStreamConfiguration) async {
        globalConfig = config
        
        // Apply config to active streams
        for binding in activeStreams {
            await applyConfigToBinding(binding, config: config)
        }
        
        logger.info("Updated global chat stream configuration")
    }
    
    func updateStreamConfig(
        _ streamId: UUID,
        config: ChatStreamBindingConfig
    ) async throws {
        guard let binding = getStreamBinding(streamId) else {
            throw ChatStreamError.streamNotFound(streamId)
        }
        
        try validateStreamConfig(config)
        
        binding.config = config
        binding.model.name = config.name
        binding.model.maxMessages = config.maxMessages
        binding.model.maxBytes = config.maxBytes
        binding.model.timeWindowMinutes = config.timeWindowMinutes
        binding.model.retentionPolicy = config.retentionPolicy.rawValue
        
        logger.info("Updated configuration for stream: \(binding.name)")
    }
    
    // MARK: - Monitoring and Health
    
    func getStreamMetrics(_ streamId: UUID) -> ChatStreamMetrics? {
        return streamMetrics[streamId]
    }
    
    func getAllStreamMetrics() -> [UUID: ChatStreamMetrics] {
        return streamMetrics
    }
    
    func getServiceHealth() async -> ChatStreamServiceHealth {
        let activeCount = activeStreams.filter { $0.isActive }.count
        let totalCount = activeStreams.count
        
        var connectorStatuses: [ChatConnectorType: Bool] = [:]
        for type in ChatConnectorType.allCases {
            connectorStatuses[type] = await isConnectorAvailable(type)
        }
        
        let issues = await detectHealthIssues()
        
        return ChatStreamServiceHealth(
            isHealthy: issues.isEmpty,
            activeStreams: activeCount,
            totalStreams: totalCount,
            connectorAvailability: connectorStatuses,
            issues: issues,
            checkedAt: Date()
        )
    }
    
    // MARK: - Private Implementation
    
    private func loadExistingStreams() async throws {
        guard let modelContext = modelContext else {
            throw ChatStreamError.modelContextNotAvailable
        }
        
        let fetchDescriptor = FetchDescriptor<ChatStreamModel>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        let streamModels = try modelContext.fetch(fetchDescriptor)
        
        for model in streamModels {
            let config = ChatStreamBindingConfig(
                name: model.name,
                streamType: ChatConnectorType(rawValue: model.streamType) ?? .cursor,
                connectionString: model.connectionString,
                isEphemeral: model.isEphemeral,
                maxMessages: model.maxMessages,
                maxBytes: model.maxBytes,
                timeWindowMinutes: model.timeWindowMinutes,
                retentionPolicy: ChatRetentionPolicy(rawValue: model.retentionPolicy) ?? .ephemeral
            )
            
            let binding = ChatStreamBinding(
                id: model.id,
                projectId: model.projectId,
                name: model.name,
                streamType: ChatConnectorType(rawValue: model.streamType) ?? .cursor,
                connectionString: model.connectionString,
                isActive: false, // Will be activated separately
                config: config,
                model: model
            )
            
            activeStreams.append(binding)
        }
        
        logger.info("Loaded \(self.activeStreams.count) existing chat stream bindings")
    }
    
    private func initializeConnectors() async {
        // Initialize available connector types
        for connectorType in ChatConnectorType.allCases {
            if await isConnectorAvailable(connectorType) {
                logger.info("Connector available: \(connectorType.rawValue)")
            } else {
                logger.warning("Connector not available: \(connectorType.rawValue)")
            }
        }
    }
    
    private func startChatSessionMonitoring() async {
        // Start monitoring for new chat sessions that could be bound
        // This would integrate with system notifications, window monitoring, etc.
        logger.info("Started chat session monitoring")
    }
    
    private func getOrCreateConnector(for binding: ChatStreamBinding) async throws -> any ChatConnector {
        if let existingConnector = connectors[binding.id] {
            return existingConnector
        }
        
        let connector = try createConnector(for: binding.streamType)
        connectors[binding.id] = connector
        return connector
    }
    
    private func createConnector(for type: ChatConnectorType) throws -> any ChatConnector {
        switch type {
        case .cursor:
            return CursorChatConnector()
        case .claudeCode:
            return ClaudeCodeChatConnector()
        case .generic:
            return GenericChatConnector()
        }
    }
    
    private func isConnectorAvailable(_ type: ChatConnectorType) async -> Bool {
        do {
            let connector = try createConnector(for: type)
            return await connector.isAvailable()
        } catch {
            return false
        }
    }
    
    private func startMessageMonitoring(
        for binding: ChatStreamBinding,
        connector: any ChatConnector
    ) async {
        // Set up message monitoring for the connector
        await connector.startMonitoring { [weak self] message in
            Task { @MainActor in
                do {
                    try await self?.processIncomingMessage(streamId: binding.id, message: message)
                } catch {
                    self?.logger.error("Failed to process incoming message: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func applyRetentionPolicy(for binding: ChatStreamBinding) async {
        let policy = binding.config.retentionPolicy
        
        switch policy {
        case .ephemeral:
            // Remove messages outside time window
            let cutoffTime = Date().addingTimeInterval(-Double(binding.config.timeWindowMinutes * 60))
            let messagesToRemove = binding.model.messages.filter { $0.timestamp < cutoffTime }
            
            for message in messagesToRemove {
                binding.model.messages.removeAll { $0.id == message.id }
            }
            
        case .persistent:
            // Keep all messages but enforce count limit
            let maxMessages = binding.config.maxMessages
            if binding.model.messages.count > maxMessages {
                let excess = binding.model.messages.count - maxMessages
                let sortedMessages = binding.model.messages.sorted { $0.timestamp < $1.timestamp }
                let messagesToRemove = Array(sortedMessages.prefix(excess))
                
                for message in messagesToRemove {
                    binding.model.messages.removeAll { $0.id == message.id }
                }
            }
            
        case .sliding:
            // Combine time and count limits
            binding.model.enforceRetentionPolicy()
        }
    }
    
    private func formatMessagesForExport(
        _ messages: [ChatMessageModel],
        format: ChatContextFormat
    ) async throws -> String {
        switch format {
        case .markdown:
            return formatAsMarkdown(messages)
        case .json:
            return try formatAsJSON(messages)
        case .text:
            return formatAsText(messages)
        }
    }
    
    private func formatAsMarkdown(_ messages: [ChatMessageModel]) -> String {
        var markdown = "# Chat Context Export\n\n"
        markdown += "Generated: \(Date().formatted())\n\n"
        
        for message in messages {
            markdown += "## \(message.role.capitalized) - \(message.timestamp.formatted())\n\n"
            markdown += "\(message.content)\n\n"
            markdown += "---\n\n"
        }
        
        return markdown
    }
    
    private func formatAsJSON(_ messages: [ChatMessageModel]) throws -> String {
        let exportMessages = messages.map { message in
            ExportChatMessage(
                role: message.role,
                content: message.content,
                timestamp: message.timestamp
            )
        }
        
        let data = try JSONEncoder().encode(exportMessages)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func formatAsText(_ messages: [ChatMessageModel]) -> String {
        return messages.map { message in
            "[\(message.timestamp.formatted())] \(message.role): \(message.content)"
        }.joined(separator: "\n\n")
    }
    
    private func applyConfigToBinding(
        _ binding: ChatStreamBinding,
        config: ChatStreamConfiguration
    ) async {
        // Apply global configuration to specific binding
        if config.globalMaxMessages != nil {
            binding.config.maxMessages = min(binding.config.maxMessages, config.globalMaxMessages!)
        }
        
        if config.globalMaxBytes != nil {
            binding.config.maxBytes = min(binding.config.maxBytes, config.globalMaxBytes!)
        }
    }
    
    private func detectHealthIssues() async -> [String] {
        var issues: [String] = []
        
        // Check for inactive streams that should be active
        let inactiveStreams = activeStreams.filter { $0.config.autoReconnect && !$0.isActive }
        if !inactiveStreams.isEmpty {
            issues.append("Found \(inactiveStreams.count) streams that should auto-reconnect but are inactive")
        }
        
        // Check for streams with high message volumes
        for (streamId, metrics) in streamMetrics {
            if metrics.messageCount > 1000 {
                issues.append("Stream \(streamId) has high message count: \(metrics.messageCount)")
            }
        }
        
        return issues
    }
    
    private func validateStreamConfig(_ config: ChatStreamBindingConfig) throws {
        guard !config.name.isEmpty else {
            throw ChatStreamError.invalidConfiguration("Stream name cannot be empty")
        }
        
        guard !config.connectionString.isEmpty else {
            throw ChatStreamError.invalidConfiguration("Connection string cannot be empty")
        }
        
        guard config.maxMessages > 0 else {
            throw ChatStreamError.invalidConfiguration("Max messages must be greater than 0")
        }
        
        guard config.maxBytes > 0 else {
            throw ChatStreamError.invalidConfiguration("Max bytes must be greater than 0")
        }
        
        guard config.timeWindowMinutes > 0 else {
            throw ChatStreamError.invalidConfiguration("Time window must be greater than 0")
        }
    }
    
    private func getStreamBinding(_ streamId: UUID) -> ChatStreamBinding? {
        return activeStreams.first { $0.id == streamId }
    }
    
    private func getStreamModel(_ streamId: UUID) async throws -> ChatStreamModel? {
        guard let modelContext = modelContext else {
            throw ChatStreamError.modelContextNotAvailable
        }
        
        let fetchDescriptor = FetchDescriptor<ChatStreamModel>(
            predicate: #Predicate { $0.id == streamId }
        )
        
        return try modelContext.fetch(fetchDescriptor).first
    }
}

// MARK: - Supporting Types

final class ChatStreamBinding: ObservableObject, Identifiable {
    let id: UUID
    let projectId: UUID
    var name: String
    let streamType: ChatConnectorType
    let connectionString: String
    @Published var isActive: Bool
    var config: ChatStreamBindingConfig
    let model: ChatStreamModel
    
    init(
        id: UUID,
        projectId: UUID,
        name: String,
        streamType: ChatConnectorType,
        connectionString: String,
        isActive: Bool,
        config: ChatStreamBindingConfig,
        model: ChatStreamModel
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.streamType = streamType
        self.connectionString = connectionString
        self.isActive = isActive
        self.config = config
        self.model = model
    }
}

struct ChatStreamBindingConfig {
    var name: String
    let streamType: ChatConnectorType
    let connectionString: String
    let isEphemeral: Bool
    var maxMessages: Int
    var maxBytes: Int
    var timeWindowMinutes: Int
    let retentionPolicy: ChatRetentionPolicy
    let autoReconnect: Bool
    
    init(
        name: String,
        streamType: ChatConnectorType,
        connectionString: String,
        isEphemeral: Bool = true,
        maxMessages: Int = 100,
        maxBytes: Int = 1_000_000,
        timeWindowMinutes: Int = 60,
        retentionPolicy: ChatRetentionPolicy = .ephemeral,
        autoReconnect: Bool = false
    ) {
        self.name = name
        self.streamType = streamType
        self.connectionString = connectionString
        self.isEphemeral = isEphemeral
        self.maxMessages = maxMessages
        self.maxBytes = maxBytes
        self.timeWindowMinutes = timeWindowMinutes
        self.retentionPolicy = retentionPolicy
        self.autoReconnect = autoReconnect
    }
}

struct ChatStreamConfiguration {
    let enableGlobalMonitoring: Bool
    let globalMaxMessages: Int?
    let globalMaxBytes: Int?
    let defaultRetentionPolicy: ChatRetentionPolicy
    let enableContextExtraction: Bool
    let enablePatternDetection: Bool
    
    init(
        enableGlobalMonitoring: Bool = true,
        globalMaxMessages: Int? = nil,
        globalMaxBytes: Int? = nil,
        defaultRetentionPolicy: ChatRetentionPolicy = .ephemeral,
        enableContextExtraction: Bool = true,
        enablePatternDetection: Bool = true
    ) {
        self.enableGlobalMonitoring = enableGlobalMonitoring
        self.globalMaxMessages = globalMaxMessages
        self.globalMaxBytes = globalMaxBytes
        self.defaultRetentionPolicy = defaultRetentionPolicy
        self.enableContextExtraction = enableContextExtraction
        self.enablePatternDetection = enablePatternDetection
    }
}

enum ChatConnectorType: String, CaseIterable, Codable {
    case cursor = "cursor"
    case claudeCode = "claude_code"
    case generic = "generic"
    
    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claudeCode: return "Claude Code"
        case .generic: return "Generic Terminal"
        }
    }
}

enum ChatRetentionPolicy: String, CaseIterable, Codable {
    case ephemeral = "ephemeral"
    case persistent = "persistent"
    case sliding = "sliding"
    
    var displayName: String {
        switch self {
        case .ephemeral: return "Ephemeral (Time-based)"
        case .persistent: return "Persistent (Count-based)"
        case .sliding: return "Sliding Window (Time + Count)"
        }
    }
}

enum ChatContextFormat: String, CaseIterable {
    case markdown = "markdown"
    case json = "json"
    case text = "text"
}

struct ChatStreamMessage {
    let role: ChatRole
    let content: String
    let timestamp: Date
    let metadata: [String: String]
    
    enum ChatRole: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
}

struct ExportChatMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date
}

struct ChatContextExport {
    let streamId: UUID
    let streamName: String
    let projectId: UUID
    let format: ChatContextFormat
    let content: String
    let messageCount: Int
    let timeRange: ChatTimeRange
    let exportedAt: Date
}

struct ChatTimeRange {
    let start: Date
    let end: Date
}

struct ProjectChatContextSummary {
    let projectId: UUID
    let activeStreams: [StreamContextSummary]
    let totalMessages: Int
    let totalBytes: Int
    let generatedAt: Date
}

struct StreamContextSummary {
    let streamId: UUID
    let streamName: String
    let messageCount: Int
    let totalBytes: Int
    let isActive: Bool
    let lastActivity: Date?
}

struct ChatStreamMetrics {
    var messageCount: Int = 0
    var totalBytes: Int = 0
    var lastMessageAt: Date?
    var connectionsCount: Int = 0
    var disconnectionsCount: Int = 0
    let startedAt: Date = Date()
}

struct ChatStreamServiceHealth {
    let isHealthy: Bool
    let activeStreams: Int
    let totalStreams: Int
    let connectorAvailability: [ChatConnectorType: Bool]
    let issues: [String]
    let checkedAt: Date
}

enum ChatStreamError: LocalizedError {
    case serviceNotInitialized
    case modelContextNotAvailable
    case streamNotFound(UUID)
    case connectionFailed(String)
    case invalidConfiguration(String)
    case connectorNotAvailable(ChatConnectorType)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "Chat stream service is not initialized"
        case .modelContextNotAvailable:
            return "Model context is not available"
        case .streamNotFound(let id):
            return "Chat stream not found: \(id)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .connectorNotAvailable(let type):
            return "Connector not available: \(type.rawValue)"
        }
    }
}