import Foundation
import SwiftData
import os

/// Manual files plugin for .md/.json file selection with change detection
actor ManualFilesPlugin: SourcePlugin {
    typealias Config = ManualFilesConfiguration
    typealias Artifact = FileArtifact
    
    let pluginId = "com.sadiuysal.voiceink.plugins.manualfiles"
    let displayName = "Manual Files"
    let version = "1.0.0"
    let capabilities = PluginCapabilities(
        supportsOffline: true,
        requiresNetwork: false,
        requiresCredentials: false,
        maxConcurrentJobs: 2,
        supportedFormats: [.markdown, .text, .json, .yaml],
        supportedArtifactTypes: [.document, .snippet, .metadata]
    )
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ManualFilesPlugin")
    
    // Plugin state
    private var currentConfig: ManualFilesConfiguration?
    private var isConfigured = false
    private var runningJobs: [UUID: Task<[FileArtifact], Error>] = [:]
    
    // File monitoring
    private var fileMonitor: FileMonitor?
    private var trackedFiles: Set<String> = []
    private var fileHashes: [String: String] = [:]
    
    init() {
        logger.info("Manual Files plugin initialized")
    }
    
    // MARK: - Plugin Lifecycle
    
    func configure(_ config: ManualFilesConfiguration) async throws {
        guard try await validate(config) else {
            throw ManualFilesError.invalidConfiguration("Configuration validation failed")
        }
        
        currentConfig = config
        isConfigured = true
        
        // Set up file monitoring if enabled
        if config.enableAutoDetection {
            await setupFileMonitoring(config: config)
        }
        
        logger.info("Configured Manual Files plugin with \(config.selectedFiles.count) files")
    }
    
    func validate(_ config: ManualFilesConfiguration) async throws -> Bool {
        // Validate all selected files exist
        for filePath in config.selectedFiles {
            guard FileManager.default.fileExists(atPath: filePath) else {
                return false
            }
        }
        
        // Validate base directory if provided
        if let baseDir = config.baseDirectory {
            guard FileManager.default.fileExists(atPath: baseDir) else {
                return false
            }
        }
        
        return true
    }
    
    func isAvailable() async -> Bool {
        return true // Always available for local files
    }
    
    // MARK: - Job Planning and Execution
    
    func planJobs(for source: ContextSource) async throws -> [JobSpec] {
        guard let config = currentConfig else {
            throw ManualFilesError.notConfigured
        }
        
        var jobSpecs: [JobSpec] = []
        
        // Group files by type for efficient processing
        let fileGroups = groupFilesByType(files: config.selectedFiles)
        
        // Create job for each file type
        for (fileType, files) in fileGroups {
            let jobSpec = JobSpec(
                sourceId: source.id,
                pluginId: pluginId,
                priority: fileType == .markdown ? .high : .normal,
                parameters: [
                    "file_type": fileType.rawValue,
                    "files": files.joined(separator: "|"),
                    "validate_content": String(config.validateContent),
                    "extract_metadata": String(config.extractMetadata),
                    "enable_change_detection": String(config.enableChangeDetection)
                ],
                timeout: 120
            )
            
            jobSpecs.append(jobSpec)
        }
        
        // Add file discovery job if auto-detection is enabled
        if config.enableAutoDetection {
            let discoveryJob = JobSpec(
                sourceId: source.id,
                pluginId: pluginId,
                priority: .low,
                parameters: [
                    "job_type": "file_discovery",
                    "base_directory": config.baseDirectory ?? "",
                    "file_patterns": config.filePatterns.joined(separator: ","),
                    "max_files": String(config.maxFiles)
                ],
                timeout: 60
            )
            
            jobSpecs.append(discoveryJob)
        }
        
        logger.info("Planned \(jobSpecs.count) file processing jobs")
        return jobSpecs
    }
    
    func executeJob(_ job: JobSpec) async throws -> [FileArtifact] {
        guard let config = currentConfig else {
            throw ManualFilesError.notConfigured
        }
        
        let jobType = job.parameters["job_type"] ?? "process_files"
        
        // Create cancellable task
        let task = Task<[FileArtifact], Error> {
            try await self.executeJobInternal(job: job, config: config, jobType: jobType)
        }
        
        runningJobs[job.id] = task
        
        do {
            let artifacts = try await task.value
            runningJobs.removeValue(forKey: job.id)
            
            logger.info("Completed job \(job.id) (\(jobType)), produced \(artifacts.count) artifacts")
            return artifacts
        } catch {
            runningJobs.removeValue(forKey: job.id)
            throw error
        }
    }
    
    private func executeJobInternal(
        job: JobSpec,
        config: ManualFilesConfiguration,
        jobType: String
    ) async throws -> [FileArtifact] {
        switch jobType {
        case "file_discovery":
            return try await executeFileDiscoveryJob(job: job, config: config)
        default:
            return try await executeFileProcessingJob(job: job, config: config)
        }
    }
    
    func cancelJob(_ jobId: UUID) async {
        if let task = runningJobs[jobId] {
            task.cancel()
            runningJobs.removeValue(forKey: jobId)
            logger.info("Cancelled job: \(jobId)")
        }
    }
    
    func cleanup() async {
        // Cancel all running jobs
        for (jobId, task) in runningJobs {
            task.cancel()
        }
        runningJobs.removeAll()
        
        // Stop file monitoring
        await fileMonitor?.stop()
        fileMonitor = nil
        
        isConfigured = false
        currentConfig = nil
        
        logger.info("Manual Files plugin cleaned up")
    }
    
    // MARK: - Content Preview and Testing
    
    func previewContent(for source: ContextSource) async throws -> ContentPreview {
        guard let config = currentConfig else {
            throw ManualFilesError.notConfigured
        }
        
        var sampleItems: [ContentPreview.PreviewItem] = []
        var totalSize = 0
        
        // Preview first few files
        for filePath in config.selectedFiles.prefix(5) {
            do {
                let fileInfo = try await getFileInfo(filePath: filePath)
                sampleItems.append(ContentPreview.PreviewItem(
                    title: fileInfo.name,
                    type: fileInfo.artifactType,
                    size: fileInfo.size,
                    preview: fileInfo.preview
                ))
                
                totalSize += fileInfo.size
                
            } catch {
                logger.warning("Failed to preview file \(filePath): \(error.localizedDescription)")
                
                sampleItems.append(ContentPreview.PreviewItem(
                    title: URL(fileURLWithPath: filePath).lastPathComponent,
                    type: .document,
                    size: 0,
                    preview: "Preview unavailable: \(error.localizedDescription)"
                ))
            }
        }
        
        return ContentPreview(
            title: "Manual Files Selection",
            description: "\(config.selectedFiles.count) manually selected files",
            itemCount: config.selectedFiles.count,
            estimatedSize: totalSize,
            sampleItems: sampleItems
        )
    }
    
    func testConnection(for source: ContextSource) async throws -> ConnectionTestResult {
        guard let config = currentConfig else {
            throw ManualFilesError.notConfigured
        }
        
        let startTime = Date()
        var accessibleFiles = 0
        var inaccessibleFiles: [String] = []
        
        // Test access to all selected files
        for filePath in config.selectedFiles {
            if FileManager.default.fileExists(atPath: filePath) &&
               FileManager.default.isReadableFile(atPath: filePath) {
                accessibleFiles += 1
            } else {
                inaccessibleFiles.append(filePath)
            }
        }
        
        let latency = Date().timeIntervalSince(startTime)
        
        if inaccessibleFiles.isEmpty {
            return .success(
                message: "All \(accessibleFiles) files are accessible",
                latency: latency,
                metadata: [
                    "accessible_files": String(accessibleFiles),
                    "total_files": String(config.selectedFiles.count)
                ]
            )
        } else {
            return .failure(
                message: "\(inaccessibleFiles.count) files are not accessible",
                metadata: [
                    "accessible_files": String(accessibleFiles),
                    "inaccessible_files": inaccessibleFiles.joined(separator: ", ")
                ]
            )
        }
    }
    
    // MARK: - Job Implementations
    
    private func executeFileProcessingJob(
        job: JobSpec,
        config: ManualFilesConfiguration
    ) async throws -> [FileArtifact] {
        guard let filesString = job.parameters["files"] else {
            throw ManualFilesError.missingParameter("files")
        }
        
        let fileType = FileType(rawValue: job.parameters["file_type"] ?? "unknown") ?? .unknown
        let validateContent = Bool(job.parameters["validate_content"] ?? "true") ?? true
        let extractMetadata = Bool(job.parameters["extract_metadata"] ?? "true") ?? true
        let enableChangeDetection = Bool(job.parameters["enable_change_detection"] ?? "false") ?? false
        
        let files = filesString.split(separator: "|").map(String.init)
        var artifacts: [FileArtifact] = []
        
        for filePath in files {
            do {
                // Check for changes if enabled
                if enableChangeDetection && !hasFileChanged(filePath: filePath) {
                    logger.debug("Skipping unchanged file: \(filePath)")
                    continue
                }
                
                let artifact = try await processFile(
                    filePath: filePath,
                    fileType: fileType,
                    sourceId: job.sourceId,
                    validateContent: validateContent,
                    extractMetadata: extractMetadata
                )
                
                artifacts.append(artifact)
                
                // Update file hash for change detection
                if enableChangeDetection {
                    await updateFileHash(filePath: filePath)
                }
                
            } catch {
                logger.error("Failed to process file \(filePath): \(error.localizedDescription)")
                
                // Create error artifact
                let errorArtifact = try createErrorArtifact(
                    filePath: filePath,
                    error: error,
                    sourceId: job.sourceId
                )
                artifacts.append(errorArtifact)
            }
        }
        
        return artifacts
    }
    
    private func executeFileDiscoveryJob(
        job: JobSpec,
        config: ManualFilesConfiguration
    ) async throws -> [FileArtifact] {
        guard let baseDirectory = job.parameters["base_directory"], !baseDirectory.isEmpty else {
            return [] // No discovery without base directory
        }
        
        let filePatterns = job.parameters["file_patterns"]?.split(separator: ",").map(String.init) ?? ["*.md", "*.json"]
        let maxFiles = Int(job.parameters["max_files"] ?? "100") ?? 100
        
        let discoveredFiles = try await discoverFiles(
            in: baseDirectory,
            patterns: filePatterns,
            maxFiles: maxFiles
        )
        
        // Create discovery summary artifact
        let summary = FileDiscoverySummary(
            baseDirectory: baseDirectory,
            patterns: filePatterns,
            discoveredFiles: discoveredFiles,
            totalCount: discoveredFiles.count,
            discoveredAt: Date()
        )
        
        let summaryArtifact = try createDiscoverySummaryArtifact(
            summary: summary,
            sourceId: job.sourceId
        )
        
        return [summaryArtifact]
    }
    
    // MARK: - File Processing
    
    private func processFile(
        filePath: String,
        fileType: FileType,
        sourceId: UUID,
        validateContent: Bool,
        extractMetadata: Bool
    ) async throws -> FileArtifact {
        let fileURL = URL(fileURLWithPath: filePath)
        
        // Read file content
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        
        // Validate content if enabled
        if validateContent {
            try validateFileContent(content: content, fileType: fileType)
        }
        
        // Extract metadata if enabled
        var fileMetadata: [String: String] = [:]
        if extractMetadata {
            fileMetadata = try await extractFileMetadata(
                filePath: filePath,
                content: content,
                fileType: fileType
            )
        }
        
        return try createFileArtifact(
            filePath: filePath,
            content: content,
            fileType: fileType,
            sourceId: sourceId,
            metadata: fileMetadata
        )
    }
    
    private func createFileArtifact(
        filePath: String,
        content: String,
        fileType: FileType,
        sourceId: UUID,
        metadata: [String: String]
    ) throws -> FileArtifact {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let contentData = content.data(using: .utf8) ?? Data()
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "manual_file",
            sourcePath: filePath,
            additionalContext: [
                "file_type": fileType.rawValue,
                "file_name": fileName,
                "file_extension": fileURL.pathExtension
            ]
        )
        
        let artifactMetadata = ArtifactMetadata(
            title: fileName,
            description: "Manually selected file: \(fileName)",
            tags: ["manual", "file", fileType.rawValue, fileURL.pathExtension],
            score: calculateFileScore(fileType: fileType, content: content),
            language: detectProgrammingLanguage(fileName: fileName, content: content),
            fileSize: contentData.count,
            lineCount: content.components(separatedBy: .newlines).count,
            custom: metadata
        )
        
        let contentBlob = ContentBlob(
            format: determineContentFormat(fileType: fileType, fileName: fileName),
            data: contentData
        )
        
        // Get file attributes
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let modificationDate = fileAttributes[.modificationDate] as? Date
        let creationDate = fileAttributes[.creationDate] as? Date
        
        return FileArtifact(
            id: UUID(),
            type: determineArtifactType(fileType: fileType),
            version: "1.0",
            source: source,
            metadata: artifactMetadata,
            content: contentBlob,
            ttl: nil,
            createdAt: Date(),
            filePath: filePath,
            fileType: fileType,
            modificationDate: modificationDate,
            creationDate: creationDate,
            fileSize: Int64(contentData.count),
            filePermissions: getFilePermissions(filePath: filePath)
        )
    }
    
    private func createErrorArtifact(
        filePath: String,
        error: Error,
        sourceId: UUID
    ) throws -> FileArtifact {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let errorContent = "Error processing file: \(error.localizedDescription)"
        let errorData = errorContent.data(using: .utf8) ?? Data()
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "manual_file_error",
            sourcePath: filePath
        )
        
        let metadata = ArtifactMetadata(
            title: "Error: \(fileName)",
            description: "Error occurred while processing file",
            tags: ["manual", "file", "error"],
            score: 0, // Low score for errors
            fileSize: errorData.count,
            custom: [
                "error_type": String(describing: type(of: error)),
                "error_message": error.localizedDescription
            ]
        )
        
        let content = ContentBlob(
            format: .text,
            data: errorData
        )
        
        return FileArtifact(
            id: UUID(),
            type: .snippet,
            version: "1.0",
            source: source,
            metadata: metadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            filePath: filePath,
            fileType: .unknown,
            modificationDate: nil,
            creationDate: nil,
            fileSize: 0,
            filePermissions: nil
        )
    }
    
    private func createDiscoverySummaryArtifact(
        summary: FileDiscoverySummary,
        sourceId: UUID
    ) throws -> FileArtifact {
        let summaryData = try JSONEncoder().encode(summary)
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "file_discovery"
        )
        
        let metadata = ArtifactMetadata(
            title: "File Discovery Summary",
            description: "Summary of discovered files in directory",
            tags: ["manual", "discovery", "summary"],
            score: 8,
            fileSize: summaryData.count,
            custom: [
                "base_directory": summary.baseDirectory,
                "discovered_count": String(summary.totalCount)
            ]
        )
        
        let content = ContentBlob(
            format: .json,
            data: summaryData
        )
        
        return FileArtifact(
            id: UUID(),
            type: .metadata,
            version: "1.0",
            source: source,
            metadata: metadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            filePath: nil,
            fileType: .json,
            modificationDate: nil,
            creationDate: nil,
            fileSize: Int64(summaryData.count),
            filePermissions: nil
        )
    }
    
    // MARK: - File Discovery and Monitoring
    
    private func discoverFiles(
        in directory: String,
        patterns: [String],
        maxFiles: Int
    ) async throws -> [String] {
        let directoryURL = URL(fileURLWithPath: directory)
        let fileManager = FileManager.default
        
        var discoveredFiles: [String] = []
        let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey])
        
        while let fileURL = enumerator?.nextObject() as? URL, discoveredFiles.count < maxFiles {
            // Check if it's a regular file
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            
            // Check against patterns
            let fileName = fileURL.lastPathComponent
            let matchesPattern = patterns.contains { pattern in
                fileName.matches(pattern: pattern)
            }
            
            if matchesPattern {
                discoveredFiles.append(fileURL.path)
            }
        }
        
        return discoveredFiles
    }
    
    private func setupFileMonitoring(config: ManualFilesConfiguration) async {
        guard config.enableChangeDetection else { return }
        
        fileMonitor = FileMonitor { [weak self] changedFiles in
            Task {
                await self?.handleFileChanges(changedFiles)
            }
        }
        
        // Add selected files to monitoring
        for filePath in config.selectedFiles {
            await fileMonitor?.addFile(filePath)
            trackedFiles.insert(filePath)
        }
        
        await fileMonitor?.start()
        logger.info("Started monitoring \(self.trackedFiles.count) files")
    }
    
    private func handleFileChanges(_ changedFiles: [String]) async {
        logger.info("Detected changes in \(changedFiles.count) files")
        
        // Update file hashes for changed files
        for filePath in changedFiles {
            await updateFileHash(filePath: filePath)
        }
        
        // Notify about changes (could trigger re-ingestion)
        // This would integrate with the orchestrator to schedule new jobs
    }
    
    private func hasFileChanged(filePath: String) -> Bool {
        guard let currentHash = calculateFileHash(filePath: filePath),
              let previousHash = fileHashes[filePath] else {
            return true // Treat as changed if we can't determine
        }
        
        return currentHash != previousHash
    }
    
    private func updateFileHash(filePath: String) async {
        if let hash = calculateFileHash(filePath: filePath) {
            fileHashes[filePath] = hash
        }
    }
    
    private func calculateFileHash(filePath: String) -> String? {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            return nil
        }
        
        return data.sha256
    }
    
    // MARK: - Helper Methods
    
    private func groupFilesByType(files: [String]) -> [FileType: [String]] {
        var groups: [FileType: [String]] = [:]
        
        for filePath in files {
            let fileType = determineFileType(filePath: filePath)
            if groups[fileType] == nil {
                groups[fileType] = []
            }
            groups[fileType]!.append(filePath)
        }
        
        return groups
    }
    
    private func determineFileType(filePath: String) -> FileType {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch fileExtension {
        case "md", "markdown":
            return .markdown
        case "json":
            return .json
        case "yaml", "yml":
            return .yaml
        case "txt":
            return .text
        case "xml":
            return .xml
        default:
            return .unknown
        }
    }
    
    private func determineContentFormat(fileType: FileType, fileName: String) -> ContentFormat {
        switch fileType {
        case .markdown:
            return .markdown
        case .json:
            return .json
        case .yaml:
            return .yaml
        case .xml:
            return .xml
        default:
            return .text
        }
    }
    
    private func determineArtifactType(fileType: FileType) -> ArtifactType {
        switch fileType {
        case .markdown, .text:
            return .document
        case .json, .yaml, .xml:
            return .metadata
        default:
            return .snippet
        }
    }
    
    private func calculateFileScore(fileType: FileType, content: String) -> Int {
        var score = 1
        
        // Higher score for structured formats
        switch fileType {
        case .markdown:
            score += 4
        case .json, .yaml:
            score += 3
        case .text:
            score += 2
        default:
            score += 1
        }
        
        // Adjust for content length
        let contentLength = content.count
        if contentLength > 100 && contentLength < 50000 {
            score += 2
        }
        
        // Higher score for files with structure
        if content.contains("# ") || content.contains("## ") { // Headings
            score += 1
        }
        
        return max(1, score)
    }
    
    private func detectProgrammingLanguage(fileName: String, content: String) -> String? {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        
        switch fileExtension {
        case "swift": return "Swift"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "py": return "Python"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "go": return "Go"
        case "rs": return "Rust"
        case "cpp", "cc": return "C++"
        case "c": return "C"
        case "h": return "C/C++ Header"
        default: return nil
        }
    }
    
    private func validateFileContent(content: String, fileType: FileType) throws {
        switch fileType {
        case .json:
            // Validate JSON
            _ = try JSONSerialization.jsonObject(with: content.data(using: .utf8) ?? Data())
        case .yaml:
            // Basic YAML validation (would use a proper YAML parser in practice)
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ManualFilesError.invalidContent("YAML content is empty")
            }
        default:
            // No specific validation for other types
            break
        }
    }
    
    private func extractFileMetadata(
        filePath: String,
        content: String,
        fileType: FileType
    ) async throws -> [String: String] {
        var metadata: [String: String] = [:]
        
        // File system metadata
        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        
        metadata["file_name"] = fileURL.lastPathComponent
        metadata["file_extension"] = fileURL.pathExtension
        metadata["file_size"] = String(attributes[.size] as? Int64 ?? 0)
        
        if let modDate = attributes[.modificationDate] as? Date {
            metadata["modification_date"] = ISO8601DateFormatter().string(from: modDate)
        }
        
        // Content-specific metadata
        switch fileType {
        case .markdown:
            metadata.merge(extractMarkdownMetadata(content: content)) { _, new in new }
        case .json:
            metadata.merge(extractJsonMetadata(content: content)) { _, new in new }
        default:
            break
        }
        
        return metadata
    }
    
    private func extractMarkdownMetadata(content: String) -> [String: String] {
        var metadata: [String: String] = [:]
        
        let lines = content.components(separatedBy: .newlines)
        
        // Count headings
        let headingCount = lines.filter { $0.hasPrefix("#") }.count
        metadata["heading_count"] = String(headingCount)
        
        // Extract first heading as title
        if let firstHeading = lines.first(where: { $0.hasPrefix("#") }) {
            let title = firstHeading.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            metadata["title"] = title
        }
        
        // Count links
        let linkPattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
        let linkMatches = content.matches(for: linkPattern)
        metadata["link_count"] = String(linkMatches.count)
        
        return metadata
    }
    
    private func extractJsonMetadata(content: String) -> [String: String] {
        var metadata: [String: String] = [:]
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: content.data(using: .utf8) ?? Data())
            
            if let dictionary = jsonObject as? [String: Any] {
                metadata["key_count"] = String(dictionary.keys.count)
                metadata["top_level_keys"] = Array(dictionary.keys.prefix(5)).joined(separator: ", ")
            } else if let array = jsonObject as? [Any] {
                metadata["array_length"] = String(array.count)
                metadata["structure_type"] = "array"
            }
            
        } catch {
            metadata["parse_error"] = error.localizedDescription
        }
        
        return metadata
    }
    
    private func getFileInfo(filePath: String) async throws -> FileInfo {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let fileType = determineFileType(filePath: filePath)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let size = attributes[.size] as? Int64 ?? 0
        
        // Read first few lines for preview
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(3).joined(separator: "\n")
        
        return FileInfo(
            name: fileName,
            size: Int(size),
            artifactType: determineArtifactType(fileType: fileType),
            preview: preview.isEmpty ? "Empty file" : preview
        )
    }
    
    private func getFilePermissions(filePath: String) -> String? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
        guard let permissions = attributes?[.posixPermissions] as? NSNumber else {
            return nil
        }
        
        return String(format: "%o", permissions.intValue)
    }
    
    private func validate(_ config: ManualFilesConfiguration) -> Bool {
        return !config.selectedFiles.isEmpty
    }
}

