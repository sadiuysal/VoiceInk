import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var projectDescription: String
    var rootPath: String?
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \ContextSource.project)
    var sources: [ContextSource] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ContextPack.project)
    var packs: [ContextPack] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        projectDescription: String = "",
        rootPath: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.rootPath = rootPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = isActive
    }
    
    func updateTimestamp() {
        updatedAt = Date()
    }
}

// MARK: - Computed Properties
extension Project {
    var sourceCount: Int {
        sources.count
    }
    
    var packCount: Int {
        packs.count
    }
    
    var activePacks: [ContextPack] {
        packs.filter { $0.isActive }
    }
    
    var lastSyncDate: Date? {
        sources.compactMap { $0.lastSyncAt }.max()
    }
}