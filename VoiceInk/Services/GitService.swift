import Foundation
import os

@MainActor
final class GitService: ObservableObject {
    static let shared = GitService()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "GitService")
    
    private init() {}
    
    // MARK: - Repository Detection
    
    /// Detects if a directory is a Git repository and extracts metadata
    func detectRepository(at path: String) async throws -> RepositoryInfo {
        guard isGitRepository(at: path) else {
            logger.debug("Directory is not a Git repository: \(path)")
            throw GitError.notAGitRepository
        }
        
        do {
            let projectName = extractProjectName(from: path)
            let currentBranch = try getCurrentBranch(at: path)
            let remoteOrigin = try getRemoteOrigin(at: path)
            let lastCommit = try getLastCommit(at: path)
            let projectDescription = try extractProjectDescription(at: path)
            
            return RepositoryInfo(
                path: path,
                projectName: projectName,
                currentBranch: currentBranch,
                remoteOrigin: remoteOrigin,
                lastCommit: lastCommit,
                projectDescription: projectDescription,
                isGitRepository: true
            )
        } catch {
            logger.error("Failed to detect repository info: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Checks if a directory is a Git repository
    private func isGitRepository(at path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }
    
    /// Extracts project name from repository path
    private func extractProjectName(from path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    /// Gets the current branch name
    private func getCurrentBranch(at path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        let output = try process.runAndWait()
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle detached HEAD state
        if branch == "HEAD" {
            return "detached"
        }
        
        return branch
    }
    
    /// Gets the remote origin URL
    private func getRemoteOrigin(at path: String) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "--get", "remote.origin.url"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        do {
            let output = try process.runAndWait()
            let remote = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return remote.isEmpty ? nil : remote
        } catch {
            // Remote origin might not be configured
            return nil
        }
    }
    
    /// Gets the last commit information
    private func getLastCommit(at path: String) throws -> CommitInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "-1", "--pretty=format:%H|%an|%ae|%s|%ci"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        let output = try process.runAndWait()
        let components = output.components(separatedBy: "|")
        
        guard components.count >= 5 else {
            throw GitError.invalidCommitFormat
        }
        
        return CommitInfo(
            hash: components[0],
            author: components[1],
            email: components[2],
            message: components[3],
            date: components[4]
        )
    }
    
    /// Extracts project description from README or similar files
    private func extractProjectDescription(at path: String) throws -> String {
        let readmeFiles = ["README.md", "README.txt", "README", "readme.md", "readme.txt"]
        
        for filename in readmeFiles {
            let readmePath = (path as NSString).appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: readmePath) {
                let content = try String(contentsOfFile: readmePath, encoding: .utf8)
                return extractFirstParagraph(from: content)
            }
        }
        
        return ""
    }
    
    /// Extracts the first meaningful paragraph from README content
    private func extractFirstParagraph(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var paragraph: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines, headers, and metadata
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("---") {
                if !paragraph.isEmpty {
                    break
                }
                continue
            }
            
            // Stop at the first header after content
            if trimmed.hasPrefix("#") && !paragraph.isEmpty {
                break
            }
            
            paragraph.append(trimmed)
        }
        
        let description = paragraph.joined(separator: " ")
        return description.isEmpty ? "No description available" : description
    }
}

// MARK: - Supporting Types

public struct RepositoryInfo {
    public let path: String
    public let projectName: String
    public let currentBranch: String
    public let remoteOrigin: String?
    public let lastCommit: CommitInfo
    public let projectDescription: String
    public let isGitRepository: Bool
    
    public var displayName: String {
        if let remote = remoteOrigin, let repoName = extractRepoNameFromRemote(remote) {
            return repoName
        }
        return projectName
    }
    
    private func extractRepoNameFromRemote(_ remote: String) -> String? {
        // Handle different remote URL formats
        if remote.hasSuffix(".git") {
            let withoutGit = String(remote.dropLast(4))
            return URL(string: withoutGit)?.lastPathComponent
        }
        
        return URL(string: remote)?.lastPathComponent
    }
}

public struct CommitInfo {
    public let hash: String
    public let author: String
    public let email: String
    public let message: String
    public let date: String
    
    public var shortHash: String {
        String(hash.prefix(8))
    }
    
    public var formattedDate: String {
        // Convert ISO date to readable format
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return date
    }
}

enum GitError: Error, LocalizedError {
    case invalidCommitFormat
    case gitCommandFailed(String)
    case notAGitRepository
    
    var errorDescription: String? {
        switch self {
        case .invalidCommitFormat:
            return "Invalid commit format"
        case .gitCommandFailed(let command):
            return "Git command failed: \(command)"
        case .notAGitRepository:
            return "The specified path is not a Git repository."
        }
    }
}

// MARK: - Process Extension

extension Process {
    func runAndWait() throws -> String {
        let pipe = Pipe()
        standardOutput = pipe
        standardError = pipe
        
        try run()
        waitUntilExit()
        
        guard terminationStatus == 0 else {
            throw GitError.gitCommandFailed("Process exited with status \(terminationStatus)")
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
