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
