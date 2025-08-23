# VoiceInk

<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>VoiceInk</h1>
  <p>Voice to text app for macOS to transcribe what you say to text almost instantly</p>
</div>

## 🎉 **Project Status: Foundation Complete, Integration In Progress**

**VoiceInk has successfully completed the foundation phase with a new SwiftData-based architecture and plugin-based backend system. The application launches successfully and has a complete UI, but the new backend features aren't yet connected to the interface.**

---

## 🚀 **What's New**

### **✅ Foundation Phase COMPLETED**
- **SwiftData Migration**: Successfully migrated from Core Data to SwiftData
- **New Backend Architecture**: Plugin-based backend with actor isolation and content-addressable storage
- **Complete UI**: Dashboard, Projects sidebar, and all interface components are functional
- **Database**: SwiftData container initializes successfully with new schema

### **⚠️ Integration Phase IN PROGRESS**
- **Backend Services**: All new backend services are implemented but not connected to UI
- **Source Plugins**: GitIngest, MCP, and Manual Files plugins exist but aren't actively used
- **Context Assembly**: Service exists but not connected to Projects interface
- **Power Mode**: AI enhancement profiles exist but aren't connected to backend

---

## ✨ **Features**

### **Core Functionality (✅ WORKING)**
- **Voice Transcription**: Real-time speech-to-text with local processing
- **Basic AI Enhancement**: Intelligent text improvement and formatting
- **Project Management**: Basic project creation and organization
- **Audio Processing**: Recording, playback, and device management

### **Advanced Features (⚠️ IMPLEMENTED BUT NOT CONNECTED)**
- **Context Management**: Advanced project context gathering and composition
- **Source Plugins**: Git repository analysis, web crawling, and file indexing
- **AI Enhancement Profiles**: Application-specific AI behavior configuration
- **Real-time Chat Integration**: Cursor IDE and terminal integration

---

## 🏗️ **Architecture**

### **Current State**
- **Frontend**: SwiftUI with SwiftData (✅ COMPLETE)
- **Backend**: Plugin-based architecture with actor isolation (✅ IMPLEMENTED, ❌ NOT CONNECTED)
- **Data Flow**: Legacy services → New backend services → UI (⚠️ PARTIAL)

### **Core Systems**
- **SwiftData Models**: Project, ContextSource, ContextPack, DictionaryEntry
- **New Backend**: ProjectRegistry, IngestionOrchestrator, SourcePlugin system
- **Legacy Services**: Most existing functionality still works through existing services
- **UI Components**: Complete interface ready for backend integration

---

## 📋 **Implementation Status**

### **✅ Phase 1: Foundation (COMPLETED)**
- SwiftData migration from Core Data
- New backend architecture definition
- Plugin system implementation
- Basic models and services
- Complete UI interface

### **⚠️ Phase 2: Integration (IN PROGRESS)**
- Connect UI to new backend services
- Integrate source plugins with Projects view
- Connect Power Mode to context assembly
- Implement context management workflows

### **❌ Phase 3: Testing & Polish (PENDING)**
- End-to-end testing of new features
- Performance optimization
- User experience refinement
- Documentation updates

---

## 🚀 **Getting Started**

### **Prerequisites**
- macOS 15+ (Apple Silicon recommended)
- Xcode 15+
- `whisper.cpp` for local transcription

### **Build Instructions**
See [CLAUDE.md](CLAUDE.md) for detailed build guide.

---

## 📚 **Documentation**

- **`CLAUDE.md`**: Comprehensive technical documentation and current status
- **`.cursorrules`**: Development guidelines and current priorities
- **`docs/`**: Legacy documentation (mostly outdated)

---

## 🎯 **Success Metrics**

### **Foundation Goals (ALL ACHIEVED)**
- ✅ SwiftData migration successful
- ✅ New backend architecture implemented
- ✅ Complete UI interface
- ✅ Application launches without errors

### **Integration Goals (IN PROGRESS)**
- ⚠️ Projects view connected to backend (IN PROGRESS)
- ❌ Source plugins executing and providing data
- ❌ Advanced context features functional
- ❌ Power Mode connected to backend

---

## 🔧 **Development**

### **Current Focus**
- **Integration Team**: Connecting UI to new backend services
- **Backend Team**: Activating source plugins and context assembly
- **UI Team**: Integrating Power Mode with backend services

### **Code Style**
- SwiftUI with SwiftData
- `@MainActor` for UI operations
- Async/await for concurrency
- Protocol-based architecture for extensibility

---

## 🎉 **Project Status Summary**

**Overall Status**: ✅ **FOUNDATION COMPLETE** + ⚠️ **INTEGRATION IN PROGRESS**

VoiceInk has successfully completed the foundation phase with a new SwiftData-based architecture and plugin-based backend system. The application launches successfully and has a complete UI, but the new backend features aren't yet connected to the interface.

**Current Focus**: Integration phase - connecting UI to backend services
**Development Approach**: Gradual migration from legacy to new backend
**Success Criteria**: All new features functional and connected to UI

**Next Phase**: 🚀 **Complete Integration** - Connect all new backend features to the UI

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
