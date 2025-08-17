import Foundation
import NaturalLanguage
import os

final class FilesystemContextService {
	static let shared = FilesystemContextService()
	
	private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "fs.context")
	private let fileManager = FileManager.default
	private let glossaryTTL: TimeInterval = 10 * 60 // 10 minutes
	
	private struct Constants {
		static let supportDirName = "VoiceInk"
		static let dictionariesDir = "ProjectDictionaries"
		static let cwdHelperPath = "~/.voiceink/cwd"
		static let storeFilePrefix = "dict_"
	}
	
	struct ProjectDictionary: Codable {
		let rootPath: String
		let updatedAt: Date
		let terms: [String]
	}
	
	private init() {}
	
	// MARK: - Public API
	func refreshIfNeeded() {
		guard UserDefaults.standard.bool(forKey: "UseFilesystemContext") else { return }
		guard let root = detectActiveProjectRoot() else { return }
		
		if let existing = loadDictionary(for: root), Date().timeIntervalSince(existing.updatedAt) < glossaryTTL {
			return
		}
		
		Task.detached(priority: .utility) { [weak self] in
			guard let self else { return }
			do {
				let terms = try self.buildGlossary(for: root)
				let dict = ProjectDictionary(rootPath: root.path, updatedAt: Date(), terms: terms)
				try self.saveDictionary(dict)
				self.logger.notice("📚 Project dictionary updated for \(root.path, privacy: .public) with \(terms.count, privacy: .public) terms")
				NotificationCenter.default.post(name: .init("filesystemDictionaryUpdated"), object: nil)
			} catch {
				self.logger.error("❌ FS context refresh failed: \(error.localizedDescription, privacy: .public)")
			}
		}
	}
	
	func currentGlossary(topK: Int = 20) -> [String] {
		guard let root = detectActiveProjectRoot(), let dict = loadDictionary(for: root) else { return [] }
		return Array(dict.terms.prefix(topK))
	}
	
	// MARK: - Detection
	func detectActiveProjectRoot() -> URL? {
		// 1) Manual override
		if let manual = UserDefaults.standard.string(forKey: "ManualProjectRootPath"), !manual.isEmpty {
			let url = URL(fileURLWithPath: manual)
			if fileManager.fileExists(atPath: url.path, isDirectory: nil) { return url }
		}
		// 2) Optional shell helper writes ~/.voiceink/cwd
		let expanded = (Constants.cwdHelperPath as NSString).expandingTildeInPath
		if let contents = try? String(contentsOfFile: expanded, encoding: .utf8) {
			let path = contents.trimmingCharacters(in: .whitespacesAndNewlines)
			if !path.isEmpty {
				let url = URL(fileURLWithPath: path)
				var isDir: ObjCBool = false
				if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
					return url
				}
			}
		}
		return nil
	}
	
	// MARK: - Build
	private func buildGlossary(for root: URL) throws -> [String] {
		let allowedNames: Set<String> = ["readme.md", "readme", "claude.md", "package.json"]
		let denylistDirs: Set<String> = [".git", "node_modules", ".venv", "build", "dist", "target", ".gradle", ".idea", ".vscode"]
		let maxBytesPerFile: Int = 128 * 1024
		
		var candidates = [URL]()
		if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
			for case let url as URL in enumerator {
				let last = url.lastPathComponent.lowercased()
				if denylistDirs.contains(last) {
					(enumerator as? FileManager.DirectoryEnumerator)?.skipDescendants()
					continue
				}
				if allowedNames.contains(last) {
					candidates.append(url)
				}
			}
		}
		
		var termScores = [String: Int]()
		
		for url in candidates {
			if url.lastPathComponent.lowercased() == "package.json" {
				if let data = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
					if let name = obj["name"] as? String { bump(&termScores, normalize(name), by: 5) }
					if let deps = obj["dependencies"] as? [String: Any] { for key in deps.keys { bump(&termScores, normalize(key), by: 3) } }
					if let dev = obj["devDependencies"] as? [String: Any] { for key in dev.keys { bump(&termScores, normalize(key), by: 2) } }
					if let scripts = obj["scripts"] as? [String: Any] { for key in scripts.keys { bump(&termScores, normalize(key), by: 1) } }
				}
				continue
			}
			
			// Markdown-like content
			if let handle = try? FileHandle(forReadingFrom: url) {
				let data = handle.readData(ofLength: maxBytesPerFile)
				handle.closeFile()
				if let content = String(data: data, encoding: .utf8) {
					extractTerms(fromMarkdown: content, into: &termScores)
				}
			}
		}
		
		// Add top-level filenames as terms (without extensions)
		if let items = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
			for item in items {
				let name = item.deletingPathExtension().lastPathComponent
				if name.count >= 3 { bump(&termScores, normalize(name), by: 1) }
			}
		}
		
		let sorted = termScores
			.filter { !$0.key.isEmpty }
			.sorted { (a, b) in a.value == b.value ? a.key < b.key : a.value > b.value }
			.map { $0.key }
		
		return Array(sorted.prefix(200))
	}
	
	private func extractTerms(fromMarkdown content: String, into scores: inout [String: Int]) {
		let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
		let headingPrefix: Set<Character> = ["#", "*", "-", "+"]
		
		for raw in lines {
			let line = String(raw)
			if line.first.map({ headingPrefix.contains($0) }) == true {
				let text = line.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#*+- "))
				for token in tokenize(text) { bump(&scores, token, by: 2) }
			} else if let codeTickRange = line.range(of: "`"), line.filter({ $0 == "`" }).count >= 2 {
				// inline code: extract between backticks
				let parts = line.split(separator: "`")
				for (idx, part) in parts.enumerated() where idx % 2 == 1 {
					let token = normalize(String(part))
					if token.count >= 2 { bump(&scores, token, by: 3) }
				}
			} else if line.starts(with: "```") {
				// code fence info string
				let lang = line.replacingOccurrences(of: "`", with: "").trimmingCharacters(in: .whitespaces)
				if !lang.isEmpty { bump(&scores, normalize(lang), by: 3) }
			}
		}
	}
	
	private func tokenize(_ text: String) -> [String] {
		let tagger = NLTagger(tagSchemes: [.lexicalClass])
		tagger.string = text
		var tokens = [String]()
		let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
		tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
			let word = String(text[range])
			let token = normalize(word)
			if token.count >= 3 { tokens.append(token) }
			return true
		}
		return tokens
	}
	
	private func normalize(_ s: String) -> String {
		let lowered = s.lowercased()
		let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_+.:/"))
		let filtered = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character(" ") }
		return String(filtered).replacingOccurrences(of: " ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	private func bump(_ dict: inout [String: Int], _ key: String, by inc: Int) {
		guard !key.isEmpty else { return }
		dict[key, default: 0] += inc
	}
	
	// MARK: - Storage
	private func storeDirectory() throws -> URL {
		let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		let appDir = support.appendingPathComponent(Constants.supportDirName, isDirectory: true)
		let dictDir = appDir.appendingPathComponent(Constants.dictionariesDir, isDirectory: true)
		if !fileManager.fileExists(atPath: appDir.path) {
			try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
		}
		if !fileManager.fileExists(atPath: dictDir.path) {
			try fileManager.createDirectory(at: dictDir, withIntermediateDirectories: true)
		}
		return dictDir
	}
	
	private func dictFilename(for root: URL) -> URL? {
		let safe = root.path.replacingOccurrences(of: "/", with: "_")
		return try? storeDirectory().appendingPathComponent("\(Constants.storeFilePrefix)\(safe).json")
	}
	
	private func saveDictionary(_ dict: ProjectDictionary) throws {
		guard let url = dictFilename(for: URL(fileURLWithPath: dict.rootPath)) else { return }
		let data = try JSONEncoder().encode(dict)
		try data.write(to: url, options: .atomic)
	}
	
	private func loadDictionary(for root: URL) -> ProjectDictionary? {
		guard let url = dictFilename(for: root) else { return nil }
		guard let data = try? Data(contentsOf: url) else { return nil }
		return try? JSONDecoder().decode(ProjectDictionary.self, from: data)
	}
}
