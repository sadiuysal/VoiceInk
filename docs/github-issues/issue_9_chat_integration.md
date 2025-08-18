# Integrate Chat Harvest into ContextBindingService

## Summary
Extend the ContextBindingService to include chat snippets in the payload when applicable, creating a unified context composition system that combines project context packs with ephemeral chat history.

## Problem Statement
Currently, VoiceInk has separate context sources (clipboard, screen capture, filesystem). We need to integrate the new chat harvest capability into a unified context binding system that:
- Combines project context packs with chat snippets seamlessly
- Triggers chat harvest at the right moment during hotkey processing
- Formats chat content appropriately for AI enhancement prompts
- Maintains separation between persistent and ephemeral context

## Tasks

### Extend ContextPayload Structure
- [ ] Modify `ContextPayload` to include `chatSnippets: [ChatSnippet]` array
- [ ] Add metadata fields for chat context (captureTime, source app, etc.)
- [ ] Ensure serialization compatibility for logging/debugging
- [ ] Maintain backward compatibility with existing context sources

### Chat Harvest Integration
- [ ] Add chat harvest trigger to hotkey processing pipeline
- [ ] Integrate `ChatHarvestService.harvestLastMessagesIfCursorContext()` call
- [ ] Handle chat harvest timeout and error scenarios gracefully
- [ ] Ensure chat harvest doesn't delay transcription start

### Prompt Template Updates
- [ ] Create dedicated chat context section in enhancement prompts
- [ ] Format chat messages with clear role separation
- [ ] Add conversation thread context (thread title, participant count)
- [ ] Implement token budget management across all context sources
- [ ] Maintain clear separation between persistent context and chat snippets

### Context Composition Logic
- [ ] Priority system for context inclusion (packs → chat → other sources)
- [ ] Token budget distribution across context types
- [ ] Intelligent truncation when context exceeds limits
- [ ] Context freshness indicators (how recent is each source)

### Settings Integration
- [ ] Respect chat harvest enable/disable setting
- [ ] Apply message count and token limits from user preferences
- [ ] Handle code-only filtering when enabled
- [ ] Provide fallback behavior when chat harvest fails

## Enhanced Context Binding Flow
```
1. Hotkey Pressed
   ↓
2. Determine Active Profile (PowerMode)
   ↓
3. Get Bound Context Packs for Profile
   ↓
4. Compose Pack-based Context (Dictionary Terms)
   ↓
5. IF Cursor is Frontmost AND Chat Harvest Enabled:
   - Try Chat Harvest (with timeout)
   - Include results if successful
   ↓
6. Add Traditional Context Sources (Clipboard, Screen)
   ↓
7. Compose Final Context Payload
   ↓
8. Send to AI Enhancement with Full Context
```

## Context Payload Structure
```swift
struct ContextPayload {
    let dictionaryEntries: [DictionaryEntry]
    let chatSnippets: [ChatSnippet]
    let clipboardContext: String?
    let screenCaptureContext: String?
    let filesystemTerms: [String]
    let metadata: ContextMetadata
}

struct ContextMetadata {
    let composedAt: Date
    let activeProfile: UUID?
    let boundPackIds: [UUID]
    let chatHarvestAttempted: Bool
    let chatHarvestSuccessful: Bool
    let totalTokenCount: Int
}
```

## Prompt Template Format
```
System: You are an AI assistant helping with [task description]

<PROJECT_CONTEXT>
Dictionary Terms: term1, term2, term3...
Active Files: file1.swift, file2.md...
</PROJECT_CONTEXT>

<CONVERSATION_CONTEXT>
Recent Chat from Cursor IDE:
Thread: "Implementing user authentication"

User: How do I set up JWT tokens in Swift?
Assistant: To implement JWT tokens in Swift, you'll need...
User: What about refresh token handling?
Assistant: For refresh tokens, you should...
</CONVERSATION_CONTEXT>

<ADDITIONAL_CONTEXT>
Clipboard: [clipboard content if available]
Screen: [screen context if available]
</ADDITIONAL_CONTEXT>

<TRANSCRIPT>
[User's voice transcription]
</TRANSCRIPT>
```

## Acceptance Criteria
- [ ] When hotkey is triggered within Cursor chat, captured chat snippet appears in enhancement prompt
- [ ] When outside Cursor chat, no chat snippet is injected (silent fallback)
- [ ] Chat integration doesn't interfere with other context sources
- [ ] Token budget is properly managed across all context types
- [ ] Enhancement quality improves with relevant chat context
- [ ] Hotkey responsiveness remains fast (< 200ms total context composition)
- [ ] Settings properly control chat harvest behavior
- [ ] Error scenarios don't break the enhancement pipeline

## Files to Modify
- `VoiceInk/Services/ContextBindingService.swift` (extend from Issue #6)
- `VoiceInk/Services/AIEnhancementService.swift` (update prompt templates)
- `VoiceInk/HotkeyManager.swift` (trigger chat harvest during hotkey processing)
- `VoiceInk/Models/ContextPayload.swift` (extend structure)

## Files to Create
- `VoiceInk/Services/ContextComposer.swift` (centralized context logic)
- `VoiceInk/Templates/ChatContextTemplate.swift` (chat formatting)

## Integration Points

### With HotkeyManager
```swift
// In HotkeyManager.handleToggleMiniRecorder()
private func handleToggleMiniRecorder() async {
    // ... existing logic ...
    
    // Trigger context composition including chat harvest
    let contextPayload = await ContextBindingService.shared.composeContext(
        for: activeProfile,
        harvestChat: true
    )
    
    // Store context for enhancement pipeline
    whisperState.setActiveContext(contextPayload)
    
    // ... continue with transcription ...
}
```

### With Enhancement Service
```swift
// In AIEnhancementService.enhanceText()
func enhanceText(_ text: String, context: ContextPayload?) async throws -> String {
    let systemMessage = composeSystemMessage(
        basePrompt: selectedPrompt,
        context: context
    )
    // ... enhancement logic ...
}
```

## Performance Considerations
- Chat harvest timeout must be strictly enforced (150ms max)
- Context composition should be cached when possible
- Large chat snippets should be intelligently truncated
- Background processing for non-critical context updates

## Privacy and Security
- Chat snippets are ephemeral (not persisted to disk)
- User can disable chat harvest entirely via settings
- Chat content is only used for current enhancement session
- No network transmission of captured chat content

## Dependencies
- Issue #6 (ContextBindingService) - requires base context binding implementation
- Issue #7 (ChatHarvestService) - requires chat capture functionality  
- Issue #8 (Settings) - requires chat harvest configuration options

## Estimated Effort
Medium (3-4 days) - Integration work with careful testing of timing and fallback scenarios