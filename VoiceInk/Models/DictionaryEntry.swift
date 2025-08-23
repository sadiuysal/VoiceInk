import Foundation
import SwiftData

public enum EntryType: String, Codable, CaseIterable {
    case term = "term"
    case file = "file"
    case directory = "directory"
    case function = "function"
    case class_ = "class"
    case variable = "variable"
    case constant = "constant"
    case comment = "comment"
    
    var displayName: String {
        switch self {
        case .term:
            return "Term"
        case .file:
            return "File"
        case .directory:
            return "Directory"
        case .function:
            return "Function"
        case .class_:
            return "Class"
        case .variable:
            return "Variable"
        case .constant:
            return "Constant"
        case .comment:
            return "Comment"
        }
    }
    
    var icon: String {
        switch self {
        case .term:
            return "textformat"
        case .file:
            return "doc"
        case .directory:
            return "folder"
        case .function:
            return "function"
        case .class_:
            return "building.2"
        case .variable:
            return "v.circle"
        case .constant:
            return "c.circle"
        case .comment:
            return "text.bubble"
        }
    }
}

@Model
public final class DictionaryEntry {
    @Attribute(.unique) public var id: UUID
    public var term: String
    public var definition: String?
    public var aliases: [String] // Alternative names or synonyms
    public var entryType: EntryType
    public var frequency: Int // How often this term appears in source
    public var importance: Double // Calculated importance score (0.0 - 1.0)
    public var sourceFile: String? // File path where term was found
    public var lineNumber: Int? // Line number in source file
    public var context: String? // Surrounding text context
    public var tags: [String] // Metadata tags for categorization
    public var createdAt: Date
    public var updatedAt: Date
    
    @Relationship public var pack: ContextPack?
    
    public init(
        id: UUID = UUID(),
        term: String,
        definition: String? = nil,
        aliases: [String] = [],
        entryType: EntryType = .term,
        frequency: Int = 1,
        importance: Double = 0.5,
        sourceFile: String? = nil,
        lineNumber: Int? = nil,
        context: String? = nil,
        tags: [String] = [],
        pack: ContextPack? = nil
    ) {
        self.id = id
        self.term = term
        self.definition = definition
        self.aliases = aliases
        self.entryType = entryType
        self.frequency = frequency
        self.importance = importance
        self.sourceFile = sourceFile
        self.lineNumber = lineNumber
        self.context = context
        self.tags = tags
        self.pack = pack
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    public func updateTimestamp() {
        updatedAt = Date()
    }
    
    public func incrementFrequency() {
        frequency += 1
        updateTimestamp()
    }
    
    public func addAlias(_ alias: String) {
        if !aliases.contains(alias) {
            aliases.append(alias)
            updateTimestamp()
        }
    }
    
    public func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            updateTimestamp()
        }
    }
}

// MARK: - Computed Properties
extension DictionaryEntry {
    var allTerms: [String] {
        [term] + aliases
    }
    
    var displayContext: String {
        if let context = context {
            return context.count > 100 ? String(context.prefix(100)) + "..." : context
        }
        return ""
    }
    
    var sourceReference: String? {
        guard let sourceFile = sourceFile else { return nil }
        let fileName = URL(fileURLWithPath: sourceFile).lastPathComponent
        if let lineNumber = lineNumber {
            return "\(fileName):\(lineNumber)"
        }
        return fileName
    }
}

// MARK: - Search and Filtering
extension DictionaryEntry {
    func matches(searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return term.lowercased().contains(lowercaseSearch) ||
               aliases.contains { $0.lowercased().contains(lowercaseSearch) } ||
               definition?.lowercased().contains(lowercaseSearch) == true ||
               tags.contains { $0.lowercased().contains(lowercaseSearch) }
    }
    
    func hasTag(_ tag: String) -> Bool {
        tags.contains(tag)
    }
    
    func hasAnyTag(_ tags: [String]) -> Bool {
        !Set(self.tags).intersection(Set(tags)).isEmpty
    }
}