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
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true))
    }

    @Test("task marks AI unavailable when not available")
    func taskMarksUnavailable() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: false)) {
            $0.aiUnavailable = true
        }
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
            $0.aiInputError = "無法解析，請再試一次或手動輸入"
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
