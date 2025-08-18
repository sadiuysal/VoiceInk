import Foundation
import SwiftData
import os

final class ContextIndexStore: ObservableObject {
    static let shared = ContextIndexStore()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ContextIndexStore")
    private let markdownIndexer = MarkdownIndexer()
    @MainActor private lazy var gitIngestService = GitIngestService.shared
    
    @Published var isIndexing = false
    @Published var indexProgress: Double = 0.0
    @Published var lastIndexedAt: Date?
    @Published var isGitIngestSyncing = false
    @Published var lastGitIngestSyncAt: Date?
    
    private var _modelContainer: ModelContainer?
    @MainActor
    var modelContext: ModelContext? {
        _modelContainer?.mainContext
    }
    
    private init() {
        // Don't setup container here - will be configured by main app
    }
    
    // MARK: - Configuration
    
    @MainActor
    func configure(with container: ModelContainer) {
        self._modelContainer = container
        logger.info("ContextIndexStore configured with shared ModelContainer")
    }
    
    // MARK: - Context Operations
    
    @MainActor
    func indexProject(at rootURL: URL) async {
        guard let context = modelContext else {
            logger.error("Model context not available")
            return
        }
        
        isIndexing = true
        indexProgress = 0.0
        
        defer {
            isIndexing = false
            indexProgress = 1.0
            lastIndexedAt = Date()
        }
        
        do {
            let markdownFiles = try await findMarkdownFiles(in: rootURL)
            logger.info("Found \(markdownFiles.count) markdown files to index")
            
            let rootPath = rootURL.path
            
            for (index, fileURL) in markdownFiles.enumerated() {
                try await indexFile(fileURL, rootPath: rootPath, context: context)
                indexProgress = Double(index + 1) / Double(markdownFiles.count)
            }
            
            try context.save()
            logger.info("Successfully indexed \(markdownFiles.count) files")
            
        } catch {
            logger.error("Failed to index project: \(error.localizedDescription)")
        }
    }

    // Index a single markdown file if it changed; migrate pinned segment IDs
    @MainActor
    func indexMarkdownFileIfNeeded(url fileURL: URL, rootURL: URL) async {
        guard let context = modelContext else { return }
        let rootPath = rootURL.path
        let relPath = fileURL.path.replacingOccurrences(of: rootPath + "/", with: "")
        guard fileURL.pathExtension.lowercased() == "md" else { return }

        do {
            // Fetch existing document and its segments for migration
            let existingDocument = try context.fetch(
                FetchDescriptor<IndexedDocument>(
                    predicate: #Predicate { $0.rootPath == rootPath && $0.relPath == relPath }
                )
            ).first

            let oldSegments: [MarkdownSegment] = {
                guard let doc = existingDocument else { return [] }
                let documentID = doc.id
                let descriptor = FetchDescriptor<MarkdownSegment>(
                    predicate: #Predicate<MarkdownSegment> { segment in
                        segment.documentID == documentID
                    },
                    sortBy: [SortDescriptor(\.lineStart)]
                )
                return (try? context.fetch(descriptor)) ?? []
            }()

            let fileModificationDate = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
            if let existing = existingDocument, existing.lastIndexedAt > fileModificationDate {
                logger.debug("Single-file index: up-to-date \(relPath)")
                return
            }

            // Delete existing document (segments cascade)
            if let existing = existingDocument {
                context.delete(existing)
            }

            // Re-index file
            guard let document = try await markdownIndexer.indexFile(at: fileURL, rootPath: rootPath) else { return }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let newSegments = markdownIndexer.createSegments(for: document, content: content)

            context.insert(document)
            newSegments.forEach { context.insert($0) }

            // Migrate pinned IDs
            let migration = buildSegmentMigration(oldSegments: oldSegments, newSegments: newSegments)
            migratePinnedSegments(rootPath: rootPath, migrationMap: migration)

            try context.save()
            logger.info("Single-file indexed: \(relPath) with \(newSegments.count) segments")
        } catch {
            logger.error("Single-file indexing failed (\(relPath)): \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func getIndexedDocuments(for rootPath: String) -> [IndexedDocument] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<IndexedDocument>(
            predicate: #Predicate { $0.rootPath == rootPath },
            sortBy: [SortDescriptor(\.relPath)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch indexed documents: \(error.localizedDescription)")
            return []
        }
    }
    
    @MainActor
    func getSegments(for documentID: UUID, kind: SegmentKind? = nil, minScore: Int = 1) -> [MarkdownSegment] {
        guard let context = modelContext else { return [] }
        
        var predicate: Predicate<MarkdownSegment>
        
        if let kind = kind {
            predicate = #Predicate { segment in
                segment.documentID == documentID &&
                segment.kind == kind &&
                segment.score >= minScore
            }
        } else {
            predicate = #Predicate { segment in
                segment.documentID == documentID &&
                segment.score >= minScore
            }
        }
        
