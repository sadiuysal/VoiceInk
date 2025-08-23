import Foundation
import SwiftData
import os

/// Enhanced GitIngest plugin with multi-job execution, artifact preview, and intelligent parsing
actor EnhancedGitIngestPlugin: SourcePlugin {
    typealias Config = GitIngestConfiguration
    typealias Artifact = GitIngestArtifact
    
    let pluginId = "com.sadiuysal.voiceink.plugins.gitingest"
    let displayName = "Enhanced GitIngest"
    let version = "2.0.0"
    let capabilities = PluginCapabilities(
        supportsOffline: true,
        requiresNetwork: false,
        requiresCredentials: true,
        maxConcurrentJobs: 3,
        supportedFormats: [.markdown, .text, .json],
        supportedArtifactTypes: [.document, .snippet, .codeBlock, .fileTree, .metadata]
    )
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "EnhancedGitIngestPlugin")
    
    // Plugin state
    private var currentConfig: GitIngestConfiguration?
    private var isConfigured = false
    private var runningJobs: [UUID: Task<[GitIngestArtifact], Error>] = [:]
    

    private let gitIngestBridgePath: String
    
    init() {
        // Path to the GitIngest bridge script
        if let resourcePath = Bundle.main.path(forResource: "GitIngestBridge", ofType: "py") {
            gitIngestBridgePath = resourcePath
        } else {
            gitIngestBridgePath = Bundle.main.bundlePath + "/Contents/Resources/GitIngestBridge.py"
        }
        
        logger.info("Enhanced GitIngest plugin initialized")
    }
    
    // MARK: - Plugin Lifecycle
    
    func configure(_ config: GitIngestConfiguration) async throws {
        guard try await validate(config) else {
            throw GitIngestPluginError.invalidConfiguration("Configuration validation failed")
        }
        
        // Test GitIngest availability
        guard await testGitIngestAvailability(config: config) else {
            throw GitIngestPluginError.gitIngestUnavailable
        }
        
        currentConfig = config
        isConfigured = true
        
        logger.info("Configured GitIngest plugin for repository: \(config.repositoryPath)")
    }
    
    func validate(_ config: GitIngestConfiguration) async throws -> Bool {
        // Validate repository path exists
        let repositoryURL = URL(fileURLWithPath: config.repositoryPath)
        guard FileManager.default.fileExists(atPath: repositoryURL.path) else {
            return false
        }
        
        // Validate it's a Git repository
        let gitDir = repositoryURL.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return false
        }
        
        // Validate patterns
        guard !config.includePatterns.isEmpty || config.preset != .custom else {
            return false
        }
        
        return true
    }
    
    func isAvailable() async -> Bool {
        let bridgeExists = FileManager.default.fileExists(atPath: gitIngestBridgePath)
        let availability = await testGitIngestAvailability(config: currentConfig ?? GitIngestConfiguration(repositoryPath: ""))
        return bridgeExists && availability
    }
    
    // MARK: - Job Planning and Execution
    
    func planJobs(for source: ContextSource) async throws -> [JobSpec] {
        guard let config = currentConfig else {
            throw GitIngestPluginError.notConfigured
        }
        
        // Analyze repository to determine optimal job partitioning
        let analysis = try await analyzeRepository(config: config)
        
        var jobSpecs: [JobSpec] = []
        
        // Job 1: Repository metadata and structure
        jobSpecs.append(JobSpec(
            sourceId: source.id,
            pluginId: pluginId,
            priority: .high,
            parameters: [
                "job_type": "metadata",
                "repository_path": config.repositoryPath
            ],
            timeout: 60
        ))
        
        // Job 2: Documentation files (high priority)
        if analysis.hasDocumentation {
            jobSpecs.append(JobSpec(
                sourceId: source.id,
                pluginId: pluginId,
                priority: .high,
                parameters: [
                    "job_type": "documentation",
                    "repository_path": config.repositoryPath,
                    "preset": "docs"
                ],
                timeout: 300
            ))
        }
        
        // Job 3: Source code (if requested)
        if config.preset == .code || config.preset == .mixed {
            jobSpecs.append(JobSpec(
                sourceId: source.id,
                pluginId: pluginId,
                priority: .normal,
                parameters: [
                    "job_type": "source_code",
                    "repository_path": config.repositoryPath,
                    "preset": config.preset.rawValue
                ],
                timeout: 600
            ))
        }
        
        // Job 4: Configuration files
        if analysis.hasConfigFiles {
            jobSpecs.append(JobSpec(
                sourceId: source.id,
                pluginId: pluginId,
                priority: .normal,
                parameters: [
                    "job_type": "config_files",
                    "repository_path": config.repositoryPath
                ],
                timeout: 120
            ))
        }
        
        logger.info("Planned \(jobSpecs.count) jobs for repository: \(config.repositoryPath)")
        return jobSpecs
    }
    
    func executeJob(_ job: JobSpec) async throws -> [GitIngestArtifact] {
        guard let config = currentConfig else {
            throw GitIngestPluginError.notConfigured
        }
        
        let jobType = job.parameters["job_type"] ?? "full"
        
        // Create cancellable task
        let task = Task<[GitIngestArtifact], Error> {
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
        config: GitIngestConfiguration,
        jobType: String
    ) async throws -> [GitIngestArtifact] {
        switch jobType {
        case "metadata":
            return try await executeMetadataJob(job: job, config: config)
        case "documentation":
            return try await executeDocumentationJob(job: job, config: config)
        case "source_code":
            return try await executeSourceCodeJob(job: job, config: config)
        case "config_files":
            return try await executeConfigFilesJob(job: job, config: config)
        default:
            return try await executeFullJob(job: job, config: config)
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
        
        isConfigured = false
        currentConfig = nil
        
        logger.info("GitIngest plugin cleaned up")
    }
    
    // MARK: - Content Preview and Testing
    
    func previewContent(for source: ContextSource) async throws -> ContentPreview {
        guard let config = currentConfig else {
            throw GitIngestPluginError.notConfigured
        }
        
        let analysis = try await analyzeRepository(config: config)
        
        var sampleItems: [ContentPreview.PreviewItem] = []
        
        // Sample documentation
        if analysis.hasDocumentation {
            sampleItems.append(ContentPreview.PreviewItem(
                title: "README.md",
                type: .document,
                size: analysis.estimatedDocSize,
                preview: "Repository documentation and guides..."
            ))
        }
        
        // Sample source code
        if analysis.hasSourceCode {
            sampleItems.append(ContentPreview.PreviewItem(
                title: "Source Code",
                type: .codeBlock,
                size: analysis.estimatedCodeSize,
                preview: "Implementation files in \(analysis.primaryLanguage ?? "multiple languages")..."
            ))
        }
        
        // Sample configuration
        if analysis.hasConfigFiles {
            sampleItems.append(ContentPreview.PreviewItem(
                title: "Configuration",
                type: .document,
                size: analysis.estimatedConfigSize,
                preview: "Project configuration and build files..."
            ))
        }
        
        return ContentPreview(
            title: "GitIngest Repository Analysis",
            description: "Repository: \(URL(fileURLWithPath: config.repositoryPath).lastPathComponent)",
            itemCount: analysis.totalFiles,
            estimatedSize: analysis.estimatedTotalSize,
            lastModified: analysis.lastCommitDate,
            sampleItems: sampleItems
        )
    }
    
    func testConnection(for source: ContextSource) async throws -> ConnectionTestResult {
        guard let config = currentConfig else {
            throw GitIngestPluginError.notConfigured
        }
        
        let startTime = Date()
        
        do {
            // Test repository access
            let repositoryURL = URL(fileURLWithPath: config.repositoryPath)
            guard FileManager.default.fileExists(atPath: repositoryURL.path) else {
                return .failure(message: "Repository path does not exist")
            }
            
            // Test Git repository
            let gitDir = repositoryURL.appendingPathComponent(".git")
            guard FileManager.default.fileExists(atPath: gitDir.path) else {
                return .failure(message: "Not a Git repository")
            }
            
            // Test GitIngest availability
            guard await testGitIngestAvailability(config: config) else {
                return .failure(message: "GitIngest is not available")
            }
            
            // Test basic analysis
            _ = try await analyzeRepository(config: config)
            
            let latency = Date().timeIntervalSince(startTime)
            
            return .success(
                message: "Repository accessible and GitIngest ready",
                latency: latency,
                metadata: [
                    "repository_path": config.repositoryPath,
                    "preset": config.preset.rawValue
                ]
            )
            
        } catch {
            return .failure(
                message: "Connection test failed: \(error.localizedDescription)",
                metadata: ["error": error.localizedDescription]
            )
        }
    }
    
    // MARK: - Job Implementations
    
    private func executeMetadataJob(
        job: JobSpec,
        config: GitIngestConfiguration
    ) async throws -> [GitIngestArtifact] {
        let repositoryURL = URL(fileURLWithPath: config.repositoryPath)
        let repositoryName = repositoryURL.lastPathComponent
        
        // Get Git metadata
        let gitMetadata = try await getGitMetadata(repositoryPath: config.repositoryPath)
        
        // Create repository structure artifact
        let structureArtifact = try await createRepositoryStructureArtifact(
            repositoryPath: config.repositoryPath,
            sourceId: job.sourceId
        )
        
        // Create metadata artifact
        let metadataArtifact = try createMetadataArtifact(
            repositoryName: repositoryName,
            gitMetadata: gitMetadata,
            sourceId: job.sourceId
        )
        
        return [structureArtifact, metadataArtifact]
    }
    
    private func executeDocumentationJob(
        job: JobSpec,
        config: GitIngestConfiguration
    ) async throws -> [GitIngestArtifact] {
        // Use GitIngest with documentation preset
        let docConfig = GitIngestConfiguration(
            repositoryPath: config.repositoryPath,
            preset: .docs,
            includePatterns: GitIngestPreset.docs.defaultIncludePatterns,
            excludePatterns: GitIngestPreset.docs.defaultExcludePatterns,
            maxFileSize: config.maxFileSize,
            includeSubmodules: config.includeSubmodules,
            branch: config.branch
        )
        
        let gitIngestResult = try await runGitIngest(config: docConfig)
        return try parseGitIngestOutput(gitIngestResult, sourceId: job.sourceId, jobType: "documentation")
    }
    
    private func executeSourceCodeJob(
        job: JobSpec,
        config: GitIngestConfiguration
    ) async throws -> [GitIngestArtifact] {
        // Use GitIngest with code preset
        let codeConfig = GitIngestConfiguration(
            repositoryPath: config.repositoryPath,
            preset: .code,
            includePatterns: GitIngestPreset.code.defaultIncludePatterns,
            excludePatterns: GitIngestPreset.code.defaultExcludePatterns,
            maxFileSize: config.maxFileSize,
            includeSubmodules: config.includeSubmodules,
            branch: config.branch
        )
        
        let gitIngestResult = try await runGitIngest(config: codeConfig)
        return try parseGitIngestOutput(gitIngestResult, sourceId: job.sourceId, jobType: "source_code")
    }
    
    private func executeConfigFilesJob(
        job: JobSpec,
        config: GitIngestConfiguration
    ) async throws -> [GitIngestArtifact] {
        let configPatterns = [
            "*.json", "*.yml", "*.yaml", "*.toml", "*.ini", "*.conf",
            "package.json", "Cargo.toml", "pyproject.toml", "pom.xml",
            "Package.swift", "Podfile", "build.gradle", "CMakeLists.txt",
            ".gitignore", ".gitattributes", ".dockerignore", "Dockerfile*",
            "*.env", ".env*"
        ]
        
        let configConfig = GitIngestConfiguration(
            repositoryPath: config.repositoryPath,
            preset: .custom,
            includePatterns: configPatterns,
            excludePatterns: ["node_modules/**/*", ".git/**/*"],
            maxFileSize: 100_000, // Smaller limit for config files
            includeSubmodules: false,
            branch: config.branch
        )
        
        let gitIngestResult = try await runGitIngest(config: configConfig)
        return try parseGitIngestOutput(gitIngestResult, sourceId: job.sourceId, jobType: "config_files")
    }
    
    private func executeFullJob(
        job: JobSpec,
        config: GitIngestConfiguration
    ) async throws -> [GitIngestArtifact] {
        let gitIngestResult = try await runGitIngest(config: config)
        return try parseGitIngestOutput(gitIngestResult, sourceId: job.sourceId, jobType: "full")
    }
    
    // MARK: - GitIngest Integration
    
    private func runGitIngest(config: GitIngestConfiguration) async throws -> GitIngestResult {
        // Prepare GitIngest command
        let command = GitIngestCommand(
            repositoryPath: config.repositoryPath,
            preset: config.preset,
            includePatterns: config.includePatterns,
            excludePatterns: config.excludePatterns,
            maxFileSize: config.maxFileSize,
            includeSubmodules: config.includeSubmodules,
            branch: config.branch
        )
        
        // Execute via bridge script
        let result = try await executeGitIngestBridge(command: command)
        return result
    }
    
    private func executeGitIngestBridge(command: GitIngestCommand) async throws -> GitIngestResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            gitIngestBridgePath,
            "--repository", command.repositoryPath,
            "--preset", command.preset.rawValue,
            "--max-file-size", String(command.maxFileSize),
            "--output-format", "json"
        ]
        
        // Add include patterns
        for pattern in command.includePatterns {
            process.arguments?.append(contentsOf: ["--include", pattern])
        }
        
        // Add exclude patterns
        for pattern in command.excludePatterns {
            process.arguments?.append(contentsOf: ["--exclude", pattern])
        }
        
        // Add optional parameters
        if command.includeSubmodules {
            process.arguments?.append("--include-submodules")
        }
        
        if let branch = command.branch {
            process.arguments?.append(contentsOf: ["--branch", branch])
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GitIngestPluginError.executionFailed(errorMessage)
        }
        
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            throw GitIngestPluginError.invalidOutput("Could not decode output as UTF-8")
        }
        
        // Parse JSON output
        guard let jsonData = outputString.data(using: .utf8) else {
            throw GitIngestPluginError.invalidOutput("Could not encode output as JSON")
        }
        
        let result = try JSONDecoder().decode(GitIngestResult.self, from: jsonData)
        return result
    }
    
    // MARK: - Result Parsing
    
    private func parseGitIngestOutput(
        _ result: GitIngestResult,
        sourceId: UUID,
        jobType: String
    ) throws -> [GitIngestArtifact] {
        var artifacts: [GitIngestArtifact] = []
        
        // Parse files into artifacts
        for file in result.files {
            let artifact = try createFileArtifact(
                file: file,
                sourceId: sourceId,
                jobType: jobType
            )
            artifacts.append(artifact)
        }
        
        // Create summary artifact
        let summaryArtifact = try createSummaryArtifact(
            result: result,
            sourceId: sourceId,
            jobType: jobType
        )
        artifacts.append(summaryArtifact)
        
        return artifacts
    }
    
    private func createFileArtifact(
        file: GitIngestFile,
        sourceId: UUID,
        jobType: String
    ) throws -> GitIngestArtifact {
        let contentData = file.content.data(using: .utf8) ?? Data()
        
        let artifactType: ArtifactType
        if file.path.hasSuffix(".md") || file.path.hasSuffix(".txt") {
            artifactType = .document
        } else if file.language != nil {
            artifactType = .codeBlock
        } else {
            artifactType = .snippet
        }
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "gitingest",
            sourcePath: file.path,
            additionalContext: [
                "job_type": jobType,
                "file_type": file.type,
                "language": file.language ?? "unknown"
            ]
        )
        
        let metadata = ArtifactMetadata(
            title: URL(fileURLWithPath: file.path).lastPathComponent,
            description: "GitIngest file: \(file.path)",
            tags: ["gitingest", jobType, file.type, file.language].compactMap { $0 },
            score: calculateFileScore(file: file),
            language: file.language,
            fileSize: contentData.count,
            lineCount: file.lineCount,
            custom: [
                "file_type": file.type,
                "encoding": file.encoding ?? "utf-8",
                "job_type": jobType
            ]
        )
        
        let content = ContentBlob(
            format: file.path.hasSuffix(".md") ? .markdown : .text,
            data: contentData
        )
        
        return GitIngestArtifact(
            id: UUID(),
            type: artifactType,
            version: "2.0",
            source: source,
            metadata: metadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            filePath: file.path,
            gitMetadata: file.gitMetadata
        )
    }
    
    private func createSummaryArtifact(
        result: GitIngestResult,
        sourceId: UUID,
        jobType: String
    ) throws -> GitIngestArtifact {
        let summary = GitIngestSummary(
            totalFiles: result.files.count,
            totalSize: result.files.reduce(0) { $0 + ($1.content.count) },
            languages: Array(Set(result.files.compactMap { $0.language })),
            fileTypes: Array(Set(result.files.map { $0.type })),
            processingTime: result.processingTime,
            gitBranch: result.gitBranch,
            gitCommit: result.gitCommit,
            timestamp: Date()
        )
        
        let summaryData = try JSONEncoder().encode(summary)
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "gitingest",
            sourcePath: nil,
            additionalContext: ["job_type": jobType]
        )
        
        let metadata = ArtifactMetadata(
            title: "GitIngest Summary (\(jobType))",
            description: "Summary of GitIngest processing for job type: \(jobType)",
            tags: ["gitingest", "summary", jobType],
            score: 10, // High score for summaries
            fileSize: summaryData.count,
            custom: [
                "job_type": jobType,
                "total_files": String(summary.totalFiles),
                "total_size": String(summary.totalSize)
            ]
        )
        
        let content = ContentBlob(
            format: .json,
            data: summaryData
        )
        
        return GitIngestArtifact(
            id: UUID(),
            type: .metadata,
            version: "2.0",
            source: source,
            metadata: metadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            filePath: nil,
            gitMetadata: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private func analyzeRepository(config: GitIngestConfiguration) async throws -> RepositoryAnalysis {
        let repositoryURL = URL(fileURLWithPath: config.repositoryPath)
        let fileManager = FileManager.default
        
        var hasDocumentation = false
        var hasSourceCode = false
        var hasConfigFiles = false
        var totalFiles = 0
        var estimatedTotalSize = 0
        var primaryLanguage: String? = nil
        var lastCommitDate: Date?
        
        // Quick scan of repository
        let contents = try fileManager.contentsOfDirectory(at: repositoryURL, includingPropertiesForKeys: [.fileSizeKey])
        
        var languageCounts: [String: Int] = [:]
        
        for item in contents {
            let name = item.lastPathComponent.lowercased()
            
            // Check for documentation
            if name.contains("readme") || name.contains("doc") || item.pathExtension == "md" {
                hasDocumentation = true
            }
            
            // Check for source code and count languages
            let sourceExtensions = ["swift", "js", "ts", "py", "java", "kt", "go", "rs", "cpp", "c", "h"]
            if sourceExtensions.contains(item.pathExtension.lowercased()) {
                hasSourceCode = true
                let ext = item.pathExtension.lowercased()
                languageCounts[ext, default: 0] += 1
            }
            
            // Check for config files
            let configNames = ["package.json", "cargo.toml", "pyproject.toml", "pom.xml"]
            if configNames.contains(name) {
                hasConfigFiles = true
            }
            
            totalFiles += 1
            
            if let fileSize = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                estimatedTotalSize += fileSize
            }
        }
        
        // Determine primary language
        if let mostCommonLanguage = languageCounts.max(by: { $0.value < $1.value }) {
            primaryLanguage = mostCommonLanguage.key
        }
        
        // Get Git metadata
        do {
            let gitMetadata = try await getGitMetadata(repositoryPath: config.repositoryPath)
            lastCommitDate = gitMetadata.lastCommitDate
        } catch {
            logger.warning("Could not get Git metadata: \(error.localizedDescription)")
        }
        
        return RepositoryAnalysis(
            hasDocumentation: hasDocumentation,
            hasSourceCode: hasSourceCode,
            hasConfigFiles: hasConfigFiles,
            totalFiles: totalFiles,
            estimatedTotalSize: estimatedTotalSize,
            estimatedDocSize: hasDocumentation ? estimatedTotalSize / 4 : 0,
            estimatedCodeSize: hasSourceCode ? estimatedTotalSize / 2 : 0,
            estimatedConfigSize: hasConfigFiles ? estimatedTotalSize / 10 : 0,
            primaryLanguage: primaryLanguage,
            lastCommitDate: lastCommitDate
        )
    }
    
    private func testGitIngestAvailability(config: GitIngestConfiguration? = nil) async -> Bool {
        do {
            let testProcess = Process()
            testProcess.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            testProcess.arguments = [gitIngestBridgePath, "--version"]
            
            let outputPipe = Pipe()
            testProcess.standardOutput = outputPipe
            testProcess.standardError = outputPipe
            
            try testProcess.run()
            testProcess.waitUntilExit()
            
            return testProcess.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func getGitMetadata(repositoryPath: String) async throws -> GitMetadata {
        // This would integrate with the existing GitService
        // Simplified implementation for now
        return GitMetadata(
            branch: "main",
            commit: "abc123",
            author: "Unknown",
            message: "Latest commit",
            lastCommitDate: Date()
        )
    }
    
    private func createRepositoryStructureArtifact(
        repositoryPath: String,
        sourceId: UUID
    ) async throws -> GitIngestArtifact {
        // Create a file tree structure
        let structure = try generateFileTree(repositoryPath: repositoryPath)
        let structureData = try JSONEncoder().encode(structure)
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "gitingest",
            sourcePath: repositoryPath
        )
        
        let metadata = ArtifactMetadata(
            title: "Repository Structure",
            description: "File tree structure of the repository",
            tags: ["gitingest", "structure", "metadata"],
            score: 8,
            fileSize: structureData.count,
            custom: ["repository_path": repositoryPath]
        )
        
        let content = ContentBlob(
            format: .json,
            data: structureData
        )
        
        return GitIngestArtifact(
            id: UUID(),
            type: .fileTree,
            version: "2.0",
            source: source,
            metadata: metadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            filePath: nil,
            gitMetadata: nil
        )
    }
    
    private func createMetadataArtifact(
        repositoryName: String,
        gitMetadata: GitMetadata,
        sourceId: UUID
    ) throws -> GitIngestArtifact {
        let metadata = RepositoryMetadata(
            name: repositoryName,
            branch: gitMetadata.branch,
            commit: gitMetadata.commit,
            author: gitMetadata.author,
            lastCommitDate: gitMetadata.lastCommitDate,
            extractedAt: Date()
        )
        
        let metadataData = try JSONEncoder().encode(metadata)
        
        let source = ArtifactSource(
            pluginId: pluginId,
            sourceId: sourceId,
            sourceType: "gitingest"
        )
        
        let artifactMetadata = ArtifactMetadata(
            title: "Repository Metadata",
            description: "Git repository metadata and information",
            tags: ["gitingest", "metadata", "git"],
            score: 9,
            fileSize: metadataData.count,
            custom: [
                "repository_name": repositoryName,
                "git_branch": gitMetadata.branch,
                "git_commit": gitMetadata.commit
            ]
        )
        
        let content = ContentBlob(
            format: .json,
            data: metadataData
        )
        
        return GitIngestArtifact(
            id: UUID(),
            type: .metadata,
            version: "2.0",
            source: source,
            metadata: artifactMetadata,
            content: content,
            ttl: nil,
            createdAt: Date(),
            filePath: nil,
            gitMetadata: nil // Repository-level metadata, not file-specific
        )
    }
    
    private func generateFileTree(repositoryPath: String) throws -> FileTreeNode {
        let repositoryURL = URL(fileURLWithPath: repositoryPath)
        return try generateFileTreeRecursive(url: repositoryURL, depth: 0, maxDepth: 5)
    }
    
    private func generateFileTreeRecursive(url: URL, depth: Int, maxDepth: Int) throws -> FileTreeNode {
        let name = url.lastPathComponent
        var isDirectory: ObjCBool = false
        
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw GitIngestPluginError.fileNotFound(url.path)
        }
        
        if isDirectory.boolValue && depth < maxDepth {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let children = try contents.compactMap { childURL -> FileTreeNode? in
                // Skip hidden files and common excluded directories
                let childName = childURL.lastPathComponent
                if childName.hasPrefix(".") || ["node_modules", "build", "dist"].contains(childName) {
                    return nil
                }
                return try generateFileTreeRecursive(url: childURL, depth: depth + 1, maxDepth: maxDepth)
            }
            
            return FileTreeNode(name: name, isDirectory: true, children: children)
        } else {
            return FileTreeNode(name: name, isDirectory: isDirectory.boolValue, children: [])
        }
    }
    
    private func calculateFileScore(file: GitIngestFile) -> Int {
        var score = 1
        
        // Higher score for documentation
        if file.path.contains("README") || file.path.contains("doc") {
            score += 5
        }
        
        // Higher score for configuration files
        if file.type == "config" {
            score += 3
        }
        
        // Higher score for certain languages
        if let language = file.language {
            switch language.lowercased() {
            case "swift", "javascript", "typescript", "python":
                score += 2
            default:
                score += 1
            }
        }
        
        // Adjust for file size (prefer medium-sized files)
        let contentLength = file.content.count
        if contentLength > 100 && contentLength < 10000 {
            score += 1
        }
        
        return max(1, score)
    }
    
    private func validate(_ config: GitIngestConfiguration) -> Bool {
        return !config.repositoryPath.isEmpty && 
               FileManager.default.fileExists(atPath: config.repositoryPath)
    }
}

