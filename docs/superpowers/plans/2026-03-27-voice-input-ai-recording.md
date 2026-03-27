# Voice Input for AI Recording — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the text-only AI recording bar with voice input — mic button streams on-device speech recognition into the text field in real time; ask mode is removed from the bar.

**Architecture:** New `SpeechClient` in Domain (interface) + Core (live `SFSpeechRecognizer` + `AVAudioEngine`). `MainTabFeature` subscribes to the recording stream; each partial result updates `aiInputText`. The existing AI extraction pipeline is untouched — voice input is just another way to produce the text that gets sent to `extractTransaction`.

**Tech Stack:** `Speech.framework`, `AVFoundation`, TCA v1.23.1, Swift Testing, `@DependencyClient` macro.

---

## File Map

| Action | File |
|--------|------|
| **Create** | `Features/Sources/Domain/Clients/SpeechClient.swift` |
| **Create** | `Features/Sources/Core/Clients/SpeechClient+Live.swift` |
| **Create** | `Features/Tests/DomainTests/Clients/SpeechClientTests.swift` |
| **Modify** | `NeuLedger/Resources/Localizable.xcstrings` |
| **Modify** | `NeuLedger/Info.plist` |
| **Modify** | `Features/Sources/Features/MainTab/MainTabFeature.swift` |
| **Modify** | `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` |
| **Modify** | `Features/Sources/Features/MainTab/MainTabView.swift` |

---

## Task 1 — SpeechClient Domain Interface

**Files:**
- Create: `Features/Sources/Domain/Clients/SpeechClient.swift`
- Create: `Features/Tests/DomainTests/Clients/SpeechClientTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Features/Tests/DomainTests/Clients/SpeechClientTests.swift`:

```swift
import Dependencies
import Foundation
import Testing
@testable import Domain

@Suite("SpeechClient Tests")
struct SpeechClientTests {

    @Test("SpeechClient is injectable via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.speechClient) var client
        #expect(true, "SpeechClient injected successfully")
    }

    @Test("SpeechClient requestPermission mock override")
    func testRequestPermissionMock() async {
        await withDependencies {
            $0.speechClient.requestPermission = { true }
        } operation: {
            @Dependency(\.speechClient) var client
            let result = await client.requestPermission()
            #expect(result == true)
        }
    }

    @Test("SpeechClient startRecording mock emits transcription text")
    func testStartRecordingMock() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.yield("早餐五十五元")
        continuation.finish()

        try await withDependencies {
            $0.speechClient.startRecording = { stream }
        } operation: {
            @Dependency(\.speechClient) var client
            var results: [String] = []
            for try await text in client.startRecording() {
                results.append(text)
            }
            #expect(results == ["早餐五十五元"])
        }
    }

    @Test("SpeechClient stopRecording mock override")
    func testStopRecordingMock() {
        let called = LockIsolated(false)
        withDependencies {
            $0.speechClient.stopRecording = { called.setValue(true) }
        } operation: {
            @Dependency(\.speechClient) var client
            client.stopRecording()
        }
        #expect(called.value == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (SpeechClient not yet defined)**

```bash
cd /path/to/NeuLedger
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/SpeechClientTests 2>&1 | tail -20
```

Expected: compile error — `SpeechClient` is undefined.

- [ ] **Step 3: Create SpeechClient.swift**

Create `Features/Sources/Domain/Clients/SpeechClient.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SpeechClient: Sendable {
    /// Requests both microphone and speech recognition permissions.
    /// Returns true only if both are granted.
    public var requestPermission: @Sendable () async -> Bool = { false }

    /// Starts recording and returns a stream of partial transcription strings.
    /// Each yielded String is the latest best-transcription result.
    public var startRecording: @Sendable () -> AsyncThrowingStream<String, Error> = { .finished }

    /// Stops recording and releases the audio session so other apps can resume audio.
    public var stopRecording: @Sendable () -> Void = { }
}

extension SpeechClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run tests — should pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/SpeechClientTests 2>&1 | tail -20
```

Expected: `Test Suite 'SpeechClientTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Clients/SpeechClient.swift \
        Features/Tests/DomainTests/Clients/SpeechClientTests.swift
