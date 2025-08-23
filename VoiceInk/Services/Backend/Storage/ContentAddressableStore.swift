import Foundation
import SwiftData
import CryptoKit
import os

/// Content-addressable storage service for artifacts with deduplication and caching
@MainActor
final class ContentAddressableStore: ObservableObject {
    static let shared = ContentAddressableStore()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ContentAddressableStore")
    
    // Storage configuration
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50MB cache
    private let defaultTTL: TimeInterval = 30 * 24 * 3600 // 30 days
    
    // In-memory cache for hot artifacts
    private var cache: [String: CachedArtifact] = [:]
    private var cacheSize: Int = 0
    private var cacheAccessOrder: [String] = []
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Start background maintenance
        Task {
            await performMaintenance()
        }
    }
    
    // MARK: - Artifact Storage
    
    func storeArtifact<T: ContentArtifact>(_ artifact: T) async throws -> String {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let contentHash = calculateContentHash(artifact.content.data)
        
        // Check if artifact already exists (deduplication)
        if let existing = try await getArtifactModel(by: contentHash) {
            existing.updateLastAccessed()
            logger.debug("Deduplicated artifact with hash: \(contentHash)")
            return contentHash
        }
        
        // Create new artifact model
        let artifactModel = try createArtifactModel(from: artifact, contentHash: contentHash)
        modelContext.insert(artifactModel)
        
        // Update cache
        updateCache(contentHash: contentHash, artifact: artifact)
        
        logger.info("Stored new artifact: \(artifact.id) with hash: \(contentHash)")
        return contentHash
    }
    
    func storeArtifacts<T: ContentArtifact>(_ artifacts: [T]) async throws -> [String] {
        var hashes: [String] = []
        
        for artifact in artifacts {
            let hash = try await storeArtifact(artifact)
            hashes.append(hash)
        }
        
        return hashes
    }
    
    // MARK: - Artifact Retrieval
    
    func getArtifact(by contentHash: String) async throws -> (any ContentArtifact)? {
        // Check cache first
        if let cached = cache[contentHash] {
            moveToFront(contentHash)
            logger.debug("Cache hit for hash: \(contentHash)")
            return cached.artifact
        }
        
        // Fallback to database
        guard let artifactModel = try await getArtifactModel(by: contentHash) else {
            return nil
        }
        
        artifactModel.updateLastAccessed()
        
        let artifact = try createArtifact(from: artifactModel)
        
        // Update cache
        updateCache(contentHash: contentHash, artifact: artifact)
        
        logger.debug("Database hit for hash: \(contentHash)")
        return artifact
    }
    
    func getArtifacts(by contentHashes: [String]) async throws -> [any ContentArtifact] {
        var artifacts: [any ContentArtifact] = []
        
        for hash in contentHashes {
            if let artifact = try await getArtifact(by: hash) {
                artifacts.append(artifact)
            }
        }
        
        return artifacts
    }
    
    func getArtifactsForSource(_ sourceId: UUID) async throws -> [any ContentArtifact] {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            predicate: #Predicate { $0.sourceId == sourceId },
            sortBy: [SortDescriptor(\.lastAccessedAt, order: .reverse)]
        )
        
        let artifactModels = try modelContext.fetch(fetchDescriptor)
        var artifacts: [any ContentArtifact] = []
        
        for model in artifactModels {
            let artifact = try createArtifact(from: model)
            artifacts.append(artifact)
            
            // Update cache for frequently accessed items
            if model.lastAccessedAt.timeIntervalSinceNow > -3600 { // Within last hour
                updateCache(contentHash: model.contentHash, artifact: artifact)
            }
        }
        
        return artifacts
    }
    
    // MARK: - Artifact Management
    
    func deleteArtifact(by contentHash: String) async throws {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        // Remove from cache
        removeFromCache(contentHash)
        
        // Remove from database
        if let artifactModel = try await getArtifactModel(by: contentHash) {
            modelContext.delete(artifactModel)
            logger.info("Deleted artifact with hash: \(contentHash)")
        }
    }
    
    func deleteArtifacts(for sourceId: UUID) async throws {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            predicate: #Predicate { $0.sourceId == sourceId }
        )
        
        let artifactModels = try modelContext.fetch(fetchDescriptor)
        
        for model in artifactModels {
            removeFromCache(model.contentHash)
            modelContext.delete(model)
        }
        
        logger.info("Deleted \(artifactModels.count) artifacts for source: \(sourceId)")
    }
    
    func deleteExpiredArtifacts() async throws {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let now = Date()
        
        // Calculate expiration time outside predicate
        let expirationTime = now.addingTimeInterval(-defaultTTL)
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            predicate: #Predicate { model in
                model.ttl != nil && 
                model.createdAt < expirationTime
            }
        )
        
        let expiredModels = try modelContext.fetch(fetchDescriptor)
        
        for model in expiredModels {
            removeFromCache(model.contentHash)
            modelContext.delete(model)
        }
        
        logger.info("Deleted \(expiredModels.count) expired artifacts")
    }
    
    func deleteEphemeralArtifacts() async throws {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            predicate: #Predicate { $0.isEphemeral == true }
        )
        
        let ephemeralModels = try modelContext.fetch(fetchDescriptor)
        
        for model in ephemeralModels {
            removeFromCache(model.contentHash)
            modelContext.delete(model)
        }
        
        logger.info("Deleted \(ephemeralModels.count) ephemeral artifacts")
    }
    
    // MARK: - Content Deduplication
    
    func findDuplicates() async throws -> [String: [UUID]] {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            sortBy: [SortDescriptor(\.contentHash)]
        )
        
        let artifacts = try modelContext.fetch(fetchDescriptor)
        var hashGroups: [String: [UUID]] = [:]
        
        for artifact in artifacts {
            if hashGroups[artifact.contentHash] != nil {
                hashGroups[artifact.contentHash]!.append(artifact.id)
            } else {
                hashGroups[artifact.contentHash] = [artifact.id]
            }
        }
        
        // Return only groups with more than one artifact
        return hashGroups.filter { $1.count > 1 }
    }
    
    func consolidateDuplicates() async throws -> Int {
        let duplicates = try await findDuplicates()
        var consolidatedCount = 0
        
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        for (hash, artifactIds) in duplicates {
            // Keep the newest artifact, delete the rest
            let artifacts = try await getArtifactModels(by: artifactIds)
            let sortedArtifacts = artifacts.sorted { $0.createdAt > $1.createdAt }
            
            if sortedArtifacts.first != nil {
                let toDelete = Array(sortedArtifacts.dropFirst())
                
                for artifact in toDelete {
                    modelContext.delete(artifact)
                    consolidatedCount += 1
                }
                
                logger.debug("Consolidated \(toDelete.count) duplicates for hash: \(hash)")
            }
        }
        
        logger.info("Consolidated \(consolidatedCount) duplicate artifacts")
        return consolidatedCount
    }
    
    // MARK: - Statistics and Health
    
    func getStorageStats() async throws -> StorageStats {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>()
        let artifacts = try modelContext.fetch(fetchDescriptor)
        
        let totalArtifacts = artifacts.count
        let totalSize = artifacts.reduce(0) { $0 + $1.fileSize }
        let uniqueHashes = Set(artifacts.map { $0.contentHash }).count
        let ephemeralCount = artifacts.filter { $0.isEphemeral }.count
        let expiredCount = artifacts.filter { $0.isExpired() }.count
        
        return StorageStats(
            totalArtifacts: totalArtifacts,
            totalSize: totalSize,
            uniqueContent: uniqueHashes,
            deduplicationRatio: totalArtifacts > 0 ? Double(uniqueHashes) / Double(totalArtifacts) : 1.0,
            ephemeralCount: ephemeralCount,
            expiredCount: expiredCount,
            cacheSize: cacheSize,
            cacheHitRate: getCacheHitRate()
        )
    }
    
    func performHealthCheck() async throws -> ContentStoreHealthStatus {
        let stats = try await getStorageStats()
        let duplicates = try await findDuplicates()
        
        var issues: [String] = []
        
        if stats.expiredCount > 100 {
            issues.append("High number of expired artifacts: \(stats.expiredCount)")
        }
        
        if duplicates.count > 50 {
            issues.append("High number of duplicate content groups: \(duplicates.count)")
        }
        
        if stats.cacheHitRate < 0.5 {
            issues.append("Low cache hit rate: \(Int(stats.cacheHitRate * 100))%")
        }
        
        let isHealthy = issues.isEmpty
        
        return ContentStoreHealthStatus(
            isHealthy: isHealthy,
            issues: issues,
            stats: stats,
            duplicateGroups: duplicates.count
        )
    }
    
    // MARK: - Maintenance
    
    func performMaintenance() async {
        logger.info("Starting content store maintenance")
        
        do {
            // Clean up expired artifacts
            try await deleteExpiredArtifacts()
            
            // Consolidate duplicates if too many
            let duplicates = try await findDuplicates()
            if duplicates.count > 100 {
                _ = try await consolidateDuplicates()
            }
            
            // Optimize cache
            optimizeCache()
            
            logger.info("Completed content store maintenance")
            
        } catch {
            logger.error("Maintenance failed: \(error.localizedDescription)")
        }
        
        // Schedule next maintenance (daily)
        Task {
            try? await Task.sleep(for: .seconds(86400))
            await performMaintenance()
        }
    }
    
    // MARK: - Private Implementation
    

    
    private func getArtifactModel(by contentHash: String) async throws -> ContentArtifactModel? {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            predicate: #Predicate { $0.contentHash == contentHash }
        )
        
        return try modelContext.fetch(fetchDescriptor).first
    }
    
    private func getArtifactModels(by ids: [UUID]) async throws -> [ContentArtifactModel] {
        guard let modelContext = modelContext else {
            throw ContentStoreError.notInitialized
        }
        
        let fetchDescriptor = FetchDescriptor<ContentArtifactModel>(
            predicate: #Predicate { model in ids.contains(model.id) }
        )
        
        return try modelContext.fetch(fetchDescriptor)
    }
    
    private func createArtifactModel<T: ContentArtifact>(
        from artifact: T,
        contentHash: String
    ) throws -> ContentArtifactModel {
        return ContentArtifactModel(
            id: artifact.id,
            contentHash: contentHash,
            artifactType: artifact.type.rawValue,
            version: artifact.version,
            sourceId: artifact.source.sourceId,
            pluginId: artifact.source.pluginId,
            sourceType: artifact.source.sourceType,
            sourcePath: artifact.source.sourcePath,
            title: artifact.metadata.title,
            description: artifact.metadata.description,
            author: artifact.metadata.author,
            tags: artifact.metadata.tags,
            score: artifact.metadata.score,
            language: artifact.metadata.language,
            fileSize: artifact.metadata.fileSize,
            lineCount: artifact.metadata.lineCount,
            customMetadata: try JSONEncoder().encode(artifact.metadata.custom),
            contentFormat: artifact.content.format.rawValue,
            contentEncoding: artifact.content.encoding,
            contentData: artifact.content.data,
            compressionAlgorithm: artifact.content.compressionAlgorithm,
            ttl: artifact.ttl,
            isEphemeral: artifact.ttl != nil && artifact.ttl! < 86400 // Less than 1 day
        )
    }
    
    private func createArtifact(from model: ContentArtifactModel) throws -> BasicContentArtifact {
        let source = ArtifactSource(
            pluginId: model.pluginId,
            sourceId: model.sourceId,
            sourceType: model.sourceType,
            sourcePath: model.sourcePath,
            additionalContext: [:]
        )
        
        let metadata = ArtifactMetadata(
            title: model.title,
            description: model.contentDescription ?? "No description",
            author: model.author,
            tags: model.tags,
            score: model.score,
            language: model.language,
            fileSize: model.fileSize,
            lineCount: model.lineCount,
            custom: (try? JSONDecoder().decode([String: String].self, from: model.customMetadata)) ?? [:]
        )
        
        let content = ContentBlob(
            format: ContentFormat(rawValue: model.contentFormat) ?? .text,
            encoding: model.contentEncoding,
            data: model.contentData,
            compressionAlgorithm: model.compressionAlgorithm
        )
        
        return BasicContentArtifact(
            id: model.id,
            type: ArtifactType(rawValue: model.artifactType) ?? .document,
            version: model.version,
            source: source,
            metadata: metadata,
            content: content,
            ttl: model.ttl,
            createdAt: model.createdAt
        )
    }
    
    // MARK: - Cache Management
    
    private func updateCache(contentHash: String, artifact: any ContentArtifact) {
        let artifactSize = artifact.content.data.count
        
        // Check if we need to evict items
        while cacheSize + artifactSize > maxCacheSize && !cache.isEmpty {
            evictLeastRecentlyUsed()
        }
        
        // Add to cache
        cache[contentHash] = CachedArtifact(
            artifact: artifact,
            size: artifactSize,
            lastAccessed: Date()
        )
        cacheSize += artifactSize
        
        // Update access order
        moveToFront(contentHash)
    }
    
    private func removeFromCache(_ contentHash: String) {
        if let cached = cache[contentHash] {
            cache.removeValue(forKey: contentHash)
            cacheSize -= cached.size
            cacheAccessOrder.removeAll { $0 == contentHash }
        }
    }
    
    private func moveToFront(_ contentHash: String) {
        cacheAccessOrder.removeAll { $0 == contentHash }
        cacheAccessOrder.append(contentHash)
        
        if let cached = cache[contentHash] {
            cached.lastAccessed = Date()
        }
    }
    
    private func evictLeastRecentlyUsed() {
        guard let lruHash = cacheAccessOrder.first else { return }
        removeFromCache(lruHash)
    }
    
    private func optimizeCache() {
        // Remove items that haven't been accessed in a while
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour
        
        let itemsToRemove = cache.filter { _, cached in
            cached.lastAccessed < cutoffDate
        }
        
        for (hash, _) in itemsToRemove {
            removeFromCache(hash)
        }
        
        logger.debug("Optimized cache, removed \(itemsToRemove.count) stale items")
    }
    
    private func getCacheHitRate() -> Double {
        // This would require tracking hits/misses, simplified for now
        return cache.isEmpty ? 0.0 : 0.8 // Placeholder
    }
}

