import Foundation
import SwiftData

enum ContextSourceType: String, Codable, CaseIterable {
    case gitIngest = "git_ingest"
    case manualNotes = "manual_notes"
    
    var displayName: String {
        switch self {
        case .gitIngest:
            return "Git Repository"
        case .manualNotes:
            return "Manual Notes"
        }
    }
    
    var icon: String {
        switch self {
        case .gitIngest:
            return "folder.badge.gearshape"
        case .manualNotes:
            return "note.text"
        }
    }
}

@Model
final class ContextSource {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: ContextSourceType
    var configuration: Data // JSON encoded configuration specific to source type
    var createdAt: Date
    var lastSyncAt: Date?
    var isEnabled: Bool
    var syncStatus: String // "idle", "syncing", "error", "completed"
    var errorMessage: String?
    
    @Relationship var project: Project?
    
    init(
        id: UUID = UUID(),
        name: String,
        type: ContextSourceType,
        configuration: Data = Data(),
        project: Project? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.configuration = configuration
        self.project = project
        self.createdAt = Date()
        self.isEnabled = isEnabled
        self.syncStatus = "idle"
    }
    
    func updateSyncStatus(_ status: String, errorMessage: String? = nil) {
        self.syncStatus = status
        self.errorMessage = errorMessage
        if status == "completed" {
            self.lastSyncAt = Date()
        }
    }
}

// MARK: - Configuration Helpers
extension ContextSource {
    func getConfiguration<T: Codable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: configuration)
    }
    
    func setConfiguration<T: Codable>(_ config: T) throws {
        self.configuration = try JSONEncoder().encode(config)
    }
}

// MARK: - GitIngest Configuration
struct GitIngestConfiguration: Codable {
    let repositoryPath: String
    let preset: GitIngestPreset
    let includePatterns: [String]
    let excludePatterns: [String]
    let maxFileSize: Int
    let includeSubmodules: Bool
    let branch: String?
    
    init(
        repositoryPath: String,
        preset: GitIngestPreset = .mixed,
        includePatterns: [String] = [],
        excludePatterns: [String] = [],
        maxFileSize: Int = 1_048_576, // 1MB
        includeSubmodules: Bool = false,
        branch: String? = nil
    ) {
        self.repositoryPath = repositoryPath
        self.preset = preset
        self.includePatterns = includePatterns
        self.excludePatterns = excludePatterns
        self.maxFileSize = maxFileSize
        self.includeSubmodules = includeSubmodules
        self.branch = branch
    }
}

enum GitIngestPreset: String, Codable, CaseIterable {
    case docs = "docs"
    case code = "code"
    case mixed = "mixed"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .docs:
            return "Documentation Only"
        case .code:
            return "Code Only"
        case .mixed:
            return "Mixed Content"
        case .custom:
            return "Custom Patterns"
        }
    }
    
    var defaultIncludePatterns: [String] {
        switch self {
        case .docs:
            return ["*.md", "*.txt", "README*", "CHANGELOG*", "docs/**/*"]
        case .code:
            return ["*.swift", "*.js", "*.ts", "*.py", "*.java", "*.kt", "*.go", "*.rs", "*.cpp", "*.c", "*.h"]
        case .mixed:
            return ["*.md", "*.swift", "*.js", "*.ts", "*.py", "*.json", "*.yml", "*.yaml"]
        case .custom:
            return []
        }
    }
    
    var defaultExcludePatterns: [String] {
        switch self {
        case .docs:
            return ["node_modules/**/*", ".git/**/*", "build/**/*", "dist/**/*", "*.min.*"]
        case .code:
            return ["node_modules/**/*", ".git/**/*", "build/**/*", "dist/**/*", "*.md", "docs/**/*"]
        case .mixed:
            return ["node_modules/**/*", ".git/**/*", "build/**/*", "dist/**/*", "*.min.*"]
        case .custom:
            return []
        }
    }
}

// MARK: - Manual Notes Configuration
struct ManualNotesConfiguration: Codable {
    let notesDirectory: String
    let autoSaveEnabled: Bool
    let markdownPreviewEnabled: Bool
    
    init(
        notesDirectory: String = "notes",
        autoSaveEnabled: Bool = true,
        markdownPreviewEnabled: Bool = true
    ) {
        self.notesDirectory = notesDirectory
        self.autoSaveEnabled = autoSaveEnabled
        self.markdownPreviewEnabled = markdownPreviewEnabled
    }
}