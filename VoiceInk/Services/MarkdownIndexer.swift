import Foundation
import CryptoKit
import os

final class MarkdownIndexer: Sendable {
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "MarkdownIndexer")
    
    // MARK: - Configuration
    private let maxFileSizeBytes = 1_000_000 // 1MB limit per file
    private let maxSegmentLines = 100 // Max lines per segment
    private let minSegmentLines = 1
    private let previewMaxChars = 200
    
    // MARK: - Public API
    
    func indexFile(at fileURL: URL, rootPath: String) async throws -> IndexedDocument? {
        let relPath = fileURL.path.replacingOccurrences(of: rootPath, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard fileURL.pathExtension.lowercased() == "md" else {
            logger.debug("Skipping non-markdown file: \(relPath)")
            return nil
        }
        
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= maxFileSizeBytes else {
            logger.warning("Skipping oversized file: \(relPath) (\(fileSize) bytes)")
            return nil
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let fileHash = calculateHash(content)
        
        let segments = parseMarkdownSegments(content: content, relPath: relPath, rootPath: rootPath)
        logger.debug("Parsed \(segments.count) segments from \(relPath)")
        
        let document = IndexedDocument(
            rootPath: rootPath,
            relPath: relPath,
            fileHash: fileHash,
            byteSize: fileSize,
            lastIndexedAt: Date()
        )
        
        return document
    }
    
    func createSegments(for document: IndexedDocument, content: String) -> [MarkdownSegment] {
        return parseMarkdownSegments(content: content, relPath: document.relPath, rootPath: document.rootPath)
            .map { draft in
                MarkdownSegment(
                    documentID: document.id,
                    anchor: draft.anchor,
                    kind: draft.kind,
                    lineStart: draft.lineStart,
                    lineEnd: draft.lineEnd,
                    hashPrefix: draft.hashPrefix,
                    tags: draft.tags,
                    preview: draft.preview,
                    score: draft.score,
                    sectionSlug: draft.sectionSlug,
                    content: draft.content
                )
            }
    }
    
    // MARK: - Private Implementation
    
    private func parseMarkdownSegments(content: String, relPath: String, rootPath: String) -> [MarkdownSegmentDraft] {
        let lines = content.components(separatedBy: .newlines)
        var segments: [MarkdownSegmentDraft] = []
        var currentSegment: MarkdownSegmentDraft?
        var currentSectionSlug: String?
        
        for (lineIndex, line) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Finalize current segment if we hit a new major element
            if let segment = currentSegment, shouldFinalizateSegment(currentLine: trimmed, currentSegment: segment) {
                if isHighQualitySegment(segment) {
                    segments.append(segment)
                }
                currentSegment = nil
            }
            
            // Start new segment based on line type
            if let newSegment = startNewSegment(line: trimmed, lineNumber: lineNumber, relPath: relPath, currentSectionSlug: currentSectionSlug) {
                currentSegment = newSegment
                
                // Update section slug for headings
                if newSegment.kind == .heading {
                    currentSectionSlug = extractSectionSlug(from: trimmed)
                }
            } else if var segment = currentSegment {
                // Extend current segment
                segment.content += "\n" + line
                segment.lineEnd = lineNumber
                currentSegment = segment
            }
        }
        
        // Finalize last segment
        if let segment = currentSegment, isHighQualitySegment(segment) {
            segments.append(segment)
        }
        
        return segments.map { finalize($0, relPath: relPath, rootPath: rootPath) }
    }
    
    private func startNewSegment(line: String, lineNumber: Int, relPath: String, currentSectionSlug: String?) -> MarkdownSegmentDraft? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Heading
        if trimmed.hasPrefix("#") {
            let level = trimmed.prefix(while: { $0 == "#" }).count
            let text = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
            let slug = extractSectionSlug(from: text)
            
            return MarkdownSegmentDraft(
                kind: .heading,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: slug,
                anchor: "", // Will be set in finalize
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        // Code block
        if trimmed.hasPrefix("```") {
            return MarkdownSegmentDraft(
                kind: .code,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: currentSectionSlug,
                anchor: "",
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        // List item
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("+") || trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
            return MarkdownSegmentDraft(
                kind: .list,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: currentSectionSlug,
                anchor: "",
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        // Quote
        if trimmed.hasPrefix(">") {
            return MarkdownSegmentDraft(
                kind: .quote,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: currentSectionSlug,
                anchor: "",
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        // Table (simple detection)
        if trimmed.contains("|") && trimmed.count > 3 {
            return MarkdownSegmentDraft(
                kind: .table,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: currentSectionSlug,
                anchor: "",
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        // Emphasis (lines with ** or __)
        if (trimmed.contains("**") || trimmed.contains("__")) && !trimmed.isEmpty {
            return MarkdownSegmentDraft(
                kind: .emphasis,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: currentSectionSlug,
                anchor: "",
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        // Regular paragraph (non-empty lines that don't match above)
        if !trimmed.isEmpty && !isMarkdownSyntaxLine(trimmed) {
            return MarkdownSegmentDraft(
                kind: .paragraph,
                lineStart: lineNumber,
                lineEnd: lineNumber,
                content: line,
                sectionSlug: currentSectionSlug,
                anchor: "",
                hashPrefix: "",
                tags: [],
                preview: "",
                score: 0
            )
        }
        
        return nil
    }
    
    private func shouldFinalizateSegment(currentLine: String, currentSegment: MarkdownSegmentDraft) -> Bool {
        let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
        
        // Always finalize on empty lines if segment has content
        if trimmed.isEmpty && !currentSegment.content.isEmpty {
            return true
        }
        
        // Finalize code blocks on closing ```
        if currentSegment.kind == .code && trimmed == "```" {
            return true
        }
        
        // Finalize on new headings
        if trimmed.hasPrefix("#") {
            return true
        }
        
        // Finalize if segment is getting too long
        if currentSegment.lineEnd - currentSegment.lineStart >= maxSegmentLines {
            return true
        }
        
        return false
    }
    
    private func isHighQualitySegment(_ segment: MarkdownSegmentDraft) -> Bool {
        let content = segment.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have meaningful content
        if content.count < 10 { return false }
        
        // Must span reasonable lines
        let lineSpan = segment.lineEnd - segment.lineStart + 1
        if lineSpan < minSegmentLines { return false }
        
        // Headings are always valuable
        if segment.kind == .heading { return true }
        
        // Code blocks are valuable if they have real content
        if segment.kind == .code && content.count > 20 { return true }
        
        // Other segments need meaningful text
        let meaningfulWords = extractMeaningfulWords(from: content)
        return meaningfulWords.count >= 3
    }
    
    private func finalize(_ draft: MarkdownSegmentDraft, relPath: String, rootPath: String) -> MarkdownSegmentDraft {
        let contentHash = calculateHash(draft.content)
        let hashPrefix = String(contentHash.prefix(4))
        
        let anchor = makeAnchor(
            relPath: relPath,
            sectionSlug: draft.sectionSlug,
            lineStart: draft.lineStart,
            lineEnd: draft.lineEnd,
            hashPrefix: hashPrefix
        )
        
        let tags = generateTags(for: draft, relPath: relPath, rootPath: rootPath)
        let preview = generatePreview(from: draft.content)
        let score = calculateScore(for: draft, tags: tags, relPath: relPath)
        
        return MarkdownSegmentDraft(
            kind: draft.kind,
            lineStart: draft.lineStart,
            lineEnd: draft.lineEnd,
            content: draft.content,
            sectionSlug: draft.sectionSlug,
            anchor: anchor,
            hashPrefix: hashPrefix,
            tags: tags,
            preview: preview,
            score: score
        )
    }
    
    private func generateTags(for segment: MarkdownSegmentDraft, relPath: String, rootPath: String) -> [String] {
        var tags: [String] = []
        
        // Source tags
        tags.append("markdown-file:\(relPath)")
        let lastDir = URL(fileURLWithPath: relPath).deletingLastPathComponent().lastPathComponent
        if lastDir != "." && !lastDir.isEmpty {
            tags.append("directory:\(lastDir)")
        }
        
        // Location tags
        tags.append("lines:L\(segment.lineStart)-L\(segment.lineEnd)")
        if let slug = segment.sectionSlug {
            tags.append("section:\(slug)")
        }
        
        // Kind tags
        tags.append("kind:\(segment.kind.rawValue)")
        
        // Semantic tags from content
        let content = segment.content
        
        // File references
        if content.contains(".swift") { tags.append("file-ref:swift") }
        if content.contains(".md") { tags.append("file-ref:markdown") }
        if content.contains(".json") { tags.append("file-ref:config") }
        if content.contains(".yml") || content.contains(".yaml") { tags.append("file-ref:config") }
        
        // Technical terms
        if content.range(of: "[A-Z][a-z]+(?:[A-Z][a-z]+)+", options: .regularExpression) != nil {
            tags.append("term:CamelCase")
        }
        if content.contains("-") && content.range(of: "[a-z]+-[a-z]+", options: .regularExpression) != nil {
            tags.append("term:kebab-case")
        }
        if content.contains("_") && content.range(of: "[a-z]+_[a-z]+", options: .regularExpression) != nil {
            tags.append("term:snake_case")
        }
        
        // Special file recognition
        if relPath.uppercased().contains("README") {
            tags.append("prio:high")
            tags.append("doc:readme")
        }
        if relPath.uppercased().contains("CLAUDE") {
            tags.append("prio:high")
            tags.append("doc:claude")
        }
        
        return tags.sorted()
    }
    
    private func calculateScore(for segment: MarkdownSegmentDraft, tags: [String], relPath: String) -> Int {
        var score = segment.kind.baseScore
        
        // Boost for high-priority files
        if tags.contains("prio:high") {
            score += 5
        }
        
        // Boost for technical content
        if tags.contains(where: { $0.hasPrefix("term:") }) {
            score += 2
        }
        
        // Boost for file references
        if tags.contains(where: { $0.hasPrefix("file-ref:") }) {
            score += 1
        }
        
        // Boost for headings
        if segment.kind == .heading {
            score += 3
        }
        
        // Content length bonus (reasonable segments)
        let contentLength = segment.content.count
        if contentLength > 100 && contentLength < 1000 {
            score += 1
        }
        
        return max(1, score)
    }
    
    // MARK: - Utility Functions
    
    private func calculateHash(_ content: String) -> String {
        let data = content.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func makeAnchor(relPath: String, sectionSlug: String?, lineStart: Int, lineEnd: Int, hashPrefix: String) -> String {
        let slug = sectionSlug ?? "root"
        return "md:\(relPath)#\(slug):L\(lineStart)-\(lineEnd):\(hashPrefix)"
    }
    
    private func extractSectionSlug(from text: String) -> String {
        let cleanText = text.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
        let slug = cleanText
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        return slug.isEmpty ? "section" : slug
    }
    
    private func generatePreview(from content: String) -> String {
        let cleanContent = content
            .replacingOccurrences(of: "#+\\s*", with: "", options: .regularExpression) // Remove heading markers
            .replacingOccurrences(of: "```[\\w]*\\n?", with: "", options: .regularExpression) // Remove code fences
            .replacingOccurrences(of: "\\*+", with: "", options: .regularExpression) // Remove emphasis
            .replacingOccurrences(of: "^>\\s*", with: "", options: .regularExpression) // Remove quote markers
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanContent.count <= previewMaxChars {
            return cleanContent
        }
        
        let truncated = String(cleanContent.prefix(previewMaxChars))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        return truncated + "..."
    }
    
    private func extractMeaningfulWords(from content: String) -> [String] {
        let words = content
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
        
        return words
    }
    
    private func isMarkdownSyntaxLine(_ line: String) -> Bool {
        let syntaxPatterns = [
            "^\\s*\\|", // Table separator
            "^\\s*---+\\s*$", // Horizontal rule
            "^\\s*\\*\\*\\*+\\s*$", // Horizontal rule
            "^\\s*___+\\s*$" // Horizontal rule
        ]
        
        return syntaxPatterns.contains { pattern in
            line.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

// MARK: - Supporting Types

struct MarkdownSegmentDraft {
    let kind: SegmentKind
    let lineStart: Int
    var lineEnd: Int
    var content: String
    let sectionSlug: String?
    let anchor: String
    let hashPrefix: String
    let tags: [String]
    let preview: String
    let score: Int
}
