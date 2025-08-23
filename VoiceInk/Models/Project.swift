import Foundation
import SwiftData

@Model
public final class Project {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var projectDescription: String
    public var rootPath: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var isActive: Bool
    public var configuration: Data? // JSON-encoded project configuration
    
    // Git repository information
    public var currentBranch: String?
    public var remoteOrigin: String?
    public var lastCommitHash: String?
    public var lastCommitAuthor: String?
    public var lastCommitMessage: String?
    public var lastCommitDate: String?
    
    @Relationship(deleteRule: .cascade, inverse: \ContextSource.project)
    public var sources: [ContextSource] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ContextPack.project)
    public var packs: [ContextPack] = []
    
    public init(
        id: UUID = UUID(),
        name: String,
        projectDescription: String = "",
        rootPath: String? = nil,
        isActive: Bool = true,
        configuration: Data? = nil,
        currentBranch: String? = nil,
        remoteOrigin: String? = nil,
        lastCommitHash: String? = nil,
        lastCommitAuthor: String? = nil,
        lastCommitMessage: String? = nil,
        lastCommitDate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.rootPath = rootPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = isActive
        self.configuration = configuration
        self.currentBranch = currentBranch
        self.remoteOrigin = remoteOrigin
        self.lastCommitHash = lastCommitHash
        self.lastCommitAuthor = lastCommitAuthor
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitDate = lastCommitDate
    }
    
    public func updateTimestamp() {
        updatedAt = Date()
    }
    
    public func updateGitInfo(from repositoryInfo: RepositoryInfo) {
        self.currentBranch = repositoryInfo.currentBranch
        self.remoteOrigin = repositoryInfo.remoteOrigin
        self.lastCommitHash = repositoryInfo.lastCommit.hash
        self.lastCommitAuthor = repositoryInfo.lastCommit.author
        self.lastCommitMessage = repositoryInfo.lastCommit.message
        self.lastCommitDate = repositoryInfo.lastCommit.formattedDate
        
        updateTimestamp()
    }
}

// MARK: - Computed Properties
extension Project {
    public var sourceCount: Int {
        sources.count
    }
    
    public var packCount: Int {
        packs.count
    }
    
    public var activePacks: [ContextPack] {
        packs.filter { $0.isActive }
    }
    
    public var lastSyncDate: Date? {
        sources.compactMap { $0.lastSyncAt }.max()
    }
}