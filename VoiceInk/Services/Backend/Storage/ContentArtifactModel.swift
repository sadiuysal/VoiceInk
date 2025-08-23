import Foundation
import SwiftData

/// SwiftData model for storing content artifacts with content-addressable storage
@Model
final class ContentArtifactModel {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var contentHash: String // SHA-256 hash for content-addressable storage
    
    // Artifact metadata
    var artifactType: String // ArtifactType.rawValue
    var version: String
    var sourceId: UUID
    var pluginId: String
    var sourceType: String
    var sourcePath: String?
    
    // Content metadata
    var title: String?
    var contentDescription: String?
    var author: String?
    var tags: [String]
    var score: Int
    var language: String?
    var fileSize: Int
    var lineCount: Int?
    var customMetadata: Data // JSON-encoded custom metadata
    
    // Content storage
    var contentFormat: String // ContentFormat.rawValue
    var contentEncoding: String
    var contentData: Data
    var compressionAlgorithm: String?
    
    // Lifecycle
    var createdAt: Date
    var lastAccessedAt: Date
    var ttl: TimeInterval?
    var isEphemeral: Bool
    
    // Relationships
    @Relationship(deleteRule: .nullify) var source: ContextSource?
    @Relationship(deleteRule: .cascade, inverse: \ContextSegmentModel.artifact)
    var segments: [ContextSegmentModel] = []
    
    init(
        id: UUID = UUID(),
        contentHash: String,
        artifactType: String,
        version: String,
        sourceId: UUID,
        pluginId: String,
        sourceType: String,
        sourcePath: String? = nil,
        title: String? = nil,
        description: String? = nil,
        author: String? = nil,
        tags: [String] = [],
        score: Int = 1,
        language: String? = nil,
        fileSize: Int = 0,
        lineCount: Int? = nil,
        customMetadata: Data = Data(),
        contentFormat: String,
        contentEncoding: String = "utf-8",
        contentData: Data,
        compressionAlgorithm: String? = nil,
        ttl: TimeInterval? = nil,
        isEphemeral: Bool = false,
        source: ContextSource? = nil
    ) {
        self.id = id
        self.contentHash = contentHash
        self.artifactType = artifactType
        self.version = version
        self.sourceId = sourceId
        self.pluginId = pluginId
        self.sourceType = sourceType
        self.sourcePath = sourcePath
        self.title = title
        self.contentDescription = description
        self.author = author
        self.tags = tags
        self.score = score
        self.language = language
        self.fileSize = fileSize
        self.lineCount = lineCount
        self.customMetadata = customMetadata
        self.contentFormat = contentFormat
        self.contentEncoding = contentEncoding
        self.contentData = contentData
        self.compressionAlgorithm = compressionAlgorithm
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.ttl = ttl
        self.isEphemeral = isEphemeral
        self.source = source
    }
    
    func updateLastAccessed() {
        lastAccessedAt = Date()
    }
    
    func isExpired() -> Bool {
        guard let ttl = ttl else { return false }
        return Date().timeIntervalSince(createdAt) > ttl
    }
    
    func getCustomMetadata<T: Codable>(_ type: T.Type) -> T? {
        guard !customMetadata.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: customMetadata)
    }
    
    func setCustomMetadata<T: Codable>(_ metadata: T) throws {
        self.customMetadata = try JSONEncoder().encode(metadata)
    }
}

/// SwiftData model for enhanced context segments with artifact relationships
@Model
final class ContextSegmentModel {
    @Attribute(.unique) var id: UUID
    var content: String
    var kind: String // SegmentKind.rawValue
    var tags: [String]
    var score: Int
    var anchor: String
    var startLine: Int
    var endLine: Int
    var contentHash: String
    
    // Artifact relationship
    @Relationship var artifact: ContentArtifactModel?
    
    // Legacy relationships (maintained for backward compatibility)
    @Relationship var document: IndexedDocument?
    
    // Metadata
    var createdAt: Date
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        content: String,
        kind: String,
        tags: [String] = [],
        score: Int = 1,
        anchor: String,
        startLine: Int,
        endLine: Int,
        contentHash: String,
        artifact: ContentArtifactModel? = nil,
        document: IndexedDocument? = nil
    ) {
        self.id = id
        self.content = content
        self.kind = kind
        self.tags = tags
        self.score = score
        self.anchor = anchor
        self.startLine = startLine
        self.endLine = endLine
        self.contentHash = contentHash
        self.artifact = artifact
        self.document = document
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    func updateContent(_ newContent: String, newHash: String) {
        content = newContent
        contentHash = newHash
        lastModified = Date()
    }
}

/// SwiftData model for ingestion jobs with enhanced tracking
@Model
final class IngestionJobModel {
    @Attribute(.unique) var id: UUID
    var sourceId: UUID
    var pluginId: String
    var status: String // IngestionJobStatus.rawValue
    var priority: String // JobPriority.rawValue
    
    // Job specification (JSON-encoded)
    var jobSpec: Data
    
    // Execution tracking
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var retryCount: Int
    var errorMessage: String?
    
    // Results
    var artifactCount: Int
    var totalSize: Int
    
    // Relationships
    @Relationship var source: ContextSource?
    @Relationship(deleteRule: .cascade) var artifacts: [ContentArtifactModel] = []
    
