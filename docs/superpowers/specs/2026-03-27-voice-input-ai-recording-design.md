# Voice Input for AI Recording — Design Spec

**Date:** 2026-03-27
**Status:** Approved

## Overview

Replace the text-only input field in the AI recording accessory bar with a voice-first input that uses Apple's on-device Speech framework. Users tap the microphone button to start recording; transcribed text streams into the input field in real time. After stopping, the text remains editable before being sent to the existing AI extraction pipeline.

The ask mode (`.ask` / `InputPurpose`) is removed from this bar. It will be revisited as a separate feature in the Analysis tab.

---

## Scope

**In scope:**
- `SpeechClient` dependency interface (Domain) and live implementation (Core)
- `MainTabFeature` state/action changes for recording
- `MainTabView` expanded AI input UI redesign
- Info.plist permission keys
- Removal of ask mode from the accessory bar

**Out of scope:**
- Voice input in `AddTransactionView`'s note field
- Ask mode in Analysis tab (separate feature)
- Multi-locale speech recognition UI
- Offline recognition failure retry logic

---

## Architecture

### Layer Distribution

```
Apple System (Speech.framework, AVFoundation)
    ↑ only Core sees this
Core/Clients/SpeechClient.swift  — liveValue using SFSpeechRecognizer + AVAudioEngine
    ↑ via @DependencyClient interface
Domain/Clients/SpeechClient.swift  — interface + testValue
    ↑ @Dependency injection
Features/MainTab/MainTabFeature.swift  — consumes speechClient
```

Feature layer never imports `Speech` or `AVFoundation`.

---

## SpeechClient Interface (Domain)

**File:** `Domain/Clients/SpeechClient.swift`

```swift
@DependencyClient
public struct SpeechClient: Sendable {
    // Requests both microphone and speech recognition permissions
    var requestPermission: @Sendable () async -> Bool = { false }

    // Starts recording; returns a stream of partial transcription strings
    var startRecording: @Sendable () -> AsyncThrowingStream<String, Error> = { .finished }

    // Stops recording and deactivates the audio session
    var stopRecording: @Sendable () -> Void = { }
}

extension DependencyValues {
    var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}
```

The `@DependencyClient` macro automatically generates `DependencyKey` conformance with `testValue` (all closures unimplemented). Override `testValue` in the extension to provide safe defaults: `requestPermission` returns `true`, `startRecording` returns `.finished`, `stopRecording` is a no-op. Tests inject a custom stream via `withDependencies`.

---

## Core Implementation (SpeechClient.liveValue)

**File:** `Core/Clients/SpeechClient+Live.swift`

Key implementation details:

- **Recognizer locale:** `SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))`, falls back to system locale if unsupported.
- **Streaming:** `SFSpeechAudioBufferRecognitionRequest` with `shouldReportPartialResults = true`. Each partial result emits a new `String` into the `AsyncThrowingStream`.
- **Audio tap:** `AVAudioEngine.inputNode.installTap` feeds buffers to the recognition request.
- **stopRecording:** calls `audioEngine.stop()`, `recognitionRequest.endAudio()`, `recognitionTask.cancel()`, then deactivates the `AVAudioSession` so other apps can resume audio.
- **Permission:** `requestPermission()` requests `AVAudioApplication.requestRecordPermission()` and `SFSpeechRecognizer.requestAuthorization()` concurrently; returns `true` only if both are granted.

---

## MainTabFeature Changes

### State

```swift
// Removed
- var inputPurpose: InputPurpose    // .record / .ask
- var aiAnswer: String?

// Added
+ var isRecording: Bool = false
```

### Actions

```swift
// Removed
- case inputPurposeSwitched(InputPurpose)
- case askSubmitted
- case answerReceived(String)
- case answerFailed
- case resultPillTapped

// Added
+ case recordingTapped                 // toggle start/stop
+ case transcriptionUpdated(String)    // partial result from stream
+ case transcriptionFailed             // recognition error or permission denied
```

### Removed Type

```swift
// Removed entirely
- public enum InputPurpose: Equatable, Sendable { case record, ask }
```

### CancelID

