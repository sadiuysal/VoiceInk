## VoiceInk — First Build Guide (macOS 15, Apple Silicon)

### Scope
Minimal steps to get a first successful local build/run. No new features; no repo restructuring.

### Prerequisites
- macOS 15 (Darwin 24.x), Apple Silicon (M1/M2/M3)
- Xcode 15.x+ with Command Line Tools
- `whisper.cpp` locally (for building the XCFramework)

---

## 1) Build Whisper XCFramework
```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
./build-xcframework.sh
# Output: build-apple/whisper.xcframework
```

- In Xcode: Drag `build-apple/whisper.xcframework` into the project.
- Target `VoiceInk` → General → Frameworks, Libraries, and Embedded Content:
  - Ensure `whisper.xcframework` is listed as “Embed & Sign”.

---

## 2) Signing & Capabilities (Debug)
- Targets: `VoiceInk`, `VoiceInkTests`, `VoiceInkUITests`
  - “Automatically manage signing”: ON
  - Set the SAME “Team” for all targets (unify; avoid mismatches).
  - Identity for Debug: “Apple Development”
- Keep “Enable Hardened Runtime” = YES (required).
- Do NOT enable sandbox (entitlements rely on Apple Events + Screen Capture).

---

## 3) Info.plist privacy keys
Add microphone usage (required), and optionally Apple Events usage:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>VoiceInk needs microphone access to transcribe your speech.</string>
<key>NSAppleEventsUsageDescription</key>
<string>VoiceInk automates your IDE to detect the active project and format file references.</string>
```

Note: `NSScreenCaptureUsageDescription` already exists.

---

## 4) Deployment targets (optional consistency)
- Project shows macOS 15.0; app/tests targets show 14.0.
- Not a blocker. For fewer warnings, align to 14.0 or 15.0 across all targets.

---

## 5) Build and Run
- Xcode: Product → Clean Build Folder, then Build (Cmd+B), Run (Cmd+R).
- If TCC prompts don’t appear correctly, move the built app to `/Applications` and run once from there.

---

## First-run permissions (TCC)
- Microphone: allow (required).
- Screen Recording: enable in System Settings → Privacy & Security → Screen Recording.
- Automation (Apple Events): allow when prompted to control `Cursor`.

---

## Common errors and fixes
- “App requires microphone permission but no prompt/denied” → Ensure `NSMicrophoneUsageDescription` is in `Info.plist`; re-run.
- “dyld: image not found (whisper)” → Ensure `whisper.xcframework` is in Embedded Content as “Embed & Sign”; rebuild.
- “No provisioning profile / signing failed” → Unify Team across all targets; Automatic signing ON.
- Screen capture not working → Manually enable in System Settings → Privacy & Security → Screen Recording.
- Cursor automation not working → Approve the Automation prompt; if missed, re-enable under Automation privacy settings.

---

## Quick verification (optional)
```bash
# Show build settings highlights:
xcodebuild -showBuildSettings -project VoiceInk.xcodeproj -scheme VoiceInk \
| egrep 'DEVELOPMENT_TEAM|CODE_SIGN|MACOSX_DEPLOYMENT_TARGET|ENABLE_HARDENED_RUNTIME'