    init(
        id: UUID = UUID(),
        sourceId: UUID,
        pluginId: String,
        status: String = "pending",
        priority: String = "normal",
        jobSpec: Data,
        source: ContextSource? = nil
    ) {
        self.id = id
        self.sourceId = sourceId
        self.pluginId = pluginId
        self.status = status
        self.priority = priority
        self.jobSpec = jobSpec
        self.createdAt = Date()
        self.retryCount = 0
        self.artifactCount = 0
        self.totalSize = 0
        self.source = source
    }
    
    func updateStatus(_ newStatus: String, errorMessage: String? = nil) {
        status = newStatus
        self.errorMessage = errorMessage
        
        if newStatus == "running" && startedAt == nil {
            startedAt = Date()
        } else if ["completed", "failed", "cancelled"].contains(newStatus) && completedAt == nil {
            completedAt = Date()
        }
    }
    
    func addArtifact(_ artifact: ContentArtifactModel) {
        artifacts.append(artifact)
        artifactCount = artifacts.count
        totalSize = artifacts.reduce(0) { $0 + $1.fileSize }
    }
    
    var duration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
    
    func getJobSpec<T: Codable>(_ type: T.Type) -> T? {
        return try? JSONDecoder().decode(type, from: jobSpec)
    }
    
    func setJobSpec<T: Codable>(_ spec: T) throws {
        self.jobSpec = try JSONEncoder().encode(spec)
    }
}

/// SwiftData model for chat streams and bindings
@Model
final class ChatStreamModel {
    @Attribute(.unique) var id: UUID
    var projectId: UUID
    var name: String
    var streamType: String // ChatStreamType.rawValue
    var connectionString: String
    var isActive: Bool
    var isEphemeral: Bool
    
    // Configuration
    var maxMessages: Int
    var maxBytes: Int
    var timeWindowMinutes: Int
    var retentionPolicy: String
    
    // Status
    var lastConnectedAt: Date?
    var lastMessageAt: Date?
    var messageCount: Int
    var totalBytes: Int
    
    // Relationships
    @Relationship var project: Project?
    @Relationship(deleteRule: .cascade) var messages: [ChatMessageModel] = []
    
    init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        streamType: String,
        connectionString: String,
        isActive: Bool = true,
        isEphemeral: Bool = true,
        maxMessages: Int = 100,
        maxBytes: Int = 1_000_000, // 1MB
        timeWindowMinutes: Int = 60,
        retentionPolicy: String = "ephemeral",
        project: Project? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.streamType = streamType
        self.connectionString = connectionString
        self.isActive = isActive
        self.isEphemeral = isEphemeral
        self.maxMessages = maxMessages
        self.maxBytes = maxBytes
        self.timeWindowMinutes = timeWindowMinutes
        self.retentionPolicy = retentionPolicy
        self.messageCount = 0
        self.totalBytes = 0
        self.project = project
    }
    
    func addMessage(_ message: ChatMessageModel) {
        messages.append(message)
        messageCount = messages.count
        totalBytes = messages.reduce(0) { $0 + $1.content.count }
        lastMessageAt = Date()
        
        // Enforce sliding window
        enforceRetentionPolicy()
    }
    
    func enforceRetentionPolicy() {
        let cutoffDate = Date().addingTimeInterval(-Double(timeWindowMinutes * 60))
        
        // Remove old messages
        let oldMessages = messages.filter { $0.timestamp < cutoffDate }
        for message in oldMessages {
            messages.removeAll { $0.id == message.id }
        }
        
        // Enforce message limit
        if messages.count > maxMessages {
            let excess = messages.count - maxMessages
            let messagesToRemove = messages.prefix(excess)
            for message in messagesToRemove {
                messages.removeAll { $0.id == message.id }
            }
        }
        
        // Update counters
        messageCount = messages.count
        totalBytes = messages.reduce(0) { $0 + $1.content.count }
    }
}

/// SwiftData model for chat messages in streams
@Model
final class ChatMessageModel {
    @Attribute(.unique) var id: UUID
    var streamId: UUID
    var role: String // "user", "assistant", "system"
    var content: String
    var timestamp: Date
    var metadata: Data // JSON-encoded metadata
    
    // Relationships
    @Relationship var stream: ChatStreamModel?
    
    init(
        id: UUID = UUID(),
        streamId: UUID,
        role: String,
        content: String,
        timestamp: Date = Date(),
        metadata: Data = Data(),
        stream: ChatStreamModel? = nil
    ) {
        self.id = id
        self.streamId = streamId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
        self.stream = stream
    }
    
    func getMetadata<T: Codable>(_ type: T.Type) -> T? {
        guard !metadata.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: metadata)
    }
    
    func setMetadata<T: Codable>(_ data: T) throws {
        self.metadata = try JSONEncoder().encode(data)
    }
}

// MARK: - Schema Version Management

enum SchemaVersion: Int, CaseIterable {
    case v1 = 1
    case v2 = 2 // Added artifact-based storage
    case v3 = 3 // Added chat streams
    
    static var current: SchemaVersion { .v3 }
}

struct SchemaVersionModel: Codable {
    let version: Int
    let migratedAt: Date
    let previousVersion: Int?
}