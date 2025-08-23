# VoiceInk - Comprehensive Project Documentation

## 🎯 **Project Overview**

VoiceInk is a native macOS voice-to-text application built with SwiftUI and SwiftData. The application has undergone a major architectural refactor from Core Data to SwiftData, with a new plugin-based backend architecture.

## 📊 **Current Implementation Status**

### **✅ What's Actually Working (August 2025)**
- **Core App**: VoiceInk launches successfully without Core Data migration errors
- **SwiftData Models**: Basic models are working (Project, ContextSource, ContextPack, etc.)
- **Basic UI**: Dashboard, Projects sidebar, and basic navigation are functional
- **Database**: SwiftData container initializes successfully with new schema

### **⚠️ What's Partially Implemented**
- **Backend Architecture**: New plugin-based system is defined but not fully integrated
- **Source Plugins**: GitIngest, MCP, and Manual Files plugins exist but aren't actively used
- **Context Assembly**: Service exists but not connected to UI
- **Chat Streams**: Service exists but not connected to UI

### **❌ What's Not Working/Connected**
- **Backend Integration**: UI doesn't use the new backend services
- **Plugin System**: Source plugins aren't being executed
- **Context Management**: Advanced context features aren't functional
- **AI Enhancement**: Power Mode features aren't connected to backend

## 🏗️ **Repository Structure Analysis**

### **Root Level**
```
VoiceInk/
├── VoiceInk/                    # Main application source code
├── VoiceInk.xcodeproj/          # Xcode project file
├── VoiceInkTests/               # Unit tests
├── VoiceInkUITests/             # UI tests
├── docs/                        # Legacy documentation (mostly outdated)
├── CLAUDE.md                    # This file - current technical documentation
├── .cursorrules                 # Development guidelines
├── README.md                    # User-facing project overview
└── BUILDING.md                  # Build instructions
```

### **Main Application Structure**
```
VoiceInk/
├── VoiceInk.swift               # App entry point with SwiftData setup
├── AppDelegate.swift            # Application lifecycle management
├── WindowManager.swift          # Window management
├── MiniRecorderShortcutManager.swift  # Recording shortcuts
├── Recorder.swift               # Audio recording functionality
├── SoundManager.swift           # Audio playback management
├── PlaybackController.swift     # Media playback control
├── HotkeyManager.swift          # Global hotkey management
├── MenuBarManager.swift         # Menu bar integration
├── MediaController.swift        # Media file handling
├── ClipboardManager.swift       # Clipboard integration
├── CursorPaster.swift           # Cursor IDE integration
├── EmailSupport.swift           # Email functionality
├── Models/                      # SwiftData data models
├── Services/                    # Business logic services
├── Views/                       # SwiftUI user interface
├── PowerMode/                   # AI enhancement features
├── Resources/                   # Assets and resources
├── Whisper/                     # Transcription engine
└── Notifications/               # Notification handling
```

## 📁 **Detailed Component Analysis**

### **Models (SwiftData) - ✅ IMPLEMENTED**
```
Models/
├── Project.swift                # Project container with configuration
├── ContextSource.swift          # Data source configuration
├── ContextPack.swift            # Context collection management
├── DictionaryEntry.swift        # AI dictionary terms
├── ChatSnippet.swift            # Chat conversation data
├── TranscriptionModel.swift     # Transcription configuration
├── Transcription.swift          # Basic transcription record
├── CustomPrompt.swift           # AI prompt templates
├── PromptTemplates.swift        # Predefined prompt system
├── PredefinedPrompts.swift      # Built-in prompts
├── AIPrompts.swift              # AI-specific prompts
├── PredefinedModels.swift       # Model configurations
├── LicenseViewModel.swift       # License management
├── IndexedFile.swift            # File indexing (legacy)
└── MarkdownSegment.swift        # Content segmentation (legacy)
```

**Status**: Core models are working. Some models (IndexedFile, MarkdownSegment) appear to be legacy and may not be used.

### **Services - Mixed Implementation**

#### **Backend Services (New Architecture) - ⚠️ PARTIALLY IMPLEMENTED**
```
Services/Backend/
├── Core/
│   ├── ProjectRegistry.swift           # Project management (✅ IMPLEMENTED)
│   ├── IngestionOrchestrator.swift     # Job orchestration (✅ IMPLEMENTED)
│   ├── SourcePlugin.swift              # Plugin protocol (✅ IMPLEMENTED)
│   └── CredentialStore.swift           # Credential management (✅ IMPLEMENTED)
├── Plugins/
│   ├── EnhancedGitIngestPlugin.swift   # Git repository analysis (✅ IMPLEMENTED)
│   ├── MCPCrawlerPlugin.swift          # Web crawling (✅ IMPLEMENTED)
│   └── ManualFilesPlugin.swift         # File selection (✅ IMPLEMENTED)
├── ContextAssembly/
│   └── EnhancedContextAssemblyService.swift  # Context composition (✅ IMPLEMENTED)
├── ChatStreams/
│   └── ChatStreamService.swift         # Real-time chat (✅ IMPLEMENTED)
├── Storage/
│   └── ContentArtifactModel.swift      # Content storage (✅ IMPLEMENTED)
└── VoiceInkBackendRegistry.swift       # Service coordination (✅ IMPLEMENTED)
```