# After build, verify embedded frameworks are signed:
codesign -vvv "$(mdfind 'kMDItemFSName = "VoiceInk.app"c' | head -1)"/Contents/Frameworks/*.framework
```

---

## Minimal troubleshooting checklist
- Whisper present, set to “Embed & Sign”.
- Same Team for app + test targets; Automatic signing ON.
- Hardened Runtime ON; no sandbox.
- `NSMicrophoneUsageDescription` present; accept prompts for Mic/Screen Recording/Automation.

---

## Notes for later (distribution, not required now)
- For distribution: sign with Developer ID Application, notarize with `notarytool`, staple.
- Keep Sparkle 2 keys as configured; retain Mach-lookup exceptions for Sparkle XPCs in entitlements.

---

## Filesystem Context (optional, no OCR)
- Enable with defaults key `UseFilesystemContext = true`.
- VoiceInk builds a per-project dictionary from README/CLAUDE/manifests and top-level filenames.
- Optional: add a shell helper to publish cwd to `~/.voiceink/cwd` for better project detection:

```bash
# ~/.zshrc
autoload -U add-zsh-hook
_voiceink_publish_cwd() { printf "%s" "$PWD" > "$HOME/.voiceink/cwd"; }
add-zsh-hook precmd _voiceink_publish_cwd
```

Privacy: reads only allowlisted files; no network; stored locally in Application Support.

---

## GitIngest Integration Architecture

### Overview
VoiceInk integrates with the [GitIngest](https://github.com/coderamp-labs/gitingest) open-source project to provide comprehensive repository-wide context analysis. This enhancement works alongside the existing Markdown Dictionary Index (MDI) system to deliver superior AI assistance for development workflows.

### Core Integration Components

#### GitInestService.swift
- **Purpose**: Main service managing Python subprocess communication with GitIngest
- **Key Features**:
  - Manages bundled or system Python environment
  - Handles configuration, timeouts, and error management  
  - Provides async repository ingestion with progress tracking
  - Supports both private (GitHub token) and public repositories

#### GitIngestBridge.py
- **Purpose**: JSON wrapper script providing clean API over GitIngest Python interface
- **Features**:
  - Supports both sync and async GitIngest operations
  - Comprehensive error handling and configuration validation
  - Structured JSON output for Swift integration
  - Private repository support with GitHub Personal Access Tokens

#### Python Environment Management
- **Bundled Environment**: `VoiceInk/Resources/python-env/` with isolated GitIngest installation
- **Setup Script**: `setup_gitingest.py` for automated environment creation
- **Fallback**: System Python with runtime GitIngest availability checking

### Hybrid Context Strategy

#### Intelligent Sync Modes
1. **Incremental Mode**: Existing file-level MDI updates (< 1 minute response)
2. **Full Repository Mode**: GitIngest comprehensive analysis (scheduled/on-demand)
3. **Hybrid Mode**: Smart combination based on change patterns and user settings

#### Sync Triggers
- **File-level changes**: Immediate incremental updates via FSEvents
- **Repository-level changes**: GitIngest full sync when:
  - New branches or significant commits detected
  - Manual trigger from Power Mode UI
  - Scheduled sync (configurable: 15min to 24 hours)
  - Large batch changes (> 10 files modified)

#### Content Merging
```swift
// Enhanced dictionary combines both approaches
func createEnhancedDictionary() -> String {
    let standardDictionary = createStandardDictionaryContent() // Existing MDI
    let repoContextTerms = getRepoContextTerms() // GitIngest insights
    return standardDictionary + repoContextTerms // Intelligent merge
}
```

### Configuration Options

#### User Settings (Settings → Project Context)
- **Enable GitIngest Repository Analysis**: Master toggle
- **Auto-sync Repository**: Automatic scheduled synchronization  
- **Include Submodules**: Process Git submodules in analysis
- **Include Gitignored Files**: Include files normally ignored by Git
- **GitHub Token**: Personal Access Token for private repositories
- **Sync Interval**: 15 minutes to 24 hours (default: 1 hour)

#### UserDefaults Keys
```swift
// GitIngest Integration
static let useGitIngest = "UseGitIngest"
static let gitIngestTimeoutSeconds = "GitIngestTimeoutSeconds" // Default: 300
static let gitIngestIncludeSubmodules = "GitIngestIncludeSubmodules"
static let gitIngestIncludeGitignored = "GitIngestIncludeGitignored"
static let gitIngestToken = "GitIngestToken" // Secure storage
static let gitIngestAutoSync = "GitIngestAutoSync"
static let gitIngestSyncInterval = "GitIngestSyncInterval" // Default: 3600 (1 hour)
```

### UI Integration

#### Power Mode Context Panel
- **Repository Status**: Shows GitIngest sync status and last sync time
- **Quick Actions**:
  - "Full Repository Sync": Manual trigger for comprehensive analysis
  - "Copy Enhanced Repository Context": AI-optimized context for clipboard
- **Progress Indicators**: Real-time sync progress and status display

#### Enhanced Context Export
- **Standard Context**: File-level MDI segments and filesystem terms
- **Repository Context**: GitIngest-powered whole-repository insights
- **Combined Export**: Intelligent merge prioritizing high-value content
- **AI-Ready Format**: Structured for optimal Cursor/Claude Code integration

### Privacy & Performance

#### Privacy-First Design
- **Local Processing**: Python environment bundled with application
- **No External Dependencies**: GitIngest runs entirely offline
- **Secure Token Storage**: GitHub tokens stored securely in Keychain
- **User Control**: All features can be disabled; granular privacy controls

#### Performance Optimization
- **Configurable Timeouts**: Prevents hanging on large repositories (default: 5 minutes)
- **Background Processing**: Non-blocking UI during repository analysis  
- **Intelligent Caching**: Repository context cached locally for quick access
- **Progressive Enhancement**: Existing workflows unaffected when disabled

---

## Markdown Dictionary Index (MDI) System

### Overview
The Markdown Dictionary Index is a comprehensive system for analyzing, indexing, and managing project documentation to create intelligent, context-aware dictionaries for AI development workflows.

### Core Architecture

#### SwiftData Models
- **IndexedDocument**: Represents a markdown file with metadata (path, hash, size, last indexed)
- **MarkdownSegment**: Individual content segments with line-precise anchors and semantic tags
- **DictionaryProfile**: Curated collections of pinned segments for specific project contexts
- **SegmentKind**: Categorizes content (heading, code, list, quote, table, emphasis, paragraph)

#### Key Services
- **ContextIndexStore**: Main coordinator managing SwiftData persistence and CRUD operations
- **MarkdownIndexer**: Parses markdown into semantic segments with quality filtering
- **FilesystemContextService**: Legacy term extraction enhanced with MDI integration

### Content Parsing & Segmentation

#### Intelligent Parsing
- Line-by-line markdown analysis with state machine approach
- Automatic segment boundary detection (headings, code blocks, lists, quotes, tables)
- Quality filtering removes low-value content (< 10 chars, insufficient meaningful words)
- Preserves exact line numbers for precise references

#### Semantic Tagging System
Each segment receives multiple semantic tags:
- **Source tags**: `markdown-file:path/to/file.md`, `directory:Services`
- **Location tags**: `lines:L15-L23`, `section:implementation-details`
- **Kind tags**: `kind:heading`, `kind:code-block`
- **Content tags**: `term:CamelCase`, `file-ref:swift`, `prio:high`

#### Anchor Generation
Durable anchor format: `md:path/file.md#section-slug:L15-23:hash4`
- Enables precise cross-references between segments
- Content hash ensures change detection
- Section slug provides human-readable context

#### Tag Generation System

VoiceInk uses a sophisticated multi-layered tagging system to categorize and score markdown content segments. Tags are automatically generated during the indexing process in `MarkdownIndexer.swift`:

**Source Tags** - File and directory context:
```swift
tags.append("markdown-file:\(relPath)")        // Source file identification
tags.append("directory:\(lastDir)")            // Parent directory context
```

**Location Tags** - Precise positioning:
```swift
tags.append("lines:L\(startLine)-L\(endLine)") // Exact line boundaries  
tags.append("section:\(sectionSlug)")          // Section hierarchy context
```

**Kind Tags** - Content classification:
```swift
tags.append("kind:\(segmentKind)")             // heading, code, list, etc.
```

**Semantic Tags** - Content analysis:
```swift
// File references
if content.contains(".swift") { tags.append("file-ref:swift") }
if content.contains(".md") { tags.append("file-ref:markdown") }
if content.contains(".json") { tags.append("file-ref:config") }

// Technical terminology patterns
if content.matches("[A-Z][a-z]+(?:[A-Z][a-z]+)+") { tags.append("term:CamelCase") }
if content.matches("[a-z]+-[a-z]+") { tags.append("term:kebab-case") }
if content.matches("[a-z]+_[a-z]+") { tags.append("term:snake_case") }
```

**Priority Tags** - Importance weighting:
```swift
if relPath.contains("README") {
    tags.append("prio:high")
    tags.append("doc:readme")
}
if relPath.contains("CLAUDE") {
    tags.append("prio:high") 
    tags.append("doc:claude")
}
```

**Scoring Algorithm**:
```swift
func calculateScore(for segment: MarkdownSegmentDraft, tags: [String]) -> Int {
    var score = segment.kind.baseScore          // Base score by content type
    
    if tags.contains("prio:high") { score += 5 }         // High-priority files
    if tags.hasPrefix("term:") { score += 2 }            // Technical terminology
    if tags.hasPrefix("file-ref:") { score += 1 }        // File references
    if segment.kind == .heading { score += 3 }           // Section headings
    
    // Content length optimization
    let length = segment.content.count
    if length > 100 && length < 1000 { score += 1 }      // Reasonable size bonus
    
    return max(1, score)
}
```

**Segment Kind Base Scores**:
- `heading`: 5 points (highest priority)
- `code`: 4 points (technical content)  
- `emphasis`: 3 points (highlighted text)
- `list`: 2 points (structured content)
- `quote`: 2 points (referenced material)
- `paragraph`: 1 point (general content)

This multi-dimensional tagging system enables precise content filtering, intelligent scoring, and context-aware dictionary generation for optimal AI assistance.

---

## VoiceInk Architecture Overview

### Core Service Architecture

VoiceInk follows a modular service-oriented architecture with clear separation of concerns:

#### Primary Services Layer
```
┌─────────────────────────────────────────────────────┐
│                   VoiceInk App                      │
├─────────────────────────────────────────────────────┤
│  Context Management    │  Transcription Services    │
│  ├─ContextIndexStore   │  ├─LocalTranscriptionSvc  │
│  ├─GitIngestService    │  ├─CloudTranscriptionSvc  │
│  ├─MarkdownIndexer     │  ├─WhisperState            │
│  ├─ProjectFileStore    │  └─TranscriptionFallback   │
│  └─FilesystemContext   │                            │
├─────────────────────────────────────────────────────┤
│  AI Enhancement        │  Power Mode & Automation   │
│  ├─AIEnhancementSvc    │  ├─PowerModeManager        │
│  ├─PromptDetection     │  ├─ActiveWindowService     │
│  ├─WordReplacement     │  ├─BrowserURLService       │
│  └─ScreenCapture       │  └─AppPicker               │
├─────────────────────────────────────────────────────┤
│  System Integration    │  Data & Storage            │
│  ├─MenuBarManager      │  ├─SwiftData Models        │
│  ├─HotkeyManager       │  ├─UserDefaultsManager    │
│  ├─NotificationMgr     │  ├─TranscriptionHistory   │
│  └─AudioDeviceManager  │  └─ImportExportService    │
└─────────────────────────────────────────────────────┘
```

#### Data Flow Architecture
```
User Input (Voice) → Audio Processing → Transcription → AI Enhancement → Context Integration → Output
     ↓                    ↓                  ↓              ↓                   ↓               ↓
[Microphone]        [WhisperState]    [LocalTranscription] [AIEnhancement]  [ContextStore]  [Clipboard]
     ↓                    ↓                  ↓              ↓                   ↓               ↓
[AudioDevice]       [CloudServices]   [TranscriptionSvc]   [PromptDetection] [GitIngest]    [PowerMode]
     ↓                    ↓                  ↓              ↓                   ↓               ↓
[HotkeyManager]     [ParakeetSvc]     [FallbackManager]    [WordReplacement] [MDI System]   [AppPicker]
```

#### Modular Component Design

**Context Management Module**:
- `ContextIndexStore`: SwiftData coordination and CRUD operations
- `MarkdownIndexer`: Semantic parsing with quality filtering  
- `GitIngestService`: Repository-wide analysis integration
- `ProjectFileIndexStore`: File-level indexing with tagging
- `FilesystemContextService`: Legacy term extraction + FSEvents

**AI Enhancement Pipeline**:
- `AIEnhancementService`: Main enhancement coordinator
- `PromptDetectionService`: Context-aware prompt selection
- `WordReplacementService`: Custom dictionary management
- `ScreenCaptureService`: Visual context extraction

**Transcription Stack**:
- `WhisperState`: Local model management and inference
- `TranscriptionService`: Service abstraction layer
- `LocalTranscriptionService`: Whisper.cpp integration
- `CloudTranscriptionService`: API-based transcription
- `TranscriptionFallbackManager`: Reliability management

**Power Mode System**:
- `PowerModeManager`: Configuration and session management
- `ActiveWindowService`: App detection and context switching
- `BrowserURLService`: URL extraction and context
- `AppPicker`: Application-specific configurations

### Key Architectural Decisions

#### SwiftData Integration
- **Models**: Transcription, MarkdownSegment, IndexedDocument, DictionaryProfile
- **Persistence**: Local SQLite with efficient indexing
- **Threading**: MainActor isolation for UI consistency
- **Migrations**: Version-safe schema evolution

#### Concurrency Architecture
- **MainActor**: UI and SwiftData operations
- **Background Tasks**: File processing, transcription, indexing
- **Actor Isolation**: Thread-safe service boundaries
- **Async/Await**: Modern Swift concurrency throughout

#### Plugin Architecture
- **Transcription Models**: Pluggable model providers (Local, Cloud, Parakeet)
- **Enhancement Services**: Modular AI enhancement pipeline  
- **Context Sources**: Extensible context data sources
- **Export Formats**: Flexible output format support

#### Privacy-First Design Principles
- **Local Processing**: All sensitive operations on-device
- **User Control**: Granular privacy settings
- **Secure Storage**: Keychain for sensitive data
- **No Telemetry**: Zero data collection without explicit consent

### Context Window Manager

#### Multi-Tab Interface
1. **Documents Tab**: Browse indexed markdown files with segment counts
2. **Segments Tab**: Filter and search all segments by kind, content, score
3. **Profiles Tab**: Manage curated dictionary collections
4. **Legacy Tab**: Original filesystem context functionality

#### Dictionary Profiles
- Create project-specific term collections
- Pin high-value segments for AI context
- Generate markdown exports with tagged anchors
- Push curated context to AI tools (Cursor integration)

### Quality & Filtering Systems

#### Stopword Filtering
Comprehensive filter for 100+ common words ("the", "and", "for", etc.)
Excludes version numbers, pure digits, and generic programming terms

#### Scoring Algorithm
- Base scores by segment kind (heading: 5, code: 4, emphasis: 3)
- Priority boosts for README.md, CLAUDE.md content (+5)
- Technical term detection bonuses (+2)
- Content length optimization (100-1000 chars gets +1)

#### Smart Term Limits
- Flexible 50-1000 range based on content quality
- Quality-first approach over arbitrary limits
- Meaningful term extraction with semantic prefixes

### File Reference Enhancement

#### Semantic File Prefixes
- `swift-file:AppDelegate.swift`
- `markdown-file:README.md`
- `config-file:package.json`
- `directory:Services`

#### Path Context Extraction
Extracts meaningful references from content:
- File paths with extensions
- Directory structures
- Relative and absolute path references
- Case-sensitive filename preservation

### Integration Points

#### CLAUDE.md Synchronization
- Special parsing for CLAUDE.md with 8x term weight multiplier
- Skip self-generated sections to prevent feedback loops
- Extract project-specific terminology and patterns
- Sync updates with comment-based section markers

#### Cursor Workflow Enhancement
- "Push to Cursor" functionality copies curated context to clipboard
- Anchor-based references for precise documentation links
- Context-aware term suggestions for development

### Performance & Storage

#### Incremental Updates
- File modification date tracking prevents unnecessary re-indexing
- Optional FSEvents integration for real-time monitoring
- Efficient SwiftData queries with proper indexing

#### Storage Optimization
- 1MB per-file size limits
- 100-line segment boundaries
- Content deduplication through hash-based tracking
- Automatic cleanup of stale indices

### User Experience

#### Context Inspector Window
- Dedicated window with proper lifecycle management
- Real-time search and filtering across all indexed content
- Copy-to-clipboard for anchor references
- Visual feedback for operations (indexing progress, copy confirmations)

#### Export Capabilities
- Generate markdown dictionaries with tagged references
- Save/load profile configurations
- Export with file reveal in Finder
- Automatic filename generation with timestamps

### Technical Implementation

#### Swift Concurrency
- MainActor isolation for SwiftData operations
- Async/await for file I/O operations  
- Proper error handling and logging throughout
- Thread-safe shared service instances

#### Error Handling
- Graceful degradation for oversized files
- Comprehensive logging with subsystem organization
- User feedback for failed operations
- Fallback mechanisms for parse errors

### Usage Scenarios

#### AI Development Workflow
1. Enable filesystem context in Settings
2. Create dictionary profile for current project
3. Browse and pin relevant documentation segments
4. Export or push curated context to AI tools
5. Reference specific sections with durable anchors

#### Documentation Management
1. Automatic indexing of all project markdown files
2. Search across documentation by content or metadata
3. Track documentation changes through hash monitoring
4. Cross-reference related sections through tagging

#### Code Context Enhancement
1. File and directory reference extraction
2. Technical term identification and weighting
3. Case-sensitive naming preservation
4. Integration with existing transcription workflows


<!-- VOICEINK:TERMS:START -->
# VoiceInk Project Context
Generated: 18.8.2025, 4:43

## Project Dictionary (100 terms)
1. for
2. the
3. VoiceInk
4. and
5. build
6. whisperxcframework
7. with
8. Screen
9. Automation
10. project
11. Apple
12. run
13. Ensure
14. targets
15. Sign
16. Embed
17. Recording
18. not
19. Build
20. app
21. apple
22. Content
23. Xcode
24. prompts
25. cwd
26. Embedded
27. bash
28. add
29. Events
30. whisper
31. Frameworks
32. signing
33. enable
34. from
35. TCC
36. required
37. voiceink
38. For
39. XCFramework
40. allow
41. Application
42. prompt
43. microphone
44. Privacy
45. locally
46. present
47. whispercpp
48. git
49. Cursor
50. Enable
51. all
52. Team
53. Infoplist
54. macOS
55. settings
56. distribution
57. VoiceInkTests
58. VoiceInkUITests
59. shell
60. into
61. First
62. Development
63. Drag
64. detection
65. but
66. UseFilesystemContext
67. Applications
68. image
69. once
70. key
71. App
72. true
73. there
74. when
75. requires
76. already
77. listed
78. appear
79. defaults
80. prompted
81. sign
82. notarytool
83. Targets
84. Target
85. better
86. denied
87. Building
88. Mic
89. move
90. Optional
91. notarize
92. dyld
93. rebuild
94. staple
95. accept
96. General
97. publish
98. Libraries
99. building
100. Note

## Source Statistics
- elapsedMs: 132
<!-- VOICEINK:TERMS:END -->