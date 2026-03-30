# Voice Input for AddTransaction Note Field — Design Spec

**Date:** 2026-03-30
**Status:** Approved

## Overview

Add a microphone button to the note field in `AddTransactionView`. Tapping it starts voice recording via the existing `SpeechClient`; partial transcription results are appended to any existing note text (append mode). Tapping again stops recording. The final text stays in the note field for editing before saving.

---

## Scope

**In scope:**
- `AddTransactionFeature` state/action/reducer changes
- `AddTransactionView` note field UI update
- Inline error display for speech errors

**Out of scope:**
- Voice input in other fields (amount, tags)
- New localization keys (reuse existing `speech_*` keys from MainTabView)

---

## AddTransactionFeature Changes

### State additions

```swift
public var isRecording: Bool = false
public var speechError: String? = nil
var noteBeforeRecording: String = ""   // internal; saves note prefix at recording start
```

### Action additions

```swift
case recordingTapped
case transcriptionUpdated(String)   // full transcript so far (partial result from SpeechClient)
case transcriptionFailed
```

### Dependency addition

```swift
@Dependency(\.speechClient) var speechClient
```

### CancelID addition

```swift
case speechRecording   // add to existing private enum CancelID
```

---

## Reducer Logic

### recordingTapped — start recording

```
guard !state.isRecording else { → stop branch below }
let granted = await speechClient.requestPermission()
if !granted:
    state.speechError = String(localized: "speech_permission_denied_error")
    return .none
state.noteBeforeRecording = state.note
state.isRecording = true
state.speechError = nil
return .run { send in
    for try await text in speechClient.startRecording() {
        await send(.transcriptionUpdated(text))
    }
} catch: { _, send in
    await send(.transcriptionFailed)
}
.cancellable(id: CancelID.speechRecording)
```

### recordingTapped — stop recording

```
state.isRecording = false
speechClient.stopRecording()
return .cancel(id: CancelID.speechRecording)
```

### transcriptionUpdated(text)

SpeechClient emits full transcription so far on each partial result (not incremental delta).
Append to prefix captured at recording start:

```
let prefix = state.noteBeforeRecording
state.note = prefix.isEmpty ? text : prefix + " " + text
```

### transcriptionFailed

```
state.isRecording = false
state.speechError = String(localized: "speech_recognition_failed_error")
speechClient.stopRecording()
return .cancel(id: CancelID.speechRecording)
```

### dismiss (existing action — add guard)

```
// existing dismiss logic…
if state.isRecording:
    state.isRecording = false
    speechClient.stopRecording()
    cancel(.speechRecording)
```

---

## View Changes (AddTransactionView)

### Note field HStack

Current:
```swift
HStack {
    TextField(...)
    if store.isBackgroundParsingNote { ProgressView() }
}
```

New:
```swift
VStack(alignment: .leading, spacing: 4) {
    if store.isRecording {
        HStack(spacing: 4) {
            Circle().fill(Color.Design.expenseRed).frame(width: 7, height: 7)
            Text(String(localized: "speech_recording_label"))
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.expenseRed)
        }
    }
    HStack {
        TextField(String(localized: "add_transaction_note_placeholder"), text: ...)
            .padding(.vertical, 12)
        if store.isBackgroundParsingNote {
            ProgressView().controlSize(.small)
        } else {
            Button { store.send(.recordingTapped) } label: {
                Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(store.isRecording ? Color.Design.expenseRed : Color.Design.textTertiary)
            }
        }
    }
    if let error = store.speechError {
        Text(error)
            .font(Font.Design.caption)
            .foregroundStyle(Color.Design.expenseRed)
    }
}
.padding(.horizontal, 16)
```

Remove the previous `.padding(.horizontal, 16)` on the HStack — it now wraps in VStack which carries the padding.

---

## Localisation

No new keys needed. Reuses:
- `speech_permission_denied_error` — existing
- `speech_recognition_failed_error` — existing
- `speech_recording_label` — existing

---

## Testing (Swift Testing)

```swift
@Suite("AddTransactionFeature — voice input")
struct AddTransactionVoiceTests {
    @Test("recordingTapped: permission denied sets speechError")
    @Test("recordingTapped: permission granted sets isRecording + saves noteBeforeRecording")
    @Test("transcriptionUpdated: appends to noteBeforeRecording")
    @Test("transcriptionUpdated: sets note directly when noteBeforeRecording is empty")
    @Test("transcriptionFailed: sets speechError, clears isRecording")
    @Test("recordingTapped while recording: stops recording, clears isRecording")
    @Test("dismiss while recording: stops recording before dismissing")
}
```
