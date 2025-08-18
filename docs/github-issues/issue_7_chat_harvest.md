# Implement ChatHarvestService for Cursor Chat

## Summary
Build a service that captures the last N messages from Cursor's chat window when the VoiceInk hotkey is pressed while Cursor is focused. This context is transient and only attached to the current enhancement session.

## Problem Statement
To provide automatic chat history context for AI enhancement, we need a service that:
- Detects when Cursor is the frontmost application
- Identifies when focus is within Cursor's chat interface
- Extracts recent conversation messages using Accessibility APIs
- Parses user vs assistant messages with role detection
- Respects strict time limits to avoid UI blocking
- Fails gracefully when Cursor isn't available or accessible

## Tasks
- [ ] Create `ChatHarvestService` with core method signature:
  ```swift
  func harvestLastMessagesIfCursorContext(
      maxMessages: Int, 
      tokenCap: Int, 
      codeOnly: Bool
  ) -> ChatSnippet?
  ```
- [ ] Implement Cursor detection logic
  - [ ] Check frontmost application bundle identifier
  - [ ] Fallback to application name matching
  - [ ] Validate application is Cursor (bundle: `com.todesktop.230313mzl4w4u92`)
- [ ] Build Accessibility API traversal
  - [ ] Get focused window and active element
  - [ ] Breadth-first search for chat container nodes
  - [ ] Handle Electron app accessibility hierarchy
- [ ] Implement chat message parsing
  - [ ] Detect message role patterns (User/Assistant/You/AI)
  - [ ] Extract text content from accessibility nodes
  - [ ] Handle code blocks and formatted content
  - [ ] Apply token counting and limits
- [ ] Add filtering options
  - [ ] Code-only mode (extract just code fences)
  - [ ] Message count limiting (last N messages)
  - [ ] Token budget enforcement
- [ ] Implement safety and performance measures
  - [ ] Hard timeout limit (150ms maximum)
  - [ ] Maximum node traversal limit (2000 nodes)
  - [ ] Graceful degradation on errors
  - [ ] No modifications to Cursor state

## Data Structures
```swift
struct ChatSnippet {
    let threadTitle: String?
    let messages: [ChatMessage]
    let capturedAt: Date
    let tokenCount: Int
}

struct ChatMessage {
    let role: MessageRole
    let content: String
    let timestamp: Date?
}

enum MessageRole {
    case user
    case assistant
    case system
}
```

## Acceptance Criteria
- [ ] When hotkey is pressed inside Cursor's chat window, service captures last N messages
- [ ] Pressing hotkey in Cursor editor (not chat) returns nil
- [ ] Pressing hotkey in non-Cursor apps returns nil  
- [ ] Service completes within 150ms timeout limit
- [ ] Accessibility denied scenario handled gracefully
- [ ] Unit tests use mock accessibility trees to verify parsing logic
- [ ] Integration tests with simulated Cursor environments
- [ ] No memory leaks during repeated harvesting

## Files to Create
- `VoiceInk/Services/ChatHarvestService.swift` (new)
- `VoiceInk/Services/AccessibilityHelper.swift` (new utility)
- `VoiceInk/Models/ChatSnippet.swift` (new model)
- `VoiceInk/Models/ChatMessage.swift` (new model)
- `VoiceInkTests/Services/ChatHarvestServiceTests.swift` (new)
- `VoiceInkTests/Mocks/MockAccessibilityElement.swift` (new)

## Files to Modify
- `VoiceInk/Services/UserDefaultsManager.swift` (add chat harvest settings)

## Technical Implementation Notes

### Accessibility API Usage
```swift
// Check if focused element is in a chat context
let focusedElement = AXUIElementCopyAttributeValue(
    systemWideElement, 
    kAXFocusedUIElementAttribute as CFString, 
    &focusedElement
)

// Traverse hierarchy looking for chat indicators
func findChatContainer(from element: AXUIElement) -> AXUIElement? {
    // Look for role patterns, aria-labels, or structural indicators
    // Common patterns: AXWebArea, AXGroup with chat-related labels
}
```

### Cursor Bundle Identification
- Primary: `com.todesktop.230313mzl4w4u92`
- Fallback: Application name contains "Cursor"
- Version tolerance for future Cursor updates

### Message Role Detection Heuristics
1. Look for UI elements labeled "You", "User", "Assistant", "AI"
2. Detect avatar patterns or role indicators
3. Fallback to alternating message assumption
4. Handle multi-turn conversations

## Integration Points
- Called from `HotkeyManager` during hotkey processing
- Results passed to `ContextBindingService` for enhancement
- Settings managed through `UserDefaultsManager`

## Privacy and Security
- Read-only operations on Cursor's accessibility tree
- No keyboard input injection or focus manipulation
- Local processing only, no network calls
- Captured content is ephemeral (not persisted)

## Dependencies
- Existing Accessibility permissions (already requested by VoiceInk)
- Issue #1 (Core Models) for ChatSnippet structure

## Estimated Effort
Large (5-6 days) - Complex accessibility work with comprehensive testing