// MARK: - Supporting Types

struct GitIngestArtifact: ContentArtifact {
    let id: UUID
    let type: ArtifactType
    let version: String
    let source: ArtifactSource
    let metadata: ArtifactMetadata
    let content: ContentBlob
    let ttl: TimeInterval?
    let createdAt: Date
    
    // GitIngest-specific data
    let filePath: String?
    let gitMetadata: GitFileMetadata?
    
    var contentHash: String {
        content.checksum
    }
}

struct GitIngestCommand {
    let repositoryPath: String
    let preset: GitIngestPreset
    let includePatterns: [String]
    let excludePatterns: [String]
    let maxFileSize: Int
    let includeSubmodules: Bool
    let branch: String?
}

struct GitIngestResult: Codable {
    let files: [GitIngestFile]
    let processingTime: TimeInterval
    let gitBranch: String?
    let gitCommit: String?
    let totalSize: Int
}

struct GitIngestFile: Codable {
    let path: String
    let content: String
    let type: String
    let language: String?
    let encoding: String?
    let lineCount: Int?
    let gitMetadata: GitFileMetadata?
}

struct GitFileMetadata: Codable {
    let lastModified: Date?
    let author: String?
    let commit: String?
}

struct GitMetadata {
    let branch: String
    let commit: String
    let author: String
    let message: String
    let lastCommitDate: Date
}

