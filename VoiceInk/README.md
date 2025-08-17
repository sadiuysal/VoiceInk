# VoiceInk

A native macOS voice-to-text transcription application with context-aware AI enhancement.

## Features

- 🎙️ **Real-time transcription** with 99% accuracy using Whisper models
- 🔒 **100% offline processing** for complete privacy
- ⚡ **Power Mode** with intelligent app detection and context awareness
- 🧠 **AI enhancement** with project-specific context
- 🎯 **Global keyboard shortcuts** for seamless workflow integration
- 📝 **Personal dictionary** with custom word replacements
- 🌐 **Filesystem context** for project-aware dictation

## System Requirements

- **macOS**: 14.0 or later
- **Hardware**: Apple Silicon (M1/M2/M3) recommended
- **Xcode**: 15.x+ for development
- **Storage**: ~500MB for dependencies and models

## Quick Start

### 1. Build Whisper Framework
```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
./build-xcframework.sh
```

### 2. Open in Xcode
```bash
open VoiceInk.xcodeproj
```

### 3. Add whisper.xcframework
- Drag `whisper.cpp/build-apple/whisper.xcframework` into project
- Set to "Embed & Sign" in target settings

### 4. Build & Run
- Product → Build (⌘B)
- Product → Run (⌘R)

## Filesystem Context Feature

VoiceInk can automatically detect your current project and build a context-aware dictionary:

### Enable Filesystem Context
```swift
// In UserDefaults
UserDefaults.standard.set(true, forKey: "UseFilesystemContext")
```

### Shell Integration (Optional)
Add to your `~/.zshrc`:
```bash
autoload -U add-zsh-hook
_voiceink_publish_cwd() { printf "%s" "$PWD" > "$HOME/.voiceink/cwd"; }
add-zsh-hook precmd _voiceink_publish_cwd
```

### What It Scans
- **Project files**: README.md, CLAUDE.md, package.json, etc.
- **Directory structure**: Folder names and organization
- **Content analysis**: Headings, code blocks, emphasis in markdown

### Privacy & Performance
- **Offline only**: No network requests
- **Local storage**: All data stays on your machine
- **Efficient updates**: Only processes changed files
- **TTL-based refresh**: 10-minute cache for performance

## Development

### Project Structure
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

### Key Services
- `FilesystemContextService`: Project context detection
- `WordReplacementService`: Custom dictionary management
- `AIEnhancementService`: Context-aware text enhancement
- `TranscriptionService`: Core transcription engine

### Testing
```bash
# Run tests
xcodebuild test -project VoiceInk.xcodeproj -scheme VoiceInk

# Clean build
xcodebuild clean -project VoiceInk.xcodeproj -scheme VoiceInk
```

## Troubleshooting

### Common Issues
1. **Microphone permission denied**: Check System Preferences → Security & Privacy
2. **Screen recording not working**: Enable in System Settings → Privacy & Security
3. **Build fails**: Ensure whisper.xcframework is properly embedded
4. **Signing errors**: Verify team selection in project settings

### Performance Tips
- Use Release configuration for production builds
- Monitor CPU usage in Activity Monitor
- Enable "Optimize for Mac" in build settings

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check the [CLAUDE.md](CLAUDE.md) for detailed setup instructions
- Review the troubleshooting section above
