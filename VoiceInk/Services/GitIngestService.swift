import Foundation
import os

// MARK: - GitIngest Data Models

struct GitIngestResult: Codable {
    let summary: GitIngestSummary
    let tree: String
    let content: String
    let timestamp: String
}

struct GitIngestSummary: Codable {
    let fileCount: Int?
    let directoryCount: Int?
    let totalSize: Int?
    let tokenCount: Int?
}

struct GitIngestConfig: Codable {
    let path: String
    let token: String?
    let includeSubmodules: Bool
    let includeGitignored: Bool
    let includePatterns: [String]?
    let excludePatterns: [String]?
    let maxFileSize: Int?
    let branch: String?
    
    init(
        path: String,
        token: String? = nil,
        includeSubmodules: Bool = false,
        includeGitignored: Bool = false,
        includePatterns: [String]? = nil,
        excludePatterns: [String]? = nil,
        maxFileSize: Int? = nil,
        branch: String? = nil
    ) {
        self.path = path
        self.token = token
        self.includeSubmodules = includeSubmodules
        self.includeGitignored = includeGitignored
        self.includePatterns = includePatterns
        self.excludePatterns = excludePatterns
        self.maxFileSize = maxFileSize
        self.branch = branch
    }
    
    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - GitIngest Service

@MainActor
final class GitIngestService: ObservableObject {
    static let shared = GitIngestService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "GitIngestService")
    
    @Published var isProcessing = false
    @Published var lastProcessedAt: Date?
    @Published var processProgress: Double = 0.0
    
    // Simple in-memory cache per (rootPath + mode signature)
    private var cachedResults: [String: GitIngestResult] = [:]
    
    // MARK: - Context Generation Modes
    enum ContextMode: CaseIterable {
        case fullRepository
        case documentationOnly
        case codeOnly
        case projectStructure
        case customFiltered
        
        fileprivate func defaultPatterns() -> GitIngestPatterns {
            switch self {
            case .fullRepository:
                return GitIngestPatterns()
            case .documentationOnly:
                return GitIngestPatterns(
                    include: ["*.md", "*.rst", "*.txt", "README*", "CHANGELOG*"],
                    exclude: ["node_modules/*", ".git/*"],
                    maxFileSize: 1024 * 100
                )
            case .codeOnly:
                return GitIngestPatterns(
                    include: ["*.swift", "*.py", "*.js", "*.ts", "*.go", "*.rs"],
                    exclude: ["*.test.*", "*.spec.*", "dist/*", "build/*", "node_modules/*", ".git/*"],
                    maxFileSize: 1024 * 200
                )
            case .projectStructure:
                return GitIngestPatterns(
                    include: ["package.json", "Cargo.toml", "requirements.txt", "Podfile", "*.xcodeproj", "*.gradle", "Makefile", "README*"],
                    exclude: ["node_modules/*", ".git/*"],
                    maxFileSize: 1024 * 50
                )
            case .customFiltered:
                return GitIngestPatterns()
            }
        }
    }
    
    struct GitIngestPatterns {
        var include: [String] = []
        var exclude: [String] = ["node_modules/*", ".git/*", "*.log"]
        var maxFileSize: Int = 1024 * 50 // 50KB default
        var branch: String? = nil
    }
    
    private var pythonPath: String {
        // Prefer relocated project-level venv first
        if let projectVenvPython = projectVenvPythonPath() {
            return projectVenvPython
        }
        // Then try bundled Python environment inside app resources (if present)
        if let bundledPython = bundledPythonPath() {
            return bundledPython
        }
        // Fallback to system Python
        return "/usr/bin/python3"
    }
    
    private var bridgeScriptPath: String {
        guard let resourcePath = Bundle.main.resourcePath else {
            logger.error("Could not find app resource path")
            return ""
        }
        return "\(resourcePath)/GitIngestBridge.py"
    }
    
    private init() {}
    
    // MARK: - Public API
    