git commit -m "feat(domain): add SpeechClient dependency interface"
```

---

## Task 2 — SpeechClient Core Live Value

**Files:**
- Create: `Features/Sources/Core/Clients/SpeechClient+Live.swift`

No unit tests for the live implementation — it requires a real device microphone. The live value is exercised by manual testing on device.

- [ ] **Step 1: Create SpeechClient+Live.swift**

Create `Features/Sources/Core/Clients/SpeechClient+Live.swift`:

```swift
import AVFoundation
import Dependencies
import Domain
import Speech

extension SpeechClient: DependencyKey {
    public static var liveValue: SpeechClient {
        let actor = SpeechRecordingActor()
        return SpeechClient(
            requestPermission: { await actor.requestPermission() },
            startRecording: { actor.startRecording() },
            stopRecording: { actor.stopRecording() }
        )
    }
}

// MARK: - SpeechRecordingActor

private actor SpeechRecordingActor {
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    func requestPermission() async -> Bool {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { return false }
        let status = await withCheckedContinuation {
            (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }

    func startRecording() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                await self.beginRecording(continuation: continuation)
            }
        }
    }

    private func beginRecording(
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        do {
            // zh-TW first; fall back to system locale if unavailable on this device
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
                    ?? SFSpeechRecognizer(locale: .current),
                  recognizer.isAvailable else {
                continuation.finish(throwing: SpeechClientError.recognizerUnavailable)
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let engine = AVAudioEngine()
            audioEngine = engine

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    continuation.yield(result.bestTranscription.formattedString)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else if result?.isFinal == true {
                    continuation.finish()
                }
            }
        } catch {
            continuation.finish(throwing: error)
        }
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}

// MARK: - SpeechClientError

enum SpeechClientError: Error {
    case recognizerUnavailable
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Clients/SpeechClient+Live.swift
git commit -m "feat(core): add SpeechClient live value using SFSpeechRecognizer"
```

---

## Task 3 — Info.plist & Localization Keys

**Files:**
- Modify: `NeuLedger/Info.plist`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add permission keys to Info.plist**

Open `NeuLedger/Info.plist` and add two keys inside `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用麥克風錄製語音，辨識成交易描述文字。</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>在裝置上辨識您的語音以快速記帳，不會上傳至伺服器。</string>
```

After editing, the full file should look like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>NSMicrophoneUsageDescription</key>
    <string>用麥克風錄製語音，辨識成交易描述文字。</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>在裝置上辨識您的語音以快速記帳，不會上傳至伺服器。</string>
</dict>
</plist>
```

- [ ] **Step 2: Add localization keys to Localizable.xcstrings**

Open `NeuLedger/Resources/Localizable.xcstrings` and add these three entries (following the same pattern as existing keys like `ai_extraction_error`):

```json
"speech_permission_denied_error" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "請至設定 › NeuLedger 開啟麥克風與語音辨識權限。"
      }
    }
  }
},
"speech_recognition_failed_error" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "語音辨識失敗，請重試或直接輸入文字。"
      }
    }
  }
},
"speech_recording_label" : {
  "extractionState" : "manual",
  "localizations" : {
    "zh-Hant" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "錄音中"
      }
    }
  }
},
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NeuLedger/Info.plist NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat: add speech permission keys and localization strings"
```

---

## Task 4 — MainTabFeature: Remove Ask Mode

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: Update the test file first — remove ask mode tests**

Replace the contents of `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` with the version below. Changes:
- Remove entire `MainTabAskModeTests` suite
- In `dismissResetsState`: remove `aiAnswer` references
- In `MainTabAccessoryBarTests`: remove `resultPillTappedClearsAndExpands` and `answerReceivedCollapsesInputBar` tests (both require `aiAnswer` and `inputPurpose`)

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("MainTabFeature — AI input")
struct MainTabFeatureTests {

