import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("MainTabFeature — AI input")
struct MainTabFeatureTests {

    @Test("task stores AI availability")
    func taskStoresAvailability() async {
        // Initial state has aiUnavailable = false; receiving isAvailable: true keeps it false (no change).
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
        // AI is unavailable → mode falls back to .add even though "ai" was stored
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
        initial.aiAnswer = "previous answer"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
            $0.aiAnswer = nil
        }
    }

    @Test("successful extraction on dashboard tab opens AddTransaction")
    func successfulExtractionRoutesDashboard() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
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
            $0.dashboard.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: fixedDate)
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

@Suite("MainTabFeature — ask mode")
struct MainTabAskModeTests {

    @Test("inputPurposeSwitched clears text and answer")
    func testInputPurposeSwitchedToAsk() async {
        var initial = MainTabFeature.State()
        initial.aiInputText = "some text"
        initial.aiAnswer = "some answer"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.answerFinancialQuestion = { _ in "" }
        }

        await store.send(.inputPurposeSwitched(.ask)) {
            $0.inputPurpose = .ask
            $0.aiInputText = ""
            $0.aiAnswer = nil
            $0.aiInputError = nil
        }
    }

    @Test("askSubmitted receives answer and resets loading")
    func testAskSubmittedReceivesAnswer() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.inputPurpose = .ask
        initial.aiInputText = "上個月餐費多少？"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.answerFinancialQuestion = { _ in "上個月餐費 NT$8,500" }
        }

        await store.send(.askSubmitted) {
            $0.isAIInputLoading = true
            $0.aiInputError = nil
            $0.aiAnswer = nil
        }
        await store.receive(\.answerReceived) {
            $0.aiAnswer = "上個月餐費 NT$8,500"
            $0.isAIInputLoading = false
            $0.aiInputText = ""
            $0.isAIInputExpanded = false
        }
    }

    @Test("askSubmitted on failure sets aiInputError")
    func testAskSubmittedHandlesFailure() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.inputPurpose = .ask
        initial.aiInputText = "上個月餐費多少？"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.answerFinancialQuestion = { _ in
                struct FakeError: Error {}
                throw FakeError()
            }
        }

        await store.send(.askSubmitted) {
            $0.isAIInputLoading = true
            $0.aiInputError = nil
            $0.aiAnswer = nil
        }
        await store.receive(\.answerFailed) {
            $0.isAIInputLoading = false
            $0.aiInputError = String(localized: "ai_ask_error")
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
                AsyncStream { continuation in
                    continuation.finish()
                }
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

@Suite("MainTabFeature — accessory bar & result pill")
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

    @Test("resultPillTapped clears aiAnswer and expands input")
    func resultPillTappedClearsAndExpands() async {
        var initial = MainTabFeature.State()
        initial.aiAnswer = "上個月餐費 NT$8,500"
        initial.isAIInputExpanded = false

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.resultPillTapped) {
            $0.aiAnswer = nil
            $0.isAIInputExpanded = true
            $0.aiInputError = nil
        }
    }

    @Test("answerReceived collapses input bar so compact pill appears")
    func answerReceivedCollapsesInputBar() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.inputPurpose = .ask
        initial.isAIInputLoading = true
        initial.aiInputText = "上個月餐費多少？"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.answerReceived("上個月餐費 NT$8,500")) {
            $0.aiAnswer = "上個月餐費 NT$8,500"
            $0.isAIInputLoading = false
            $0.aiInputText = ""
            $0.isAIInputExpanded = false
        }
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
        // AI unavailable — reducer ignores the .ai value and keeps .add
        await store.send(.accessoryModeLoaded(.ai))
        // state.accessoryMode remains .add (default)
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