// MARK: - Supporting Types

struct FileArtifact: ContentArtifact {
    let id: UUID
    let type: ArtifactType
    let version: String
    let source: ArtifactSource
    let metadata: ArtifactMetadata
    let content: ContentBlob
    let ttl: TimeInterval?
    let createdAt: Date
    
    // File-specific data
    let filePath: String?
    let fileType: FileType
    let modificationDate: Date?
    let creationDate: Date?
    let fileSize: Int64
    let filePermissions: String?
    
    var contentHash: String {
        content.checksum
    }
}

struct ManualFilesConfiguration: Codable {
    let selectedFiles: [String]
    let baseDirectory: String?
    let filePatterns: [String]
    let maxFiles: Int
    let enableAutoDetection: Bool
    let enableChangeDetection: Bool
    let validateContent: Bool
    let extractMetadata: Bool
    
    init(
        selectedFiles: [String],
        baseDirectory: String? = nil,
        filePatterns: [String] = ["*.md", "*.json"],
        maxFiles: Int = 100,
        enableAutoDetection: Bool = false,
        enableChangeDetection: Bool = true,
        validateContent: Bool = true,
        extractMetadata: Bool = true
    ) {
        self.selectedFiles = selectedFiles
        self.baseDirectory = baseDirectory
        self.filePatterns = filePatterns
        self.maxFiles = maxFiles
        self.enableAutoDetection = enableAutoDetection
        self.enableChangeDetection = enableChangeDetection
        self.validateContent = validateContent
        self.extractMetadata = extractMetadata
    }
}

