import Foundation
import SwiftData

@Model
final class IndexedDocument {
    @Attribute(.unique) var id: UUID
    var rootPath: String
    var relPath: String
    var fileHash: String
    var byteSize: Int
    var lastIndexedAt: Date
    
    @Relationship(deleteRule: .cascade)
    var segments: [MarkdownSegment] = []
    
    init(id: UUID = UUID(), rootPath: String, relPath: String, fileHash: String, byteSize: Int, lastIndexedAt: Date = Date()) {
        self.id = id
        self.rootPath = rootPath
        self.relPath = relPath
        self.fileHash = fileHash
        self.byteSize = byteSize
        self.lastIndexedAt = lastIndexedAt
    }
}

@Model
final class MarkdownSegment {
    @Attribute(.unique) var id: UUID
    var documentID: UUID
    var anchor: String
    var kind: SegmentKind
    var lineStart: Int
    var lineEnd: Int
    var hashPrefix: String
    var tags: [String]
    var preview: String
    var score: Int
    var sectionSlug: String?
    var content: String
    
    init(id: UUID = UUID(), documentID: UUID, anchor: String, kind: SegmentKind, lineStart: Int, lineEnd: Int, hashPrefix: String, tags: [String], preview: String, score: Int, sectionSlug: String? = nil, content: String) {
        self.id = id
        self.documentID = documentID
        self.anchor = anchor
        self.kind = kind
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.hashPrefix = hashPrefix
        self.tags = tags
        self.preview = preview
        self.score = score
        self.sectionSlug = sectionSlug
        self.content = content
    }
}

enum SegmentKind: String, Codable, CaseIterable {
    case heading = "heading"
    case paragraph = "paragraph"
    case code = "code"
    case list = "list"
    case quote = "quote"
    case table = "table"
    case emphasis = "emphasis"
    
    var displayName: String {
        switch self {
        case .heading: return "Heading"
        case .paragraph: return "Paragraph"
        case .code: return "Code Block"
        case .list: return "List"
        case .quote: return "Quote"
        case .table: return "Table"
        case .emphasis: return "Emphasis"
        }
    }
    
    var baseScore: Int {
        switch self {
        case .heading: return 5
        case .code: return 4
        case .emphasis: return 3
        case .list: return 2
        case .quote: return 2
        case .table: return 2
        case .paragraph: return 1
        }
    }
}

@Model
final class DictionaryProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var projectRoot: String
    var profileDescription: String
    var pinnedSegmentIDs: [UUID]
    var customTerms: [String]
    var createdAt: Date
    var lastModifiedAt: Date
    var maxContextBytes: Int
    
    init(id: UUID = UUID(), name: String, projectRoot: String, profileDescription: String = "", pinnedSegmentIDs: [UUID] = [], customTerms: [String] = [], createdAt: Date = Date(), lastModifiedAt: Date = Date(), maxContextBytes: Int = 8000) {
        self.id = id
        self.name = name
        self.projectRoot = projectRoot
        self.profileDescription = profileDescription
        self.pinnedSegmentIDs = pinnedSegmentIDs
        self.customTerms = customTerms
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.maxContextBytes = maxContextBytes
    }
}