        let descriptor = FetchDescriptor<MarkdownSegment>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.score, order: .reverse),
                SortDescriptor(\.lineStart)
            ]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch segments: \(error.localizedDescription)")
            return []
        }
    }
    
    @MainActor
    func getAllSegments(for rootPath: String, minScore: Int = 3) -> [MarkdownSegment] {
        guard let context = modelContext else { return [] }
        
        let documents = getIndexedDocuments(for: rootPath)
        let documentIDs = documents.map { $0.id }
        
        let descriptor = FetchDescriptor<MarkdownSegment>(
            predicate: #Predicate { segment in
                documentIDs.contains(segment.documentID) && segment.score >= minScore
            },
            sortBy: [
                SortDescriptor(\.score, order: .reverse),
                SortDescriptor(\.lineStart)
            ]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch all segments: \(error.localizedDescription)")
            return []
        }
    }
    
    @MainActor
    func searchSegments(for rootPath: String, query: String, minScore: Int = 1) -> [MarkdownSegment] {
        let allSegments = getAllSegments(for: rootPath, minScore: minScore)
        let queryLower = query.lowercased()
        
        return allSegments.filter { segment in
            segment.content.lowercased().contains(queryLower) ||
            segment.preview.lowercased().contains(queryLower) ||
            segment.tags.contains { $0.lowercased().contains(queryLower) }
        }
    }
    
    @MainActor
    func getProfiles(for rootPath: String) -> [DictionaryProfile] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<DictionaryProfile>(
            predicate: #Predicate { $0.projectRoot == rootPath },
            sortBy: [SortDescriptor(\.lastModifiedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch profiles: \(error.localizedDescription)")
            return []
        }
    }
    
    @MainActor
    func createProfile(name: String, projectRoot: String, profileDescription: String = "") -> DictionaryProfile {
        guard let context = modelContext else {
            fatalError("Model context not available")
        }
        
        let profile = DictionaryProfile(
            name: name,
            projectRoot: projectRoot,
            profileDescription: profileDescription
        )
        
        context.insert(profile)
        
        do {
            try context.save()
            logger.info("Created profile: \(name)")
        } catch {
            logger.error("Failed to save profile: \(error.localizedDescription)")
        }
        
        return profile
    }
    
    @MainActor
    func pinSegment(_ segmentID: UUID, to profile: DictionaryProfile) {
        guard let context = modelContext else { return }
        
        if !profile.pinnedSegmentIDs.contains(segmentID) {
            profile.pinnedSegmentIDs.append(segmentID)
            profile.lastModifiedAt = Date()
            
            do {
                try context.save()
                logger.debug("Pinned segment \(segmentID) to profile \(profile.name)")
            } catch {
                logger.error("Failed to pin segment: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    func unpinSegment(_ segmentID: UUID, from profile: DictionaryProfile) {
        guard let context = modelContext else { return }
        
        if let index = profile.pinnedSegmentIDs.firstIndex(of: segmentID) {
            profile.pinnedSegmentIDs.remove(at: index)
            profile.lastModifiedAt = Date()
            
            do {
                try context.save()
                logger.debug("Unpinned segment \(segmentID) from profile \(profile.name)")
            } catch {
                logger.error("Failed to unpin segment: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    func deleteDocument(_ document: IndexedDocument) {
        guard let context = modelContext else { return }
        
        context.delete(document)
        
        do {
            try context.save()
            logger.info("Deleted document: \(document.relPath)")
        } catch {
            logger.error("Failed to delete document: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func clearIndex(for rootPath: String) {
        guard let context = modelContext else { return }
        
        let documents = getIndexedDocuments(for: rootPath)
        
        for document in documents {
            context.delete(document)
        }
        
        do {
            try context.save()
            logger.info("Cleared index for: \(rootPath)")
        } catch {
            logger.error("Failed to clear index: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func generateDictionary(for profile: DictionaryProfile) -> [DictionaryEntry] {
        let pinnedSegments = getPinnedSegments(for: profile)
        var entries: [DictionaryEntry] = []
        
        // Group segments by similar content/tags
        var entriesMap: [String: DictionaryEntry] = [:]
        
        for segment in pinnedSegments {
            // Create entries for meaningful tagged terms
            let meaningfulTags = segment.tags.filter { tag in
                !tag.hasPrefix("lines:") && 
                !tag.hasPrefix("kind:") &&
                tag.contains(":")
            }
            
            for tag in meaningfulTags {
                let key = tag
                
                if var existing = entriesMap[key] {
                    existing.refs.append(segment.anchor)
                    existing.score = max(existing.score, segment.score)
                    entriesMap[key] = existing
                } else {
                    entriesMap[key] = DictionaryEntry(
                        label: tag,
                        tags: [tag],
                        refs: [segment.anchor],
                        score: segment.score,
                        examples: [segment.preview]
                    )
                }
            }
            
            // Extract meaningful terms from content
            let meaningfulTerms = extractMeaningfulTerms(from: segment.content)
            for term in meaningfulTerms {
                let key = "term:\(term)"
                
                if var existing = entriesMap[key] {
                    existing.refs.append(segment.anchor)
                    existing.score = max(existing.score, segment.score - 2) // Slightly lower score for content terms
                    entriesMap[key] = existing
                } else {
                    entriesMap[key] = DictionaryEntry(
                        label: term,
                        tags: ["term:\(term)", "extracted"],
                        refs: [segment.anchor],
                        score: segment.score - 2,
                        examples: [segment.preview]
                    )
                }
            }
        }
        
        // Filter and sort entries
        entries = Array(entriesMap.values)
            .filter { $0.score >= 3 } // Only high-quality entries
            .sorted { $0.score > $1.score }
        
        return entries
    }
    
    // MARK: - GitIngest Integration
    
    @MainActor
    func performFullRepoSync(rootURL: URL) async throws {
        guard UserDefaults.standard.useGitIngest else {
            logger.info("GitIngest disabled, skipping full repo sync")
            return
        }
        
        isGitIngestSyncing = true
        
        defer {
            isGitIngestSyncing = false
            lastGitIngestSyncAt = Date()
        }
        
        do {
            logger.info("Starting full repository sync with GitIngest for: \(rootURL.path)")
            
            let token = UserDefaults.standard.gitIngestToken
            // Use enhanced mode-aware generation to respect user patterns
            let repoDigest = try await gitIngestService.generateContext(
                for: rootURL,
                mode: .fullRepository,
                customPatterns: nil,
                token: token
            )
            
            // Process the repository digest and enhance existing context
            try await processRepositoryDigest(repoDigest, rootURL: rootURL)
            
            logger.info("Full repository sync completed successfully")
            
        } catch {
            logger.error("Full repository sync failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func performHybridSync(rootURL: URL) async throws {
        // Smart combination: file-level for recent changes, repo-level on schedule
        let shouldPerformFullSync = shouldTriggerFullRepoSync()
        
        if shouldPerformFullSync {
            try await performFullRepoSync(rootURL: rootURL)
        } else {
            // Use existing incremental indexing
            await indexProject(at: rootURL)
        }
    }
    
    @MainActor
    func createEnhancedDictionary(for rootPath: String) async throws -> String {
        guard UserDefaults.standard.useGitIngest else {
            // Fallback to existing functionality
            return createStandardDictionaryContent(for: rootPath)
        }
        
        // Combine existing MDI with GitIngest repo context
        let standardDictionary = createStandardDictionaryContent(for: rootPath)
        
        // Add repo-wide context from GitIngest if available
        let repoContextTerms = await getRepoContextTerms(for: rootPath)
        
        var enhancedContent = standardDictionary
        if !repoContextTerms.isEmpty {
            enhancedContent += "\n\n## Repository Context (GitIngest)\n"
            enhancedContent += repoContextTerms.joined(separator: "\n")
        }
        
        return enhancedContent
    }
    
    @MainActor
    private func createStandardDictionaryContent(for rootPath: String) -> String {
        // Create a basic dictionary from existing segments and filesystem context
        let segments = getAllSegments(for: rootPath, minScore: 3)
        let fsTerms = FilesystemContextService.shared.currentGlossary(topK: UserDefaults.standard.fsTermsLimit)
        
        var content = "# Project Dictionary\n\n"
        
        // Add filesystem terms
        if !fsTerms.isEmpty {
            content += "## Key Terms\n"
            for (index, term) in fsTerms.enumerated() {
                content += "\(index + 1). \(term)\n"
            }
            content += "\n"
        }
        
        // Add high-quality segments
        if !segments.isEmpty {
            content += "## Documentation Segments\n"
            for segment in segments.prefix(20) {
                content += "- \(segment.content.prefix(100))...\n"
            }
        }
        
        return content
    }
    
    // MARK: - Private GitIngest Implementation
    
    private func processRepositoryDigest(_ digest: GitIngestResult, rootURL: URL) async throws {
        // Enhance GitIngest output and store meaningful metadata/terms
        logger.info("Processing repository digest with \(digest.summary.fileCount ?? 0) files")
        
        // Post-process for richer metadata and dictionary
        let post = GitIngestPostProcessor()
        let enhanced = await post.processGitIngestOutput(result: digest)
        
        // Merge repository-wide terms from content and dictionary
        var repoTerms = extractRepositoryTerms(from: digest.content)
        repoTerms.append(contentsOf: enhanced.dictionary.technicalTerms.prefix(200))
        repoTerms.append(contentsOf: enhanced.dictionary.types.prefix(100))
        repoTerms.append(contentsOf: enhanced.dictionary.apis.prefix(100))
        repoTerms = Array(Set(repoTerms)).sorted()
        
        // Store repository context metadata (could be expanded to use SwiftData model)
        await storeRepositoryContext(digest, rootURL: rootURL, terms: repoTerms)
    }
    
    private func extractRepositoryTerms(from content: String) -> [String] {
        // Enhanced term extraction using the full repository context
        var terms: [String] = []
        
        // Use existing meaningful terms extraction
        terms += extractMeaningfulTerms(from: content)
        
        // Add repository-specific patterns
        // Class/interface definitions
        let classPattern = "(?:class|interface|struct|enum)\\s+([A-Z][a-zA-Z0-9]+)"
        if let classRegex = try? NSRegularExpression(pattern: classPattern, options: .caseInsensitive) {
            let matches = classRegex.matches(in: content, range: NSRange(location: 0, length: content.count))
            for match in matches where match.numberOfRanges > 1 {
                if let range = Range(match.range(at: 1), in: content) {
                    terms.append(String(content[range]))
                }
            }
        }
        
        // Function/method names
        let functionPattern = "(?:func|function|def)\\s+([a-zA-Z_][a-zA-Z0-9_]+)"
        if let funcRegex = try? NSRegularExpression(pattern: functionPattern, options: .caseInsensitive) {
            let matches = funcRegex.matches(in: content, range: NSRange(location: 0, length: content.count))
            for match in matches where match.numberOfRanges > 1 {
                if let range = Range(match.range(at: 1), in: content) {
                    let term = String(content[range])
                    if term.count >= 3 { // Filter very short function names
                        terms.append(term)
                    }
                }
            }
        }
        
        return Array(Set(terms)).sorted()
    }
    
    private func storeRepositoryContext(_ digest: GitIngestResult, rootURL: URL, terms: [String]) async {
        // Store repository context data
        // This could be enhanced to use a dedicated SwiftData model for repository metadata
        let contextData: [String: Any] = [
            "timestamp": digest.timestamp,
            "fileCount": digest.summary.fileCount ?? 0,
            "terms": terms,
            "rootPath": rootURL.path
        ]
        
        // For now, store in UserDefaults (could be moved to SwiftData later)
        let key = "GitIngestContext_\(rootURL.path.replacingOccurrences(of: "/", with: "_"))"
        UserDefaults.standard.set(contextData, forKey: key)
        
        logger.info("Stored repository context with \(terms.count) terms")
    }
    
    private func shouldTriggerFullRepoSync() -> Bool {
        guard UserDefaults.standard.gitIngestAutoSync else { return false }
        
        guard let lastSync = lastGitIngestSyncAt else { return true }
        
        let interval = UserDefaults.standard.gitIngestSyncInterval
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        
        return timeSinceLastSync > interval
    }
    
    private func getRepoContextTerms(for rootPath: String) async -> [String] {
        let key = "GitIngestContext_\(rootPath.replacingOccurrences(of: "/", with: "_"))"
        
        guard let contextData = UserDefaults.standard.dictionary(forKey: key),
              let terms = contextData["terms"] as? [String] else {
            return []
        }
        
        return terms.prefix(50).map { "- \($0)" } // Limit and format for dictionary
    }
    
    // MARK: - Private Implementation
    
    private func findMarkdownFiles(in directory: URL) async throws -> [URL] {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .pathKey]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw NSError(domain: "ContextIndexStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create directory enumerator"])
        }
        
        var markdownFiles: [URL] = []
        
        let enumArray = Array(enumerator)
        for case let fileURL as URL in enumArray {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if resourceValues.isRegularFile == true {
                markdownFiles.append(fileURL)
            }
        }
        
        return markdownFiles
    }
    
    private func indexFile(_ fileURL: URL, rootPath: String, context: ModelContext) async throws {
        let relPath = fileURL.path.replacingOccurrences(of: rootPath + "/", with: "")
        
        // Check if file is already indexed and up-to-date
        let existingDocument = try? context.fetch(
            FetchDescriptor<IndexedDocument>(
                predicate: #Predicate { $0.rootPath == rootPath && $0.relPath == relPath }
            )
        ).first
        
        let fileModificationDate = try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
        
        if let existing = existingDocument,
           existing.lastIndexedAt > fileModificationDate {
            logger.debug("Skipping up-to-date file: \(relPath)")
            return
        }
        
        // Delete existing document and segments
        if let existing = existingDocument {
            context.delete(existing)
        }
        
        // Index the file
        guard let document = try await markdownIndexer.indexFile(at: fileURL, rootPath: rootPath) else {
            return
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let segments = markdownIndexer.createSegments(for: document, content: content)
        
        context.insert(document)
        
        for segment in segments {
            context.insert(segment)
        }
        
        logger.debug("Indexed \(segments.count) segments from \(relPath)")
    }

    // MARK: - Pinned migration helpers

    private func buildSegmentMigration(oldSegments: [MarkdownSegment], newSegments: [MarkdownSegment]) -> [UUID: UUID] {
        var map: [UUID: UUID] = [:]
        // Precompute token sets for similarity
        let newByKey: [(MarkdownSegment, Set<String>)] = newSegments.map { ($0, tokenSet($0.content)) }

        for old in oldSegments {
            let oldTokens = tokenSet(old.content)
            var best: (UUID, Double)? = nil
            for (cand, candTokens) in newByKey {
                if cand.kind != old.kind { continue }
                if let os = old.sectionSlug, let ns = cand.sectionSlug, !os.isEmpty, !ns.isEmpty, os != ns { continue }
                let sim = jaccard(oldTokens, candTokens)
                if sim > (best?.1 ?? -1) { best = (cand.id, sim) }
            }
            if let (newId, score) = best, score >= 0.3 { // threshold
                map[old.id] = newId
            }
        }
        return map
    }

    private func tokenSet(_ s: String) -> Set<String> {
        let words = s
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: " ", options: .regularExpression)
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 }
        return Set(words)
    }

    private func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let inter = a.intersection(b).count
        let union = a.union(b).count
        return union == 0 ? 0 : Double(inter) / Double(union)
    }

    @MainActor
    private func migratePinnedSegments(rootPath: String, migrationMap: [UUID: UUID]) {
        guard let context = modelContext, !migrationMap.isEmpty else { return }
        let profiles = getProfiles(for: rootPath)
        for profile in profiles {
            var changed = false
            var newPinned: [UUID] = []
            for id in profile.pinnedSegmentIDs {
                if let mapped = migrationMap[id] {
                    if !newPinned.contains(mapped) { newPinned.append(mapped) }
                    changed = true
                } else {
                    if !newPinned.contains(id) { newPinned.append(id) }
                }
            }
            if changed {
                profile.pinnedSegmentIDs = newPinned
                profile.lastModifiedAt = Date()
            }
        }
        do { try context.save() } catch {
            logger.error("Failed to save pinned migration: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func getPinnedSegments(for profile: DictionaryProfile) -> [MarkdownSegment] {
        guard let context = modelContext else { return [] }
        
        let segmentIDs = profile.pinnedSegmentIDs
        
        let descriptor = FetchDescriptor<MarkdownSegment>(
            predicate: #Predicate { segment in
                segmentIDs.contains(segment.id)
            },
            sortBy: [SortDescriptor(\.score, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch pinned segments: \(error.localizedDescription)")
            return []
        }
    }
    
    private func extractMeaningfulTerms(from content: String) -> [String] {
        // Extract CamelCase, kebab-case, snake_case terms
        var terms: [String] = []
        
        // CamelCase pattern
        let camelCasePattern = "[A-Z][a-z]+(?:[A-Z][a-z]+)+"
        if let camelRegex = try? NSRegularExpression(pattern: camelCasePattern) {
            let matches = camelRegex.matches(in: content, range: NSRange(location: 0, length: content.count))
            for match in matches {
                if let range = Range(match.range, in: content) {
                    terms.append(String(content[range]))
                }
            }
        }
        
        // kebab-case pattern
        let kebabPattern = "[a-z]+(?:-[a-z]+)+"
        if let kebabRegex = try? NSRegularExpression(pattern: kebabPattern) {
            let matches = kebabRegex.matches(in: content, range: NSRange(location: 0, length: content.count))
            for match in matches {
                if let range = Range(match.range, in: content) {
                    let term = String(content[range])
                    if term.count >= 5 { // Meaningful kebab-case terms
                        terms.append(term)
                    }
                }
            }
        }
        
        // snake_case pattern
        let snakePattern = "[a-z]+(?:_[a-z]+)+"
        if let snakeRegex = try? NSRegularExpression(pattern: snakePattern) {
            let matches = snakeRegex.matches(in: content, range: NSRange(location: 0, length: content.count))
            for match in matches {
                if let range = Range(match.range, in: content) {
                    let term = String(content[range])
                    if term.count >= 5 { // Meaningful snake_case terms
                        terms.append(term)
                    }
                }
            }
        }
        
        return Array(Set(terms)).sorted() // Remove duplicates and sort
    }
}

// MARK: - Supporting Types

struct DictionaryEntry {
    let label: String
    let tags: [String]
    var refs: [String]
    var score: Int
    let examples: [String]
}

extension ContextIndexStore {
    @MainActor
    func getModelContext() -> ModelContext? {
        return modelContext
    }
}
