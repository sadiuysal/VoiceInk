import XCTest
import SwiftData
@testable import VoiceInk

final class ProjectModelTests: XCTestCase {
    
    func testProjectInitialization() {
        let project = Project(name: "Test Project", projectDescription: "A test project")
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertEqual(project.projectDescription, "A test project")
        XCTAssertTrue(project.isActive)
        XCTAssertEqual(project.sources.count, 0)
        XCTAssertEqual(project.packs.count, 0)
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
    }
    
    func testProjectComputedProperties() {
        let project = Project(name: "Test Project")
        
        XCTAssertEqual(project.sourceCount, 0)
        XCTAssertEqual(project.packCount, 0)
        XCTAssertEqual(project.activePacks.count, 0)
        XCTAssertNil(project.lastSyncDate)
    }
    
    func testProjectUpdateTimestamp() {
        let project = Project(name: "Test Project")
        let originalTimestamp = project.updatedAt
        
        // Wait a small amount to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)
        
        project.updateTimestamp()
        
        XCTAssertGreaterThan(project.updatedAt, originalTimestamp)
    }
}

final class ContextSourceModelTests: XCTestCase {
    
    func testContextSourceInitialization() {
        let source = ContextSource(
            name: "Test Repository",
            type: .gitIngest
        )
        
        XCTAssertEqual(source.name, "Test Repository")
        XCTAssertEqual(source.type, .gitIngest)
        XCTAssertTrue(source.isEnabled)
        XCTAssertEqual(source.syncStatus, "idle")
        XCTAssertNil(source.errorMessage)
        XCTAssertNil(source.lastSyncAt)
        XCTAssertNotNil(source.id)
        XCTAssertNotNil(source.createdAt)
    }
    
    func testContextSourceSyncStatusUpdate() {
        let source = ContextSource(name: "Test", type: .gitIngest)
        
        source.updateSyncStatus("syncing")
        XCTAssertEqual(source.syncStatus, "syncing")
        XCTAssertNil(source.lastSyncAt)
        
        source.updateSyncStatus("completed")
        XCTAssertEqual(source.syncStatus, "completed")
        XCTAssertNotNil(source.lastSyncAt)
        
        source.updateSyncStatus("error", errorMessage: "Test error")
        XCTAssertEqual(source.syncStatus, "error")
        XCTAssertEqual(source.errorMessage, "Test error")
    }
    
    func testGitIngestConfiguration() throws {
        let config = GitIngestConfiguration(
            repositoryPath: "/path/to/repo",
            preset: .docs,
            maxFileSize: 2_000_000
        )
        
        let source = ContextSource(name: "Test", type: .gitIngest)
        try source.setConfiguration(config)
        
        let retrievedConfig: GitIngestConfiguration? = source.getConfiguration(GitIngestConfiguration.self)
        XCTAssertNotNil(retrievedConfig)
        XCTAssertEqual(retrievedConfig?.repositoryPath, "/path/to/repo")
        XCTAssertEqual(retrievedConfig?.preset, .docs)
        XCTAssertEqual(retrievedConfig?.maxFileSize, 2_000_000)
    }
    
    func testGitIngestPresetPatterns() {
        let docsPreset = GitIngestPreset.docs
        XCTAssertTrue(docsPreset.defaultIncludePatterns.contains("*.md"))
        XCTAssertTrue(docsPreset.defaultExcludePatterns.contains("node_modules/**/*"))
        
        let codePreset = GitIngestPreset.code
        XCTAssertTrue(codePreset.defaultIncludePatterns.contains("*.swift"))
        XCTAssertTrue(codePreset.defaultExcludePatterns.contains("*.md"))
    }
}

final class ContextPackModelTests: XCTestCase {
    
    func testContextPackInitialization() {
        let pack = ContextPack(name: "Test Pack", packDescription: "A test pack")
        
        XCTAssertEqual(pack.name, "Test Pack")
        XCTAssertEqual(pack.packDescription, "A test pack")
        XCTAssertTrue(pack.isActive)
        XCTAssertEqual(pack.sourceIds.count, 0)
        XCTAssertEqual(pack.termCount, 0)
        XCTAssertNotNil(pack.id)
        XCTAssertNotNil(pack.createdAt)
        XCTAssertNotNil(pack.updatedAt)
    }
    
