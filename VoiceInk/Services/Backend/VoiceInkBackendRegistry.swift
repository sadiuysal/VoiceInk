import Foundation
import SwiftData
import OSLog

@MainActor
final class VoiceInkBackendRegistry: ObservableObject {
    static let shared = VoiceInkBackendRegistry()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "BackendRegistry")
    
    // Core Backend Services
    private(set) var projectRegistry: ProjectRegistry?
    private(set) var ingestionOrchestrator: IngestionOrchestrator?
    private(set) var contextAssemblyService: EnhancedContextAssemblyService?
    private(set) var chatStreamService: ChatStreamService?
    private(set) var credentialStore: CredentialStore?
    
    // Service Status
    @Published var isInitialized = false
    @Published var initializationProgress: Double = 0.0
    @Published var initializationStatus = "Starting backend services..."
    
    private init() {}
    
    func initialize(with container: ModelContainer) async throws {
        logger.info("Initializing VoiceInk backend services")
        
        let initTasks: [(String, () async throws -> Void)] = [
            ("Initializing Project Registry", initializeProjectRegistry),
            ("Starting Ingestion Orchestrator", initializeIngestionOrchestrator),
            ("Configuring Context Assembly", initializeContextAssembly),
            ("Setting up Chat Streams", initializeChatStreams),
            ("Initializing Credential Store", initializeCredentialStore),
            ("Registering Source Plugins", registerSourcePlugins),
            ("Finalizing Backend Setup", finalizeSetup)
        ]
        
        let totalTasks = Double(initTasks.count)
        
        for (index, (taskName, task)) in initTasks.enumerated() {
            await MainActor.run {
                initializationStatus = taskName
                initializationProgress = Double(index) / totalTasks
            }
            
            logger.info("Backend initialization: \(taskName)")
            
            do {
                try await task()
            } catch {
                logger.error("Backend initialization failed at \(taskName): \(error.localizedDescription)")
                throw BackendInitializationError.taskFailed(taskName, error)
            }
        }
        
        await MainActor.run {
            initializationProgress = 1.0
            initializationStatus = "Backend services ready"
            isInitialized = true
        }
        
        logger.info("VoiceInk backend services initialized successfully")
    }
    
    // MARK: - Service Initialization
    
    private func initializeProjectRegistry() async throws {
        projectRegistry = ProjectRegistry.shared
        // ProjectRegistry initializes itself lazily
    }
    
    private func initializeIngestionOrchestrator() async throws {
        ingestionOrchestrator = IngestionOrchestrator.shared
        // IngestionOrchestrator is ready on creation
    }
    
    private func initializeContextAssembly() async throws {
        contextAssemblyService = EnhancedContextAssemblyService.shared
    }
    
    private func initializeChatStreams() async throws {
        chatStreamService = ChatStreamService.shared
    }
    
    private func initializeCredentialStore() async throws {
        credentialStore = CredentialStore.shared
    }
    
    private func registerSourcePlugins() async throws {
        // Register built-in plugins with the PluginRegistry
        let gitPlugin = EnhancedGitIngestPlugin()
        let mcpPlugin = MCPCrawlerPlugin()
        let filesPlugin = ManualFilesPlugin()
        
        let pluginRegistry = PluginRegistry.shared
        await pluginRegistry.registerPlugin(gitPlugin)
        await pluginRegistry.registerPlugin(mcpPlugin)
        await pluginRegistry.registerPlugin(filesPlugin)
        
        logger.info("Registered \(3) source plugins")
    }
    
    private func finalizeSetup() async throws {
        // Perform any final setup tasks
        logger.info("Backend initialization complete")
    }
    
    // MARK: - Service Access
    
    func requireProjectRegistry() throws -> ProjectRegistry {
        guard let registry = projectRegistry else {
            throw BackendAccessError.serviceNotInitialized("ProjectRegistry")
        }
        return registry
    }
    
    func requireIngestionOrchestrator() throws -> IngestionOrchestrator {
        guard let orchestrator = ingestionOrchestrator else {
            throw BackendAccessError.serviceNotInitialized("IngestionOrchestrator")
        }
        return orchestrator
    }
    
    func requireContextAssemblyService() throws -> EnhancedContextAssemblyService {
        guard let service = contextAssemblyService else {
            throw BackendAccessError.serviceNotInitialized("EnhancedContextAssemblyService")
        }
        return service
    }
    
    func requireChatStreamService() throws -> ChatStreamService {
        guard let service = chatStreamService else {
            throw BackendAccessError.serviceNotInitialized("ChatStreamService")
        }
        return service
    }
    
    func requireCredentialStore() throws -> CredentialStore {
        guard let store = credentialStore else {
            throw BackendAccessError.serviceNotInitialized("CredentialStore")
        }
        return store
    }
    
    // MARK: - Health Check
    
    func performHealthCheck() async -> BackendHealthReport {
        var componentStatuses: [String: ComponentStatus] = [:]
        
        // Check ProjectRegistry
        componentStatuses["ProjectRegistry"] = projectRegistry != nil ? .healthy : .unavailable
        
        // Check IngestionOrchestrator
        if let orchestrator = ingestionOrchestrator {
            let activeJobs = await orchestrator.getActiveJobs()
            componentStatuses["IngestionOrchestrator"] = activeJobs.count < 100 ? .healthy : .degraded
        } else {
            componentStatuses["IngestionOrchestrator"] = .unavailable
        }
        
        // Check ContextAssemblyService
        componentStatuses["ContextAssemblyService"] = contextAssemblyService != nil ? .healthy : .unavailable
        
        // Check ChatStreamService
        if let chatService = chatStreamService {
            let activeStreams = chatService.activeStreams.filter { $0.isActive }.count
            componentStatuses["ChatStreamService"] = activeStreams >= 0 ? .healthy : .degraded
        } else {
            componentStatuses["ChatStreamService"] = .unavailable
        }
        
        // Check CredentialStore
        componentStatuses["CredentialStore"] = credentialStore != nil ? .healthy : .unavailable
        
        let overallStatus: SystemStatus
        if componentStatuses.values.allSatisfy({ $0 == .healthy }) {
            overallStatus = .healthy
        } else if componentStatuses.values.contains(.unavailable) {
            overallStatus = .critical
        } else {
            overallStatus = .degraded
        }
        
        return BackendHealthReport(
            overallStatus: overallStatus,
            componentStatuses: componentStatuses,
            timestamp: Date(),
            isInitialized: isInitialized
        )
    }
}