**Status**: All backend services are implemented but not actively used by the UI.

#### **Legacy Services - ⚠️ MIXED STATUS**
```
Services/
├── FilesystemContextService.swift      # Legacy file indexing (❌ NOT USED)
├── ContextIndexStore.swift             # Legacy context storage (❌ NOT USED)
├── GitService.swift                    # Basic Git operations (✅ WORKING)
├── SmartDefaultsService.swift          # Default settings (✅ WORKING)
├── UserDefaultsManager.swift           # Settings management (✅ WORKING)
├── AIService.swift                     # AI enhancement (⚠️ PARTIAL)
├── AudioFileProcessor.swift            # Audio processing (✅ WORKING)
├── TranscriptionAutoCleanupService.swift # Cleanup (✅ WORKING)
├── MarkdownIndexer.swift               # Content indexing (⚠️ PARTIAL)
├── LocalTranscriptionService.swift     # Local transcription (✅ WORKING)
├── ScreenCaptureService.swift          # Screen capture (✅ WORKING)
├── AudioFileTranscriptionManager.swift # File transcription (✅ WORKING)
├── AIEnhancementService.swift          # AI enhancement (⚠️ PARTIAL)
├── SelectedTextService.swift           # Text selection (✅ WORKING)
├── NativeAppleTranscriptionService.swift # Apple transcription (✅ WORKING)
├── WordReplacementService.swift        # Text replacement (✅ WORKING)
├── CloudTranscription/                 # Cloud services (⚠️ PARTIAL)
├── PromptMigrationService.swift        # Prompt migration (✅ WORKING)
├── AudioDeviceManager.swift            # Audio devices (✅ WORKING)
├── AudioFileTranscriptionService.swift # File transcription (✅ WORKING)
├── AudioDeviceConfiguration.swift      # Audio config (✅ WORKING)
├── TranscriptionFallbackManager.swift  # Fallback handling (✅ WORKING)
├── TranscriptionService.swift          # Service protocol (✅ WORKING)
├── VoiceInkCSVExportService.swift     # CSV export (✅ WORKING)
├── ImportExportService.swift           # Import/export (✅ WORKING)
├── LastTranscriptionService.swift      # Recent transcriptions (✅ WORKING)
├── OllamaService.swift                 # Ollama integration (⚠️ PARTIAL)
├── ParakeetTranscriptionService.swift  # Parakeet engine (✅ WORKING)
├── PasteEligibilityService.swift       # Paste validation (✅ WORKING)
├── PolarService.swift                  # Polar integration (⚠️ PARTIAL)
├── PromptDetectionService.swift        # Prompt detection (✅ WORKING)
├── AIEnhancementOutputFilter.swift     # Output filtering (⚠️ PARTIAL)
└── AnnouncementsService.swift          # Announcements (✅ WORKING)
```

**Status**: Many legacy services are still functional and actively used. The new backend services exist but aren't integrated.

### **Views - ✅ IMPLEMENTED**
```
Views/
├── DashboardView.swift                 # Main dashboard (✅ WORKING)
├── ProjectsView.swift                  # Projects sidebar (✅ WORKING)
├── ProjectDetailView.swift             # Project details (✅ WORKING)
├── ContextManagementWindow.swift       # Context management (✅ WORKING)
├── ContextManagementSheets.swift       # Context sheets (✅ WORKING)
├── EnhancementProfileView.swift        # AI profiles (✅ WORKING)
├── ContentView.swift                   # Main content (✅ WORKING)
├── ContextInspectorView.swift          # Context inspection (✅ WORKING)
├── TranscriptionHistoryView.swift      # History view (✅ WORKING)
├── TranscriptionCard.swift             # Transcription display (✅ WORKING)
├── ModelSettingsView.swift             # Model configuration (✅ WORKING)
├── PermissionsView.swift               # Permission management (✅ WORKING)
├── PromptEditorView.swift              # Prompt editing (✅ WORKING)
├── LicenseManagementView.swift         # License management (✅ WORKING)
├── LicenseView.swift                   # License display (✅ WORKING)
├── MenuBarView.swift                   # Menu bar (✅ WORKING)
├── KeyboardShortcutView.swift          # Shortcut configuration (✅ WORKING)
├── AudioTranscribeView.swift           # Audio transcription (✅ WORKING)
├── AudioPlayerView.swift               # Audio playback (✅ WORKING)
├── Common/                             # Shared components
├── Components/                         # Reusable components
├── Workflows/                          # Guided workflows
├── Projects/                           # Project-specific views
├── Settings/                           # Configuration views
├── Recorder/                           # Recording interface
├── Onboarding/                         # Setup guides
├── AI Models/                          # AI model configuration
└── Dictionary/                         # Dictionary management
```

