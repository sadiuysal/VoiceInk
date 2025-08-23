import Foundation
import os

/// Protocol defining the interface for chat connectors
protocol ChatConnector: Actor {
    /// Unique identifier for this connector type
    var connectorType: ChatConnectorType { get }
    
    /// Display name for this connector
    var displayName: String { get }
    
    /// Whether this connector is available on the current system
    func isAvailable() async -> Bool
    
    /// Connect to a chat stream
    func connect(binding: ChatStreamBinding) async throws
    
    /// Disconnect from the current chat stream
    func disconnect() async
    
    /// Start monitoring for new messages
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async
    
    /// Stop monitoring for messages
    func stopMonitoring() async
    
    /// Send a message to the chat (if supported)
    func sendMessage(_ content: String) async throws
    
    /// Get current connection status
    func getConnectionStatus() async -> ChatConnectionStatus
    
    /// Validate connection parameters
    func validateConnection(_ connectionString: String) async -> Bool
    
    /// Get available chat sessions that can be connected to
    func getAvailableSessions() async -> [ChatSessionInfo]
}

// MARK: - Base Chat Connector

actor BaseChatConnector: ChatConnector {
    let connectorType: ChatConnectorType
    let displayName: String
    
    private let logger: Logger
    private var isConnected = false
    private var currentBinding: ChatStreamBinding?
    private var monitoringTask: Task<Void, Never>?
    private var messageCallback: ((ChatStreamMessage) -> Void)?
    
    init(connectorType: ChatConnectorType, displayName: String) {
        self.connectorType = connectorType
        self.displayName = displayName
        self.logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ChatConnector.\(connectorType.rawValue)")
    }
    
    func isAvailable() async -> Bool {
        // Override in subclasses
        return false
    }
    
    func connect(binding: ChatStreamBinding) async throws {
        guard await isAvailable() else {
            throw ChatConnectorError.connectorNotAvailable
        }
        
        guard !isConnected else {
            logger.info("Already connected to chat stream")
            return
        }
        
        currentBinding = binding
        
        do {
            try await performConnection(binding: binding)
            isConnected = true
            logger.info("Connected to chat stream: \(binding.name)")
        } catch {
            currentBinding = nil
            throw error
        }
    }
    
    func disconnect() async {
        guard isConnected else { return }
        
        await stopMonitoring()
        await performDisconnection()
        
        isConnected = false
        currentBinding = nil
        
        logger.info("Disconnected from chat stream")
    }
    
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async {
        guard isConnected else {
            logger.warning("Cannot start monitoring: not connected")
            return
        }
        
        messageCallback = onMessage
        
        monitoringTask = Task {
            await performMonitoring()
        }
        
        logger.info("Started message monitoring")
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        messageCallback = nil
        
        logger.info("Stopped message monitoring")
    }
    
    func sendMessage(_ content: String) async throws {
        guard isConnected else {
            throw ChatConnectorError.notConnected
        }
        
        try await performSendMessage(content)
    }
    
    func getConnectionStatus() async -> ChatConnectionStatus {
        return ChatConnectionStatus(
            isConnected: isConnected,
            connectorType: connectorType,
            connectionString: currentBinding?.connectionString,
            lastActivity: Date(), // Would track actual activity
            messageCount: 0 // Would track actual count
        )
    }
    
    func validateConnection(_ connectionString: String) async -> Bool {
        // Override in subclasses
        return !connectionString.isEmpty
    }
    
    func getAvailableSessions() async -> [ChatSessionInfo] {
        // Override in subclasses
        return []
    }
    
    // MARK: - Protected Methods (Override in Subclasses)
    
    func performConnection(binding: ChatStreamBinding) async throws {
        // Override in subclasses
        throw ChatConnectorError.notImplemented
    }
    
    func performDisconnection() async {
        // Override in subclasses
    }
    
    func performMonitoring() async {
        // Override in subclasses
    }
    
    func performSendMessage(_ content: String) async throws {
        // Override in subclasses
        throw ChatConnectorError.notImplemented
    }
    
    // MARK: - Protected Utilities
    
    func emitMessage(_ message: ChatStreamMessage) {
        messageCallback?(message)
    }
    
    func getCurrentBinding() -> ChatStreamBinding? {
        return currentBinding
    }
    
    func isMonitoring() -> Bool {
        return monitoringTask != nil && !(monitoringTask?.isCancelled ?? true)
    }
}

