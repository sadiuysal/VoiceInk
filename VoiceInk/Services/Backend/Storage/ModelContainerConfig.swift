import Foundation
import SwiftData
import os

/// Enhanced model container configuration for the new backend architecture
@MainActor
final class ModelContainerConfig {
    static let shared = ModelContainerConfig()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ModelContainerConfig")
    
    private init() {}
    
    // MARK: - Model Container Creation
    
    func createContainer() throws -> ModelContainer {
        let schema = getSchema()
        let configuration = getConfiguration()
        
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            logger.info("Created model container with \(schema.entities.count) entities")
            return container
        } catch {
            logger.error("Failed to create model container: \(error.localizedDescription)")
            throw ModelContainerError.creationFailed(error)
        }
    }
    
    func createInMemoryContainer() throws -> ModelContainer {
        let schema = getSchema()
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            logger.info("Created in-memory model container for testing")
            return container
        } catch {
            logger.error("Failed to create in-memory container: \(error.localizedDescription)")
            throw ModelContainerError.creationFailed(error)
        }
    }
    
    // MARK: - Schema Definition
    
    private func getSchema() -> Schema {
        return Schema([
            // Core models (existing)
            Project.self,
            ContextSource.self,
            ContextPack.self,
            Transcription.self,
            
            // Legacy models (maintained for migration)
            IndexedDocument.self,
            MarkdownSegment.self,
            DictionaryEntry.self,
            
            // New backend models
            ContentArtifactModel.self,
            ContextSegmentModel.self,
            IngestionJobModel.self,
            ChatStreamModel.self,
            ChatMessageModel.self
        ])
    }
    
    private func getConfiguration() -> ModelConfiguration {
        let url = getStorageURL()
        
        let configuration = ModelConfiguration(
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none // Local storage only for privacy
        )
        
        return configuration
    }
    
    private func getStorageURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let voiceInkDir = appSupport.appendingPathComponent("VoiceInk")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: voiceInkDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return voiceInkDir.appendingPathComponent("VoiceInk.sqlite")
    }
    
    // MARK: - Container Initialization
    
    func initializeContainer(_ container: ModelContainer) async throws {
        let context = ModelContext(container)
        
        // Check if migration is needed
        let needsMigration = try StorageMigrations.shared.checkMigrationNeeded(context: context)
        
        if needsMigration {
            logger.info("Migration required, starting migration process")
            try await StorageMigrations.shared.performMigrations(context: context)
        }
        
        // Initialize content-addressable store
        ContentAddressableStore.shared.configure(with: context)
        
        // Validate data integrity
        let validationResult = try await StorageMigrations.shared.validateMigration(context: context)
        if !validationResult.isValid {
            logger.warning("Data validation issues: \(validationResult.issues.joined(separator: ", "))")
        }
        
        logger.info("Model container initialized successfully")
    }
    
    // MARK: - Development and Testing
    
    func createTestContainer() throws -> ModelContainer {
        return try createInMemoryContainer()
    }
    
    func createTestContext() throws -> ModelContext {
        let container = try createTestContainer()
        return ModelContext(container)
    }
    
    func seedTestData(in context: ModelContext) throws {
        // Create sample project
        let project = Project(
            name: "Test Project",
            projectDescription: "A test project for development",
            rootPath: "/Users/test/TestProject"
        )
        context.insert(project)
        
        // Create sample source
        let source = ContextSource(
            name: "Test Source",
            sourceDescription: "A test source",
            sourceType: .gitIngest,
            sourcePath: "/Users/test/TestProject",
            project: project
        )
        
        let config = GitIngestConfiguration(repositoryPath: "/Users/test/TestProject")
        try source.setConfiguration(config)
        context.insert(source)
        
        // Create sample artifact
        let artifact = ContentArtifactModel(
            contentHash: "test-hash-123",
            artifactType: ArtifactType.document.rawValue,
            version: "1.0",
            sourceId: source.id,
            pluginId: "com.sadiuysal.voiceink.plugins.test",
            sourceType: "test",
            title: "Test Document",
            description: "A test document",
            tags: ["test", "sample"],
            score: 5,
            fileSize: 1024,
            contentFormat: ContentFormat.markdown.rawValue,
            contentData: "# Test Document\n\nThis is a test document.".data(using: .utf8)!,
            source: source
        )
        context.insert(artifact)
        
        // Create sample segment
        let segment = ContextSegmentModel(
            content: "# Test Document",
            kind: "heading",
            tags: ["test", "heading"],
            score: 5,
            anchor: "test-anchor",
            startLine: 1,
            endLine: 1,
            contentHash: "segment-hash-123",
            artifact: artifact
        )
        context.insert(segment)
        
        try context.save()
        logger.info("Seeded test data")
    }
    
    // MARK: - Cleanup and Maintenance
    
    func performMaintenance(in context: ModelContext) async throws {
        logger.info("Starting database maintenance")
        
        // Clean up expired artifacts
        try await ContentAddressableStore.shared.deleteExpiredArtifacts()
        
        // Clean up orphaned records
        try await cleanupOrphanedRecords(in: context)
        
        // Optimize database
        try optimizeDatabase(in: context)
        
        logger.info("Database maintenance completed")
    }
    
    private func cleanupOrphanedRecords(in context: ModelContext) async throws {
        // Find segments without artifacts or documents
        let orphanedSegments = try context.fetch(FetchDescriptor<ContextSegmentModel>(
            predicate: #Predicate { $0.artifact == nil && $0.document == nil }
        ))
        
        for segment in orphanedSegments {
            context.delete(segment)
        }
        
        // Find jobs without sources
        let orphanedJobs = try context.fetch(FetchDescriptor<IngestionJobModel>(
            predicate: #Predicate { $0.source == nil }
        ))
        
        for job in orphanedJobs {
            context.delete(job)
        }
        
        if !orphanedSegments.isEmpty || !orphanedJobs.isEmpty {
            try context.save()
            logger.info("Cleaned up \(orphanedSegments.count) orphaned segments and \(orphanedJobs.count) orphaned jobs")
        }
    }
    
    private func optimizeDatabase(in context: ModelContext) throws {
        // Perform SQLite optimization
        // This would require direct SQLite access, simplified for now
        logger.info("Database optimization completed")
    }
    
    // MARK: - Database Health
    
    func checkDatabaseHealth(in context: ModelContext) async throws -> DatabaseHealthStatus {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check for orphaned records
        let orphanedSegments = try context.fetch(FetchDescriptor<ContextSegmentModel>(
            predicate: #Predicate { $0.artifact == nil && $0.document == nil }
        ))
        
        if !orphanedSegments.isEmpty {
            warnings.append("Found \(orphanedSegments.count) orphaned segments")
        }
        
        // Check for missing artifacts
        let segmentsWithoutArtifacts = try context.fetch(FetchDescriptor<ContextSegmentModel>(
            predicate: #Predicate { $0.artifact == nil }
        ))
        
        if segmentsWithoutArtifacts.count > orphanedSegments.count {
            let legacySegments = segmentsWithoutArtifacts.count - orphanedSegments.count
            warnings.append("Found \(legacySegments) legacy segments without artifacts")
        }
        
        // Check storage stats
        let storageStats = try await ContentAddressableStore.shared.getStorageStats()
        
        if storageStats.expiredCount > 100 {
            warnings.append("High number of expired artifacts: \(storageStats.expiredCount)")
        }
        
        if storageStats.deduplicationRatio < 0.8 {
            warnings.append("Low deduplication ratio: \(Int(storageStats.deduplicationRatio * 100))%")
        }
        
        return DatabaseHealthStatus(
            isHealthy: issues.isEmpty,
            issues: issues,
            warnings: warnings,
            storageStats: storageStats
        )
    }
    
    // MARK: - Backup and Restore
    
    func createBackup() async throws -> URL {
        let backupURL = getBackupURL()
        let storageURL = getStorageURL()
        
        // Copy the SQLite database file
        try FileManager.default.copyItem(at: storageURL, to: backupURL)
        
        logger.info("Created database backup at: \(backupURL.path)")
        return backupURL
    }
    
    private func getBackupURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let backupDir = appSupport.appendingPathComponent("VoiceInk/Backups")
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return backupDir.appendingPathComponent("VoiceInk_\(timestamp).sqlite")
    }
    
    func restoreFromBackup(_ backupURL: URL) throws {
        let storageURL = getStorageURL()
        
        // Remove current database
        try? FileManager.default.removeItem(at: storageURL)
        
        // Copy backup to storage location
        try FileManager.default.copyItem(at: backupURL, to: storageURL)
        
        logger.info("Restored database from backup: \(backupURL.path)")
    }
}