enum FileType: String, Codable, CaseIterable {
    case markdown = "markdown"
    case json = "json"
    case yaml = "yaml"
    case text = "text"
    case xml = "xml"
    case unknown = "unknown"
}

struct FileInfo {
    let name: String
    let size: Int
    let artifactType: ArtifactType
    let preview: String
}

struct FileDiscoverySummary: Codable {
    let baseDirectory: String
    let patterns: [String]
    let discoveredFiles: [String]
    let totalCount: Int
    let discoveredAt: Date
}

enum ManualFilesError: LocalizedError {
    case notConfigured
    case invalidConfiguration(String)
    case fileNotFound(String)
    case invalidContent(String)
    case missingParameter(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Plugin is not configured"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidContent(let message):
            return "Invalid content: \(message)"
        case .missingParameter(let param):
            return "Missing parameter: \(param)"
        }
    }
}

// MARK: - File Monitoring

actor FileMonitor {
    private let callback: ([String]) -> Void
    private var isRunning = false
    private var monitoredFiles: Set<String> = []
    
    init(callback: @escaping ([String]) -> Void) {
        self.callback = callback
    }
    
    func addFile(_ filePath: String) {
        monitoredFiles.insert(filePath)
    }
    
    func removeFile(_ filePath: String) {
        monitoredFiles.remove(filePath)
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // This would implement actual file system monitoring
        // Using FSEvents or similar on macOS
        // For now, this is a placeholder
    }
    
    func stop() {
        isRunning = false
    }
}

// MARK: - Extensions

extension String {
    func matches(pattern: String) -> Bool {
        // Convert glob pattern to regex
        let regexPattern = pattern
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        do {
            let regex = try NSRegularExpression(pattern: "^" + regexPattern + "$")
            let range = NSRange(location: 0, length: self.count)
            return regex.firstMatch(in: self, range: range) != nil
        } catch {
            return false
        }
    }
    
    func matches(for pattern: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: self.count)
            let matches = regex.matches(in: self, range: range)
            
            return matches.compactMap { match in
                guard let range = Range(match.range, in: self) else { return nil }
                return String(self[range])
            }
        } catch {
            return []
        }
    }
}