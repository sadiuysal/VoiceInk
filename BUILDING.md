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

## GitIngest Setup

VoiceInk includes GitIngest integration for comprehensive repository analysis:

### Automatic Setup
The app will automatically create a Python environment on first use when GitIngest features are enabled.

### Manual Setup
If you prefer manual setup:
```bash
cd VoiceInk/Resources
python setup_gitingest.py
```

### System-wide Installation
```bash
pip install gitingest
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

## Troubleshooting

### Build Issues
If you encounter any build issues:
1. Clean the build folder (Cmd+Shift+K)
2. Clean the build cache (Cmd+Shift+K twice)
3. Check Xcode and macOS versions
4. Verify all dependencies are properly installed
5. Make sure whisper.xcframework is properly built and linked

### GitIngest Issues
If GitIngest features aren't working:
1. **Python Environment**: Check that Python 3.8+ is installed
2. **GitIngest Installation**: Verify with `python -c "import gitingest; print('OK')"`
3. **Permissions**: Ensure the app has necessary file system permissions
4. **Network**: For private repositories, verify GitHub token configuration
5. **Logs**: Check Console.app for VoiceInk logs with subsystem `GitIngestService`

### Common Error Solutions
- **"GitIngest not available"**: Run the setup script or install GitIngest manually
- **"Repository sync failed"**: Check repository permissions and network connectivity
- **"Python environment not found"**: Verify Python installation and PATH configuration

For more help, please check the [issues](https://github.com/Beingpax/VoiceInk/issues) section or create a new issue. 