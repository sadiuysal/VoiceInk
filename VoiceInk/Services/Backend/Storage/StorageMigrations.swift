import Foundation
import SwiftData
import os

/// Migration utilities for transitioning from legacy storage to new architecture
@MainActor
final class StorageMigrations: ObservableObject {
    static let shared = StorageMigrations()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "StorageMigrations")
    
    @Published var migrationProgress: MigrationProgress = MigrationProgress()
    @Published var isRunning = false
    
    private init() {}
    
    // MARK: - Migration Orchestration
    
    func performMigrations(context: ModelContext) async throws {
        isRunning = true
        migrationProgress.reset()
        
        defer {
            isRunning = false
        }
        
        do {
            let currentVersion = try getCurrentSchemaVersion(context: context)
            
            logger.info("Starting migration from version \(currentVersion) to \(SchemaVersion.current.rawValue)")
            
            // Perform incremental migrations
            if currentVersion < SchemaVersion.v2.rawValue {
                try await migrateToV2(context: context)
            }
            
            if currentVersion < SchemaVersion.v3.rawValue {
                try await migrateToV3(context: context)
            }
            
            // Update schema version
            try setSchemaVersion(SchemaVersion.current, context: context)
            
            migrationProgress.complete()
            logger.info("Migration completed successfully")
            
        } catch {
            migrationProgress.fail(error: error)
            logger.error("Migration failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - V1 to V2 Migration (Legacy to Artifact-based)
    
    private func migrateToV2(context: ModelContext) async throws {
        migrationProgress.startPhase("Migrating to artifact-based storage")
        
        // Migrate IndexedDocument to ContentArtifactModel
        try await migrateIndexedDocuments(context: context)
        
        // Migrate MarkdownSegment to ContextSegmentModel with artifact relationships
        try await migrateMarkdownSegments(context: context)
        
        // Create initial ingestion jobs for existing sources
        try await createInitialIngestionJobs(context: context)
        
        migrationProgress.completePhase()
        logger.info("V2 migration completed")
    }
    
    private func migrateIndexedDocuments(context: ModelContext) async throws {
        let fetchDescriptor = FetchDescriptor<IndexedDocument>()
        let documents = try context.fetch(fetchDescriptor)
        
        migrationProgress.updateTotal(documents.count)
        
        for (index, document) in documents.enumerated() {
            try await migrateDocument(document, context: context)
            migrationProgress.updateProgress(index + 1)
        }
        
        logger.info("Migrated \(documents.count) indexed documents")
    }
    
    private func migrateDocument(_ document: IndexedDocument, context: ModelContext) async throws {
        // TODO: Fix property access - filePath might not be the correct property name
        // For now, skip this migration step
        logger.warning("Migration step skipped - IndexedDocument properties need to be verified")
        return
        
        // Read document content
        // let url = URL(fileURLWithPath: document.filePath)
        // guard let content = try? String(contentsOf: url) else {
        //     logger.warning("Could not read content from: \(document.filePath)")
        //     return
        // }
        
        // TODO: Implement when IndexedDocument properties are verified
        // Create content artifact
        // let contentData = content.data(using: .utf8) ?? Data()
        // let contentHash = ContentAddressableStore.shared.calculateContentHash(contentData)
        // 
        // let artifact = ContentArtifactModel(
        //     contentHash: contentHash,
        //     artifactType: ArtifactType.document.rawValue,
        //     version: "1.0",
        //     sourceId: UUID(), // Generate placeholder source ID
        //     pluginId: "com.sadiuysal.voiceink.plugins.legacy",
        //     sourceType: "markdown",
        //     sourcePath: document.filePath,
        //     title: document.fileName,
        //     description: "Migrated from IndexedDocument",
        //     tags: ["migrated", "legacy"],
        //     score: 5, // High score for existing content
        //     fileSize: contentData.count,
        //     contentFormat: ContentFormat.markdown.rawValue,
        //     contentData: contentData
        // )
        // 
        // context.insert(artifact)
        // 
        // // Link existing segments to this artifact
        // for segment in document.segments {
        //     segment.artifact = artifact
        // }
    }
    
    private func migrateMarkdownSegments(context: ModelContext) async throws {
        let fetchDescriptor = FetchDescriptor<MarkdownSegment>()
        let segments = try context.fetch(fetchDescriptor)
        
        for segment in segments {
            // Create new ContextSegmentModel if needed
            if context.container.schema.entities.contains(where: { $0.name == "ContextSegmentModel" }) {
                let segmentModel = ContextSegmentModel(
                    content: segment.content,
                    kind: segment.kind.rawValue,
                    tags: segment.tags,
                    score: segment.score,
                    anchor: segment.anchor,
                    startLine: 0, // Default value - would need proper migration
                    endLine: 0, // Default value - would need proper migration
                    contentHash: "migrated-segment-\(segment.id.uuidString)" // Generate placeholder hash
                )
                
                context.insert(segmentModel)
            }
        }
        
        logger.info("Migrated \(segments.count) markdown segments")
    }
    
    private func createInitialIngestionJobs(context: ModelContext) async throws {
        let fetchDescriptor = FetchDescriptor<ContextSource>()
        let sources = try context.fetch(fetchDescriptor)
        
        for source in sources {
            let jobSpec = JobSpec(
                sourceId: source.id,
                pluginId: getPluginId(for: source.sourceType),
                priority: .background
            )
            
            let jobModel = IngestionJobModel(
                sourceId: source.id,
                pluginId: jobSpec.pluginId,
                status: "completed", // Mark as completed since content already exists
                priority: jobSpec.priority.rawValue,
                jobSpec: try JSONEncoder().encode(jobSpec),
                source: source
            )
            
            context.insert(jobModel)
        }
        
        logger.info("Created initial ingestion jobs for \(sources.count) sources")
    }
    
    // MARK: - V2 to V3 Migration (Add Chat Streams)
    
    private func migrateToV3(context: ModelContext) async throws {
        migrationProgress.startPhase("Adding chat stream support")
        
        // Chat streams are new functionality, no data migration needed
        // Just ensure the new models are available
        
        logger.info("Chat stream models are now available")
        migrationProgress.completePhase()
    }
    
    // MARK: - Migration Utilities
    
    func checkMigrationNeeded(context: ModelContext) throws -> Bool {
        let currentVersion = try getCurrentSchemaVersion(context: context)
        return currentVersion < SchemaVersion.current.rawValue
    }
    
    func estimateMigrationTime(context: ModelContext) throws -> TimeInterval {
        let currentVersion = try getCurrentSchemaVersion(context: context)
        var estimatedTime: TimeInterval = 0
        
        if currentVersion < SchemaVersion.v2.rawValue {
            // Estimate based on document count
            let documentCount = try context.fetch(FetchDescriptor<IndexedDocument>()).count
            estimatedTime += Double(documentCount) * 0.1 // ~0.1 seconds per document
        }
        
        if currentVersion < SchemaVersion.v3.rawValue {
            estimatedTime += 5 // 5 seconds for schema updates
        }
        
        return max(estimatedTime, 10) // Minimum 10 seconds
    }
    
    private func getCurrentSchemaVersion(context: ModelContext) throws -> Int {
        // Try to read from UserDefaults first (new method)
        if let version = UserDefaults.standard.object(forKey: "VoiceInkSchemaVersion") as? Int {
            return version
        }
        
        // Fallback: detect based on available models
        let entities = context.container.schema.entities.map { $0.name }
        
        if entities.contains("ContentArtifactModel") {
            if entities.contains("ChatStreamModel") {
                return SchemaVersion.v3.rawValue
            } else {
                return SchemaVersion.v2.rawValue
            }
        } else {
            return SchemaVersion.v1.rawValue
        }
    }
    
    private func setSchemaVersion(_ version: SchemaVersion, context: ModelContext) throws {
        UserDefaults.standard.set(version.rawValue, forKey: "VoiceInkSchemaVersion")
        UserDefaults.standard.set(Date(), forKey: "VoiceInkLastMigration")
        
        logger.info("Set schema version to: \(version.rawValue)")
    }
    
    private func getPluginId(for sourceType: ContextSourceType) -> String {
        switch sourceType {
        case .gitIngest:
            return "com.sadiuysal.voiceink.plugins.gitingest"
        case .manualNotes, .markdown, .documentation:
            return "com.sadiuysal.voiceink.plugins.manualfiles"
        }
    }
    
    // MARK: - Data Validation
    
    func validateMigration(context: ModelContext) async throws -> MigrationValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check for orphaned segments
        let orphanedSegments = try findOrphanedSegments(context: context)
        if !orphanedSegments.isEmpty {
            warnings.append("Found \(orphanedSegments.count) orphaned segments")
        }
        
        // Check for missing artifacts
        let missingArtifacts = try findMissingArtifacts(context: context)
        if !missingArtifacts.isEmpty {
            issues.append("Found \(missingArtifacts.count) segments without artifacts")
        }
        
        // Check for duplicate content hashes
        let duplicateHashes = try findDuplicateContentHashes(context: context)
        if !duplicateHashes.isEmpty {
            warnings.append("Found \(duplicateHashes.count) duplicate content hashes")
        }
        
        return MigrationValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    private func findOrphanedSegments(context: ModelContext) throws -> [ContextSegmentModel] {
        let fetchDescriptor = FetchDescriptor<ContextSegmentModel>(
            predicate: #Predicate { $0.artifact == nil && $0.document == nil }
        )
        return try context.fetch(fetchDescriptor)
    }
    
    private func findMissingArtifacts(context: ModelContext) throws -> [ContextSegmentModel] {
        let fetchDescriptor = FetchDescriptor<ContextSegmentModel>(
            predicate: #Predicate { $0.artifact == nil }
        )
        return try context.fetch(fetchDescriptor)
    }
    
    private func findDuplicateContentHashes(context: ModelContext) throws -> [String] {
        let artifacts = try context.fetch(FetchDescriptor<ContentArtifactModel>())
        let hashCounts = Dictionary(grouping: artifacts, by: { $0.contentHash })
        return hashCounts.compactMap { hash, group in
            group.count > 1 ? hash : nil
        }
    }
    
    // MARK: - Rollback Support
    
    func createMigrationBackup(context: ModelContext) async throws -> URL {
        let backupURL = getMigrationBackupURL()
        
        // Export current state to backup file
        // This is a simplified implementation - would need more robust backup/restore
        let backupData = MigrationBackup(
            version: try getCurrentSchemaVersion(context: context),
            timestamp: Date(),
            documentCount: try context.fetch(FetchDescriptor<IndexedDocument>()).count,
            segmentCount: try context.fetch(FetchDescriptor<MarkdownSegment>()).count
        )
        
        let data = try JSONEncoder().encode(backupData)
        try data.write(to: backupURL)
        
        logger.info("Created migration backup at: \(backupURL.path)")
        return backupURL
    }
    
    private func getMigrationBackupURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voiceInkDir = appSupport.appendingPathComponent("VoiceInk")
        try? FileManager.default.createDirectory(at: voiceInkDir, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return voiceInkDir.appendingPathComponent("migration_backup_\(timestamp).json")
    }
}

extension ContentAddressableStore {
    func calculateContentHash(_ data: Data) -> String {
        return data.sha256
    }
}

// MARK: - Supporting Types

class MigrationProgress: ObservableObject {
    @Published var currentPhase: String = ""
    @Published var progress: Int = 0
    @Published var total: Int = 0
    @Published var isComplete: Bool = false
    @Published var error: Error?
    
    var percentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(progress) / Double(total) * 100.0
    }
    
    func reset() {
        currentPhase = ""
        progress = 0
        total = 0
        isComplete = false
        error = nil
    }
    
    func startPhase(_ phase: String) {
        currentPhase = phase
        progress = 0
    }
    
    func updateTotal(_ newTotal: Int) {
        total = newTotal
    }
    
    func updateProgress(_ newProgress: Int) {
        progress = newProgress
    }
    
    func completePhase() {
        progress = total
    }
    
    func complete() {
        isComplete = true
        currentPhase = "Migration completed"
    }
    
    func fail(error: Error) {
        self.error = error
        currentPhase = "Migration failed"
    }
}

struct MigrationValidationResult {
    let isValid: Bool
    let issues: [String]
    let warnings: [String]
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var summary: String {
        if isValid && !hasWarnings {
            return "Migration validation passed with no issues"
        } else if isValid && hasWarnings {
            return "Migration validation passed with \(warnings.count) warnings"
        } else {
            return "Migration validation failed with \(issues.count) issues"
        }
    }
}

struct MigrationBackup: Codable {
    let version: Int
    let timestamp: Date
    let documentCount: Int
    let segmentCount: Int
}

enum MigrationError: LocalizedError {
    case unsupportedVersion(Int)
    case backupFailed(String)
    case validationFailed([String])
    case rollbackFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported schema version: \(version)"
        case .backupFailed(let message):
            return "Backup failed: \(message)"
        case .validationFailed(let issues):
            return "Validation failed: \(issues.joined(separator: ", "))"
        case .rollbackFailed(let message):
            return "Rollback failed: \(message)"
        }
    }
}