**Status**: All UI views are implemented and functional. The interface is complete but not connected to the new backend.

### **PowerMode - ⚠️ PARTIALLY IMPLEMENTED**
```
PowerMode/
├── PowerModeView.swift                 # Main Power Mode interface
├── PowerModeViewComponents.swift       # Power Mode components
└── PowerModeSettings.swift             # Power Mode configuration
```

**Status**: Power Mode UI exists but isn't connected to the new backend services.

## 🔄 **Integration Status**

### **What's Connected**
- ✅ **Basic App**: VoiceInk launches and shows dashboard
- ✅ **Projects UI**: Projects sidebar and basic project management
- ✅ **Legacy Services**: Most existing functionality still works
- ✅ **SwiftData**: Database models and basic persistence

### **What's Not Connected**
- ❌ **New Backend**: UI doesn't use VoiceInkBackendRegistry
- ❌ **Source Plugins**: GitIngest, MCP, and Manual Files plugins aren't executed
- ❌ **Context Assembly**: Advanced context features aren't functional
- ❌ **Chat Streams**: Real-time chat integration isn't working
- ❌ **Power Mode**: AI enhancement profiles aren't connected to backend

## 🚧 **Current Development State**

### **Phase 1: Foundation (COMPLETED)**
- ✅ SwiftData migration from Core Data
- ✅ New backend architecture definition
- ✅ Plugin system implementation
- ✅ Basic models and services

### **Phase 2: Integration (IN PROGRESS)**
- ⚠️ Connect UI to new backend services
- ⚠️ Integrate source plugins with Projects view
- ⚠️ Connect Power Mode to context assembly
- ⚠️ Implement context management workflows

### **Phase 3: Testing & Polish (PENDING)**
- ❌ End-to-end testing of new features
- ❌ Performance optimization
- ❌ User experience refinement
- ❌ Documentation updates

## 🎯 **Next Steps for Development**

### **Immediate Priorities**
1. **Connect Projects View to Backend**: Integrate ProjectRegistry with ProjectsView
2. **Activate Source Plugins**: Connect GitIngest, MCP, and Manual Files plugins to UI
3. **Implement Context Assembly**: Connect context composition to Projects interface
4. **Integrate Power Mode**: Connect AI enhancement profiles to backend services

### **Medium Term**
1. **End-to-End Testing**: Verify all new features work together
2. **Performance Optimization**: Ensure context assembly meets <200ms target
3. **User Experience**: Refine workflows and reduce complexity
4. **Documentation**: Update user guides and developer documentation

### **Long Term**
1. **Plugin Ecosystem**: Enable third-party source plugins
2. **Advanced Features**: Implement advanced context analysis
3. **Performance Monitoring**: Add metrics and optimization tools
4. **User Feedback**: Iterate based on real-world usage

## 🔧 **Development Guidelines**

### **Current Architecture**
- **Frontend**: SwiftUI with SwiftData (✅ WORKING)
- **Backend**: Plugin-based architecture with actor isolation (✅ IMPLEMENTED, ❌ NOT CONNECTED)
- **Data Flow**: Legacy services → New backend services → UI (⚠️ PARTIAL)

### **Code Organization**
- **Models**: SwiftData models in `Models/` directory
- **Services**: Legacy services in `Services/`, new backend in `Services/Backend/`
- **Views**: SwiftUI views in `Views/` directory
- **Plugins**: Source plugins in `Services/Backend/Plugins/`

### **Integration Points**
- **Projects**: Use `ProjectRegistry.shared` for project management
- **Context**: Use `EnhancedContextAssemblyService.shared` for context composition
- **Plugins**: Use `PluginRegistry.shared` for source plugin management
- **Chat**: Use `ChatStreamService.shared` for real-time chat integration

## 📚 **Documentation Status**

### **Current Files**
- **CLAUDE.md** (this file): ✅ Up-to-date technical documentation
- **.cursorrules**: ✅ Current development guidelines
- **README.md**: ✅ User-facing project overview
- **BUILDING.md**: ✅ Build instructions
- **docs/**: ❌ Legacy documentation (mostly outdated)

### **Documentation Needs**
- **User Guide**: How to use the new context management features
- **Developer Guide**: How to integrate with the new backend
- **API Reference**: Documentation for new services and plugins
- **Migration Guide**: How to transition from legacy to new features

## 🎉 **Summary**

VoiceInk has successfully completed the foundation phase with a new SwiftData-based architecture and plugin-based backend system. The application launches successfully and has a complete UI, but the new backend features aren't yet connected to the interface.

**Current Status**: Foundation complete, integration in progress
**Next Phase**: Connect UI to backend services and activate source plugins
**Timeline**: Ready for active development to complete the integration phase

The codebase is well-structured and ready for the next phase of development to bring the advanced context management and AI enhancement features to life.