// MARK: - Cursor Chat Connector

actor CursorChatConnector: ChatConnector {
    private var cursorProcess: Process?
    private var cursorPipe: Pipe?
    
    let connectorType: ChatConnectorType = .cursor
    let displayName: String = "Cursor Chat"
    
    private var isConnected = false
    private var currentBinding: ChatStreamBinding?
    private var monitoringTask: Task<Void, Never>?
    private var messageCallback: ((ChatStreamMessage) -> Void)?
    
    func isAvailable() async -> Bool {
        // Check if Cursor is installed and accessible
        return await checkCursorInstallation()
    }
    
    func connect(binding: ChatStreamBinding) async throws {
        guard await isAvailable() else {
            throw ChatConnectorError.connectorNotAvailable
        }
        
        guard !isConnected else {
            return
        }
        
        currentBinding = binding
        isConnected = true
        
        // Parse connection string for Cursor-specific parameters
        let connectionParams = try parseCursorConnectionString(binding.connectionString)
        
        // Connect to Cursor via AppleScript or direct process communication
        try await connectToCursor(params: connectionParams)
    }
    
    func disconnect() async {
        guard isConnected else { return }
        
        await stopMonitoring()
        
        cursorProcess?.terminate()
        cursorProcess = nil
        cursorPipe = nil
        
        isConnected = false
        currentBinding = nil
    }
    
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async {
        guard isConnected else { return }
        
        messageCallback = onMessage
        
        monitoringTask = Task {
            await performMonitoring()
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        messageCallback = nil
    }
    
    private func performMonitoring() async {
        guard let pipe = cursorPipe else { return }
        
        let fileHandle = pipe.fileHandleForReading
        
        while !Task.isCancelled {
            do {
                let data = fileHandle.availableData
                if !data.isEmpty {
                    if let content = String(data: data, encoding: .utf8) {
                        await processCursorOutput(content)
                    }
                }
                
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                break
            }
        }
    }
    
    func sendMessage(_ content: String) async throws {
        guard isConnected else {
            throw ChatConnectorError.notConnected
        }
        
        // Send message to Cursor via AppleScript
        try await sendToCursorViaAppleScript(content)
    }
    
    func validateConnection(_ connectionString: String) async -> Bool {
        do {
            _ = try parseCursorConnectionString(connectionString)
            return await checkCursorInstallation()
        } catch {
            return false
        }
    }
    
    func getAvailableSessions() async -> [ChatSessionInfo] {
        // Get available Cursor windows/sessions
        return await getCursorSessions()
    }
    
    func getConnectionStatus() async -> ChatConnectionStatus {
        return ChatConnectionStatus(
            isConnected: isConnected,
            connectorType: connectorType,
            connectionString: currentBinding?.connectionString,
            lastActivity: Date(),
            messageCount: 0
        )
    }
    
    // MARK: - Cursor-Specific Implementation
    
    private func checkCursorInstallation() async -> Bool {
        let cursorPaths = [
            "/Applications/Cursor.app",
            "/usr/local/bin/cursor",
            "~/Applications/Cursor.app"
        ]
        
        for path in cursorPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        
        return false
    }
    
    private func parseCursorConnectionString(_ connectionString: String) throws -> CursorConnectionParams {
        // Parse connection string format: "cursor://window_id" or "cursor://project_path"
        guard connectionString.hasPrefix("cursor://") else {
            throw ChatConnectorError.invalidConnectionString("Must start with cursor://")
        }
        
        let path = String(connectionString.dropFirst("cursor://".count))
        
        return CursorConnectionParams(
            identifier: path,
            projectPath: path.hasPrefix("/") ? path : nil,
            windowId: path.hasPrefix("/") ? nil : path
        )
    }
    
    private func connectToCursor(params: CursorConnectionParams) async throws {
        // Create pipe for communication
        cursorPipe = Pipe()
        
        // Set up AppleScript-based communication or direct process connection
        if let projectPath = params.projectPath {
            try await connectToCursorProject(projectPath)
        } else if let windowId = params.windowId {
            try await connectToCursorWindow(windowId)
        } else {
            throw ChatConnectorError.invalidConnectionString("Invalid Cursor connection parameters")
        }
    }
    
    private func connectToCursorProject(_ projectPath: String) async throws {
        // Use AppleScript to connect to specific Cursor project
        let script = """
        tell application "Cursor"
            activate
            open "\(projectPath)"
        end tell
        """
        
        try await executeAppleScript(script)
    }
    
    private func connectToCursorWindow(_ windowId: String) async throws {
        // Connect to specific Cursor window
        let script = """
        tell application "Cursor"
            activate
            set frontmost to true
        end tell
        """
        
        try await executeAppleScript(script)
    }
    
    private func executeAppleScript(_ script: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ChatConnectorError.connectionFailed("AppleScript execution failed")
        }
    }
    
    private func processCursorOutput(_ output: String) async {
        // Parse Cursor output and extract chat messages
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if let message = parseCursorChatLine(line) {
                messageCallback?(message)
            }
        }
    }
    
    private func parseCursorChatLine(_ line: String) -> ChatStreamMessage? {
        // Parse a line of Cursor chat output
        // This would depend on Cursor's actual output format
        
        // Example format: "[2024-01-01 12:00:00] user: Hello"
        let pattern = #"\[([^\]]+)\]\s+(\w+):\s+(.+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)) else {
            return nil
        }
        
        let timestampRange = Range(match.range(at: 1), in: line)
        let roleRange = Range(match.range(at: 2), in: line)
        let contentRange = Range(match.range(at: 3), in: line)
        
        guard let timestampRange = timestampRange,
              let roleRange = roleRange,
              let contentRange = contentRange else {
            return nil
        }
        
        let timestampString = String(line[timestampRange])
        let roleString = String(line[roleRange])
        let content = String(line[contentRange])
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.date(from: timestampString) ?? Date()
        
        let role = ChatStreamMessage.ChatRole(rawValue: roleString.lowercased()) ?? .user
        
        return ChatStreamMessage(
            role: role,
            content: content,
            timestamp: timestamp,
            metadata: ["source": "cursor", "raw_line": line]
        )
    }
    
    private func sendToCursorViaAppleScript(_ content: String) async throws {
        let script = """
        tell application "Cursor"
            activate
            delay 0.5
            tell application "System Events"
                keystroke "\(content)"
                key code 36 -- Enter key
            end tell
        end tell
        """
        
        try await executeAppleScript(script)
    }
    
    private func getCursorSessions() async -> [ChatSessionInfo] {
        // Get available Cursor sessions via AppleScript
        let script = """
        tell application "Cursor"
            get name of every window
        end tell
        """
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            let windowNames = output.components(separatedBy: ", ")
            
            return windowNames.enumerated().map { index, name in
                ChatSessionInfo(
                    id: "cursor_window_\(index)",
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: .cursor,
                    isActive: index == 0,
                    lastActivity: Date()
                )
            }
            
        } catch {
            return []
        }
    }
}

