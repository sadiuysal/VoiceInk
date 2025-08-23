import Foundation
import SwiftData
import os

/// Main coordinator for project management with versioning and configuration control
@MainActor
public final class ProjectRegistry: ObservableObject {
    static let shared = ProjectRegistry()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ProjectRegistry")
    
    @Published var activeProject: Project?
    @Published var projects: [Project] = []
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadProjects()
    }
    
    // MARK: - Project Management
    
    func createProject(
        name: String,
        description: String = "",
        rootPath: String? = nil,
        configuration: ProjectConfiguration = ProjectConfiguration()
    ) throws -> Project {
        guard let modelContext = modelContext else {
            throw ProjectRegistryError.modelContextNotConfigured
        }
        
        // Validate unique name
        if projects.contains(where: { $0.name == name }) {
            throw ProjectRegistryError.projectNameExists(name)
        }
        
        let project = Project(
            name: name,
            projectDescription: description,
            rootPath: rootPath
        )
        
        // Store configuration
        try project.setProjectConfiguration(configuration)
        
        modelContext.insert(project)
        projects.append(project)
        
        logger.info("Created project: \(name)")
        return project
    }
    
    func updateProject(
        _ project: Project,
        name: String? = nil,
        description: String? = nil,
        rootPath: String? = nil,
        configuration: ProjectConfiguration? = nil
    ) throws {
        if let name = name {
            // Validate unique name if changing
            if name != project.name && projects.contains(where: { $0.name == name }) {
                throw ProjectRegistryError.projectNameExists(name)
            }
            project.name = name
        }
        
        if let description = description {
            project.projectDescription = description
        }
        
        if let rootPath = rootPath {
            project.rootPath = rootPath
        }
        
        if let configuration = configuration {
            try project.setProjectConfiguration(configuration)
        }
        
        project.updateTimestamp()
        logger.info("Updated project: \(project.name)")
    }
    
    func deleteProject(_ project: Project) throws {
        guard let modelContext = modelContext else {
            throw ProjectRegistryError.modelContextNotConfigured
        }
        
        if activeProject?.id == project.id {
            activeProject = nil
        }
        
        projects.removeAll { $0.id == project.id }
        modelContext.delete(project)
        
        logger.info("Deleted project: \(project.name)")
    }
    
    func setActiveProject(_ project: Project?) {
        activeProject = project
        logger.info("Set active project: \(project?.name ?? "none")")
    }
    
    // MARK: - Project Discovery
    
    func discoverProjects(in directory: URL) async throws -> [ProjectDiscoveryResult] {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let results = try await self.performProjectDiscovery(in: directory)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performProjectDiscovery(in directory: URL) async throws -> [ProjectDiscoveryResult] {
        let fileManager = FileManager.default
        var discoveries: [ProjectDiscoveryResult] = []
        
        // Look for Git repositories
        let gitRepos = try findGitRepositories(in: directory)
        for repo in gitRepos {
            let discovery = ProjectDiscoveryResult(
                type: .gitRepository,
                name: repo.lastPathComponent,
                path: repo.path,
                confidence: 0.9,
                metadata: ["hasGit": true]
            )
            discoveries.append(discovery)
        }
        
        // Look for common project markers
        let projectMarkers = [
            "package.json", "Cargo.toml", "pyproject.toml", "pom.xml",
            "Package.swift", "Podfile", "build.gradle", "CMakeLists.txt"
        ]
        
        for marker in projectMarkers {
            let markerURL = directory.appendingPathComponent(marker)
            if fileManager.fileExists(atPath: markerURL.path) {
                let discovery = ProjectDiscoveryResult(
                    type: .projectMarker,
                    name: directory.lastPathComponent,
                    path: directory.path,
                    confidence: 0.7,
                    metadata: ["marker": marker]
                )
                discoveries.append(discovery)
            }
        }
        
        return discoveries
    }
    
    private func findGitRepositories(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var gitRepos: [URL] = []
        
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        for item in contents {
            let gitDir = item.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitDir.path) {
                gitRepos.append(item)
            }
        }
        
        return gitRepos
    }
    
    // MARK: - Configuration Management
    
    func getProjectConfiguration(_ project: Project) -> ProjectConfiguration {
        return project.getProjectConfiguration() ?? ProjectConfiguration()
    }
    
    func updateProjectConfiguration(
        _ project: Project,
        _ configuration: ProjectConfiguration
    ) throws {
        try project.setProjectConfiguration(configuration)
        project.updateTimestamp()
        logger.info("Updated configuration for project: \(project.name)")
    }
    
    // MARK: - Private Methods
    
    private func loadProjects() {
        guard let modelContext = modelContext else { return }
        
        let fetchDescriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            projects = try modelContext.fetch(fetchDescriptor)
            
            // Set active project to most recently updated if none set
            if activeProject == nil {
                activeProject = projects.first
            }
            
            logger.info("Loaded \(self.projects.count) projects")
        } catch {
            logger.error("Failed to load projects: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

public struct ProjectConfiguration: Codable {
    public let version: String
    public let ingestionPolicy: IngestionPolicy
    public let privacySettings: PrivacySettings
    public let performanceSettings: PerformanceSettings
    
    public init(
        version: String = "1.0",
        ingestionPolicy: IngestionPolicy = IngestionPolicy(),
        privacySettings: PrivacySettings = PrivacySettings(),
        performanceSettings: PerformanceSettings = PerformanceSettings()
    ) {
        self.version = version
        self.ingestionPolicy = ingestionPolicy
        self.privacySettings = privacySettings
        self.performanceSettings = performanceSettings
    }
}

public struct IngestionPolicy: Codable {
    public let maxFileSize: Int
    public let maxTotalSize: Int
    public let allowedFileTypes: [String]
    public let excludePatterns: [String]
    public let enableAutoSync: Bool
    public let syncInterval: TimeInterval
    
    public init(
        maxFileSize: Int = 1_048_576, // 1MB
        maxTotalSize: Int = 100_000_000, // 100MB
        allowedFileTypes: [String] = ["md", "txt", "json", "swift", "js", "ts", "py"],
        excludePatterns: [String] = ["node_modules/**", ".git/**", "build/**", "dist/**"],
        enableAutoSync: Bool = true,
        syncInterval: TimeInterval = 3600 // 1 hour
    ) {
        self.maxFileSize = maxFileSize
        self.maxTotalSize = maxTotalSize
        self.allowedFileTypes = allowedFileTypes
        self.excludePatterns = excludePatterns
        self.enableAutoSync = enableAutoSync
        self.syncInterval = syncInterval
    }
}

public struct PrivacySettings: Codable {
    public let enablePIIFiltering: Bool
    public let enableCredentialRedaction: Bool
    public let allowExternalCalls: Bool
    public let dataRetentionDays: Int
    
    public init(
        enablePIIFiltering: Bool = true,
        enableCredentialRedaction: Bool = true,
        allowExternalCalls: Bool = false,
        dataRetentionDays: Int = 30
    ) {
        self.enablePIIFiltering = enablePIIFiltering
        self.enableCredentialRedaction = enableCredentialRedaction
        self.allowExternalCalls = allowExternalCalls
        self.dataRetentionDays = dataRetentionDays
    }
}

public struct PerformanceSettings: Codable {
    public let maxConcurrentJobs: Int
    public let contextAssemblyTimeoutMs: Int
    public let cacheSizeMB: Int
    public let enableWarmPaths: Bool
    
    public init(
        maxConcurrentJobs: Int = 3,
        contextAssemblyTimeoutMs: Int = 200,
        cacheSizeMB: Int = 50,
        enableWarmPaths: Bool = true
    ) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.contextAssemblyTimeoutMs = contextAssemblyTimeoutMs
        self.cacheSizeMB = cacheSizeMB
        self.enableWarmPaths = enableWarmPaths
    }
}

public struct ProjectDiscoveryResult {
    public let type: DiscoveryType
    public let name: String
    public let path: String
    public let confidence: Double
    public let metadata: [String: Any]
    
    public enum DiscoveryType {
        case gitRepository
        case projectMarker
        case documentationDirectory
        case notesDirectory
    }
}

enum ProjectRegistryError: LocalizedError {
    case modelContextNotConfigured
    case projectNameExists(String)
    case projectNotFound(UUID)
    case configurationInvalid(String)
    
    var errorDescription: String? {
        switch self {
        case .modelContextNotConfigured:
            return "Model context not configured"
        case .projectNameExists(let name):
            return "Project name '\(name)' already exists"
        case .projectNotFound(let id):
            return "Project with ID '\(id)' not found"
        case .configurationInvalid(let message):
            return "Configuration invalid: \(message)"
        }
    }
}

// MARK: - Project Model Extensions

extension Project {
    func getProjectConfiguration() -> ProjectConfiguration? {
        guard let configuration = configuration, !configuration.isEmpty else { return nil }
        return try? JSONDecoder().decode(ProjectConfiguration.self, from: configuration)
    }
    
    func setProjectConfiguration(_ config: ProjectConfiguration) throws {
        self.configuration = try JSONEncoder().encode(config)
    }
}