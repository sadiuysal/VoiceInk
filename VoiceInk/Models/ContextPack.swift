import Foundation
import SwiftData

@Model
final class ContextPack {
    @Attribute(.unique) var id: UUID
    var name: String
    var packDescription: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var sourceIds: [UUID] // References to ContextSource IDs
    var filterConfiguration: Data // JSON encoded filter settings
    var termCount: Int // Cached count of dictionary entries
    
    @Relationship var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \DictionaryEntry.pack)
    var entries: [DictionaryEntry] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        packDescription: String = "",
        project: Project? = nil,
        sourceIds: [UUID] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.packDescription = packDescription
        self.project = project
        self.sourceIds = sourceIds
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.filterConfiguration = Data()
        self.termCount = 0
    }
    
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    func updateTermCount() {
        termCount = entries.count
    }
    
    func addSourceId(_ sourceId: UUID) {
        if !sourceIds.contains(sourceId) {
            sourceIds.append(sourceId)
            updateTimestamp()
        }
    }
    
    func removeSourceId(_ sourceId: UUID) {
        sourceIds.removeAll { $0 == sourceId }
        updateTimestamp()
    }
}

// MARK: - Filter Configuration
struct PackFilterConfiguration: Codable {
    let includeFileTypes: [String]
    let excludeFileTypes: [String]
    let minTermLength: Int
    let maxTermLength: Int
    let minFrequency: Int
    let includeCodeBlocks: Bool
    let includeComments: Bool
    let termLimit: Int?
    
    init(
        includeFileTypes: [String] = [],
        excludeFileTypes: [String] = [],
        minTermLength: Int = 2,
        maxTermLength: Int = 50,
        minFrequency: Int = 1,
        includeCodeBlocks: Bool = true,
        includeComments: Bool = false,
        termLimit: Int? = nil
    ) {
        self.includeFileTypes = includeFileTypes
        self.excludeFileTypes = excludeFileTypes
        self.minTermLength = minTermLength
        self.maxTermLength = maxTermLength
        self.minFrequency = minFrequency
        self.includeCodeBlocks = includeCodeBlocks
        self.includeComments = includeComments
        self.termLimit = termLimit
    }
}

// MARK: - Configuration Helpers
extension ContextPack {
    func getFilterConfiguration() -> PackFilterConfiguration {
        (try? JSONDecoder().decode(PackFilterConfiguration.self, from: filterConfiguration)) 
        ?? PackFilterConfiguration()
    }
    
    func setFilterConfiguration(_ config: PackFilterConfiguration) throws {
        self.filterConfiguration = try JSONEncoder().encode(config)
        updateTimestamp()
    }
}