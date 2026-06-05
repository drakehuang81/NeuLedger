import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("AccessoryBarFeature — lifecycle")
struct AccessoryBarFeatureLifecycleTests {

    @Test("task loads availability and resolves saved mode when AI available")
    func taskAIAvailable() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.isAvailable = { true }
            $0.platformClient.accessoryMode = { .ai }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true))
        await store.receive(.accessoryModeLoaded(.ai)) {
            $0.accessoryMode = .ai
        }
    }

    @Test("task falls back to .add when AI unavailable")
    func taskAIUnavailable() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.isAvailable = { false }
            $0.platformClient.accessoryMode = { .ai }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: false)) {
            $0.aiUnavailable = true
        }
        await store.receive(.accessoryModeLoaded(.add))
    }
}

@Suite("AccessoryBarFeature — AI input")
struct AccessoryBarAIInputTests {

    @Test("AI input button expands the input bar")
    func aiInputButtonExpands() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        }
        await store.send(.aiInputButtonTapped) {
            $0.isAIInputExpanded = true
        }
    }

    @Test("dismiss resets all AI input state")
    func dismissResetsState() async {
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.aiInputError = "some error"

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { }
        }
        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
        }
    }

    @Test("successful extraction resets input and emits transactionExtracted delegate")
    func successfulExtractionEmitsDelegate() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        await store.send(.aiExtractionCompleted(.success(extracted))) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
        }
        await store.receive(.delegate(.transactionExtracted(extracted)))
    }

    @Test("failed extraction shows error and keeps input open")
    func failedExtractionShowsError() async {
        struct FakeError: Error {}
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        await store.send(.aiExtractionCompleted(.failure(FakeError()))) {
            $0.isAIInputLoading = false
            $0.aiInputError = String(localized: "ai_extraction_error")
        }
    }

    @Test("contextActionTapped emits contextActionRequested delegate")
    func contextActionEmitsDelegate() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        }
        await store.send(.contextActionTapped)
        await store.receive(.delegate(.contextActionRequested))
    }

    @Test("aiInputSubmitted is ignored when text is empty")
    func submitIgnoredWhenEmpty() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        }
        // aiInputText is empty by default → guard returns before extraction; no state change
        await store.send(.aiInputSubmitted)
    }
}

@Suite("AccessoryBarFeature — accessory mode")
struct AccessoryBarModeTests {

    @Test("accessoryModeLoaded sets mode when AI is available")
    func modeLoadedAIAvailable() async {
        var initial = AccessoryBarFeature.State()
        initial.aiUnavailable = false
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        await store.send(.accessoryModeLoaded(.ai)) {
            $0.accessoryMode = .ai
        }
    }

    @Test("accessoryModeLoaded falls back to .add when AI unavailable")
    func modeLoadedAIUnavailable() async {
        var initial = AccessoryBarFeature.State()
        initial.aiUnavailable = true
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        // AI unavailable — reducer ignores the .ai value and keeps .add
        await store.send(.accessoryModeLoaded(.ai))
    }

    @Test("accessoryModeSwitched updates state and persists via platformClient")
    func modeSwitchedPersists() async {
        let savedMode = LockIsolated<AccessoryMode?>(nil)
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.platformClient.setAccessoryMode = { mode in savedMode.setValue(mode) }
        }
        await store.send(.accessoryModeSwitched(.ai)) {
            $0.accessoryMode = .ai
        }
        #expect(savedMode.value == .ai)
    }

    @Test("accessoryModeSwitched to .add persists correctly")
    func modeSwitchedToAdd() async {
        var initial = AccessoryBarFeature.State()
        initial.accessoryMode = .ai
        let savedMode = LockIsolated<AccessoryMode?>(nil)
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.platformClient.setAccessoryMode = { mode in savedMode.setValue(mode) }
        }
        await store.send(.accessoryModeSwitched(.add)) {
            $0.accessoryMode = .add
        }
        #expect(savedMode.value == .add)
    }
}

@Suite("AccessoryBarFeature — recording")
struct AccessoryBarRecordingTests {

    @Test("recordingTapped requests permission then starts recording")
    func recordingTappedStartsWhenPermitted() async {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.finish()   // empty stream so the effect completes immediately

        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.requestVoicePermission = { true }
            $0.captureClient.startVoiceSession = { stream }
            $0.captureClient.stopVoiceSession = { }
        }

        await store.send(.recordingTapped)
        await store.receive(.recordingStarted) {
            $0.isRecording = true
            $0.aiInputError = nil
        }
    }

    @Test("recordingTapped stops recording when already recording")
    func recordingTappedStopsWhenRecording() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { stopCalled.setValue(true) }
        }

        await store.send(.recordingTapped) {
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }

    @Test("recordingTapped shows permission error when denied")
    func recordingTappedDeniedPermission() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.requestVoicePermission = { false }
        }

        await store.send(.recordingTapped)
        await store.receive(.permissionDenied) {
            $0.aiInputError = String(localized: "speech_permission_denied_error")
        }
    }

    @Test("transcriptionUpdated sets aiInputText")
    func transcriptionUpdatedSetsText() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { }
        }

        await store.send(.transcriptionUpdated("早餐五十五元")) {
            $0.aiInputText = "早餐五十五元"
        }
    }

    @Test("transcriptionUpdated overwrites previous partial result")
    func transcriptionUpdatedOverwrites() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { }
        }

        await store.send(.transcriptionUpdated("早餐五十五元")) {
            $0.aiInputText = "早餐五十五元"
        }
    }

    @Test("transcriptionFailed clears recording state and shows error")
    func transcriptionFailedShowsError() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { }
        }

        await store.send(.transcriptionFailed) {
            $0.isRecording = false
            $0.aiInputError = String(localized: "speech_recognition_failed_error")
        }
    }

    @Test("aiInputSubmitted is ignored while recording is active")
    func submitIgnoredWhileRecording() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { }
        }

        // Should be a no-op — isRecording guard prevents extraction
        await store.send(.aiInputSubmitted)
    }

    @Test("aiInputDismissed stops active recording")
    func dismissStopsActiveRecording() async {
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.stopVoiceSession = { stopCalled.setValue(true) }
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