// MARK: - Supporting Types

private class CachedArtifact {
    let artifact: any ContentArtifact
    let size: Int
    var lastAccessed: Date
    
    init(artifact: any ContentArtifact, size: Int, lastAccessed: Date) {
        self.artifact = artifact
        self.size = size
        self.lastAccessed = lastAccessed
    }
}

struct BasicContentArtifact: ContentArtifact {
    let id: UUID
    let type: ArtifactType
    let version: String
    let source: ArtifactSource
    let metadata: ArtifactMetadata
    let content: ContentBlob
    let ttl: TimeInterval?
    let createdAt: Date
    
    var contentHash: String {
        content.checksum
    }
}

struct StorageStats {
    let totalArtifacts: Int
    let totalSize: Int
    let uniqueContent: Int
    let deduplicationRatio: Double
    let ephemeralCount: Int
    let expiredCount: Int
    let cacheSize: Int
    let cacheHitRate: Double
}

struct ContentStoreHealthStatus {
    let isHealthy: Bool
    let issues: [String]
    let stats: StorageStats
    let duplicateGroups: Int
}

enum ContentStoreError: LocalizedError {
    case notInitialized
    case invalidContentHash
    case artifactNotFound(String)
    case duplicateArtifact(String)
    case cacheFull
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Content store is not initialized"
        case .invalidContentHash:
            return "Invalid content hash"
        case .artifactNotFound(let hash):
            return "Artifact not found for hash: \(hash)"
        case .duplicateArtifact(let hash):
            return "Duplicate artifact for hash: \(hash)"
        case .cacheFull:
            return "Cache is full and cannot accommodate new items"
        case .corruptedData:
            return "Artifact data is corrupted"
        }
    }
}