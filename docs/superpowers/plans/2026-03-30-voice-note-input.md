# Voice Note Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a microphone button to `AddTransactionView`'s note field so users can dictate notes via `SpeechClient`; partial transcripts append to any existing note text.

**Architecture:** Extend `AddTransactionFeature` in place — add three new public actions (`recordingTapped`, `transcriptionUpdated`, `transcriptionFailed`) plus one internal action (`recordingPermissionResult`), three state properties, and a `speechClient` dependency. Update the note field from a plain `HStack` to a `VStack` that shows a recording indicator and mic/stop button.

**Tech Stack:** TCA v1.23.1, SpeechClient (Domain interface, already implemented), Swift Testing, SwiftUI (iOS 26)

---

### Task 1: Write failing tests for voice actions

**Files:**
- Modify: `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift` (append new suite)

- [ ] **Step 1: Append the new test suite to the existing test file**

Open `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift` and add the following block at the very end of the file (after the last closing `}`):

```swift
@Suite("AddTransactionFeature — voice input")
struct AddTransactionVoiceTests {

    // MARK: - permission denied

    @Test("recordingTapped: permission denied sets speechError")
    func recordingTappedPermissionDenied() async {
        let store = await TestStore(initialState: AddTransactionFeature.State()) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.requestPermission = { false }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.recordingTapped)
        await store.receive(.recordingPermissionResult(false)) {
            $0.speechError = String(localized: "speech_permission_denied_error")
        }
    }

    // MARK: - permission granted

    @Test("recordingTapped: permission granted sets isRecording and saves noteBeforeRecording")
    func recordingTappedPermissionGranted() async {
        var initial = AddTransactionFeature.State()
        initial.note = "早餐"

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.finish()   // finish immediately so effect completes

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.requestPermission = { true }
            $0.speechClient.startRecording = { stream }
            $0.speechClient.stopRecording = { }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.recordingTapped)
        await store.receive(.recordingPermissionResult(true)) {
            $0.isRecording = true
            $0.noteBeforeRecording = "早餐"
            $0.speechError = nil
        }
        // stream finished immediately — no further actions
    }

    // MARK: - transcriptionUpdated

    @Test("transcriptionUpdated: appends transcript to noteBeforeRecording prefix")
    func transcriptionUpdatedAppendsToPrefix() async {
        var initial = AddTransactionFeature.State()
        initial.isRecording = true
        initial.noteBeforeRecording = "早餐"
        initial.note = "早餐"

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.transcriptionUpdated("五十五元")) {
            $0.note = "早餐 五十五元"
        }
    }

    @Test("transcriptionUpdated: sets note directly when noteBeforeRecording is empty")
    func transcriptionUpdatedEmptyPrefix() async {
        var initial = AddTransactionFeature.State()
        initial.isRecording = true
        initial.noteBeforeRecording = ""

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.transcriptionUpdated("午餐便當")) {
            $0.note = "午餐便當"
        }
    }

    // MARK: - transcriptionFailed

    @Test("transcriptionFailed: sets speechError and clears isRecording")
    func transcriptionFailedSetsError() async {
        var initial = AddTransactionFeature.State()
        initial.isRecording = true
        initial.noteBeforeRecording = "早餐"

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { stopCalled.setValue(true) }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.transcriptionFailed) {
            $0.isRecording = false
            $0.speechError = String(localized: "speech_recognition_failed_error")
        }
        #expect(stopCalled.value)
    }

    // MARK: - stop recording

    @Test("recordingTapped while recording: stops recording and clears isRecording")
    func recordingTappedWhileRecording() async {
        var initial = AddTransactionFeature.State()
        initial.isRecording = true

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { stopCalled.setValue(true) }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.recordingTapped) {
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }

    // MARK: - dismiss guard

    @Test("dismiss while recording: stops recording before dismissing")
    func dismissWhileRecording() async {
        var initial = AddTransactionFeature.State()
        initial.isRecording = true
        initial.noteBeforeRecording = "早餐"

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { stopCalled.setValue(true) }
            $0.aiServiceClient.isAvailable = { false }
        }
        store.exhaustivity = .off

        await store.send(.dismiss) {
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (compile error expected)**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AddTransactionVoiceTests 2>&1 | tail -40
```

