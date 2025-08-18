import Foundation
import os

struct ProjectContextSnapshot: Codable, Identifiable {
    let id: UUID
    let rootPath: String
    let createdAt: Date
    let ttlSeconds: Int
    let terms: [String]
    let sourceStats: [String:Int]
    let markdownSummary: String?
    let hashPrefix: String?
}

final class ProjectContextStore {
    static let shared = ProjectContextStore()
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "fs.snapshot")
    private let fileManager = FileManager.default

    private init() {}

    func rootHash(for root: URL) -> String {
        let path = root.path
        let hash = abs(path.hashValue)
        return String(hash, radix: 16).prefix(8).description
    }

    private func baseDir() throws -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = appSupport.appendingPathComponent("com.sadiuysal.VoiceInk/ProjectContexts", isDirectory: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func contextsDir(for root: URL) throws -> URL {
        let dir = try baseDir().appendingPathComponent(rootHash(for: root), isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveCurrent(_ s: ProjectContextSnapshot, for root: URL) throws {
        let dir = try contextsDir(for: root)
        let url = dir.appendingPathComponent("current.json")
        let data = try JSONEncoder().encode(s)
        try data.write(to: url, options: .atomic)
        logger.log("Saved current snapshot root:\(root.lastPathComponent, privacy: .public) terms:\(s.terms.count)")
    }

    func loadCurrent(for root: URL) -> ProjectContextSnapshot? {
        guard let url = try? contextsDir(for: root).appendingPathComponent("current.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProjectContextSnapshot.self, from: data)
    }

    func saveSnapshot(_ s: ProjectContextSnapshot, for root: URL) throws -> URL {
        let dir = try contextsDir(for: root).appendingPathComponent("snapshots", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(Int(s.createdAt.timeIntervalSince1970)).json")
        let data = try JSONEncoder().encode(s)
        try data.write(to: url, options: .atomic)
        return url
    }

    func listSnapshots(for root: URL) -> [ProjectContextSnapshot] {
        guard let dir = try? contextsDir(for: root).appendingPathComponent("snapshots"),
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return files.compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(ProjectContextSnapshot.self, from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func exportMarkdown(_ s: ProjectContextSnapshot) -> String {
        let terms = s.terms.enumerated().map { "\($0.offset+1). \($0.element)" }.joined(separator: "\n")
        let stats = s.sourceStats.map { "- \($0.key): \($0.value)" }.joined(separator: "\n")
        return """
        # Project Context Snapshot
        - Root: \(s.rootPath)
        - Created: \(s.createdAt)
        - TTL: \(s.ttlSeconds)s

        ## Top Terms
        \(terms)

        ## Source Stats
        \(stats)
        """
    }

    	@discardableResult
	func writeExport(_ s: ProjectContextSnapshot, for root: URL) throws -> URL {
		let dir = try contextsDir(for: root).appendingPathComponent("exports", isDirectory: true)
		try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
		let url = dir.appendingPathComponent("\(Int(s.createdAt.timeIntervalSince1970)).md")
		try exportMarkdown(s).write(to: url, atomically: true, encoding: .utf8)
		return url
	}

	@discardableResult
	func syncClaude(_ s: ProjectContextSnapshot, at root: URL) throws -> URL {
		let claudeFile = root.appendingPathComponent("CLAUDE.md")
		let start = "<!-- VOICEINK:TERMS:START -->"
		let end = "<!-- VOICEINK:TERMS:END -->"
		
		let contextBlock = """
		\(start)
		# VoiceInk Project Context
		Generated: \(s.createdAt.formatted())
		
		## Project Dictionary (\(s.terms.count) terms)
		\(s.terms.prefix(UserDefaults.standard.fsTermsLimit).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
		
		## Source Statistics
		\(s.sourceStats.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
		\(end)
		"""
		
		let existing = (try? String(contentsOf: claudeFile)) ?? ""
		let updated: String
		
		if let startRange = existing.range(of: start),
		   let endRange = existing.range(of: end),
		   startRange.lowerBound < endRange.upperBound {
			// Replace existing block
			updated = existing.replacingCharacters(in: startRange.lowerBound..<endRange.upperBound, with: contextBlock)
		} else {
			// Append to end
			updated = existing.isEmpty ? contextBlock : existing + "\n\n" + contextBlock
		}
		
		try updated.write(to: claudeFile, atomically: true, encoding: .utf8)
		logger.log("Synced \(s.terms.count) terms to CLAUDE.md")
		return claudeFile
	}
}
