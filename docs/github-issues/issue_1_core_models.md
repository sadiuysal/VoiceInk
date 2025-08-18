# Implement Core Data Models and Migrations for Projects & Context

## Summary
Introduce new SwiftData models to support Projects, Context Packs, dictionary entries, and chat structures. Create necessary migrations to ensure existing users can upgrade smoothly.

## Problem Statement
To implement the new Project Context and Chat Harvest features, we need foundational data models that can:
- Manage multiple context sources (GitIngest repositories, manual notes)
- Organize content into context packs for different use cases
- Store dictionary entries with metadata and references
- Support chat snippets from external applications
- Integrate with existing PowerMode profiles

## Tasks
- [ ] Add `Project` model (id, name, description, rootPath, createdAt, updatedAt)
- [ ] Add `ContextSource` model (id, projectId, type enum, configuration, lastSync)
- [ ] Add `ContextPack` model (id, projectId, name, sourceIds, filters, isActive)
- [ ] Add `DictionaryEntry` model (id, packId, term, definition, frequency, tags)
- [ ] Add `ChatSnippet` model (id, threadTitle, messages, capturedAt) - ephemeral
- [ ] Add `EnhancementConfig` model (id, promptId, boundPackIds, settings)
- [ ] Extend `PowerModeConfig` with `boundPackIds: [UUID]` property
- [ ] Define proper relationships between models
- [ ] Write migration logic for existing PowerMode data
- [ ] Add CRUD operations for all new entities

## Acceptance Criteria
- [ ] Models compile and integrate with existing SwiftData schema in `ContextIndexStore`
- [ ] Migrations succeed without data loss on test installations  
- [ ] Unit tests cover basic CRUD operations for all new models
- [ ] Existing PowerMode functionality remains intact after migration
- [ ] Schema changes are backward compatible

## Files to Modify
- `VoiceInk/Models/Project.swift` (new)
- `VoiceInk/Models/ContextSource.swift` (new)
- `VoiceInk/Models/ContextPack.swift` (new)
- `VoiceInk/Models/DictionaryEntry.swift` (new)
- `VoiceInk/Models/ChatSnippet.swift` (new)
- `VoiceInk/Models/EnhancementConfig.swift` (new)
- `VoiceInk/Services/ContextIndexStore.swift` (extend schema)
- `VoiceInk/PowerMode/PowerModeConfig.swift` (add boundPackIds property)
- `VoiceInkTests/Models/` (new test files)

## Technical Notes
- Use SwiftData's `@Model` decorator for all new entities
- Ensure proper `Codable` conformance for UserDefaults persistence where needed
- Follow existing naming conventions and patterns
- Consider using `UUID` for all primary keys
- Add appropriate database indexes for frequently queried fields

## Dependencies
- None (foundation issue)

## Estimated Effort
Medium (2-3 days) - Core infrastructure work with testing