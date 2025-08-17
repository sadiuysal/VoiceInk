# VoiceInk Setup Guide for macOS M1 Max

## Project Overview

VoiceInk is a native macOS voice-to-text transcription application that provides:
- 🎙️ Real-time voice transcription with 99% accuracy
- 🔒 100% offline processing for privacy
- ⚡ Power Mode with intelligent app detection
- 🧠 Context-aware AI enhancement
- 🎯 Global keyboard shortcuts
- 📝 Personal dictionary with custom word replacements

This is a Swift/SwiftUI macOS application built with Xcode, designed for macOS 14.0+.

## System Requirements

- **macOS**: 14.0 or later (current deployment target)
- **Hardware**: M1 Max is fully supported
- **Xcode**: Latest version recommended
- **Storage**: ~500MB for dependencies and models

## Dependencies Overview

### Core Frameworks
- **whisper.cpp**: High-performance Whisper model inference (requires manual build)
- **FluidAudio**: Parakeet model implementation
- **Sparkle**: Auto-update functionality
- **KeyboardShortcuts**: Global hotkey management
- **LaunchAtLogin**: System startup integration
- **MediaRemoteAdapter**: Media playback control
- **Zip**: File compression utilities

### Swift Package Dependencies
All Swift packages are managed via SPM and auto-resolved by Xcode:
- KeyboardShortcuts
- LaunchAtLogin  
- Sparkle
- MediaRemoteAdapter
- FluidAudio
- Zip

## Setup Instructions

### 1. Clone Repository
```bash
git clone https://github.com/Beingpax/VoiceInk.git
cd VoiceInk
```

### 2. Build whisper.cpp Framework
This is the most critical dependency requiring manual setup:

```bash
# Clone whisper.cpp in parent directory
cd ..
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build XCFramework for macOS (optimized for Apple Silicon)
./build-xcframework.sh
```

This creates: `build-apple/whisper.xcframework`

### 3. Configure Xcode Project
```bash
cd ../VoiceInk
open VoiceInk.xcodeproj
```

In Xcode:
1. **Add whisper.xcframework**:
   - Drag `../whisper.cpp/build-apple/whisper.xcframework` into project navigator
   - Or manually add in "Frameworks, Libraries, and Embedded Content"

2. **Verify Swift Package Dependencies**:
   - Go to File → Add Package Dependencies (if needed)
   - All packages should auto-resolve from Package.resolved

3. **Build Configuration**:
   - Select "VoiceInk" scheme
   - Choose "My Mac (Apple Silicon)" as destination
   - Minimum deployment: macOS 14.0

### 4. Grant Required Permissions
VoiceInk requires these system permissions:
- **Microphone**: For audio recording
- **Screen Recording**: For context awareness
- **Apple Events**: For browser URL detection

These will be requested on first launch.

### 5. Build and Run
```bash
# In Xcode
cmd+B  # Build
cmd+R  # Run
```

Or via command line:
```bash
xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug
```

## Development Workflow

### Testing
```bash
# Run tests
cmd+U  # In Xcode
# Or
xcodebuild test -project VoiceInk.xcodeproj -scheme VoiceInk
```

### Building for Release
```bash
xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Release
```

### Clean Build
```bash
# In Xcode
cmd+shift+K  # Clean build folder
# Or
xcodebuild clean -project VoiceInk.xcodeproj -scheme VoiceInk
```

## Customization for Cursor/Claude Code Integration

### Key Components for Text Input Integration

1. **Text Pasting**: `VoiceInk/CursorPaster.swift:*`
2. **App Detection**: `VoiceInk/PowerMode/ActiveWindowService.swift:*`
3. **Keyboard Shortcuts**: `VoiceInk/HotkeyManager.swift:*`
4. **Clipboard Management**: `VoiceInk/ClipboardManager.swift:*`

### Integration Points

#### For Cursor/Claude Code Context:
- **App-specific prompts**: Modify `VoiceInk/Models/PredefinedPrompts.swift:*`
- **Power Mode configs**: Update `VoiceInk/PowerMode/PowerModeConfig.swift:*`
- **Context detection**: Enhance `VoiceInk/Services/SelectedTextService.swift:*`

#### Custom Enhancement Prompts:
```swift
// Add to PredefinedPrompts.swift
static let cursorCodePrompt = CustomPrompt(
    name: "Cursor Code Context",
    prompt: "Enhance this code comment/documentation for better Claude Code understanding...",
    isBuiltIn: true
)
```

#### App-Specific Detection:
```swift
// Add to PowerModeConfig.swift
case "com.todesktop.230313mzl4w4u92": // Cursor
    return .codingMode
case "claude-code": // Claude Code CLI
    return .technicalWriting
```

## Troubleshooting

### whisper.cpp Build Issues
```bash
# Clean and rebuild
cd whisper.cpp
make clean
./build-xcframework.sh
```

### Xcode Build Errors
1. Clean build folder: `cmd+shift+K`
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData`
3. Verify deployment target: Project Settings → macOS 14.0
4. Check code signing: Automatically manage signing

### Permission Issues
- System Preferences → Security & Privacy → Privacy
- Grant Microphone, Screen Recording, and Accessibility permissions

### Performance on M1 Max
- Enable "Optimize for Mac" in build settings
- Use Release configuration for performance testing
- Monitor CPU usage in Activity Monitor

## Project Structure for Development

```
VoiceInk/
├── Models/           # Data models and prompts
├── Services/         # Core business logic
├── Views/            # SwiftUI interfaces  
├── PowerMode/        # App-specific configurations
├── Whisper/          # Local transcription engine
├── Notifications/    # System notifications
└── Resources/        # Assets and scripts
```

## Next Steps

1. **Run the app** and verify basic functionality
2. **Test microphone recording** with global shortcuts
3. **Configure Power Mode** for Cursor/Claude Code
4. **Customize prompts** for your workflow
5. **Set up development certificates** for distribution

For issues or contributions, see the main repository issues page.