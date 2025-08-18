# Create Projects & Context Packs UI

## Summary
Add a new sidebar item "Projects" and build views for managing context sources and packs with a comprehensive tabbed interface.

## Problem Statement
Users need an intuitive interface to:
- Create and manage projects for different codebases/contexts
- Configure multiple context sources (GitIngest repos, manual notes)
- Organize content into context packs for specific use cases
- View generated dictionary terms and their metadata
- Control synchronization and ingestion processes

## Tasks

### Sidebar Integration
- [ ] Add "Projects" entry to main settings sidebar
- [ ] Update navigation structure in `ContentView.swift`
- [ ] Ensure proper icon and styling consistency

### Project List View
- [ ] Create master view showing all projects
- [ ] Add/remove project functionality
- [ ] Project metadata display (name, last sync, source count)
- [ ] Search and filtering capabilities

### Project Detail View with Tabs
- [ ] **Sources Tab**
  - [ ] List of configured sources (GitIngest, Manual Notes)
  - [ ] Add new source workflow with type selection
  - [ ] Source configuration UI (repo URL, presets, patterns)
  - [ ] Re-ingest source action with progress indication
  - [ ] Source status and last sync information
- [ ] **Packs Tab**
  - [ ] List of context packs within the project
  - [ ] Create new pack workflow
  - [ ] Pack configuration (name, description, source selection)
  - [ ] Filter and refinement options
  - [ ] Pack activation/deactivation controls
- [ ] **Dictionary Tab**
  - [ ] Generated terms from all sources in the project
  - [ ] Term frequency and importance scoring
  - [ ] Filter by source, pack, or term type
  - [ ] Search functionality across all terms
  - [ ] Term alias and definition management
- [ ] **Sync Tab**
  - [ ] Manual re-ingest triggers for each source
  - [ ] Sync status and progress indication
  - [ ] Last sync times and next scheduled sync
  - [ ] Sync configuration (auto-sync intervals)
  - [ ] Error logs and troubleshooting info

### Source Configuration UI
- [ ] GitIngest source setup
  - [ ] Repository path/URL input with validation
  - [ ] Preset selection (docs, code, mixed, custom)
  - [ ] Include/exclude pattern configuration
  - [ ] Branch and submodule options
- [ ] Manual Notes source setup
  - [ ] Note creation and editing interface
  - [ ] Markdown editor with preview
  - [ ] Note organization and tagging

### Pack Management
- [ ] Context pack creation wizard
- [ ] Source selection for pack inclusion
- [ ] Filter configuration UI
- [ ] Pack preview with term counts
- [ ] Pack export/import functionality

## User Workflows

### Creating a New Project
1. Navigate to Projects sidebar item
2. Click "Add Project" button
3. Enter project name and optional description
4. Set project root path (auto-detected from active directory)
5. Project appears in list

### Adding a GitIngest Source
1. Select project → Sources tab
2. Click "Add Source" → "Git Repository"
3. Enter repository path or URL
4. Select preset (docs-only, code-only, mixed)
5. Configure include/exclude patterns if custom
6. Click "Add & Ingest" to begin processing

### Creating a Context Pack
1. Select project → Packs tab
2. Click "Create Pack"
3. Enter pack name and description
4. Select which sources to include
5. Configure any filters or term limits
6. Save pack for use in enhancement

## Acceptance Criteria
- [ ] Projects can be created and deleted through the UI
- [ ] Sources can be added with proper configuration options
- [ ] Sources can be ingested with progress feedback
- [ ] Packs can be created with selected sources and filters
- [ ] Dictionary tab displays terms derived from ingested files
- [ ] All tabs function correctly with proper navigation
- [ ] UI follows existing VoiceInk design patterns and theming
- [ ] Responsive layout works with different window sizes
- [ ] Error states are handled gracefully with user feedback

## Files to Create
- `VoiceInk/Views/Projects/ProjectsView.swift` (main container)
- `VoiceInk/Views/Projects/ProjectListView.swift` (project list)
- `VoiceInk/Views/Projects/ProjectDetailView.swift` (tabbed detail)
- `VoiceInk/Views/Projects/SourcesTabView.swift` (sources management)
- `VoiceInk/Views/Projects/PacksTabView.swift` (pack management)
- `VoiceInk/Views/Projects/DictionaryTabView.swift` (terms display)
- `VoiceInk/Views/Projects/SyncTabView.swift` (sync controls)
- `VoiceInk/Views/Projects/Components/` (reusable components)

## Files to Modify
- `VoiceInk/Views/Settings/SettingsView.swift` (add sidebar entry)
- `VoiceInk/Views/ContentView.swift` (navigation updates)

## Design Patterns
- Follow existing VoiceInk card-based layout
- Use consistent spacing and typography
- Implement proper loading states
- Provide clear visual feedback for actions
- Use standard SwiftUI navigation patterns

## Accessibility
- Proper VoiceOver support for all controls
- Keyboard navigation throughout interface
- Clear focus indicators
- Descriptive labels for screen readers

## Dependencies
- Issue #1 (Core Data Models) - requires Project, ContextSource, ContextPack models
- Issue #2 (Source Providers) - requires GitIngestService and ManualNotesProvider

## Estimated Effort
Large (6-7 days) - Comprehensive UI development with multiple views and workflows