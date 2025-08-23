import Foundation
import NaturalLanguage
import os
import CoreServices

final class FilesystemContextService {
    static let shared = FilesystemContextService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "fs.context")
    private let fileManager = FileManager.default
    private let glossaryTTL: TimeInterval = 10 * 60 // 10 minutes
    private var fseventStream: FSEventStreamRef?
    private var lastEventProcessAt: Date = .distantPast
    
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
    
    	/// Refresh the glossary if TTL has expired
	func refreshIfNeeded() {
		Task {
			guard UserDefaults.standard.useFilesystemContext else {
				logger.debug("Filesystem context disabled; skipping refresh")
				return
			}
			do {
				if let root = detectActiveProjectRoot() {
					logger.debug("Detected project root: \(root.path, privacy: .public)")
					try await buildAndStoreGlossary(for: root)
					// TODO: Implement with new backend architecture
					// await ProjectFileIndexStore.shared.indexProject(at: root)
					
					// Also update the Markdown Dictionary Index
					await ContextIndexStore.shared.indexProject(at: root)
				} else {
					logger.debug("No project root detected; not building glossary")
				}
			} catch {
				logger.error("Failed to refresh glossary: \(error.localizedDescription)")
			}
		}
	}
    
    /// Get current glossary terms, top K most relevant
    func currentGlossary(topK: Int = 20) -> [String] {
        guard let root = detectActiveProjectRoot(),
              let dict = loadDictionary(for: root) else {
            return []
        }
        
        // Return top K terms, sorted by relevance (could be enhanced with frequency scoring)
        return Array(dict.terms.prefix(topK))
    }
    
    // MARK: - Detection
    
    /// Detect the active project root directory
    func detectActiveProjectRoot() -> URL? {
        // Priority 1: Manual override from UserDefaults
        if let manualPath = UserDefaults.standard.string(forKey: "ManualProjectRootPath"),
           !manualPath.isEmpty {
            let url = URL(fileURLWithPath: manualPath)
            if fileManager.fileExists(atPath: url.path) {
                logger.debug("Using manual project root: \(url.path, privacy: .public)")
                return url
            }
        }
        
        // Priority 2: Shell helper file (~/.voiceink/cwd)
        let cwdPath = (Constants.cwdHelperPath as NSString).expandingTildeInPath
        if fileManager.fileExists(atPath: cwdPath),
           let cwdContent = try? String(contentsOfFile: cwdPath),
           !cwdContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: cwdContent.trimmingCharacters(in: .whitespacesAndNewlines))
            if fileManager.fileExists(atPath: url.path) {
                logger.debug("Using cwd helper root: \(url.path, privacy: .public)")
                return url
            }
        }
        
        // Priority 3: Current working directory (fallback)
        let currentDir = fileManager.currentDirectoryPath
        let url = URL(fileURLWithPath: currentDir)
        logger.debug("Fallback currentDirectoryPath: \(url.path, privacy: .public)")
        
        // Check if this looks like a project root (has common project files)
        if isProjectRoot(url) {
            logger.debug("Current directory recognized as project root")
            return url
        }
        
        // Try to find project root by walking up the directory tree
        let found = findProjectRootInParentDirectories(startingFrom: url)
        if found == nil { logger.debug("Parent walk-up did not find a project root") }
        return found
    }
    
    // MARK: - Build
    
    private func buildAndStoreGlossary(for root: URL) async throws {
        let start = Date()
        let terms = try buildGlossary(for: root)
        let dict = ProjectDictionary(
            rootPath: root.path,
            updatedAt: Date(),
            terms: terms
        )
        try saveDictionary(dict)
        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        logger.info("Built glossary with \(terms.count) terms for \(root.lastPathComponent) in \(elapsedMs)ms")

        // TODO: Implement with new backend architecture
        // Save minimal snapshot for Inspector
        // let ttl = UserDefaults.standard.fsRefreshTTLSeconds
        // let limit = UserDefaults.standard.fsTermsLimit
        // let snapshot = ProjectContextSnapshot(
        //     id: UUID(),
        //     rootPath: root.path,
        //     createdAt: Date(),
        //     ttlSeconds: ttl,
        //     terms: Array(terms.prefix(limit)),
        //     sourceStats: ["elapsedMs": elapsedMs],
        //     markdownSummary: nil,
        //     hashPrefix: nil
        // )
        // try? ProjectContextStore.shared.saveCurrent(snapshot, for: root)
        // _ = try? ProjectContextStore.shared.saveSnapshot(snapshot, for: root)
    }
    
    private func buildGlossary(for root: URL) throws -> [String] {
        var termScores: [String: Int] = [:]
        var filesScanned = 0
        var dirsScanned = 0
        
        		// Scan for project files
		let allowedExtensions = ["md", "txt", "json", "yaml", "yml", "toml", "lock", "gradle", "pom", "cargo", "package", "swift", "py", "js", "ts"]
		let allowedFilenames = ["README", "CLAUDE", "CHANGELOG", "LICENSE", "CONTRIBUTING", "BUILDING", "Makefile", "Dockerfile"]
        
        // Scan top-level files and directories
        let contents = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        
        for item in contents {
            let filename = item.lastPathComponent
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            // Score directory names (project structure)
            if isDirectory {
                dirsScanned += 1
                
                // Add semantic directory reference
                let semanticDirRef = generateSemanticFileReference(filename: filename, extension: "", isDirectory: true)
                bump(&termScores, semanticDirRef, by: 4) // Semantic refs get highest weight
                
                // Also add component terms for searchability
                let cleanName = filename.replacingOccurrences(of: ".", with: " ")
                let terms = tokenize(cleanName)
                for term in terms {
                    bump(&termScores, term, by: 2) // Individual terms get lower weight
                }
            }
            
            // Score filenames
            if allowedFilenames.contains(where: { filename.uppercased().contains($0.uppercased()) }) {
                let fileExtension = item.pathExtension
                
                // Add semantic file reference
                let semanticFileRef = generateSemanticFileReference(filename: filename, extension: fileExtension, isDirectory: false)
                bump(&termScores, semanticFileRef, by: 5) // Semantic refs get highest weight
                
                // Also add component terms for searchability
                let cleanName = filename.replacingOccurrences(of: ".", with: " ")
                let terms = tokenize(cleanName)
                for term in terms {
                    bump(&termScores, term, by: 2) // Individual terms get lower weight
                }
            }
            
            			// Score content of markdown and text files
			if allowedExtensions.contains(item.pathExtension.lowercased()) {
				filesScanned += 1
				if let content = try? String(contentsOf: item) {
					// Always extract from markdown/text content
					extractTerms(fromMarkdown: content, into: &termScores)
					
					// Special handling for CLAUDE.md with highest weights
					if filename.uppercased().contains("CLAUDE") {
						extractClaudeTerms(from: content, into: &termScores)
					}
					// Enhanced processing for README files
					else if filename.uppercased().contains("README") {
						extractEnhancedTerms(from: content, into: &termScores, weight: 4)
					}
					// All other markdown files get moderate enhancement
					else if item.pathExtension.lowercased() == "md" {
						extractEnhancedTerms(from: content, into: &termScores, weight: 2)
					}
				}
			}
        }
        
        logger.debug("Scanned dirs: \(dirsScanned), files: \(filesScanned) at root: \(root.lastPathComponent, privacy: .public)")
        		// Convert to sorted array and apply quality-based filtering
		let sortedTerms = termScores.sorted { $0.value > $1.value }
		
		// Quality-based filtering instead of arbitrary limits
		var qualityTerms: [String] = []
		let maxTerms = max(50, min(1000, sortedTerms.count)) // Flexible between 50-1000 based on content
		
		for (term, score) in sortedTerms.prefix(maxTerms) {
			// Only include terms with reasonable scores and semantic value
			if score >= 2 && isMeaningfulTerm(term) {
				qualityTerms.append(term)
			}
			
			// Stop if we have enough high-quality terms
			if qualityTerms.count >= 300 { break }
		}
		
		logger.debug("Filtered \(sortedTerms.count) raw terms down to \(qualityTerms.count) meaningful terms")
		return qualityTerms
    }
    
    	private func extractClaudeTerms(from content: String, into scores: inout [String: Int]) {
		// Extract project-specific terminology from CLAUDE.md with higher weights
		let lines = content.components(separatedBy: .newlines)
		
		for line in lines {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			
			// Skip the generated VoiceInk section to avoid self-reinforcement
			if trimmed.contains("VOICEINK:TERMS") { continue }
			
			// Look for key-value patterns, definitions, and technical terms
			if trimmed.contains(":") || trimmed.contains("=") || trimmed.contains("-") {
				let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: ":=-"))
				for part in parts {
					let terms = tokenize(part)
					for term in terms {
						bump(&scores, term, by: 8) // CLAUDE terms get highest weight
					}
				}
			}
			
			// Extract code blocks and technical references
			if trimmed.contains("`") || trimmed.contains("```") {
				let codeContent = trimmed.replacingOccurrences(of: "`", with: " ")
				let terms = tokenize(codeContent)
				for term in terms {
					bump(&scores, term, by: 7)
				}
			}
			
			// Extract file and directory references (preserve case)
			if trimmed.contains("/") || trimmed.contains(".") {
				let pathTerms = extractSemanticPathTerms(from: trimmed)
				for term in pathTerms {
					bump(&scores, term, by: 6)
				}
			}
			
			// Extract technical terms from regular text
			if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
				let terms = tokenize(trimmed)
				for term in terms {
					if term.count >= 4 { // Longer terms from CLAUDE.md are likely important
						bump(&scores, term, by: 3)
					}
				}
			}
		}
	}
	
	private func extractEnhancedTerms(from content: String, into scores: inout [String: Int], weight: Int) {
		// Enhanced extraction for important markdown files
		let lines = content.components(separatedBy: .newlines)
		
		for line in lines {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			
			// Extract from headings with higher priority
			if trimmed.hasPrefix("#") {
				let heading = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
				let terms = tokenize(heading)
				for term in terms {
					bump(&scores, term, by: weight + 2) // Extra weight for headings
				}
			}
			
			// Extract from code blocks and technical terms
			if trimmed.contains("`") {
				let codeContent = trimmed.replacingOccurrences(of: "`", with: " ")
				let terms = tokenize(codeContent)
				for term in terms {
					bump(&scores, term, by: weight + 1)
				}
			}
			
			// Extract emphasized terms (bold/italic)
			if trimmed.contains("**") || trimmed.contains("*") {
				let emphasized = trimmed.replacingOccurrences(of: "\\*+", with: " ", options: .regularExpression)
				let terms = tokenize(emphasized)
				for term in terms {
					bump(&scores, term, by: weight + 1)
				}
			}
			
			// Extract project-specific patterns (CamelCase, kebab-case, snake_case)
			let patterns = [
				"[A-Z][a-z]+(?:[A-Z][a-z]+)+", // CamelCase
				"[a-z]+(?:-[a-z]+)+", // kebab-case
				"[a-z]+(?:_[a-z]+)+" // snake_case
			]
			
			for pattern in patterns {
				let regex = try? NSRegularExpression(pattern: pattern)
				let matches = regex?.matches(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) ?? []
				for match in matches {
					if let range = Range(match.range, in: trimmed) {
						let term = String(trimmed[range])
						if isMeaningfulTerm(term) {
							bump(&scores, term, by: weight)
						}
					}
				}
			}
			
			// Extract from regular content
			let terms = tokenize(trimmed)
			for term in terms {
				bump(&scores, term, by: weight)
			}
		}
	}

	private func extractTerms(fromMarkdown content: String, into scores: inout [String: Int]) {
        // Extract headings, code blocks, and emphasis
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Headings (## Title)
            if trimmed.hasPrefix("#") {
                let title = trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                let terms = tokenize(title)
                for term in terms {
                    bump(&scores, term, by: 4) // Headings get highest weight
                }
            }
            
            // Code blocks and inline code
            if trimmed.contains("`") || trimmed.contains("```") {
                let codeContent = trimmed.replacingOccurrences(of: "`", with: " ")
                let terms = tokenize(codeContent)
                for term in terms {
                    bump(&scores, term, by: 2)
                }
            }
            
            // Bold/italic emphasis
            if trimmed.contains("**") || trimmed.contains("*") {
                let emphasisContent = trimmed.replacingOccurrences(of: "**", with: " ").replacingOccurrences(of: "*", with: " ")
                let terms = tokenize(emphasisContent)
                for term in terms {
                    bump(&scores, term, by: 1)
                }
            }
        }
    }
    
    	private func tokenize(_ text: String) -> [String] {
		let tagger = NLTagger(tagSchemes: [.lexicalClass])
		tagger.string = text
		
		var terms: [String] = []
		tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
			let word = String(text[range])
			let normalized = normalize(word)
			
			// Use enhanced filtering for meaningful terms
			if isMeaningfulTerm(normalized) && normalized.count <= 50 {
				terms.append(normalized)
			}
			return true
		}
		
		return terms
	}
    
    	private func extractPathTerms(from text: String) -> [String] {
		// Extract meaningful terms from file paths and references (preserve case sensitivity)
		var terms: [String] = []
		
		// Split by common path separators and extract meaningful parts
		let pathComponents = text.components(separatedBy: CharacterSet(charactersIn: "/.\\"))
		
		for component in pathComponents {
			let clean = component.trimmingCharacters(in: .whitespacesAndNewlines)
			if clean.count >= 2 && clean.count <= 30 {
				// Keep original case for file/directory names
				terms.append(clean)
				
				// Also add without common extensions for broader matching
				let withoutExt = clean.replacingOccurrences(of: #"\.(md|txt|json|yaml|yml|toml|lock|gradle|pom|cargo|package|swift|py|js|ts)$"#, with: "", options: .regularExpression)
				if withoutExt.count >= 2 && withoutExt != clean {
					terms.append(withoutExt)
				}
			}
		}
		
		return terms
	}
	
	private func extractSemanticPathTerms(from text: String) -> [String] {
		// Extract file and directory references with semantic prefixes
		var terms: [String] = []
		
		// Look for file paths and references
		let patterns = [
			#"[\w\-\.]+\.[\w]{1,4}"#,  // Files with extensions
			#"[\w\-]+/[\w\-\.]+"#,     // Directory/file paths  
			#"/[\w\-\./]+"#,           // Absolute paths
			#"\.[\w]+/"#               // Relative paths starting with ./
		]
		
		for pattern in patterns {
			let regex = try? NSRegularExpression(pattern: pattern, options: [])
			let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
			
			for match in matches {
				if let range = Range(match.range, in: text) {
					let matchedText = String(text[range])
					let components = matchedText.components(separatedBy: "/")
					
					for component in components {
						let clean = component.trimmingCharacters(in: .whitespacesAndNewlines)
						if clean.count >= 2 {
							// Determine if it's a file or directory and create semantic reference
							if clean.contains(".") && !clean.hasSuffix(".") {
								// Likely a file
								let parts = clean.components(separatedBy: ".")
								if parts.count >= 2 {
									let filename = clean
									let ext = parts.last ?? ""
									let semanticRef = generateSemanticFileReference(filename: filename, extension: ext, isDirectory: false)
									terms.append(semanticRef)
								}
							} else if !clean.contains(".") {
								// Likely a directory
								let semanticRef = generateSemanticFileReference(filename: clean, extension: "", isDirectory: true)
								terms.append(semanticRef)
							}
							
							// Also add the raw term for backward compatibility
							terms.append(clean)
						}
					}
				}
			}
		}
		
		return terms
	}

	private func normalize(_ s: String) -> String {
		// Preserve case sensitivity for better file/directory matching
		return s.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)
	}
	
	private func isStopWord(_ term: String) -> Bool {
		// Filter out common English words that don't add value to the context
		let stopWords = Set([
			"for", "the", "and", "with", "from", "but", "not", "all", "any", "can", "had", "her", "was", "one", "our", "out", "day", "had", "his", "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use",
			"are", "you", "have", "that", "will", "this", "when", "they", "been", "said", "each", "which", "your", "their", "time", "would", "there", "could", "other", "after", "first", "never", "these", "think", "where", "being", "every", "great", "might", "shall", "still", "those", "under", "while",
			"into", "about", "then", "them", "than", "only", "come", "made", "over", "also", "back", "what", "were", "some", "may", "must", "such", "upon", "before", "here", "much", "own", "take", "very", "well", "get", "through", "should", "between", "want", "just", "good", "even", "most", "many", "little", "long", "same", "another", "down", "right", "again", "few", "work", "yet", "against", "find", "tell", "part", "give", "off", "end", "why", "turn", "away", "place", "come", "keep", "old", "seem", "any", "ask", "own", "below", "try", "last", "help",
			// Additional technical stopwords and common words
			"using", "used", "example", "examples", "note", "notes", "info", "information", "description", "details", "step", "steps", "section", "sections", "chapter", "chapters", "page", "pages", "line", "lines", "item", "items", "list", "lists", "table", "tables", "figure", "figures",
			// Common markdown/docs words
			"markdown", "readme", "documentation", "docs", "guide", "tutorial", "manual", "reference", "overview", "introduction", "getting", "started", "basic", "basics", "advanced", "features", "feature", "options", "option", "settings", "setting", "config", "configuration", "setup",
			// Programming common words
			"function", "method", "class", "interface", "implementation", "import", "export", "return", "value", "values", "parameter", "parameters", "argument", "arguments", "variable", "variables", "constant", "constants", "type", "types", "string", "number", "boolean", "object", "array"
		])
		return stopWords.contains(term.lowercased())
	}
	
	private func isMeaningfulTerm(_ term: String) -> Bool {
		// Additional filtering for meaningful terms
		let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Filter out pure numbers, single characters, or very short terms
		if cleanTerm.count < 3 { return false }
		
		// Filter out pure numbers or version numbers like "1.0", "2.3.4"
		if cleanTerm.range(of: "^[0-9.]+$", options: .regularExpression) != nil { return false }
		
		// Filter out terms that are mostly numbers with minimal letters
		let letterCount = cleanTerm.filter { $0.isLetter }.count
		let digitCount = cleanTerm.filter { $0.isNumber }.count
		if digitCount > letterCount && letterCount < 2 { return false }
		
		// Filter out very common suffixes/prefixes alone
		let commonPrefixSuffixes = ["ing", "tion", "ness", "ment", "able", "ible", "ful", "less", "pre", "post", "sub", "non", "anti", "pro", "de", "re", "un", "dis", "over", "under", "out", "up", "down"]
		if commonPrefixSuffixes.contains(cleanTerm.lowercased()) { return false }
		
		// Filter out single words that are too generic
		let genericWords = ["main", "app", "test", "demo", "sample", "temp", "tmp", "build", "dist", "src", "lib", "bin", "var", "let", "def", "if", "else", "then", "do", "while", "for", "case", "switch", "try", "catch", "throw", "async", "await", "public", "private", "static", "final"]
		if genericWords.contains(cleanTerm.lowercased()) { return false }
		
		// Must contain at least one letter
		if !cleanTerm.contains(where: { $0.isLetter }) { return false }
		
		// Check if it's a stopword
		if isStopWord(cleanTerm) { return false }
		
		return true
	}
	
	private func generateSemanticFileReference(filename: String, extension: String, isDirectory: Bool) -> String {
		if isDirectory {
			return "directory:\(filename)"
		}
		
		// Create semantic prefixes based on file type
		switch `extension`.lowercased() {
		case "swift":
			return "swift-file:\(filename)"
		case "md", "markdown":
			return "markdown-file:\(filename)"
		case "py":
			return "python-file:\(filename)"
		case "js":
			return "javascript-file:\(filename)"
		case "ts":
			return "typescript-file:\(filename)"
		case "json":
			return "config-file:\(filename)"
		case "yaml", "yml":
			return "config-file:\(filename)"
		case "toml":
			return "config-file:\(filename)"
		case "txt":
			return "text-file:\(filename)"
		case "lock":
			return "lock-file:\(filename)"
		case "gradle":
			return "build-file:\(filename)"
		case "pom":
			return "build-file:\(filename)"
		case "cargo":
			return "build-file:\(filename)"
		case "package":
			return "package-file:\(filename)"
		case "":
			// Files without extension (like README, Dockerfile, Makefile)
			let name = filename.uppercased()
			if name.contains("README") {
				return "readme-file:\(filename)"
			} else if name.contains("CLAUDE") {
				return "claude-file:\(filename)"
			} else if name.contains("LICENSE") {
				return "license-file:\(filename)"
			} else if name.contains("MAKEFILE") || name.contains("DOCKERFILE") {
				return "build-file:\(filename)"
			} else {
				return "system-file:\(filename)"
			}
		default:
			return "file:\(filename)"
		}
	}
    
    private func bump(_ dict: inout [String: Int], _ key: String, by inc: Int) {
        dict[key, default: 0] += inc
    }
    
    // MARK: - Storage
    
    private func storeDirectory() throws -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let voiceInkDir = appSupport.appendingPathComponent(Constants.supportDirName)
        let dictDir = voiceInkDir.appendingPathComponent(Constants.dictionariesDir)
        
        try fileManager.createDirectory(at: dictDir, withIntermediateDirectories: true)
        return dictDir
    }
    
    private func dictFilename(for root: URL) -> URL? {
        // Create a safe filename from the root path
        let safePath = root.path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        
        return try? storeDirectory().appendingPathComponent("\(Constants.storeFilePrefix)\(safePath).json")
    }
    
    private func saveDictionary(_ dict: ProjectDictionary) throws {
        let data = try JSONEncoder().encode(dict)
        if let filename = dictFilename(for: URL(fileURLWithPath: dict.rootPath)) {
            try data.write(to: filename)
        }
    }
    
    private func loadDictionary(for root: URL) -> ProjectDictionary? {
        guard let filename = dictFilename(for: root),
              let data = try? Data(contentsOf: filename),
              let dict = try? JSONDecoder().decode(ProjectDictionary.self, from: data) else {
            return nil
        }
        
        // Check if TTL has expired
        if Date().timeIntervalSince(dict.updatedAt) > glossaryTTL {
            return nil
        }
        
        return dict
    }
    
    // MARK: - Helper Methods
    
    private func isProjectRoot(_ url: URL) -> Bool {
        let projectFiles = ["README.md", "package.json", "Cargo.toml", "pom.xml", "build.gradle", "Makefile", ".git", ".gitignore"]
        
        for file in projectFiles {
            if fileManager.fileExists(atPath: url.appendingPathComponent(file).path) {
                return true
            }
        }
        
        return false
    }
    
    private func findProjectRootInParentDirectories(startingFrom startURL: URL) -> URL? {
        var currentURL = startURL
        
        while currentURL.path != "/" {
            if isProjectRoot(currentURL) {
                return currentURL
            }
            
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return nil
    }

	// MARK: - Incremental Updates (optional)
	func startIncrementalWatchIfEnabled() {
		guard UserDefaults.standard.enableFSIncremental else { return }
		guard let root = detectActiveProjectRoot() else { return }
		stopIncrementalWatch()
		var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
		let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPathsPointer, eventFlags, eventIds) in
			guard let info = clientCallBackInfo else { return }
			let service = Unmanaged<FilesystemContextService>.fromOpaque(info).takeUnretainedValue()
			// Process events in a debounced batch
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
				let paths = unsafeBitCast(eventPathsPointer, to: NSArray.self) as? [String] ?? []
				service.handleFileEvents(paths: paths)
			}
		}
		let pathsToWatch = [root.path] as CFArray
		let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
		if let stream = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, pathsToWatch, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags) {
			fseventStream = stream
			FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
			FSEventStreamStart(stream)
		}
	}

	func stopIncrementalWatch() {
		if let stream = fseventStream {
			FSEventStreamStop(stream)
			FSEventStreamInvalidate(stream)
			FSEventStreamRelease(stream)
			fseventStream = nil
		}
	}
    // MARK: - Incremental event handling
    private func handleFileEvents(paths: [String]) {
        let now = Date()
        if now.timeIntervalSince(lastEventProcessAt) < 0.2 { return }
        lastEventProcessAt = now

        guard let root = detectActiveProjectRoot() else { return }
        let rootPath = root.path

        let unique = Array(Set(paths))
        for path in unique {
            let url = URL(fileURLWithPath: path)
            // Skip directories
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }

            // Handle deletes
            if !fileManager.fileExists(atPath: path) {
                let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
                if path.hasPrefix(prefix) {
                    let rel = String(path.dropFirst(prefix.count))
                    Task { @MainActor in
                        // TODO: Implement with new backend architecture
                        // try? ProjectFileIndexStore.shared.deletePath(rel, rootPath: root.path)
                    }
                }
                continue
            }

            Task { @MainActor in
                // TODO: Implement with new backend architecture
                // await ProjectFileIndexStore.shared.upsertFile(url, rootURL: root)
                if url.pathExtension.lowercased() == "md" {
                    await ContextIndexStore.shared.indexMarkdownFileIfNeeded(url: url, rootURL: root)
                }
            }
        }
    }
}