Expected: Compile errors such as `value of type 'AddTransactionFeature.Action' has no member 'recordingTapped'`, `'isRecording' is inaccessible`, etc.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift
git commit -m "test(add-transaction): write failing tests for voice note input

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Implement AddTransactionFeature voice state/action/reducer

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`

- [ ] **Step 1: Add three state properties to `AddTransactionFeature.State`**

Find the block that ends with `public var categorySuggestionError: String? = nil` (around line 49) and add the following immediately after it, before the `public init`:

```swift
        // Voice recording state
        public var isRecording: Bool = false
        public var speechError: String? = nil
        var noteBeforeRecording: String = ""   // saves note prefix at recording start
```

- [ ] **Step 2: Add new Action cases**

Find the block:
```swift
        // AI assistance actions
        case backgroundExtractionCompleted(ExtractedTransaction?)
        case suggestCategoryTapped
        case categorySuggestionsReceived(TaskResult<CategorySuggestions>)
```

Add the following immediately after `case categorySuggestionsReceived(...)`:

```swift

        // Voice recording actions
        case recordingTapped
        case transcriptionUpdated(String)   // full transcript so far (not a delta)
        case transcriptionFailed
        case recordingPermissionResult(Bool)   // internal: bridges async permission check to state
```

- [ ] **Step 3: Add `speechClient` dependency**

Find the line:
```swift
    @Dependency(\.aiServiceClient) var aiServiceClient
```

Add immediately after it:

```swift
    @Dependency(\.speechClient) var speechClient
```

- [ ] **Step 4: Add `speechRecording` to CancelID**

Find:
```swift
    private enum CancelID { case task; case noteDebounce; case categorySuggest }
```

Replace with:
```swift
    private enum CancelID { case task; case noteDebounce; case categorySuggest; case speechRecording }
```

- [ ] **Step 5: Guard `.dismiss` to stop active recording**

Find:
```swift
            case .dismiss:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }
```

Replace with:
```swift
            case .dismiss:
                if state.isRecording {
                    state.isRecording = false
                    speechClient.stopRecording()
                }
                return .concatenate(
                    .cancel(id: CancelID.speechRecording),
                    .run { send in
                        await send(.delegate(.dismissed))
                        await dismiss()
                    }
                )
```

- [ ] **Step 6: Add voice reducer cases**

Find:
```swift
            case .categorySuggestionsReceived(.failure):
                state.isSuggestingCategory = false
                state.categorySuggestionError = String(localized: "add_transaction_category_suggestion_failed")
                return .none
            }
        }
    }
}
```

Insert the new cases before the closing `}` of the `switch action` block — i.e., between `return .none` (the categorySuggestionsReceived failure case) and the `}` that closes the switch. Replace that closing sequence with:

```swift
            case .categorySuggestionsReceived(.failure):
                state.isSuggestingCategory = false
                state.categorySuggestionError = String(localized: "add_transaction_category_suggestion_failed")
                return .none

            // MARK: - Voice recording

            case .recordingTapped:
                guard !state.isRecording else {
                    // Stop branch
                    state.isRecording = false
                    speechClient.stopRecording()
                    return .cancel(id: CancelID.speechRecording)
                }
                // Start branch — check permission asynchronously
                return .run { send in
                    let granted = await speechClient.requestPermission()
                    await send(.recordingPermissionResult(granted))
                }

            case let .recordingPermissionResult(granted):
                guard granted else {
                    state.speechError = String(localized: "speech_permission_denied_error")
                    return .none
                }
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

            case let .transcriptionUpdated(text):
                let prefix = state.noteBeforeRecording
                state.note = prefix.isEmpty ? text : prefix + " " + text
                return .none

            case .transcriptionFailed:
                state.isRecording = false
                state.speechError = String(localized: "speech_recognition_failed_error")
                speechClient.stopRecording()
                return .cancel(id: CancelID.speechRecording)
            }
        }
    }
}
```

- [ ] **Step 7: Run the voice tests to verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AddTransactionVoiceTests 2>&1 | tail -40
```

