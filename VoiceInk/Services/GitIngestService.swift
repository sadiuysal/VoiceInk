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
    
    init(path: String, token: String? = nil, includeSubmodules: Bool = false, includeGitignored: Bool = false) {
        self.path = path
        self.token = token
        self.includeSubmodules = includeSubmodules
        self.includeGitignored = includeGitignored
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
    
    private var pythonPath: String {
        // First try bundled Python environment
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
                includeGitignored: UserDefaults.standard.gitIngestIncludeGitignored
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
    
    func checkRepositoryUpdates(at url: URL, since date: Date) async throws -> [String] {
        // This could be enhanced to detect git changes since last sync
        // For now, return empty array - full sync will be used
        return []
    }
    
    // MARK: - Private Implementation
    
    private func bundledPythonPath() -> String? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let pythonEnvPath = "\(resourcePath)/python-env/bin/python"
        
        if FileManager.default.fileExists(atPath: pythonEnvPath) {
            return pythonEnvPath
        }
        
        return nil
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
                summary, tree, content = ingest(
                    config['path'], 
                    token=config.get('token'),
                    include_submodules=config.get('includeSubmodules', False),
                    include_gitignored=config.get('includeGitignored', False)
                )
                result = {
                    'summary': summary.__dict__ if hasattr(summary, '__dict__') else str(summary),
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