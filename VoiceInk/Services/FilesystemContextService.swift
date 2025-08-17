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
    
    /// Refresh the glossary if TTL has expired
    func refreshIfNeeded() {
        Task {
            do {
                if let root = detectActiveProjectRoot() {
                    try await buildAndStoreGlossary(for: root)
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
                return url
            }
        }
        
        // Priority 2: Shell helper file (~/.voiceink/cwd)
        if let cwdPath = (Constants.cwdHelperPath as NSString).expandingTildeInPath,
           fileManager.fileExists(atPath: cwdPath),
           let cwdContent = try? String(contentsOfFile: cwdPath),
           !cwdContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: cwdContent.trimmingCharacters(in: .whitespacesAndNewlines))
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        
        // Priority 3: Current working directory (fallback)
        let currentDir = fileManager.currentDirectoryPath
        let url = URL(fileURLWithPath: currentDir)
        
        // Check if this looks like a project root (has common project files)
        if isProjectRoot(url) {
            return url
        }
        
        // Try to find project root by walking up the directory tree
        return findProjectRootInParentDirectories(startingFrom: url)
    }
    
    // MARK: - Build
    
    private func buildAndStoreGlossary(for root: URL) async throws {
        let terms = try buildGlossary(for: root)
        let dict = ProjectDictionary(
            rootPath: root.path,
            updatedAt: Date(),
            terms: terms
        )
        try saveDictionary(dict)
        logger.info("Built glossary with \(terms.count) terms for \(root.lastPathComponent)")
    }
    
    private func buildGlossary(for root: URL) throws -> [String] {
        var termScores: [String: Int] = [:]
        
        // Scan for project files
        let allowedExtensions = ["md", "txt", "json", "yaml", "yml", "toml", "lock", "gradle", "pom", "cargo", "package"]
        let allowedFilenames = ["README", "CLAUDE", "CHANGELOG", "LICENSE", "CONTRIBUTING", "BUILDING", "Makefile", "Dockerfile"]
        
        // Scan top-level files and directories
        let contents = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        
        for item in contents {
            let filename = item.lastPathComponent
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            // Score directory names (project structure)
            if isDirectory {
                let cleanName = filename.replacingOccurrences(of: ".", with: " ")
                let terms = tokenize(cleanName)
                for term in terms {
                    bump(&termScores, term, by: 3) // Directories get higher weight
                }
            }
            
            // Score filenames
            if allowedFilenames.contains { filename.uppercased().contains($0.uppercased()) } {
                let cleanName = filename.replacingOccurrences(of: ".", with: " ")
                let terms = tokenize(cleanName)
                for term in terms {
                    bump(&termScores, term, by: 2)
                }
            }
            
            // Score content of markdown and text files
            if allowedExtensions.contains(item.pathExtension.lowercased()) {
                if let content = try? String(contentsOf: item) {
                    extractTerms(fromMarkdown: content, into: &termScores)
                }
            }
        }
        
        // Convert to sorted array
        let sortedTerms = termScores.sorted { $0.value > $1.value }.map { $0.key }
        return Array(sortedTerms.prefix(100)) // Limit to top 100 terms
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
            if normalized.count >= 3 && normalized.count <= 20 { // Reasonable term length
                terms.append(normalized)
            }
            return true
        }
        
        return terms
    }
    
    private func normalize(_ s: String) -> String {
        return s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
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
}
