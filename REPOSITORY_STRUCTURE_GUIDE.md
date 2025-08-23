# VoiceInk Repository Structure Guide

## 🎯 **Purpose of This Guide**

This guide provides a comprehensive understanding of the VoiceInk repository structure, explaining what each component does, how they relate to each other, and which parts are actively used vs. legacy. This will help you understand the codebase and plan future refactoring.

---

## 🏗️ **Repository Overview**

```
VoiceInk/                          # Main application source code
├── VoiceInk.swift                 # App entry point with SwiftData setup
├── AppDelegate.swift              # Application lifecycle management
├── WindowManager.swift            # Window management
├── MiniRecorderShortcutManager.swift  # Recording shortcuts
├── Recorder.swift                 # Audio recording functionality
├── SoundManager.swift             # Audio playback management
├── PlaybackController.swift       # Media playback control
├── HotkeyManager.swift            # Global hotkey management
├── MenuBarManager.swift           # Menu bar integration
├── MediaController.swift          # Media file handling
├── ClipboardManager.swift         # Clipboard integration
├── CursorPaster.swift             # Cursor IDE integration
├── EmailSupport.swift             # Email functionality
├── Models/                        # SwiftData data models
├── Services/                      # Business logic services
├── Views/                         # SwiftUI user interface
├── PowerMode/                     # AI enhancement features
├── Resources/                     # Assets and resources
├── Whisper/                       # Transcription engine
└── Notifications/                 # Notification handling
```

---

## 📁 **Detailed Component Analysis**

### **🔧 Core Application Files**

#### **VoiceInk.swift** - App Entry Point
- **Purpose**: Main application entry point and SwiftData setup
- **Status**: ✅ **WORKING** - Successfully handles SwiftData migration
- **Key Features**: 
  - Database reset mechanism for development
  - SwiftData container initialization
  - Error handling for migration issues
- **Usage**: Automatically runs when app launches

#### **AppDelegate.swift** - Application Lifecycle
- **Purpose**: Handles application lifecycle events
- **Status**: ✅ **WORKING** - Standard macOS app delegate
- **Key Features**: App launch, termination, and system events

#### **WindowManager.swift** - Window Management
- **Purpose**: Manages application windows and their states
- **Status**: ✅ **WORKING** - Handles window creation and management
- **Key Features**: Window positioning, sizing, and state persistence

### **🎤 Audio & Recording System**

#### **Recorder.swift** - Audio Recording
- **Purpose**: Core audio recording functionality
- **Status**: ✅ **WORKING** - Handles microphone input and recording
- **Key Features**: 
  - Real-time audio capture
  - Recording state management
  - Audio format handling

#### **SoundManager.swift** - Audio Playback
- **Purpose**: Manages audio playback and sound effects
- **Status**: ✅ **WORKING** - Handles audio output
- **Key Features**: 
  - Audio file playback
  - Sound effect management
  - Volume control

#### **PlaybackController.swift** - Media Control
- **Purpose**: Controls media playback (audio/video)
- **Status**: ✅ **WORKING** - Media playback interface
- **Key Features**: Play, pause, stop, seek functionality

#### **AudioDeviceManager.swift** - Device Management
- **Purpose**: Manages audio input/output devices
- **Status**: ✅ **WORKING** - Device selection and configuration
- **Key Features**: 
  - Device enumeration
  - Input/output selection
  - Device configuration

### **⌨️ Input & Integration**

#### **HotkeyManager.swift** - Global Hotkeys
- **Purpose**: Manages global keyboard shortcuts
- **Status**: ✅ **WORKING** - System-wide hotkey registration
- **Key Features**: 
  - Global hotkey registration
  - Shortcut customization
  - Conflict resolution

#### **MiniRecorderShortcutManager.swift** - Recording Shortcuts
- **Purpose**: Quick recording access via shortcuts
- **Status**: ✅ **WORKING** - Instant recording triggers
- **Key Features**: 
  - Quick start/stop recording
  - Shortcut-based activation
  - Recording state management

#### **CursorPaster.swift** - Cursor IDE Integration
- **Purpose**: Integrates with Cursor IDE for text insertion
- **Status**: ⚠️ **PARTIAL** - Basic integration exists
- **Key Features**: 
  - Text insertion into Cursor
  - Clipboard management
  - IDE communication

#### **ClipboardManager.swift** - Clipboard Integration
- **Purpose**: Manages system clipboard operations
- **Status**: ✅ **WORKING** - Standard clipboard functionality
- **Key Features**: 
  - Copy/paste operations
  - Clipboard monitoring
  - Content management