struct RepositoryAnalysis {
    let hasDocumentation: Bool
    let hasSourceCode: Bool
    let hasConfigFiles: Bool
    let totalFiles: Int
    let estimatedTotalSize: Int
    let estimatedDocSize: Int
    let estimatedCodeSize: Int
    let estimatedConfigSize: Int
    let primaryLanguage: String?
    let lastCommitDate: Date?
}

struct GitIngestSummary: Codable {
    let totalFiles: Int
    let totalSize: Int
    let languages: [String]
    let fileTypes: [String]
    let processingTime: TimeInterval
    let gitBranch: String?
    let gitCommit: String?
    let timestamp: Date
}

struct RepositoryMetadata: Codable {
    let name: String
    let branch: String
    let commit: String
    let author: String
    let lastCommitDate: Date
    let extractedAt: Date
}

struct FileTreeNode: Codable {
    let name: String
    let isDirectory: Bool
    let children: [FileTreeNode]
}

enum GitIngestPluginError: LocalizedError {
    case notConfigured
    case invalidConfiguration(String)
    case gitIngestUnavailable
    case executionFailed(String)
    case invalidOutput(String)
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Plugin is not configured"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .gitIngestUnavailable:
            return "GitIngest is not available"
        case .executionFailed(let message):
            return "GitIngest execution failed: \(message)"
        case .invalidOutput(let message):
            return "Invalid GitIngest output: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}