```swift
private enum CancelID {
    case aiExtraction
    case task
    // Added:
    case speechRecording
}
```

### Dependencies

```swift
// Added
@Dependency(\.speechClient) var speechClient
```

### Reducer Logic — recordingTapped

```
if not recording:
    call speechClient.requestPermission()
    if denied → set aiInputError (inline message) → return
    set isRecording = true, clear aiInputError
    run speechClient.startRecording() stream:
        on each value → send .transcriptionUpdated(text)
        on error → send .transcriptionFailed
    .cancellable(id: .speechRecording)

if recording:
    set isRecording = false
    call speechClient.stopRecording()
    cancel(.speechRecording)
```

### Reducer Logic — aiInputDismissed

When the user dismisses the expanded bar, also stop any active recording:

```
state.isAIInputExpanded = false
state.aiInputText = ""
state.isAIInputLoading = false
state.aiInputError = nil
if state.isRecording:
    state.isRecording = false
    speechClient.stopRecording()
    cancel(.speechRecording)
```

---

## MainTabView UI Changes

### Layout Change

`expandedAIInputContent` HStack changes:

| Before | After |
|--------|-------|
| Mode badge (記帳/詢問) + TextField + send btn | TextField (multi-line) + mic btn + send btn |

- Remove mode badge entirely
- Remove ask-mode toggle button
- `TextField(axis: .vertical)` with `.lineLimit(1...3)` — auto-grows up to 3 lines, scrolls internally beyond that
- `HStack(alignment: .bottom)` — mic and send buttons anchor to the last line

### Mic Button States

| State | Appearance |
|-------|-----------|
| Idle | Gray circle, `🎙️` icon |
| Recording | Red circle, `⏹` (stop) icon |
| Transcribing (brief) | N/A — stream is continuous; button stays red until user taps stop |

### Send Button

- Enabled when `aiInputText` is non-empty **and** `!isRecording`
- Disabled (dimmed) during recording

### Pill Shape

Change from `Capsule()` to `RoundedRectangle(cornerRadius: 18)` so the pill doesn't distort as it grows vertically.

### Recording Inline Indicator

Inside the pill when recording, show a small red dot + "錄音中" label above the text field (within the same VStack).

### Removed UI Elements

- Mode badge (`inputPurpose` toggle)
- Ask mode placeholder text
- `aiAnswer` result card in expanded view
- Result pill (`resultPillContent`) — no longer needed without ask mode

### Error Display

Permission denied or recognition failure sets `aiInputError`:

> 「請至設定 › NeuLedger 開啟麥克風與語音辨識權限。」
> or
> 「語音辨識失敗，請重試或直接輸入文字。」

Displayed inline below the pill (existing `aiInputError` display, no Alert).

---

## Info.plist

Two new keys required:

| Key | Value |
|-----|-------|
| `NSMicrophoneUsageDescription` | 「用麥克風錄製語音，辨識成交易描述文字。」 |
| `NSSpeechRecognitionUsageDescription` | 「在裝置上辨識您的語音以快速記帳，不會上傳至伺服器。」 |

Permission is requested **lazily** — only on the first tap of the mic button, not at app launch.

---

## Data Flow (End-to-End)

1. User taps mic → `.recordingTapped`
2. `requestPermission()` — if denied, show inline error and stop
3. `isRecording = true`, start stream
4. Partial transcription strings → `.transcriptionUpdated(text)` → `aiInputText` updates → TextField shows live text
5. User taps mic again → `.recordingTapped` → `isRecording = false`, `stopRecording()`
6. Text remains in `aiInputText`; user may edit
7. User taps send → `.aiInputSubmitted` → existing `aiServiceClient.extractTransaction` flow → opens `AddTransactionFeature` pre-filled

---

## Testing Notes

- `SpeechClientTests`: inject a controlled `AsyncThrowingStream` that emits known strings; assert `aiInputText` updates correctly.
- `MainTabFeatureTests`: test `recordingTapped` toggles `isRecording`; test `transcriptionFailed` sets `aiInputError`.
- No changes required to existing `AddTransactionFeature` tests.