// MARK: - Claude Code Chat Connector

actor ClaudeCodeChatConnector: ChatConnector {
    private var terminalSession: TerminalSession?
    
    // MARK: - ChatConnector Protocol Properties
    
    let connectorType: ChatConnectorType = .claudeCode
    let displayName: String = "Claude Code Terminal"
    
    var isConnected: Bool = false
    var currentBinding: ChatStreamBinding?
    var monitoringTask: Task<Void, Never>?
    var messageCallback: ((ChatStreamMessage) -> Void)?
    
    init() {
        // Initialize with default values
    }
    
    func isAvailable() async -> Bool {
        // Check if we can connect to Claude Code terminal
        return await checkClaudeCodeAvailability()
    }
    
    func connect(binding: ChatStreamBinding) async throws {
        currentBinding = binding
        let connectionParams = try parseClaudeCodeConnectionString(binding.connectionString)
        terminalSession = try await connectToClaudeCodeTerminal(params: connectionParams)
        isConnected = true
    }
    
    func disconnect() async {
        await terminalSession?.disconnect()
        terminalSession = nil
        isConnected = false
        currentBinding = nil
    }
    
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async {
        messageCallback = onMessage
        
        monitoringTask = Task {
            await performMonitoring()
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        messageCallback = nil
    }
    
    func sendMessage(_ content: String) async throws {
        guard let session = terminalSession else {
            throw ChatConnectorError.notConnected
        }
        
        try await session.sendInput(content)
    }
    
    func validateConnection(_ connectionString: String) async -> Bool {
        do {
            _ = try parseClaudeCodeConnectionString(connectionString)
            return await checkClaudeCodeAvailability()
        } catch {
            return false
        }
    }
    
    func getConnectionStatus() async -> ChatConnectionStatus {
        return ChatConnectionStatus(
            isConnected: isConnected,
            connectorType: connectorType,
            connectionString: currentBinding?.connectionString,
            lastActivity: Date(),
            messageCount: 0
        )
    }
    
    func emitMessage(_ message: ChatStreamMessage) {
        messageCallback?(message)
    }
    
    private func performMonitoring() async {
        guard let session = terminalSession else { return }
        
        while !Task.isCancelled {
            do {
                if let output = await session.readOutput() {
                    await processClaudeCodeOutput(output)
                }
                
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                break
            }
        }
    }
    
    func getAvailableSessions() async -> [ChatSessionInfo] {
        return await getClaudeCodeSessions()
    }
    
    // MARK: - Claude Code Specific Implementation
    
    private func checkClaudeCodeAvailability() async -> Bool {
        // Check if Claude Code CLI is available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func parseClaudeCodeConnectionString(_ connectionString: String) throws -> ClaudeCodeConnectionParams {
        // Parse connection string format: "claude://session_id" or "claude://terminal"
        guard connectionString.hasPrefix("claude://") else {
            throw ChatConnectorError.invalidConnectionString("Must start with claude://")
        }
        
        let identifier = String(connectionString.dropFirst("claude://".count))
        
        return ClaudeCodeConnectionParams(
            sessionId: identifier == "terminal" ? nil : identifier,
            useDefaultTerminal: identifier == "terminal"
        )
    }
    
    private func connectToClaudeCodeTerminal(params: ClaudeCodeConnectionParams) async throws -> TerminalSession {
        if params.useDefaultTerminal {
            return try await TerminalSession.connectToDefault()
        } else if let sessionId = params.sessionId {
            return try await TerminalSession.connectToSession(sessionId)
        } else {
            throw ChatConnectorError.invalidConnectionString("Invalid Claude Code parameters")
        }
    }
    
    private func processClaudeCodeOutput(_ output: String) async {
        // Parse Claude Code terminal output for chat messages
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if let message = parseClaudeCodeChatLine(line) {
                emitMessage(message)
            }
        }
    }
    
    private func parseClaudeCodeChatLine(_ line: String) -> ChatStreamMessage? {
        // Parse Claude Code chat output format
        // This would depend on how Claude Code formats its terminal output
        
        if line.contains("Claude:") {
            let content = line.replacingOccurrences(of: "Claude:", with: "").trimmingCharacters(in: .whitespaces)
            return ChatStreamMessage(
                role: .assistant,
                content: content,
                timestamp: Date(),
                metadata: ["source": "claude_code", "raw_line": line]
            )
        } else if line.contains("You:") {
            let content = line.replacingOccurrences(of: "You:", with: "").trimmingCharacters(in: .whitespaces)
            return ChatStreamMessage(
                role: .user,
                content: content,
                timestamp: Date(),
                metadata: ["source": "claude_code", "raw_line": line]
            )
        }
        
        return nil
    }
    
    private func getClaudeCodeSessions() async -> [ChatSessionInfo] {
        // Get available Claude Code sessions
        // This would integrate with Claude Code's session management
        return [
            ChatSessionInfo(
                id: "claude_default",
                name: "Default Terminal",
                type: .claudeCode,
                isActive: true,
                lastActivity: Date()
            )
        ]
    }
}

