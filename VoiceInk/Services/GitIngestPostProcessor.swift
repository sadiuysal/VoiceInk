import Foundation
import os

// MARK: - Parsed/Enhanced Models (minimal viable for now)

struct ParsedGitIngest: Codable {
	let summary: GitIngestSummary
	let tree: String
	let content: String
}

struct RepositoryMetadata: Codable {
	let languages: [String]
	let frameworks: [String]
	let architecturePatterns: [String]
	let dependencies: [String]
	let entryPoints: [String]
	let testFiles: [String]
	let configFiles: [String]
	let documentationFiles: [String]
	let buildFiles: [String]
}

struct FileRelationshipGraph: Codable {
	var edges: [String: [String]] = [:]

	func getRelatedFiles(_ fileName: String) -> [String] {
		return edges[fileName] ?? []
	}
}

struct ContextDictionary: Codable {
	var technicalTerms: [String] = []
	var apis: [String] = []
	var types: [String] = []
	var identifiers: [String] = []
	var fileReferences: [String] = []
	var docKeywords: [String] = []

	func findMatches(for needle: String) -> [String] {
		let hay = technicalTerms + apis + types + identifiers + fileReferences + docKeywords
		return hay.filter { $0.localizedCaseInsensitiveContains(needle) }.prefix(20).map { $0 }
	}
}

struct PromptSegment: Codable {
	let title: String
	let body: String
}

struct EnhancedRepositoryContext: Codable {
	let original: ParsedGitIngest
	let metadata: RepositoryMetadata
	let relationships: FileRelationshipGraph
	let dictionary: ContextDictionary
	let promptSegments: [PromptSegment]

	func findRelevantSegments(for query: String) -> [PromptSegment] {
		let lowered = query.lowercased()
		return promptSegments.filter { $0.title.lowercased().contains(lowered) || $0.body.lowercased().contains(lowered) }.prefix(10).map { $0 }
	}
}