    func testContextPackSourceManagement() {
        let pack = ContextPack(name: "Test Pack")
        let sourceId1 = UUID()
        let sourceId2 = UUID()
        
        pack.addSourceId(sourceId1)
        XCTAssertEqual(pack.sourceIds.count, 1)
        XCTAssertTrue(pack.sourceIds.contains(sourceId1))
        
        // Adding same ID should not duplicate
        pack.addSourceId(sourceId1)
        XCTAssertEqual(pack.sourceIds.count, 1)
        
        pack.addSourceId(sourceId2)
        XCTAssertEqual(pack.sourceIds.count, 2)
        
        pack.removeSourceId(sourceId1)
        XCTAssertEqual(pack.sourceIds.count, 1)
        XCTAssertFalse(pack.sourceIds.contains(sourceId1))
        XCTAssertTrue(pack.sourceIds.contains(sourceId2))
    }
    
    func testPackFilterConfiguration() throws {
        let pack = ContextPack(name: "Test Pack")
        let filterConfig = PackFilterConfiguration(
            includeFileTypes: ["swift", "md"],
            minTermLength: 3,
            maxTermLength: 30,
            termLimit: 100
        )
        
        try pack.setFilterConfiguration(filterConfig)
        
        let retrievedConfig = pack.getFilterConfiguration()
        XCTAssertEqual(retrievedConfig.includeFileTypes, ["swift", "md"])
        XCTAssertEqual(retrievedConfig.minTermLength, 3)
        XCTAssertEqual(retrievedConfig.maxTermLength, 30)
        XCTAssertEqual(retrievedConfig.termLimit, 100)
    }
}

final class DictionaryEntryModelTests: XCTestCase {
    
    func testDictionaryEntryInitialization() {
        let entry = DictionaryEntry(
            term: "testTerm",
            definition: "A test definition",
            entryType: .function,
            frequency: 5
        )
        
        XCTAssertEqual(entry.term, "testTerm")
        XCTAssertEqual(entry.definition, "A test definition")
        XCTAssertEqual(entry.entryType, .function)
        XCTAssertEqual(entry.frequency, 5)
        XCTAssertEqual(entry.aliases.count, 0)
        XCTAssertEqual(entry.tags.count, 0)
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertNotNil(entry.updatedAt)
    }
    
    func testDictionaryEntryAliasManagement() {
        let entry = DictionaryEntry(term: "testTerm")
        
        entry.addAlias("alias1")
        XCTAssertEqual(entry.aliases.count, 1)
        XCTAssertTrue(entry.aliases.contains("alias1"))
        
        // Adding same alias should not duplicate
        entry.addAlias("alias1")
        XCTAssertEqual(entry.aliases.count, 1)
        
        entry.addAlias("alias2")
        XCTAssertEqual(entry.aliases.count, 2)
        
        let allTerms = entry.allTerms
        XCTAssertEqual(allTerms.count, 3)
        XCTAssertTrue(allTerms.contains("testTerm"))
        XCTAssertTrue(allTerms.contains("alias1"))
        XCTAssertTrue(allTerms.contains("alias2"))
    }
    
    func testDictionaryEntryTagManagement() {
        let entry = DictionaryEntry(term: "testTerm")
        
        entry.addTag("tag1")
        XCTAssertEqual(entry.tags.count, 1)
        XCTAssertTrue(entry.hasTag("tag1"))
        
        entry.addTag("tag2")
        XCTAssertEqual(entry.tags.count, 2)
        XCTAssertTrue(entry.hasAnyTag(["tag1", "tag3"]))
        XCTAssertFalse(entry.hasAnyTag(["tag3", "tag4"]))
    }
    
    func testDictionaryEntrySearch() {
        let entry = DictionaryEntry(
            term: "TestFunction",
            definition: "A function for testing",
            aliases: ["testFunc", "tester"]
        )
        entry.addTag("swift")
        
        XCTAssertTrue(entry.matches(searchText: "test"))
        XCTAssertTrue(entry.matches(searchText: "function"))
        XCTAssertTrue(entry.matches(searchText: "func"))
        XCTAssertTrue(entry.matches(searchText: "swift"))
        XCTAssertFalse(entry.matches(searchText: "python"))
    }
    
    func testFrequencyIncrement() {
        let entry = DictionaryEntry(term: "testTerm", frequency: 1)
        let originalTimestamp = entry.updatedAt
        
        Thread.sleep(forTimeInterval: 0.01)
        
        entry.incrementFrequency()
        
        XCTAssertEqual(entry.frequency, 2)
        XCTAssertGreaterThan(entry.updatedAt, originalTimestamp)
    }
}