### **📱 User Interface Components**

#### **Views/** - SwiftUI Interface
- **Purpose**: Complete user interface implementation
- **Status**: ✅ **COMPLETE** - All UI components implemented
- **Key Components**:
  - `DashboardView.swift` - Main dashboard interface
  - `ProjectsView.swift` - Project management sidebar
  - `PowerModeView.swift` - AI enhancement profiles
  - `ContextManagementWindow.swift` - Context management interface
  - `TranscriptionHistoryView.swift` - Transcription history
  - `AudioTranscribeView.swift` - Audio transcription interface
  - `AudioPlayerView.swift` - Audio playback interface

#### **PowerMode/** - AI Enhancement
- **Purpose**: AI enhancement profile management
- **Status**: ⚠️ **IMPLEMENTED BUT NOT CONNECTED**
- **Key Features**:
  - Enhancement profile configuration
  - Application-specific behavior
  - Trigger management

### **🧠 AI & Intelligence**

#### **AIService.swift** - AI Enhancement
- **Purpose**: Core AI enhancement functionality
- **Status**: ⚠️ **PARTIAL** - Basic functionality works
- **Key Features**:
  - Text enhancement
  - AI model integration
  - Prompt management

#### **AIEnhancementService.swift** - Enhancement Engine
- **Purpose**: Advanced AI enhancement processing
- **Status**: ⚠️ **PARTIAL** - Service exists but limited integration
- **Key Features**:
  - Context-aware enhancement
  - Profile-based behavior
  - Output filtering

#### **PromptTemplates.swift** - AI Prompts
- **Purpose**: Manages AI prompt templates
- **Status**: ✅ **WORKING** - Template system functional
- **Key Features**:
  - Prompt template management
  - Custom prompt creation
  - Template versioning

### **📝 Transcription System**

#### **TranscriptionService.swift** - Service Protocol
- **Purpose**: Defines transcription service interface
- **Status**: ✅ **WORKING** - Protocol definition
- **Key Features**: Service contract for transcription providers

#### **LocalTranscriptionService.swift** - Local Processing
- **Purpose**: Handles local transcription processing
- **Status**: ✅ **WORKING** - Local transcription functional
- **Key Features**: 
  - Local audio processing
  - Whisper integration
  - Offline transcription

#### **NativeAppleTranscriptionService.swift** - Apple's Engine
- **Purpose**: Uses Apple's built-in transcription
- **Status**: ✅ **WORKING** - Apple transcription integration
- **Key Features**: 
  - System transcription
  - Language support
  - High accuracy

#### **Whisper/** - Whisper Engine
- **Purpose**: OpenAI Whisper transcription integration
- **Status**: ✅ **WORKING** - Whisper.cpp integration
- **Key Features**: 
  - Local Whisper models
  - High-quality transcription
  - Multiple language support

### **🗄️ Data & Storage**

#### **Models/** - SwiftData Models
- **Purpose**: Data models for SwiftData persistence
- **Status**: ✅ **WORKING** - Core models functional
- **Key Models**:
  - `Project.swift` - Project container with configuration
  - `ContextSource.swift` - Data source configuration
  - `ContextPack.swift` - Context collection management
  - `DictionaryEntry.swift` - AI dictionary terms
  - `Transcription.swift` - Basic transcription record

#### **UserDefaultsManager.swift** - Settings Storage
- **Purpose**: Manages application settings and preferences
- **Status**: ✅ **WORKING** - Settings persistence
- **Key Features**: 
  - Preference storage
  - Settings management
  - Configuration persistence

### **🔌 New Backend Architecture (⚠️ IMPLEMENTED BUT NOT CONNECTED)**

#### **Services/Backend/** - New Backend System
- **Purpose**: Plugin-based backend architecture
- **Status**: ⚠️ **IMPLEMENTED BUT NOT CONNECTED**
- **Key Components**:
  - `VoiceInkBackendRegistry.swift` - Service coordination
  - `ProjectRegistry.swift` - Project management hub
  - `IngestionOrchestrator.swift` - Job orchestration
  - `SourcePlugin.swift` - Plugin protocol
  - `EnhancedContextAssemblyService.swift` - Context composition
  - `ChatStreamService.swift` - Real-time chat integration