// MARK: - Generic Chat Connector

actor GenericChatConnector: ChatConnector {
    let connectorType: ChatConnectorType = .generic
    let displayName: String = "Generic Terminal"
    
    private(set) var isConnected: Bool = false
    private(set) var currentBinding: ChatStreamBinding?
    private var monitoringTask: Task<Void, Never>?
    private var messageCallback: ((ChatStreamMessage) -> Void)?
    
    func isAvailable() async -> Bool {
        return true // Always available as fallback
    }
    
    func connect(binding: ChatStreamBinding) async throws {
        currentBinding = binding
        isConnected = true
    }
    
    func disconnect() async {
        currentBinding = nil
        isConnected = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func startMonitoring(onMessage: @escaping (ChatStreamMessage) -> Void) async {
        messageCallback = onMessage
        // Generic monitoring implementation
        // Monitor clipboard, log files, or other generic sources
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        messageCallback = nil
    }
    
    func sendMessage(_ content: String) async throws {
        // Generic message sending implementation
    }
    
    func validateConnection(_ connectionString: String) async -> Bool {
        return true // Generic connector accepts any connection string
    }
    
    func getConnectionStatus() async -> ChatConnectionStatus {
        return ChatConnectionStatus(
            isConnected: isConnected,
            connectorType: connectorType,
            connectionString: currentBinding?.connectionString,
            lastActivity: Date(),
            messageCount: 0
        )
    }
    
    func getAvailableSessions() async -> [ChatSessionInfo] {
        return [
            ChatSessionInfo(
                id: "generic_terminal",
                name: "Generic Terminal",
                type: .generic,
                isActive: false,
                lastActivity: Date()
            )
        ]
    }
    
    private func emitMessage(_ message: ChatStreamMessage) {
        messageCallback?(message)
    }
}

// MARK: - Supporting Types

struct CursorConnectionParams {
    let identifier: String
    let projectPath: String?
    let windowId: String?
}

struct ClaudeCodeConnectionParams {
    let sessionId: String?
    let useDefaultTerminal: Bool
}

struct ChatConnectionStatus {
    let isConnected: Bool
    let connectorType: ChatConnectorType
    let connectionString: String?
    let lastActivity: Date
    let messageCount: Int
}

struct ChatSessionInfo {
    let id: String
    let name: String
    let type: ChatConnectorType
    let isActive: Bool
    let lastActivity: Date
}

// MARK: - Terminal Session (Simplified)

actor TerminalSession {
    private let sessionId: String
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    
    init(sessionId: String) {
        self.sessionId = sessionId
    }
    
    static func connectToDefault() async throws -> TerminalSession {
        let session = TerminalSession(sessionId: "default")
        try await session.connect()
        return session
    }
    
    static func connectToSession(_ sessionId: String) async throws -> TerminalSession {
        let session = TerminalSession(sessionId: sessionId)
        try await session.connect()
        return session
    }
    
    private func connect() async throws {
        // Set up terminal connection
        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()
        
        // Configure process (simplified)
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
    }
    
    func disconnect() async {
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
    }
    
    func sendInput(_ input: String) async throws {
        guard let inputPipe = inputPipe else {
            throw ChatConnectorError.notConnected
        }
        
        let data = (input + "\n").data(using: .utf8) ?? Data()
        inputPipe.fileHandleForWriting.write(data)
    }
    
    func readOutput() async -> String? {
        guard let outputPipe = outputPipe else { return nil }
        
        let data = outputPipe.fileHandleForReading.availableData
        return data.isEmpty ? nil : String(data: data, encoding: .utf8)
    }
}

enum ChatConnectorError: LocalizedError {
    case connectorNotAvailable
    case notConnected
    case invalidConnectionString(String)
    case connectionFailed(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .connectorNotAvailable:
            return "Chat connector is not available"
        case .notConnected:
            return "Not connected to chat stream"
        case .invalidConnectionString(let message):
            return "Invalid connection string: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .notImplemented:
            return "Feature not implemented"
        }
    }
}