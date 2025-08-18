# Build GitIngest and Manual Notes Source Providers

## Summary
Provide services to ingest content from Git repositories and local markdown notes as context sources. Use the GitIngest library with multiple presets (docs-only, code-only, mixed) and ensure that ingestion runs offline.

## Problem Statement
The current VoiceInk system has GitIngestService but needs to be extended to support:
- Multiple ingestion presets for different content types
- Manual notes as a context source
- Integration with the new Project/ContextPack data model
- Artifact standardization for different source types

## Tasks
- [ ] Extend `GitIngestService` to support preset configurations
  - [ ] Add `GitIngestPreset` enum (docs, code, mixed, custom)
  - [ ] Implement preset-specific include/exclude patterns
  - [ ] Add repository URL/path validation
  - [ ] Support branch and submodule options
- [ ] Create `ManualNotesSourceProvider` service
  - [ ] File-based markdown note storage in app data directory
  - [ ] CRUD operations for note management
  - [ ] Note content parsing and artifact extraction
- [ ] Define `SourceProviderProtocol` for unified interface
  - [ ] Common methods: `ingest()`, `validate()`, `getArtifacts()`
  - [ ] Error handling and progress reporting
- [ ] Create standardized `Artifact` struct
  - [ ] Fields: path, mimeType, content, metadata, checksum
  - [ ] Support for text content and binary references
- [ ] Implement offline-first architecture
  - [ ] No network calls during ingestion
  - [ ] Local file processing only
  - [ ] Privacy-respecting operation

## Acceptance Criteria
- [ ] Given a sample repository, GitIngest provider returns artifacts matching preset rules
- [ ] Manual notes can be created, edited, and ingested as artifacts
- [ ] No network calls are made during ingestion process
- [ ] Unit tests validate file inclusion/exclusion logic for all presets
- [ ] Providers integrate seamlessly with Project data model from Issue #1
- [ ] Error handling provides clear feedback for invalid sources
- [ ] Progress reporting works for long-running ingestion tasks

## Files to Modify
- `VoiceInk/Services/GitIngestService.swift` (extend existing)
- `VoiceInk/Services/ManualNotesSourceProvider.swift` (new)
- `VoiceInk/Services/SourceProviderProtocol.swift` (new)
- `VoiceInk/Models/Artifact.swift` (new)
- `VoiceInk/Models/GitIngestPreset.swift` (new)
- `VoiceInkTests/Services/` (new test files)

## GitIngest Presets
```swift
enum GitIngestPreset: String, CaseIterable {
    case docs = "docs-only"        // *.md, README*, docs/, wiki/
    case code = "code-only"        // Source files, exclude docs/vendor
    case mixed = "mixed"           // Balanced selection
    case custom = "custom"         // User-defined patterns
}
```

## Manual Notes Structure
```
~/Library/Application Support/VoiceInk/Projects/{projectId}/notes/
├── note-1.md
├── note-2.md
└── .metadata.json
```

## Technical Notes
- Leverage existing GitIngest Python integration where possible
- Ensure thread-safe operations for concurrent ingestion
- Use file system events for change detection in manual notes
- Implement proper error propagation and user feedback
- Consider memory usage for large repositories

## Dependencies
- Issue #1 (Core Data Models) - requires Project and ContextSource models

## Estimated Effort
Large (4-5 days) - Significant service development with testing