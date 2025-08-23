import Foundation
import SwiftData
import os

/// Protocol defining the interface for source plugins in the new architecture
public protocol SourcePlugin: Actor {
    associatedtype Config: Codable
    associatedtype Artifact: ContentArtifact
    
    /// Plugin metadata
    var pluginId: String { get }
    var displayName: String { get }
    var version: String { get }
    var capabilities: PluginCapabilities { get }
    
    /// Plugin lifecycle
    func configure(_ config: Config) async throws
    func validate(_ config: Config) async throws -> Bool
    func isAvailable() async -> Bool
    
    /// Job planning and execution
    func planJobs(for source: ContextSource) async throws -> [JobSpec]
    func executeJob(_ job: JobSpec) async throws -> [Artifact]
    func cancelJob(_ jobId: UUID) async
    func cleanup() async
    
    /// Content preview and testing
    func previewContent(for source: ContextSource) async throws -> ContentPreview
    func testConnection(for source: ContextSource) async throws -> ConnectionTestResult
}

/// Content artifact protocol for plugin outputs
public protocol ContentArtifact: Identifiable, Codable, Sendable {
    var id: UUID { get }
    var type: ArtifactType { get }
    var version: String { get }
    var source: ArtifactSource { get }
    var contentHash: String { get }
    var metadata: ArtifactMetadata { get }
    var content: ContentBlob { get }
    var ttl: TimeInterval? { get }
    var createdAt: Date { get }
}

// MARK: - Supporting Types

public struct PluginCapabilities: Codable, Sendable {
    let supportsOffline: Bool
    let requiresNetwork: Bool
    let requiresCredentials: Bool
    let maxConcurrentJobs: Int
    let supportedFormats: Set<ContentFormat>
    let supportedArtifactTypes: Set<ArtifactType>
    
    public init(
        supportsOffline: Bool = true,
        requiresNetwork: Bool = false,
        requiresCredentials: Bool = false,
        maxConcurrentJobs: Int = 3,
        supportedFormats: Set<ContentFormat> = [.markdown, .text],
        supportedArtifactTypes: Set<ArtifactType> = [.document, .snippet]
    ) {
        self.supportsOffline = supportsOffline
        self.requiresNetwork = requiresNetwork
        self.requiresCredentials = requiresCredentials
        self.maxConcurrentJobs = maxConcurrentJobs
        self.supportedFormats = supportedFormats
        self.supportedArtifactTypes = supportedArtifactTypes
    }
}

public struct JobSpec: Codable, Identifiable, Sendable {
    public let id: UUID
    let sourceId: UUID
    let pluginId: String
    let priority: JobPriority
    let parameters: [String: String]
    let dependencies: [UUID]
    let timeout: TimeInterval
    let retryPolicy: RetryPolicy
    let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        sourceId: UUID,
        pluginId: String,
        priority: JobPriority = .normal,
        parameters: [String: String] = [:],
        dependencies: [UUID] = [],
        timeout: TimeInterval = 300,
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.id = id
        self.sourceId = sourceId
        self.pluginId = pluginId
        self.priority = priority
        self.parameters = parameters
        self.dependencies = dependencies
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.createdAt = Date()
    }
}

public enum JobPriority: String, Codable, CaseIterable, Sendable {
    case urgent = "urgent"
    case high = "high"
    case normal = "normal"
    case low = "low"
    case background = "background"
    
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        case .background: return 4
        }
    }
}

public struct RetryPolicy: Codable, Sendable {
    let maxRetries: Int
    let backoffStrategy: BackoffStrategy
    let retryableErrors: [String]
    
    public init(
        maxRetries: Int = 3,
        backoffStrategy: BackoffStrategy = .exponential,
        retryableErrors: [String] = ["network", "timeout", "rate_limit"]
    ) {
        self.maxRetries = maxRetries
        self.backoffStrategy = backoffStrategy
        self.retryableErrors = retryableErrors
    }
}

public enum BackoffStrategy: String, Codable, Sendable {
    case linear = "linear"
    case exponential = "exponential"
    case fixed = "fixed"
}

public enum ArtifactType: String, Codable, CaseIterable, Sendable {
    case document = "document"
    case snippet = "snippet"
    case codeBlock = "code_block"
    case metadata = "metadata"
    case chatTranscript = "chat_transcript"
    case webPage = "web_page"
    case fileTree = "file_tree"
    
    var displayName: String {
        switch self {
        case .document: return "Document"
        case .snippet: return "Snippet"
        case .codeBlock: return "Code Block"
        case .metadata: return "Metadata"
        case .chatTranscript: return "Chat Transcript"
        case .webPage: return "Web Page"
        case .fileTree: return "File Tree"
        }
    }
}

public enum ContentFormat: String, Codable, CaseIterable, Sendable {
    case markdown = "markdown"
    case text = "text"
    case json = "json"
    case html = "html"
    case xml = "xml"
    case yaml = "yaml"
    
    var mimeType: String {
        switch self {
        case .markdown: return "text/markdown"
        case .text: return "text/plain"
        case .json: return "application/json"
        case .html: return "text/html"
        case .xml: return "application/xml"
        case .yaml: return "application/yaml"
        }
    }
}

public struct ArtifactSource: Codable, Sendable {
    let pluginId: String
    let sourceId: UUID
    let sourceType: String
    let sourcePath: String?
    let additionalContext: [String: String]
    
