# Building VoiceInk

This guide provides detailed instructions for building VoiceInk from source with all features including GitIngest integration.

## Prerequisites

Before you begin, ensure you have:
- macOS 14.0 or later (macOS 15.0+ recommended)
- Xcode 15.x+ with Command Line Tools
- Python 3.8+ (for GitIngest integration)
- Apple Silicon Mac (M1/M2/M3) recommended for optimal performance

## Building whisper.cpp Framework

1. Clone and build whisper.cpp:
```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
./build-xcframework.sh
```
This will create the XCFramework at `build-apple/whisper.xcframework`.

## Building VoiceInk

1. Clone the VoiceInk repository:
```bash
git clone https://github.com/Beingpax/VoiceInk.git
cd VoiceInk
```

2. Add the whisper.xcframework to your project:
   - Drag and drop `../whisper.cpp/build-apple/whisper.xcframework` into the project navigator, or
   - Add it manually in the "Frameworks, Libraries, and Embedded Content" section of project settings

3. Set Up GitIngest Integration (Optional)
   - Run the setup script: `python VoiceInk/Resources/setup_gitingest.py`
   - This creates an isolated Python environment with GitIngest installed
   - Alternatively, install GitIngest system-wide: `pip install gitingest`

4. Build and Run
   - Build the project using Cmd+B or Product > Build
   - Run the project using Cmd+R or Product > Run

## Backend Architecture 2.0

VoiceInk 2.0 features a completely redesigned backend architecture with plugin-based source management:

### **Built-in Source Plugins**
- **GitIngest Plugin**: Multi-job repository analysis with artifact preview
- **MCP Crawler Plugin**: Web scraping via crawl4ai-mcp-server integration
- **Manual Files Plugin**: .md/.json file selection with change detection
- **Chat Stream Plugin**: Real-time Cursor/Claude Code terminal binding

### **Plugin Development**
The new architecture uses a stable `SourcePlugin` protocol for extensibility:
```swift
public protocol SourcePlugin: Actor {
    associatedtype Config: Codable
    associatedtype Artifact: ContentArtifact
    
    func configure(_ config: Config) async throws
    func planJobs() async throws -> [JobSpec]
    func run(_ job: JobSpec) async throws -> [Artifact]
    func emitArtifacts() async throws -> [Artifact]
    func cancel() async
    func cleanup() async
}
```

## Development Setup

1. **Xcode Configuration**
   - Ensure you have the latest Xcode version
   - Install any required Xcode Command Line Tools

2. **Dependencies**
   - The project uses [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for transcription
   - Ensure the whisper.xcframework is properly linked in your Xcode project
   - Test the whisper.cpp installation independently before proceeding

3. **Building for Development**
   - Use the Debug configuration for development
   - Enable relevant debugging options in Xcode

4. **Testing**
   - Run the test suite before making changes
   - Ensure all tests pass after your modifications
   - Use `BackendIntegrationTestSuite` for backend functionality
   - Use `PerformanceBenchmarkSuite` for performance validation
   - Use `MockingFramework` for isolated component testing

## Troubleshooting

### Build Issues
If you encounter any build issues:
1. Clean the build folder (Cmd+Shift+K)
2. Clean the build cache (Cmd+Shift+K twice)
3. Check Xcode and macOS versions
4. Verify all dependencies are properly installed
5. Make sure whisper.xcframework is properly built and linked

### Backend Architecture Issues
If the new backend features aren't working:
1. **Service Initialization**: Check that `VoiceInkBackendRegistry` initializes correctly
2. **Plugin Registration**: Verify all source plugins are properly registered
3. **Permissions**: Ensure the app has necessary file system and network permissions
4. **Configuration**: Check UserDefaults for feature flags and settings
5. **Logs**: Check Console.app for VoiceInk logs with subsystem `BackendRegistry`

### Common Error Solutions
- **"Backend services not initialized"**: Check `VoiceInkBackendRegistry` initialization
- **"Plugin not found"**: Verify plugin registration in the backend registry
- **"Context assembly timeout"**: Check performance targets and resource usage
- **"Plugin execution failed"**: Review plugin configuration and error logs

For more help, please check the [issues](https://github.com/Beingpax/VoiceInk/issues) section or create a new issue.

---

## 🚀 **New Architecture Features**

### **Performance Targets**
- **Context Assembly**: <200ms target for AI enhancement
- **Chat Harvest**: <150ms target for real-time chat integration
- **Job Scheduling**: <50ms target for plugin execution
- **Resource Management**: Efficient back-pressure and throttling

### **Plugin System**
- **Extensible Architecture**: Easy to add new data sources
- **Stable Interfaces**: Consistent plugin protocol
- **Actor Isolation**: Thread-safe concurrency
- **Content Deduplication**: SHA-256 based storage optimization

### **Real-Time Integration**
- **Chat Streams**: Live Cursor and Claude Code terminal binding
- **MCP Crawling**: Web scraping via Model Context Protocol
- **Multi-Source Assembly**: Intelligent context composition
- **Performance Monitoring**: Built-in metrics and health checks

The new backend architecture provides a modern, scalable foundation for VoiceInk's future development while maintaining the privacy-first, performance-focused design principles.

---

## 📚 **Documentation Management**

### **Core Documentation Files**
VoiceInk maintains exactly two core documentation files:
- **`CLAUDE.md`** - Comprehensive project documentation and architecture
- **`.cursorrules`** - Development rules and coding standards

### **Documentation Synchronization**
- **MUST**: Keep both files synchronized with current project status
- **MUST**: Update both files when making architectural changes
- **NEVER**: Create additional standalone documentation files
- **NEVER**: Store project information in README.md or other files

### **Build Documentation Updates**
When updating build instructions or architecture:
1. Update `CLAUDE.md` with technical details and implementation
2. Update `.cursorrules` with development rules and patterns
3. Ensure both files reflect the same current state
4. Include documentation updates in commits with code changes

This ensures all team members have access to consistent, up-to-date information about the project. 