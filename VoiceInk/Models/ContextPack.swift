import Foundation
import SwiftData

@Model
public final class ContextPack {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var packDescription: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var sourceIds: [UUID] // References to ContextSource IDs
    public var filterConfiguration: Data // JSON encoded filter settings
    public var termCount: Int // Cached count of dictionary entries
    public var lastSyncDate: Date? // Last synchronization with sources
    
    @Relationship public var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \DictionaryEntry.pack)
    public var entries: [DictionaryEntry] = []
    
    public init(
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
        self.lastSyncDate = nil
    }
    
    public func updateTimestamp() {
        updatedAt = Date()
    }
    
    public func updateTermCount() {
        termCount = entries.count
    }
    
    public func updateSyncDate() {
        lastSyncDate = Date()
        updateTimestamp()
    }
    
    public func addSourceId(_ sourceId: UUID) {
        if !sourceIds.contains(sourceId) {
            sourceIds.append(sourceId)
            updateTimestamp()
        }
    }
    
    public func removeSourceId(_ sourceId: UUID) {
        sourceIds.removeAll { $0 == sourceId }
        updateTimestamp()
    }
}

// MARK: - Filter Configuration
public struct PackFilterConfiguration: Codable {
    public var includeFileTypes: [String]
    public var excludeFileTypes: [String]
    public var minTermLength: Int
    public var maxTermLength: Int
    public var minFrequency: Int
    public var includeCodeBlocks: Bool
    public var includeComments: Bool
    public var termLimit: Int?
    
    public init(
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