// MARK: - Errors

enum BackendInitializationError: LocalizedError {
    case taskFailed(String, Error)
    case missingDependency(String)
    
    var errorDescription: String? {
        switch self {
        case .taskFailed(let task, let error):
            return "Backend initialization failed at '\(task)': \(error.localizedDescription)"
        case .missingDependency(let dependency):
            return "Missing required dependency: \(dependency)"
        }
    }
}

enum BackendAccessError: LocalizedError {
    case serviceNotInitialized(String)
    case serviceUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized(let service):
            return "Service not initialized: \(service)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service)"
        }
    }
}

// MARK: - Health Monitoring

struct BackendHealthReport {
    let overallStatus: SystemStatus
    let componentStatuses: [String: ComponentStatus]
    let timestamp: Date
    let isInitialized: Bool
    
    var healthPercentage: Double {
        let healthyCount = componentStatuses.values.filter { $0 == .healthy }.count
        return Double(healthyCount) / Double(componentStatuses.count)
    }
    
    var criticalComponents: [String] {
        return componentStatuses.compactMap { key, status in
            status == .unavailable ? key : nil
        }
    }
    
    var degradedComponents: [String] {
        return componentStatuses.compactMap { key, status in
            status == .degraded ? key : nil
        }
    }
}

enum SystemStatus: String, CaseIterable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .healthy:
            return "green"
        case .degraded:
            return "orange"
        case .critical:
            return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }
}

enum ComponentStatus: String, CaseIterable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case unavailable = "Unavailable"
    
    var color: String {
        switch self {
        case .healthy:
            return "green"
        case .degraded:
            return "orange"
        case .unavailable:
            return "red"
        }
    }
}

// MARK: - Extension for Access from Views

extension VoiceInkBackendRegistry {
    
    func createProject(name: String, description: String = "", rootPath: String? = nil) async throws -> Project {
        let registry = try requireProjectRegistry()
        return try registry.createProject(name: name, description: description, rootPath: rootPath)
    }
    
    func addContextSource(to project: Project, type: ContextSourceType, configuration: Data) async throws -> ContextSource {
        let source = ContextSource(
            name: "New \(type.displayName) Source",
            sourceType: type,
            configuration: configuration,
            project: project,
            isEnabled: true
        )
        
        // TODO: Implement source registration with IngestionOrchestrator if needed
        // let orchestrator = try requireIngestionOrchestrator()
        // try await orchestrator.registerSource(source)
        
        return source
    }
    
    // TODO: Implement context assembly when EnhancedContextView and ContextAssemblyOptions are defined
    // func assembleContext(for project: Project, options: ContextAssemblyOptions = ContextAssemblyOptions()) async throws -> EnhancedContextView {
    //     let assemblyService = try requireContextAssemblyService()
    //     return try await assemblyService.assembleContext(for: project, options: options)
    // }
    
    func createChatStreamBinding(for project: Project, config: ChatStreamBindingConfig) async throws -> ChatStreamBinding {
        let chatService = try requireChatStreamService()
        return try await chatService.createStreamBinding(for: project, config: config)
    }
}