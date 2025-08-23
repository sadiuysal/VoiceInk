import Foundation
import SwiftData
import os

/// Main backend service coordinator implementing the new architecture
@MainActor
public final class VoiceInkBackend: ObservableObject {
    public static let shared = VoiceInkBackend()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "VoiceInkBackend")
    
    // Core services
    public let projectRegistry = ProjectRegistry.shared
    public let credentialStore = CredentialStore.shared
    public let pluginRegistry = PluginRegistry.shared
    
    // Service state
    @Published public var isInitialized = false
    @Published public var initializationError: Error?
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    // MARK: - Initialization
    
    public func initialize(with modelContext: ModelContext) async throws {
        guard !isInitialized else {
            logger.info("Backend already initialized")
            return
        }
        
        self.modelContext = modelContext
        
        do {
            // Initialize core services
            projectRegistry.configure(with: modelContext)
            
            // Register default plugins
            await registerDefaultPlugins()
            
            // Perform health checks
            try await performHealthChecks()
            
            isInitialized = true
            initializationError = nil
            
            logger.info("VoiceInk backend initialized successfully")
            
        } catch {
            initializationError = error
            logger.error("Failed to initialize backend: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func registerDefaultPlugins() async {
        // Register enhanced GitIngest plugin
        let gitIngestPlugin = EnhancedGitIngestPlugin()
        await pluginRegistry.registerPlugin(gitIngestPlugin)
        
        // Register manual files plugin
        let manualFilesPlugin = ManualFilesPlugin()
        await pluginRegistry.registerPlugin(manualFilesPlugin)
        
        logger.info("Registered default plugins")
    }
    
    private func performHealthChecks() async throws {
        // Check plugin availability
        let plugins = pluginRegistry.availablePlugins
        for plugin in plugins {
            let available = await plugin.isAvailable()
            if !available {
                let pluginId = await plugin.pluginId
                logger.warning("Plugin \(pluginId) is not available")
            }
        }
        
        logger.info("Health checks completed")
    }
    
    // MARK: - Project Management
    
    public func createProject(
        name: String,
        description: String = "",
        rootPath: String? = nil,
        configuration: ProjectConfiguration = ProjectConfiguration()
    ) async throws -> Project {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        return try projectRegistry.createProject(
            name: name,
            description: description,
            rootPath: rootPath,
            configuration: configuration
        )
    }
    
    public func updateProject(
        _ project: Project,
        name: String? = nil,
        description: String? = nil,
        rootPath: String? = nil,
        configuration: ProjectConfiguration? = nil
    ) async throws {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        try projectRegistry.updateProject(
            project,
            name: name,
            description: description,
            rootPath: rootPath,
            configuration: configuration
        )
    }
    
    public func deleteProject(_ project: Project) async throws {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        // Remove all credentials for this project
        try credentialStore.removeAllCredentials(for: project)
        
        // Cancel all active jobs for this project
        let sources = project.sources
        for source in sources {
            await IngestionOrchestrator.shared.cancelAllJobs(for: source.id)
        }
        
        // Delete the project
        try projectRegistry.deleteProject(project)
    }
    
    // MARK: - Source Management
    
    public func addSource(
        to project: Project,
        name: String,
        description: String = "",
        type: ContextSourceType,
        configuration: Data,
        sourcePath: String? = nil
    ) async throws -> ContextSource {
        guard isInitialized, let modelContext = modelContext else {
            throw VoiceInkBackendError.notInitialized
        }
        
        // Validate configuration with appropriate plugin
        let pluginId = getPluginId(for: type)
        guard let plugin = pluginRegistry.getPlugin(pluginId) else {
            throw VoiceInkBackendError.pluginNotFound(pluginId)
        }
        
        // Create the source
        let source = ContextSource(
            name: name,
            sourceDescription: description,
            sourceType: type,
            sourcePath: sourcePath,
            configuration: configuration,
            project: project
        )
        
        modelContext.insert(source)
        
        logger.info("Added source '\(name)' to project '\(project.name)'")
        return source
    }
    
    public func removeSource(_ source: ContextSource) async throws {
        guard isInitialized, let modelContext = modelContext else {
            throw VoiceInkBackendError.notInitialized
        }
        
        // Cancel any active jobs
        await IngestionOrchestrator.shared.cancelAllJobs(for: source.id)
        
        // Remove from model context
        modelContext.delete(source)
        
        logger.info("Removed source '\(source.name)'")
    }
    
    public func updateSource(
        _ source: ContextSource,
        name: String? = nil,
        description: String? = nil,
        configuration: Data? = nil,
        enabled: Bool? = nil
    ) async throws {
        if let name = name {
            source.name = name
        }
        
        if let description = description {
            source.sourceDescription = description
        }
        
        if let configuration = configuration {
            source.configuration = configuration
        }
        
        if let enabled = enabled {
            source.isEnabled = enabled
        }
        
        logger.info("Updated source '\(source.name)'")
    }
    
    // MARK: - Ingestion Management
    
    public func runIngestion(for project: Project) async throws -> [UUID] {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        var jobIds: [UUID] = []
        
        for source in project.sources.filter({ $0.isEnabled }) {
            let sourceJobIds = try await runIngestion(for: source)
            jobIds.append(contentsOf: sourceJobIds)
        }
        
        logger.info("Started ingestion for project '\(project.name)' with \(jobIds.count) jobs")
        return jobIds
    }
    
    public func runIngestion(for source: ContextSource) async throws -> [UUID] {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        let pluginId = getPluginId(for: source.sourceType)
        guard let plugin = pluginRegistry.getPlugin(pluginId) else {
            throw VoiceInkBackendError.pluginNotFound(pluginId)
        }
        
        // TODO: Configure plugin - needs type-safe approach due to associated types
        // let config = try parseConfiguration(source.configuration, for: source.sourceType)
        // try await plugin.configure(config)
        
        // TODO: Plan jobs - needs type-safe approach
        // let jobSpecs = try await plugin.planJobs(for: source)
        
        // TODO: Schedule jobs - needs type-safe approach
        // var jobIds: [UUID] = []
        // for spec in jobSpecs {
        //     let jobId = try await IngestionOrchestrator.shared.scheduleJob(spec, for: source)
        //     jobIds.append(jobId)
        // }
        
        // Update source status
        source.updateSyncStatus("syncing")
        
        logger.info("Started ingestion for source '\(source.name)' - TODO: implement with type-safe plugin approach")
        return [] // TODO: Return actual job IDs
    }
    
    public func cancelIngestion(for project: Project) async {
        for source in project.sources {
            await IngestionOrchestrator.shared.cancelAllJobs(for: source.id)
        }
        
        logger.info("Cancelled ingestion for project '\(project.name)'")
    }
    
    public func cancelIngestion(for source: ContextSource) async {
        await IngestionOrchestrator.shared.cancelAllJobs(for: source.id)
        source.updateSyncStatus("cancelled")
        
        logger.info("Cancelled ingestion for source '\(source.name)'")
    }
    
    // MARK: - Content Preview and Testing
    
    public func previewContent(for source: ContextSource) async throws -> ContentPreview {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        let pluginId = getPluginId(for: source.sourceType)
        guard let plugin = pluginRegistry.getPlugin(pluginId) else {
            throw VoiceInkBackendError.pluginNotFound(pluginId)
        }
        
        // TODO: Configure plugin - needs type-safe approach due to associated types
        // let config = try parseConfiguration(source.configuration, for: source.sourceType)
        // try await plugin.configure(config)
        
        // TODO: Return actual preview - needs type-safe approach
        throw VoiceInkBackendError.configurationInvalid("Preview not yet implemented with new plugin architecture")
    }
    
    public func testConnection(for source: ContextSource) async throws -> ConnectionTestResult {
        guard isInitialized else {
            throw VoiceInkBackendError.notInitialized
        }
        
        let pluginId = getPluginId(for: source.sourceType)
        guard let plugin = pluginRegistry.getPlugin(pluginId) else {
            throw VoiceInkBackendError.pluginNotFound(pluginId)
        }
        
        // TODO: Configure plugin - needs type-safe approach due to associated types
        // let config = try parseConfiguration(source.configuration, for: source.sourceType)
        // try await plugin.configure(config)
        
        // TODO: Return actual test result - needs type-safe approach
        throw VoiceInkBackendError.configurationInvalid("Connection testing not yet implemented with new plugin architecture")
    }
    
    // MARK: - Job Status and Management
    
    public func getJobStatus(_ jobId: UUID) async -> IngestionJobStatus? {
        return await IngestionOrchestrator.shared.getJobStatus(jobId)
    }
    
    public func getJob(_ jobId: UUID) async -> IngestionJob? {
        return await IngestionOrchestrator.shared.getJob(jobId)
    }
    
    public func getJobsForProject(_ project: Project) async -> [IngestionJob] {
        var allJobs: [IngestionJob] = []
        
        for source in project.sources {
            let jobs = await IngestionOrchestrator.shared.getJobsForSource(source.id)
            allJobs.append(contentsOf: jobs)
        }
        
        return allJobs
    }
    
    public func getJobsForSource(_ source: ContextSource) async -> [IngestionJob] {
        return await IngestionOrchestrator.shared.getJobsForSource(source.id)
    }
    
    // MARK: - Configuration Management
    
    public func updateBackendConfiguration(_ config: BackendConfiguration) async {
        await IngestionOrchestrator.shared.updateConfiguration(
            maxConcurrentJobs: config.maxConcurrentJobs
        )
        
        logger.info("Updated backend configuration")
    }
    
    // MARK: - Credential Management
    
    public func storeCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType,
        value: String
    ) async throws {
        try credentialStore.storeCredential(
            for: project,
            sourceType: sourceType,
            credentialType: credentialType,
            value: value
        )
    }
    
    public func hasCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType
    ) -> Bool {
        return credentialStore.hasCredential(
            for: project,
            sourceType: sourceType,
            credentialType: credentialType
        )
    }
    
    // MARK: - Plugin Management
    
    public func getAvailablePlugins() -> [any SourcePlugin] {
        return pluginRegistry.availablePlugins
    }
    
    public func getPlugin(_ pluginId: String) -> (any SourcePlugin)? {
        return pluginRegistry.getPlugin(pluginId)
    }
    
    // MARK: - Health and Maintenance
    
    public func performMaintenance() async {
        // Cleanup old completed jobs
        await IngestionOrchestrator.shared.cleanupCompletedJobs(olderThan: 86400) // 24 hours
        
        // Cleanup old artifacts based on TTL
        // TODO: Implement artifact cleanup
        
        logger.info("Performed maintenance tasks")
    }
    
    public func getHealthStatus() async -> BackendHealthStatus {
        let pluginStatuses = await withTaskGroup(of: PluginHealthStatus.self) { group in
            var statuses: [PluginHealthStatus] = []
            
            for plugin in pluginRegistry.availablePlugins {
                group.addTask {
                    let available = await plugin.isAvailable()
                    let pluginId = await plugin.pluginId
                    let displayName = await plugin.displayName
                    let version = await plugin.version
                    return PluginHealthStatus(
                        pluginId: pluginId,
                        displayName: displayName,
                        isAvailable: available,
                        version: version
                    )
                }
            }
            
            for await status in group {
                statuses.append(status)
            }
            
            return statuses
        }
        
        let activeJobs = await IngestionOrchestrator.shared.getActiveJobs()
        
        return BackendHealthStatus(
            isHealthy: true,
            pluginStatuses: pluginStatuses,
            activeJobCount: activeJobs.count,
            lastMaintenanceDate: Date() // TODO: Track actual maintenance date
        )
    }
    
    // MARK: - Private Helpers
    
    private func getPluginId(for sourceType: ContextSourceType) -> String {
        switch sourceType {
        case .gitIngest:
            return "com.sadiuysal.voiceink.plugins.gitingest"
        case .manualNotes:
            return "com.sadiuysal.voiceink.plugins.manualfiles"
        case .markdown:
            return "com.sadiuysal.voiceink.plugins.manualfiles"
        case .documentation:
            return "com.sadiuysal.voiceink.plugins.manualfiles"
        }
    }
    
    private func parseConfiguration(_ data: Data, for sourceType: ContextSourceType) throws -> Any {
        switch sourceType {
        case .gitIngest:
            return try JSONDecoder().decode(GitIngestConfiguration.self, from: data)
        case .manualNotes:
            return try JSONDecoder().decode(ManualNotesConfiguration.self, from: data)
        case .markdown, .documentation:
            return try JSONDecoder().decode(ManualNotesConfiguration.self, from: data)
        }
    }
}

// MARK: - Supporting Types

public struct BackendConfiguration {
    let maxConcurrentJobs: Int
    let enableHealthChecks: Bool
    let maintenanceInterval: TimeInterval
    
    public init(
        maxConcurrentJobs: Int = 3,
        enableHealthChecks: Bool = true,
        maintenanceInterval: TimeInterval = 86400
    ) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.enableHealthChecks = enableHealthChecks
        self.maintenanceInterval = maintenanceInterval
    }
}

public struct BackendHealthStatus {
    let isHealthy: Bool
    let pluginStatuses: [PluginHealthStatus]
    let activeJobCount: Int
    let lastMaintenanceDate: Date
}

public struct PluginHealthStatus {
    let pluginId: String
    let displayName: String
    let isAvailable: Bool
    let version: String
}

public enum VoiceInkBackendError: LocalizedError {
    case notInitialized
    case pluginNotFound(String)
    case configurationInvalid(String)
    case sourceNotFound(UUID)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Backend is not initialized"
        case .pluginNotFound(let pluginId):
            return "Plugin '\(pluginId)' not found"
        case .configurationInvalid(let message):
            return "Configuration invalid: \(message)"
        case .sourceNotFound(let id):
            return "Source '\(id)' not found"
        }
    }
}