final class GitIngestPostProcessor {
	private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "GitIngestPostProcessor")

	func processGitIngestOutput(result: GitIngestResult) async -> EnhancedRepositoryContext {
		let parsed = ParsedGitIngest(summary: result.summary, tree: result.tree, content: result.content)
		let metadata = extractIntelligentMetadata(parsed)
		let relationships = buildFileRelationships(parsed.tree)
		let dictionary = generateSmartDictionary(parsed.content, languages: metadata.languages)
		let segments = createPromptSegments(parsed, metadata: metadata)
		return EnhancedRepositoryContext(original: parsed, metadata: metadata, relationships: relationships, dictionary: dictionary, promptSegments: segments)
	}

	private func extractIntelligentMetadata(_ parsed: ParsedGitIngest) -> RepositoryMetadata {
		// Very lightweight heuristics to start; can be enhanced later
		let treeLower = parsed.tree.lowercased()
		var languages: [String] = []
		if treeLower.contains(".swift") { languages.append("Swift") }
		if treeLower.contains(".py") { languages.append("Python") }
		if treeLower.contains(".js") { languages.append("JavaScript") }
		if treeLower.contains(".ts") { languages.append("TypeScript") }
		if treeLower.contains(".go") { languages.append("Go") }
		if treeLower.contains(".rs") { languages.append("Rust") }

		let lines = parsed.tree.components(separatedBy: "\n")
		let documentationFiles = lines.filter { line in line.localizedCaseInsensitiveContains("readme") || line.hasSuffix(".md") }
		let configExts = [".json",".yml",".yaml",".toml",".plist"]
		let configFiles = lines.filter { line in
			let lower = line.lowercased()
			return configExts.contains(where: { ext in lower.hasSuffix(ext) })
		}
		let buildFiles = lines.filter { line in line.localizedCaseInsensitiveContains("makefile") || line.localizedCaseInsensitiveContains("dockerfile") || line.localizedCaseInsensitiveContains("gradle") }
		let testFiles = lines.filter { line in line.localizedCaseInsensitiveContains("test") || line.localizedCaseInsensitiveContains("spec") }

		return RepositoryMetadata(
			languages: Array(Set(languages)),
			frameworks: [],
			architecturePatterns: [],
			dependencies: [],
			entryPoints: [],
			testFiles: testFiles,
			configFiles: configFiles,
			documentationFiles: documentationFiles,
			buildFiles: buildFiles
		)
	}

	private func buildFileRelationships(_ tree: String) -> FileRelationshipGraph {
		// Placeholder: relate files in same directories
		var graph = FileRelationshipGraph()
		let lines = tree.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
		let files = lines.map { $0.trimmingCharacters(in: .whitespaces) }
		var dirToFiles: [String:[String]] = [:]
		for f in files {
			let dir = (f as NSString).deletingLastPathComponent
			dirToFiles[dir, default: []].append(f)
		}
		for (_, group) in dirToFiles {
			for a in group {
				graph.edges[a] = group.filter { $0 != a }
			}
		}
		return graph
	}

	private func generateSmartDictionary(_ content: String, languages: [String]) -> ContextDictionary {
		var dict = ContextDictionary()
		// Types (class/struct/enum)
		let typePattern = "(?:class|struct|enum|interface)\\s+([A-Z][a-zA-Z0-9_]+)"
		if let regex = try? NSRegularExpression(pattern: typePattern, options: .caseInsensitive) {
			let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
			for m in matches where m.numberOfRanges > 1 {
				if let r = Range(m.range(at: 1), in: content) { dict.types.append(String(content[r])) }
			}
		}
		// Functions
		let funcPattern = "(?:func|function|def)\\s+([a-zA-Z_][a-zA-Z0-9_]+)"
		if let regex = try? NSRegularExpression(pattern: funcPattern, options: .caseInsensitive) {
			let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
			for m in matches where m.numberOfRanges > 1 {
				if let r = Range(m.range(at: 1), in: content) { dict.apis.append(String(content[r])) }
			}
		}
		// Identifiers (CamelCase, snake_case, kebab-case)
		let idPatterns = ["[A-Z][a-z]+(?:[A-Z][a-z]+)+","[a-z]+(?:_[a-z]+)+","[a-z]+(?:-[a-z]+)+"]
		for p in idPatterns {
			if let regex = try? NSRegularExpression(pattern: p) {
				let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
				for m in matches {
					if let r = Range(m.range, in: content) { dict.identifiers.append(String(content[r])) }
				}
			}
		}
		// File references
		let filePattern = "[\\w\\-\\.]+\\.[a-zA-Z0-9]{1,4}"
		if let regex = try? NSRegularExpression(pattern: filePattern) {
			let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
			for m in matches { if let r = Range(m.range, in: content) { dict.fileReferences.append(String(content[r])) } }
		}
		// Doc keywords (very basic)
		let keywords = ["install","setup","configure","usage","example","build","test","deploy","license"]
		for k in keywords { if content.localizedCaseInsensitiveContains(k) { dict.docKeywords.append(k) } }
		// Technical terms: naive split and filter
		let words = content.replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: " ", options: .regularExpression).split(separator: " ").map(String.init)
		dict.technicalTerms = Array(Set(words.filter { $0.count >= 4 })).sorted().prefix(500).map { $0 }
		return dict
	}

	private func createPromptSegments(_ parsed: ParsedGitIngest, metadata: RepositoryMetadata) -> [PromptSegment] {
		var segments: [PromptSegment] = []
		segments.append(PromptSegment(title: "Repository Summary", body: "Files/Dirs from GitIngest; tokens estimated if available."))
		segments.append(PromptSegment(title: "Directory Structure", body: parsed.tree.prefix(4000).description))
		segments.append(PromptSegment(title: "Content", body: parsed.content.prefix(6000).description))
		if !metadata.documentationFiles.isEmpty {
			segments.append(PromptSegment(title: "Documentation Files", body: metadata.documentationFiles.joined(separator: "\n")))
		}
		return segments
	}
}