#### **Services/Backend/Plugins/** - Source Plugins
- **Purpose**: Extensible data source plugins
- **Status**: ⚠️ **IMPLEMENTED BUT NOT CONNECTED**
- **Key Plugins**:
  - `EnhancedGitIngestPlugin.swift` - Git repository analysis
  - `MCPCrawlerPlugin.swift` - Web crawling via MCP tools
  - `ManualFilesPlugin.swift` - File selection and indexing

### **🔄 Legacy Services (✅ MOSTLY WORKING)**

#### **FilesystemContextService.swift** - File Indexing
- **Purpose**: Legacy file indexing and context management
- **Status**: ❌ **LEGACY** - Not actively used
- **Key Features**: File system monitoring and indexing

#### **ContextIndexStore.swift** - Context Storage
- **Purpose**: Legacy context storage and retrieval
- **Status**: ❌ **LEGACY** - Not actively used
- **Key Features**: Context indexing and search

#### **GitService.swift** - Git Operations
- **Purpose**: Basic Git repository operations
- **Status**: ✅ **WORKING** - Git integration functional
- **Key Features**: 
  - Repository information
  - Commit history
  - Branch management

#### **SmartDefaultsService.swift** - Smart Defaults
- **Purpose**: Intelligent default value management
- **Status**: ✅ **WORKING** - Smart defaults functional
- **Key Features**: 
  - Context-aware defaults
  - User preference learning
  - Adaptive configuration

---

## 🔄 **Data Flow Architecture**

### **Current State (Legacy + New Backend)**
```
User Input → Legacy Services → UI Display
     ↓
New Backend Services (Not Connected)
     ↓
Source Plugins (Not Executing)
```

### **Target State (Fully Integrated)**
```
User Input → New Backend Services → Source Plugins → Context Assembly → UI Display
     ↓
Legacy Services (Deprecated/Removed)
```

---

## 🎯 **Integration Priorities**

### **Priority 1: Connect Projects View to Backend**
- **Files Involved**: `ProjectsView.swift`, `ProjectRegistry.swift`
- **Goal**: Use new backend for project management
- **Benefit**: Centralized project management with new architecture

### **Priority 2: Activate Source Plugins**
- **Files Involved**: All files in `Services/Backend/Plugins/`
- **Goal**: Execute plugins and provide data to UI
- **Benefit**: Extensible data source system

### **Priority 3: Implement Context Assembly**
- **Files Involved**: `EnhancedContextAssemblyService.swift`, UI components
- **Goal**: Connect context composition to Projects interface
- **Benefit**: Advanced context management features

### **Priority 4: Integrate Power Mode**
- **Files Involved**: `PowerMode/`, backend services
- **Goal**: Connect AI enhancement profiles to backend
- **Benefit**: Context-aware AI enhancement

---

## 🚫 **Common Pitfalls to Avoid**

### **Architecture Anti-patterns**
- ❌ **DON'T** create new services when backend services already exist
- ❌ **DON'T** bypass the new backend architecture for new features
- ❌ **DON'T** mix legacy and new backend calls in the same component

### **Development Anti-patterns**
- ❌ **DON'T** modify working legacy services unnecessarily
- ❌ **DON'T** create duplicate functionality between legacy and new backend
- ❌ **DON'T** ignore the plugin system when adding new data sources

---

## 🔍 **How to Use This Guide**

### **For Understanding the Codebase**
1. **Start with Core Files**: Begin with `VoiceInk.swift` and `AppDelegate.swift`
2. **Follow Data Flow**: Understand how data moves through the system
3. **Identify Integration Points**: See where new backend should connect

### **For Planning Refactoring**
1. **Map Dependencies**: Understand which components depend on each other
2. **Identify Legacy**: See which services can be deprecated
3. **Plan Integration**: Determine the order for connecting new backend

### **For Adding New Features**
1. **Check Backend**: See if backend service already exists
2. **Use New Architecture**: Prefer new backend over legacy services
3. **Follow Patterns**: Use existing integration patterns

---

## 📚 **Additional Resources**

- **`CLAUDE.md`**: Comprehensive technical documentation
- **`.cursorrules`**: Development guidelines and current priorities
- **`BUILDING.md`**: Build and setup instructions
- **`DATABASE_RESET_GUIDE.md`**: Database management for development

---

## 🎉 **Summary**

This guide provides a comprehensive understanding of the VoiceInk repository structure. The codebase has a solid foundation with a complete UI and new backend architecture, but the integration between them is incomplete.

**Key Insight**: The new backend architecture is fully implemented but not connected to the UI. The legacy services are still providing most of the functionality.

**Next Steps**: Focus on integration - connecting the UI to the new backend services and activating the source plugins to bring the advanced features to life.