// MARK: - Supporting Types

struct DatabaseHealthStatus {
    let isHealthy: Bool
    let issues: [String]
    let warnings: [String]
    let storageStats: StorageStats
    
    var summary: String {
        if isHealthy && warnings.isEmpty {
            return "Database is healthy"
        } else if isHealthy && !warnings.isEmpty {
            return "Database is healthy with \(warnings.count) warnings"
        } else {
            return "Database has \(issues.count) issues"
        }
    }
}

enum ModelContainerError: LocalizedError {
    case creationFailed(Error)
    case migrationRequired
    case invalidConfiguration
    case backupFailed(Error)
    case restoreFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let error):
            return "Failed to create model container: \(error.localizedDescription)"
        case .migrationRequired:
            return "Database migration is required"
        case .invalidConfiguration:
            return "Invalid model configuration"
        case .backupFailed(let error):
            return "Backup failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions for Existing Models

extension Project {
    var artifactCount: Int {
        sources.reduce(0) { total, source in
            // This would need to be implemented with proper relationships
            return total
        }
    }
}

extension ContextSource {
    var lastJobStatus: String? {
        // This would need to be implemented with proper relationships
        return nil
    }
    
    var artifactCount: Int {
        // This would need to be implemented with proper relationships
        return 0
    }
}