    @Test("task stores AI availability")
    func taskStoresAvailability() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.string = { _ in "add" }
            $0.notificationClient.pendingConfirmations = {
                AsyncStream { $0.finish() }
            }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true))
        await store.receive(.accessoryBarVisibilityLoaded(true))
        await store.receive(.accessoryModeLoaded(.add))
    }

    @Test("task marks AI unavailable when not available")
    func taskMarksUnavailable() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
            $0.userSettingsClient.string = { _ in "ai" }
            $0.notificationClient.pendingConfirmations = {
                AsyncStream { $0.finish() }
            }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: false)) {
            $0.aiUnavailable = true
        }
        await store.receive(.accessoryBarVisibilityLoaded(true))
        await store.receive(.accessoryModeLoaded(.add))
    }

    @Test("AI input button expands the input bar")
    func aiInputButtonExpands() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.aiInputButtonTapped) {
            $0.isAIInputExpanded = true
        }
    }

    @Test("dismiss resets all AI input state")
    func dismissResetsState() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.aiInputError = "some error"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
            $0.speechClient.stopRecording = { }
        }
        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
        }
    }

    @Test("successful extraction on dashboard tab opens AddTransaction")
    func successfulExtractionRoutesDashboard() async {
        let extracted = ExtractedTransaction(
            amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense"
        )
        let fixedDate = Date(timeIntervalSince1970: 0)

        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.extractTransaction = { _ in extracted }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsClient.string = { _ in "" }
            $0.date = .constant(fixedDate)
        }
        await store.send(.aiExtractionCompleted(.success(extracted))) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
        }
        await store.receive(.dashboard(.addTransactionWithPrefilledData(extracted))) {
            $0.dashboard.addTransaction = AddTransactionFeature.State(
                mode: .addPrefilled(extracted), date: fixedDate
            )
        }
    }

    @Test("failed extraction shows error and keeps input open")
    func failedExtractionShowsError() async {
        struct FakeError: Error {}
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.aiExtractionCompleted(.failure(FakeError()))) {
            $0.isAIInputLoading = false
            $0.aiInputError = String(localized: "ai_extraction_error")
        }
    }
}

@Suite("MainTabFeature — recurring confirmation")
struct MainTabRecurringConfirmationTests {

    @Test("pendingRecurringConfirmationReceived pre-fills dashboard and switches tab")
    func testPendingRecurringConfirmationReceived() async {
        let recurringId = UUID()
        let template = RecurringTransaction(
            id: recurringId, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID(), toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [template] }
            $0.aiServiceClient.isAvailable = { false }
            $0.userSettingsClient.bool = { _ in false }
            $0.notificationClient.pendingConfirmations = {
                AsyncStream { continuation in continuation.finish() }
            }
        }
        store.exhaustivity = .off

        await store.send(.pendingRecurringConfirmationReceived(recurringId))
        await store.receive(\.recurringTemplateFetched) { state in
            #expect(state.dashboard.addTransaction != nil)
            #expect(state.selectedTab == .dashboard)
            #expect(state.pendingRecurringConfirmationId == recurringId)
        }
    }
}

@Suite("MainTabFeature — accessory bar")
struct MainTabAccessoryBarTests {

    @Test("task reads showAccessoryBar=false and stores it")
    func taskReadsAccessoryBarFalse() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.bool = { key in
                key.rawValue == SettingsKey.showAccessoryBar.rawValue ? false : key.defaultValue
            }
            $0.userSettingsClient.string = { _ in "add" }
            $0.notificationClient.pendingConfirmations = {
                AsyncStream { $0.finish() }
            }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true))
        await store.receive(.accessoryBarVisibilityLoaded(false)) {
            $0.showAccessoryBar = false
        }
        await store.receive(.accessoryModeLoaded(.add))
    }
}

@Suite("MainTabFeature — accessory mode")
struct MainTabAccessoryModeTests {