Expected: All 7 tests pass. If any existing AddTransactionFeature tests fail, investigate — most likely a missing `speechClient` mock in a test that now needs one (add `$0.speechClient.stopRecording = { }` to the withDependencies block).

- [ ] **Step 8: Run all Feature tests to check for regressions**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -40
```

Expected: All tests pass (green).

- [ ] **Step 9: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift
git commit -m "feat(add-transaction): add voice recording state/actions/reducer for note field

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Update AddTransactionView note field UI

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift`

- [ ] **Step 1: Replace the note field HStack with a VStack**

Find the current note field block (lines ~232–245):

```swift
            // Note field
            HStack {
                TextField(String(localized: "add_transaction_note_placeholder"), text: Binding(
                    get: { store.note },
                    set: { store.send(.noteChanged($0)) }
                ))
                .padding(.vertical, 12)

                if store.isBackgroundParsingNote {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
```

Replace it with:

```swift
            // Note field with voice input
            VStack(alignment: .leading, spacing: 4) {
                if store.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.Design.expenseRed)
                            .frame(width: 7, height: 7)
                        Text(String(localized: "speech_recording_label"))
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                }
                HStack {
                    TextField(String(localized: "add_transaction_note_placeholder"), text: Binding(
                        get: { store.note },
                        set: { store.send(.noteChanged($0)) }
                    ))
                    .padding(.vertical, 12)

                    if store.isBackgroundParsingNote {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            store.send(.recordingTapped)
                        } label: {
                            Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(
                                    store.isRecording
                                        ? Color.Design.expenseRed
                                        : Color.Design.textTertiary
                                )
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

- [ ] **Step 2: Build the app to confirm no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run all Feature tests one final time**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -40
```

Expected: All tests pass (green).

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionView.swift
git commit -m "feat(add-transaction): add voice mic button and recording indicator to note field

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ `isRecording`, `speechError`, `noteBeforeRecording` state properties added (Task 2, Step 1)
- ✅ `recordingTapped`, `transcriptionUpdated(String)`, `transcriptionFailed` actions added (Task 2, Step 2)
- ✅ `@Dependency(\.speechClient)` added (Task 2, Step 3)
- ✅ `CancelID.speechRecording` added (Task 2, Step 4)
- ✅ Start recording: permission check → set prefix + `isRecording` → stream (Task 2, Step 6)
- ✅ Stop recording: inline stop + cancel effect (Task 2, Step 6)
- ✅ `transcriptionUpdated`: `prefix.isEmpty ? text : prefix + " " + text` (Task 2, Step 6)
- ✅ `transcriptionFailed`: clear recording, set error, stop (Task 2, Step 6)
- ✅ `dismiss` guard: stops recording before delegate/dismiss (Task 2, Step 5)
- ✅ Recording indicator (red dot + `speech_recording_label`) shown when `isRecording` (Task 3, Step 1)
- ✅ Mic button shown when `!isBackgroundParsingNote` (Task 3, Step 1)
- ✅ Stop icon when recording, mic icon when not (Task 3, Step 1)
- ✅ `speechError` shown inline below HStack (Task 3, Step 1)
- ✅ All 7 spec tests covered (Task 1, Step 1)
- ✅ Reuses existing l10n keys — no new localization needed

**Placeholder scan:** None found.

**Type consistency:** `CancelID.speechRecording` used consistently across Task 2 Steps 4, 5, and 6. `state.noteBeforeRecording` set in `recordingPermissionResult(true)` and read in `transcriptionUpdated` — consistent. `speechClient.stopRecording()` called inline (synchronous `() -> Void`) in `recordingTapped` stop branch, `transcriptionFailed`, and `dismiss` guard — consistent.