    public init(
        pluginId: String,
        sourceId: UUID,
        sourceType: String,
        sourcePath: String? = nil,
        additionalContext: [String: String] = [:]
    ) {
        self.pluginId = pluginId
        self.sourceId = sourceId
        self.sourceType = sourceType
        self.sourcePath = sourcePath
        self.additionalContext = additionalContext
    }
}

public struct ArtifactMetadata: Codable, Sendable {
    let title: String?
    let description: String?
    let author: String?
    let tags: [String]
    let score: Int
    let language: String?
    let fileSize: Int
    let lineCount: Int?
    let custom: [String: String]
    
    public init(
        title: String? = nil,
        description: String? = nil,
        author: String? = nil,
        tags: [String] = [],
        score: Int = 1,
        language: String? = nil,
        fileSize: Int = 0,
        lineCount: Int? = nil,
        custom: [String: String] = [:]
    ) {
        self.title = title
        self.description = description
        self.author = author
        self.tags = tags
        self.score = score
        self.language = language
        self.fileSize = fileSize
        self.lineCount = lineCount
        self.custom = custom
    }
}

public struct ContentBlob: Codable, Sendable {
    let format: ContentFormat
    let encoding: String
    let data: Data
    let checksum: String
    let compressionAlgorithm: String?
    
    public init(
        format: ContentFormat,
        encoding: String = "utf-8",
        data: Data,
        compressionAlgorithm: String? = nil
    ) {
        self.format = format
        self.encoding = encoding
        self.data = data
        self.checksum = ContentBlob.calculateChecksum(data)
        self.compressionAlgorithm = compressionAlgorithm
    }
    
    private static func calculateChecksum(_ data: Data) -> String {
        return data.sha256
    }
}

public struct ContentPreview: Sendable {
    let title: String
    let description: String
    let itemCount: Int
    let estimatedSize: Int
    let lastModified: Date?
    let sampleItems: [PreviewItem]
    
    public init(
        title: String,
        description: String,
        itemCount: Int,
        estimatedSize: Int,
        lastModified: Date? = nil,
        sampleItems: [PreviewItem] = []
    ) {
        self.title = title
        self.description = description
        self.itemCount = itemCount
        self.estimatedSize = estimatedSize
        self.lastModified = lastModified
        self.sampleItems = sampleItems
    }
    
    public struct PreviewItem: Sendable {
        let title: String
        let type: ArtifactType
        let size: Int
        let preview: String
        
        public init(title: String, type: ArtifactType, size: Int, preview: String) {
            self.title = title
            self.type = type
            self.size = size
            self.preview = preview
        }
    }
}

public struct ConnectionTestResult: Sendable {
    let success: Bool
    let message: String
    let latency: TimeInterval?
    let metadata: [String: String]
    
    public init(
        success: Bool,
        message: String,
        latency: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.success = success
        self.message = message
        self.latency = latency
        self.metadata = metadata
    }
    
    public static func success(
        message: String = "Connection successful",
        latency: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: message, latency: latency, metadata: metadata)
    }
    
    public static func failure(
        message: String,
        metadata: [String: String] = [:]
    ) -> ConnectionTestResult {
        ConnectionTestResult(success: false, message: message, latency: nil, metadata: metadata)
    }
}

// MARK: - Plugin Registry

@MainActor
public final class PluginRegistry: ObservableObject {
    static let shared = PluginRegistry()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "PluginRegistry")
    private var plugins: [String: any SourcePlugin] = [:]
    
    private init() {}
    
    /// Register a plugin
    public func registerPlugin<T: SourcePlugin>(_ plugin: T) async {
        await plugin.cleanup() // Ensure clean state
        let pluginId = await plugin.pluginId
        plugins[pluginId] = plugin
        logger.info("Registered plugin: \(pluginId)")
    }
    
    /// Get plugin by ID
    public func getPlugin(_ pluginId: String) -> (any SourcePlugin)? {
        return plugins[pluginId]
    }
    
    /// Get all available plugins
    public var availablePlugins: [any SourcePlugin] {
        return Array(plugins.values)
    }
    
    /// Get plugins by capability
    public func getPluginsWithCapability(_ capability: PluginCapability) async -> [any SourcePlugin] {
        var result: [any SourcePlugin] = []
        
        for plugin in plugins.values {
            let available = await plugin.isAvailable()
            let pluginCapabilities = await plugin.capabilities
            if available && pluginCapabilities.supports(capability) {
                result.append(plugin)
            }
        }
        
        return result
    }
}

public enum PluginCapability {
    case offline
    case network
    case credentials
    case format(ContentFormat)
    case artifactType(ArtifactType)
}

extension PluginCapabilities {
    func supports(_ capability: PluginCapability) -> Bool {
        switch capability {
        case .offline:
            return supportsOffline
        case .network:
            return requiresNetwork
        case .credentials:
            return requiresCredentials
        case .format(let format):
            return supportedFormats.contains(format)
        case .artifactType(let type):
            return supportedArtifactTypes.contains(type)
        }
    }
}

// MARK: - Data Extensions

extension Data {
    var sha256: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit

extension Data {
    private var sha256Hash: SHA256Digest {
        SHA256.hash(data: self)
    }
}