    @Test("accessoryModeLoaded sets mode when AI is available")
    func modeLoadedAIAvailable() async {
        var initial = MainTabFeature.State()
        initial.aiUnavailable = false
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.accessoryModeLoaded(.ai)) {
            $0.accessoryMode = .ai
        }
    }

    @Test("accessoryModeLoaded falls back to .add when AI unavailable")
    func modeLoadedAIUnavailable() async {
        var initial = MainTabFeature.State()
        initial.aiUnavailable = true
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.accessoryModeLoaded(.ai))
    }

    @Test("accessoryModeSwitched updates state and persists to settings")
    func modeSwitchedPersists() async {
        let savedKey: LockIsolated<String?> = LockIsolated(nil)
        let savedValue: LockIsolated<String?> = LockIsolated(nil)
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.setString = { value, key in
                savedKey.setValue(key.rawValue)
                savedValue.setValue(value)
            }
        }
        await store.send(.accessoryModeSwitched(.ai)) {
            $0.accessoryMode = .ai
        }
        #expect(savedKey.value == "accessoryMode")
        #expect(savedValue.value == "ai")
    }

    @Test("accessoryModeSwitched to .add persists correctly")
    func modeSwitchedToAdd() async {
        var initial = MainTabFeature.State()
        initial.accessoryMode = .ai
        let savedValue: LockIsolated<String?> = LockIsolated(nil)
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.setString = { value, _ in savedValue.setValue(value) }
        }
        await store.send(.accessoryModeSwitched(.add)) {
            $0.accessoryMode = .add
        }
        #expect(savedValue.value == "add")
    }
}
```

- [ ] **Step 2: Remove ask mode from MainTabFeature.swift — State**

In `Features/Sources/Features/MainTab/MainTabFeature.swift`, remove from `State`:

```swift
// DELETE these two lines from State:
var inputPurpose: InputPurpose = .record
var aiAnswer: String? = nil
```

- [ ] **Step 3: Remove ask mode from MainTabFeature.swift — Action**

Remove these five cases from the `Action` enum:

```swift
// DELETE:
case inputPurposeSwitched(InputPurpose)
case askSubmitted
case answerReceived(String)
case answerFailed
case resultPillTapped
```

- [ ] **Step 4: Remove ask mode from MainTabFeature.swift — Reducer cases**

Remove these four reducer cases entirely:

```swift
// DELETE case .inputPurposeSwitched:
case let .inputPurposeSwitched(purpose):
    state.inputPurpose = purpose
    state.aiInputText = ""
    state.aiAnswer = nil
    state.aiInputError = nil
    return .cancel(id: CancelID.aiAnswer)

// DELETE case .askSubmitted:
case .askSubmitted:
    guard !state.aiInputText.isEmpty else { return .none }
    state.isAIInputLoading = true
    state.aiInputError = nil
    state.aiAnswer = nil
    let question = state.aiInputText
    return .run { send in
        do {
            let answer = try await aiServiceClient.answerFinancialQuestion(question)
            await send(.answerReceived(answer))
        } catch {
            await send(.answerFailed)
        }
    }
    .cancellable(id: CancelID.aiAnswer, cancelInFlight: true)

// DELETE case .answerReceived:
case let .answerReceived(text):
    guard state.inputPurpose == .ask else { return .none }
    state.aiAnswer = text
    state.isAIInputLoading = false
    state.aiInputText = ""
    state.isAIInputExpanded = false
    return .none

// DELETE case .answerFailed:
case .answerFailed:
    state.isAIInputLoading = false
    state.aiInputError = String(localized: "ai_ask_error")
    return .none

// DELETE case .resultPillTapped:
case .resultPillTapped:
    state.aiAnswer = nil
    state.isAIInputExpanded = true
    state.aiInputError = nil
    return .none
```

- [ ] **Step 5: Remove ask mode from MainTabFeature.swift — CancelID and enum**

Remove `case aiAnswer` from `CancelID`:
```swift
// Before:
private enum CancelID { case aiExtraction; case aiAnswer; case task }
// After:
private enum CancelID { case aiExtraction; case task }
```

Remove the `InputPurpose` enum from the top of the file (the public enum at lines 5–8):
```swift
// DELETE this entire declaration:
public enum InputPurpose: Equatable, Sendable {
    case record
    case ask
}
```

- [ ] **Step 6: Run tests — should pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MainTabFeatureTests \
  -only-testing:FeaturesTests/MainTabRecurringConfirmationTests \
  -only-testing:FeaturesTests/MainTabAccessoryBarTests \
  -only-testing:FeaturesTests/MainTabAccessoryModeTests 2>&1 | tail -20
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift \
        Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "refactor(maintab): remove ask mode (inputPurpose, aiAnswer, 5 actions)"
```

---

## Task 5 — MainTabFeature: Add Recording

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: Write failing recording tests**

Append a new suite to the bottom of `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`:

```swift
@Suite("MainTabFeature — recording")
struct MainTabRecordingTests {

    @Test("recordingTapped requests permission then starts recording")
    func recordingTappedStartsWhenPermitted() async {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.finish()   // empty stream so the effect completes immediately

        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.requestPermission = { true }
            $0.speechClient.startRecording = { stream }
            $0.speechClient.stopRecording = { }
        }

        await store.send(.recordingTapped)
        await store.receive(.recordingStarted) {
            $0.isRecording = true
            $0.aiInputError = nil
        }
        // stream finished immediately — no transcriptionUpdated expected
    }

    @Test("recordingTapped stops recording when already recording")
    func recordingTappedStopsWhenRecording() async {
        var initial = MainTabFeature.State()
        initial.isRecording = true

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { stopCalled.setValue(true) }
        }

        await store.send(.recordingTapped) {
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }

    @Test("recordingTapped shows permission error when denied")
    func recordingTappedDeniedPermission() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.requestPermission = { false }
        }

        await store.send(.recordingTapped)
        await store.receive(.permissionDenied) {
            $0.aiInputError = String(localized: "speech_permission_denied_error")
        }
    }

    @Test("transcriptionUpdated sets aiInputText")
    func transcriptionUpdatedSetsText() async {
        var initial = MainTabFeature.State()
        initial.isRecording = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { }
        }

        await store.send(.transcriptionUpdated("早餐五十五元")) {
            $0.aiInputText = "早餐五十五元"
        }
    }

    @Test("transcriptionUpdated overwrites previous partial result")
    func transcriptionUpdatedOverwrites() async {
        var initial = MainTabFeature.State()
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { }
        }

        await store.send(.transcriptionUpdated("早餐五十五元")) {
            $0.aiInputText = "早餐五十五元"
        }
    }

    @Test("transcriptionFailed clears recording state and shows error")
    func transcriptionFailedShowsError() async {
        var initial = MainTabFeature.State()
        initial.isRecording = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { }
        }

        await store.send(.transcriptionFailed) {
            $0.isRecording = false
            $0.aiInputError = String(localized: "speech_recognition_failed_error")
        }
    }

    @Test("aiInputDismissed stops active recording")
    func dismissStopsActiveRecording() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.speechClient.stopRecording = { stopCalled.setValue(true) }
        }

        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (new actions not defined)**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MainTabRecordingTests 2>&1 | tail -20
```

Expected: compile error — `recordingTapped`, `recordingStarted`, etc. are undefined.

- [ ] **Step 3: Add State and Actions to MainTabFeature.swift**

In `State`, add after `var accessoryMode: AccessoryMode = .add`:
```swift
var isRecording: Bool = false
```

In `Action`, add after `case accessoryModeSwitched(AccessoryMode)`:
```swift
case recordingTapped
case recordingStarted          // set after permission granted
case permissionDenied          // set when mic/speech permission refused
case transcriptionUpdated(String)
case transcriptionFailed
```

In `CancelID`, add `case speechRecording`:
```swift
private enum CancelID { case aiExtraction; case task; case speechRecording }
```

Add `@Dependency(\.speechClient) var speechClient` alongside the other dependencies.

- [ ] **Step 4: Add reducer cases to MainTabFeature.swift**

Add these cases inside the `Reduce { state, action in switch action {` body, before the `case .dashboard:` catch-all:

```swift
case .recordingTapped:
    if state.isRecording {
        state.isRecording = false
        return .merge(
            .cancel(id: CancelID.speechRecording),
            .run { _ in speechClient.stopRecording() }
        )
    } else {
        return .run { send in
            let granted = await speechClient.requestPermission()
            guard granted else {
                await send(.permissionDenied)
                return
            }
            await send(.recordingStarted)
            do {
                for try await text in speechClient.startRecording() {
                    await send(.transcriptionUpdated(text))
                }
            } catch {
                await send(.transcriptionFailed)
            }
        }
        .cancellable(id: CancelID.speechRecording)
    }

case .recordingStarted:
    state.isRecording = true
    state.aiInputError = nil
    return .none

case .permissionDenied:
    state.aiInputError = String(localized: "speech_permission_denied_error")
    return .none

case let .transcriptionUpdated(text):
    state.aiInputText = text
    return .none

case .transcriptionFailed:
    state.isRecording = false
    state.aiInputError = String(localized: "speech_recognition_failed_error")
    return .none
```

