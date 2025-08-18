# Add Settings for Chat Harvest and Projects & Context

## Summary
Provide user-accessible controls for automatic chat capture and context management through a new "Projects & Context" settings section.

## Problem Statement
Users need granular control over the new chat harvest and project context features:
- Enable/disable automatic chat capture
- Configure chat capture parameters (message count, token limits)
- Set project context preferences
- Control sync behavior and performance settings
- Maintain privacy and performance boundaries

## Tasks

### New Settings Section: "Projects & Context"
- [ ] Add new section in Settings sidebar between existing sections
- [ ] Implement proper section navigation and state management
- [ ] Follow existing VoiceInk settings UI patterns and styling

### Chat Harvest Settings
- [ ] **Auto-capture Cursor chat** (Toggle, default: On)
  - Master switch for chat harvest functionality
  - When disabled, completely skips chat harvest attempts
- [ ] **Last messages** (Integer input, default: 8, range: 1-20)
  - Number of recent messages to capture
  - Validation and user feedback for invalid values
- [ ] **Token cap** (Integer input, default: 512, range: 100-2000)
  - Maximum tokens for all captured chat content
  - Help text explaining token counting
- [ ] **Include code blocks only** (Toggle, default: Off)
  - When enabled, extract only code fences from chat
  - Useful for technical discussions with lots of code

### Project Context Settings
- [ ] **Default project root** (Path picker, default: auto-detect)
  - Fallback path when auto-detection fails
  - Browse button for manual selection
- [ ] **Auto-detect project context** (Toggle, default: On)
  - Enable automatic project context detection
  - Uses shell helper or current working directory
- [ ] **Ingestion file size limit** (Integer, default: 1MB, range: 100KB-10MB)
  - Maximum size for individual files during ingestion
  - Prevents memory issues with large files

### Sync and Performance Settings
- [ ] **Auto-sync interval** (Dropdown: Manual, 15min, 1hr, 6hr, Daily)
  - How often to automatically re-ingest context sources
  - Manual = only on user request
- [ ] **Background sync** (Toggle, default: On)
  - Allow sync operations while app is in background
  - Respects system performance settings
- [ ] **Max concurrent ingestions** (Integer, default: 2, range: 1-4)
  - Limit parallel source processing for performance

### Advanced Settings (Collapsible Section)
- [ ] **Chat harvest timeout** (Integer, default: 150ms, range: 50-500ms)
  - Maximum time allowed for chat capture
  - Advanced users only, hidden by default
- [ ] **Context token budget** (Integer, default: 2048, range: 512-8192)
  - Total tokens across all context sources
  - Affects how much context is included in prompts
- [ ] **Enable filesystem monitoring** (Toggle, default: Off)
  - Use FSEvents for real-time project file changes
  - Can impact battery life on laptops

## Settings UI Design

### Layout Structure
```
Projects & Context
├── Chat Capture
│   ├── [Toggle] Auto-capture Cursor chat
│   ├── [Field] Last messages (8)
│   ├── [Field] Token cap (512)
│   └── [Toggle] Include code blocks only
├── Project Detection  
│   ├── [Toggle] Auto-detect project context
│   ├── [Path] Default project root
│   └── [Field] Ingestion file size limit
├── Synchronization
│   ├── [Dropdown] Auto-sync interval
│   ├── [Toggle] Background sync
│   └── [Field] Max concurrent ingestions
└── [Expandable] Advanced Options
    ├── [Field] Chat harvest timeout
    ├── [Field] Context token budget
    └── [Toggle] Enable filesystem monitoring
```

### UserDefaults Keys
```swift
// Chat Harvest Settings
static let autoCaptureChat = "AutoCaptureCursorChat"
static let chatLastMessages = "ChatHarvestLastMessages" 
static let chatTokenCap = "ChatHarvestTokenCap"
static let chatCodeOnly = "ChatHarvestCodeOnly"

// Project Context Settings  
static let defaultProjectRoot = "DefaultProjectRoot"
static let autoDetectProject = "AutoDetectProjectContext"
static let ingestionFileSizeLimit = "IngestionFileSizeLimit"

// Sync Settings
static let autoSyncInterval = "AutoSyncInterval"
static let backgroundSync = "BackgroundSyncEnabled"
static let maxConcurrentIngestions = "MaxConcurrentIngestions"

// Advanced Settings
static let chatHarvestTimeout = "ChatHarvestTimeoutMs"
static let contextTokenBudget = "ContextTokenBudget"
static let enableFilesystemMonitoring = "EnableFilesystemMonitoring"
```

## User Experience Features

### Help and Documentation
- [ ] Info tooltips for each setting explaining purpose and impact
- [ ] Links to documentation for advanced features
- [ ] Performance impact indicators for resource-intensive options
- [ ] "Reset to Defaults" button for each section

### Validation and Feedback
- [ ] Real-time validation of numeric inputs
- [ ] Clear error messages for invalid configurations
- [ ] Visual feedback when settings are saved
- [ ] Warning indicators for settings that may impact performance

### Smart Defaults
- [ ] Detect system capabilities and adjust defaults
- [ ] Consider available RAM for token budget defaults
- [ ] Auto-detect optimal concurrent ingestion count
- [ ] Suggest appropriate sync intervals based on usage patterns

## Acceptance Criteria
- [ ] Settings persist correctly via UserDefaults
- [ ] Toggling auto-capture chat prevents all chat harvest attempts
- [ ] Editing last messages/token cap updates ChatHarvestService parameters
- [ ] All numeric inputs validate ranges and provide user feedback
- [ ] Settings integrate with existing VoiceInk settings UI seamlessly
- [ ] Changes take effect immediately without requiring app restart
- [ ] Export/import settings work with new keys
- [ ] Settings reset functionality includes new options

## Files to Modify
- `VoiceInk/Views/Settings/SettingsView.swift` (add new section)
- `VoiceInk/Services/UserDefaultsManager.swift` (add new keys and accessors)

## Files to Create
- `VoiceInk/Views/Settings/ProjectContextSettingsView.swift` (new settings section)
- `VoiceInk/Views/Components/SettingsCard.swift` (reusable card component)

## Integration Points
- Settings values consumed by `ChatHarvestService`
- Project settings used by source providers
- Sync settings control background operations
- Performance settings affect resource usage

## Testing Considerations
- [ ] Settings persistence across app restarts
- [ ] Validation of edge cases (negative numbers, extreme values)
- [ ] UI state management when rapidly changing settings
- [ ] Impact on existing settings and migration scenarios

## Dependencies
- Issue #7 (ChatHarvestService) - settings control chat harvest behavior
- Issue #2 (Source Providers) - settings affect ingestion parameters

## Estimated Effort
Medium (2-3 days) - UI development with comprehensive setting validation