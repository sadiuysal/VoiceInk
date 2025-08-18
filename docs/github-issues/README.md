# GitHub Issues for VoiceInk Chat Harvest and Project Context Implementation

This directory contains the detailed GitHub issues for implementing the modular chat harvest and project context features. Each issue is designed to be self-contained and can be worked on in parallel where dependencies allow.

## Implementation Roadmap

### Milestone 1: Foundations ✅ (Issue #1 Complete)
- [x] **Issue #1: Core Data Models** - COMPLETED
  - Implemented Project, ContextSource, ContextPack, DictionaryEntry models
  - Created ChatSnippet and ChatMessage structures
  - Extended PowerModeConfig with boundPackIds
  - Added ContextBindingService foundation
  - Comprehensive UserDefaults keys for settings

### Milestone 1: Remaining Foundation Work
- [ ] **Issue #2**: Build GitIngest and Manual Notes Source Providers
- [ ] **Issue #3**: Create Projects & Context UI 
- [ ] **Issue #4**: Update Enhancement UI for Post-processing
- [ ] **Issue #5**: Refactor Power Mode Editor
- [ ] **Issue #6**: Complete ContextBindingService Integration

### Milestone 2: Chat Harvest & Integration
- [ ] **Issue #7**: Implement ChatHarvestService for Cursor Chat
- [ ] **Issue #8**: Add Settings for Chat Harvest and Projects & Context
- [ ] **Issue #9**: Integrate Chat Harvest into ContextBindingService

### Milestone 3: Polish & Documentation
- [ ] **Issue #10**: Add GitIngest Presets and Pack Filters
- [ ] **Issue #11**: Expand Settings and Sync Controls
- [ ] **Issue #12**: Testing & QA for Context Harvest and Binding
- [ ] **Issue #13**: Documentation and Release Notes

## Quick Start for Development Team

1. **Foundation complete**: Core data models are implemented and ready
2. **Parallel development ready**: Issues #2-6 can be worked on simultaneously
3. **Integration points defined**: ContextBindingService provides clear interfaces
4. **Testing foundation**: Unit tests demonstrate expected model behavior

## Key Technical Decisions Made

- **SwiftData Integration**: All models integrate with existing ContextIndexStore
- **Unified Context**: ContextBindingService combines all context sources
- **Modular Source Providers**: Clean protocol-based architecture for extensibility
- **Settings Infrastructure**: Comprehensive UserDefaults management
- **Ephemeral Chat**: Chat snippets are request-scoped, not persisted

## Next Steps

Development teams can immediately begin work on:
- **UI Team**: Issues #3, #4, #5 (Projects UI, Enhancement refactor, PowerMode updates)
- **Backend Team**: Issues #2, #6 (Source providers, ContextBinding completion)
- **Integration Team**: Issues #7, #9 (Chat harvest, integration)

Each issue file contains:
- Detailed technical specifications
- Acceptance criteria
- File modification lists
- Dependencies and estimated effort
- Integration points with existing codebase