    func ingestRepository(at url: URL, token: String? = nil) async throws -> GitIngestResult {
        logger.info("Starting repository ingestion for: \(url.path)")
        
        await MainActor.run {
            isProcessing = true
            processProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processProgress = 0.0
            }
        }
        
        do {
            // Verify gitingest is available
            try await verifyGitIngestAvailability()
            
            await MainActor.run {
                processProgress = 0.3
            }
            
            // Prepare configuration
            let config = GitIngestConfig(
                path: url.path,
                token: token,
                includeSubmodules: UserDefaults.standard.gitIngestIncludeSubmodules,
                includeGitignored: UserDefaults.standard.gitIngestIncludeGitignored,
                includePatterns: nil,
                excludePatterns: nil,
                maxFileSize: nil,
                branch: nil
            )
            
            await MainActor.run {
                processProgress = 0.5
            }
            
            // Execute gitingest via bridge
            let result = try await executeGitIngestBridge(with: config)
            
            await MainActor.run {
                processProgress = 1.0
                lastProcessedAt = Date()
            }
            
            logger.info("Repository ingestion completed successfully")
            return result
            
        } catch {
            logger.error("Repository ingestion failed: \(error.localizedDescription)")
            throw error
        }
    }

    func generateContext(
        for repository: URL,
        mode: ContextMode,
        customPatterns: GitIngestPatterns? = nil,
        token: String? = nil
    ) async throws -> GitIngestResult {
        let patterns = (mode == .customFiltered) ? (customPatterns ?? GitIngestPatterns()) : mode.defaultPatterns()
        let cacheKey = cacheKeyFor(repository: repository, mode: mode, patterns: patterns)
        if let cached = cachedResults[cacheKey] { return cached }
        
        try await verifyGitIngestAvailability()
        
        let config = GitIngestConfig(
            path: repository.path,
            token: token ?? UserDefaults.standard.gitIngestToken,
            includeSubmodules: UserDefaults.standard.gitIngestIncludeSubmodules,
            includeGitignored: UserDefaults.standard.gitIngestIncludeGitignored,
            includePatterns: patterns.include.isEmpty ? nil : patterns.include,
            excludePatterns: patterns.exclude.isEmpty ? nil : patterns.exclude,
            maxFileSize: patterns.maxFileSize,
            branch: patterns.branch
        )
        
        let result = try await executeGitIngestBridge(with: config)
        cachedResults[cacheKey] = result
        return result
    }
    
    func generatePromptReadyContext(for repository: URL, mode: ContextMode = .fullRepository) async throws -> String {
        let result = try await generateContext(for: repository, mode: mode)
        var out = ""
        // Compose in the exact format expected by most LLM processors
        if let summaryText = serializeSummary(result.summary) {
            out += summaryText + "\n\n"
        }
        out += "\(result.tree)\n\n"
        out += result.content
        return out
    }
    
    private func serializeSummary(_ s: GitIngestSummary) -> String? {
        var lines: [String] = []
        lines.append("Repository summary:")
        if let fc = s.fileCount { lines.append("- Files analyzed: \(fc)") }
        if let dc = s.directoryCount { lines.append("- Directories: \(dc)") }
        if let ts = s.totalSize { lines.append("- Total size: \(ts) bytes") }
        if let tk = s.tokenCount { lines.append("- Estimated tokens: \(tk)") }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
    
    private func cacheKeyFor(repository: URL, mode: ContextMode, patterns: GitIngestPatterns) -> String {
        let p = [
            repository.path,
            String(describing: mode),
            patterns.include.joined(separator: ","),
            patterns.exclude.joined(separator: ","),
            String(patterns.maxFileSize),
            patterns.branch ?? "-"
        ].joined(separator: "|")
        return String(p.hashValue)
    }
    
    func checkRepositoryUpdates(at url: URL, since date: Date) async throws -> [String] {
        // This could be enhanced to detect git changes since last sync
        // For now, return empty array - full sync will be used
        return []
    }
    
    // MARK: - Private Implementation
    
    private func bundledPythonPath() -> String? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let pythonEnvPath = "\(resourcePath)/python-env/bin/python"
        return FileManager.default.fileExists(atPath: pythonEnvPath) ? pythonEnvPath : nil
    }

    private func projectVenvPythonPath() -> String? {
        // Look for python-env moved to project root to avoid app bundling
        let projectVenv = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("python-env/bin/python")
            .path
        return FileManager.default.fileExists(atPath: projectVenv) ? projectVenv : nil
    }
    
    private func verifyGitIngestAvailability() async throws {
        let testProcess = Process()
        testProcess.executableURL = URL(fileURLWithPath: pythonPath)
        testProcess.arguments = ["-c", "import gitingest; print('OK')"]
        
        let pipe = Pipe()
        testProcess.standardOutput = pipe
        testProcess.standardError = pipe
        
        try testProcess.run()
        testProcess.waitUntilExit()
        
        if testProcess.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("GitIngest not available: \(errorString)")
            throw GitIngestError.dependencyNotAvailable(errorString)
        }
    }
    
    private func executeGitIngestBridge(with config: GitIngestConfig) async throws -> GitIngestResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        
        // Check if bridge script exists, otherwise use inline Python
        if FileManager.default.fileExists(atPath: bridgeScriptPath) {
            process.arguments = [bridgeScriptPath, try config.jsonString()]
        } else {
            // Fallback: inline Python execution
            let inlineScript = """
            import json, sys
            from gitingest import ingest
            
            config = json.loads(sys.argv[1])
            try:
                kwargs = dict(
                    source=config['path'],
                    token=config.get('token'),
                    include_submodules=config.get('includeSubmodules', False),
                    include_gitignored=config.get('includeGitignored', False)
                )
                if config.get('includePatterns'):
                    kwargs['include_patterns'] = config.get('includePatterns')
                if config.get('excludePatterns'):
                    kwargs['exclude_patterns'] = config.get('excludePatterns')
                if config.get('maxFileSize'):
                    kwargs['max_file_size'] = int(config.get('maxFileSize'))
                if config.get('branch'):
                    kwargs['branch'] = config.get('branch')
                summary, tree, content = ingest(**kwargs)
                if hasattr(summary, '__dict__'):
                    summary_dict = summary.__dict__
                elif isinstance(summary, dict):
                    summary_dict = summary
                elif hasattr(summary, '_asdict'):
                    summary_dict = summary._asdict()
                else:
                    summary_dict = {'raw': str(summary)}
                result = {
                    'summary': summary_dict,
                    'tree': tree,
                    'content': content,
                    'timestamp': __import__('datetime').datetime.utcnow().isoformat()
                }
                print(json.dumps(result))
            except Exception as e:
                print(json.dumps({'error': str(e)}), file=sys.stderr)
                sys.exit(1)
            """
            
            process.arguments = ["-c", inlineScript, try config.jsonString()]
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set timeout
        let timeout = UserDefaults.standard.gitIngestTimeoutSeconds
        
        try process.run()
        
        // Wait with timeout
        let timeoutDate = Date().addingTimeInterval(TimeInterval(timeout))
        while process.isRunning && Date() < timeoutDate {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if process.isRunning {
            process.terminate()
            throw GitIngestError.timeout
        }
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("GitIngest process failed: \(errorString)")
            throw GitIngestError.processingFailed(errorString)
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        do {
            let result = try JSONDecoder().decode(GitIngestResult.self, from: outputData)
            return result
        } catch {
            logger.error("Failed to parse GitIngest output: \(error.localizedDescription)")
            throw GitIngestError.invalidResponse(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum GitIngestError: LocalizedError {
    case dependencyNotAvailable(String)
    case processingFailed(String)
    case invalidResponse(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .dependencyNotAvailable(let details):
            return "GitIngest dependency not available: \(details)"
        case .processingFailed(let details):
            return "GitIngest processing failed: \(details)"
        case .invalidResponse(let details):
            return "Invalid GitIngest response: \(details)"
        case .timeout:
            return "GitIngest operation timed out"
        }
    }
}