- [ ] **Step 5: Update aiInputDismissed case in MainTabFeature.swift**

Replace the existing `case .aiInputDismissed:` with:

```swift
case .aiInputDismissed:
    let wasRecording = state.isRecording
    state.isAIInputExpanded = false
    state.aiInputText = ""
    state.isAIInputLoading = false
    state.aiInputError = nil
    state.isRecording = false
    if wasRecording {
        return .merge(
            .cancel(id: CancelID.speechRecording),
            .run { _ in speechClient.stopRecording() }
        )
    }
    return .none
```

- [ ] **Step 6: Run all MainTab tests — should pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MainTabFeatureTests \
  -only-testing:FeaturesTests/MainTabRecordingTests \
  -only-testing:FeaturesTests/MainTabRecurringConfirmationTests \
  -only-testing:FeaturesTests/MainTabAccessoryBarTests \
  -only-testing:FeaturesTests/MainTabAccessoryModeTests 2>&1 | tail -20
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift \
        Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "feat(maintab): add voice recording state and actions (SpeechClient)"
```

---

## Task 6 — MainTabView: Recording UI

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`

No unit tests for View changes. Build verifies compilation; manual testing on device verifies UI.

- [ ] **Step 1: Update the expanded AI input content — full replacement**

In `MainTabView.swift`, replace the entire `expandedAIInputContent` computed property with:

```swift
// MARK: - ④ Expanded AI input

@ViewBuilder
private var expandedAIInputContent: some View {
    VStack(spacing: 4) {
        // Recording indicator — shown while mic is active
        if store.isRecording {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.Design.expenseRed)
                    .frame(width: 7, height: 7)
                Text(String(localized: "speech_recording_label"))
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.expenseRed)
            }
            .padding(.horizontal, 16)
        }

        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                String(localized: "ai_record_placeholder"),
                text: Binding(
                    get: { store.aiInputText },
                    set: { store.send(.aiInputTextChanged($0)) }
                ),
                axis: .vertical
            )
            .lineLimit(1...3)
            .textFieldStyle(.plain)
            .submitLabel(.send)
            .onSubmit {
                store.send(.aiInputSubmitted)
            }

            if store.isAIInputLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                // Mic button
                Button {
                    store.send(.recordingTapped)
                } label: {
                    Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            store.isRecording ? Color.Design.expenseRed : Color.primary
                        )
                }

                // Send button
                Button {
                    store.send(.aiInputSubmitted)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(store.aiInputText.isEmpty || store.isRecording)

                // Dismiss button
                Button {
                    store.send(.aiInputDismissed)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Design.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(
            Glass.clear.interactive().tint(Color.Design.surface),
            in: RoundedRectangle(cornerRadius: 18)
        )

        if let error = store.aiInputError {
            Text(error)
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.expenseRed)
                .padding(.horizontal, 16)
        }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
    .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

- [ ] **Step 2: Remove the resultPillContent function**

Delete the entire `resultPillContent` function (lines roughly 148–176 in the original file):

```swift
// DELETE this entire function:
private func resultPillContent(_ answer: String) -> some View {
    Button { ... } label: { ... }
    ...
}
```

- [ ] **Step 3: Update the expanded/compact switch — remove resultPillContent reference**

In the `case .expanded, _:` switch, replace:

```swift
// Before:
case .expanded, _:
    if store.isAIInputExpanded {
        expandedAIInputContent
    } else if store.isAIInputLoading {
        processingPillContent
    } else if let answer = store.aiAnswer {
        resultPillContent(answer)
    } else {
        compactPillContent
    }

// After:
case .expanded, _:
    if store.isAIInputExpanded {
        expandedAIInputContent
    } else if store.isAIInputLoading {
        processingPillContent
    } else {
        compactPillContent
    }
```

- [ ] **Step 4: Build to verify compilation**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run full Features test suite to catch any regressions**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabView.swift
git commit -m "feat(maintab): voice recording UI — mic button, multi-line TextField, remove ask mode UI"
```
