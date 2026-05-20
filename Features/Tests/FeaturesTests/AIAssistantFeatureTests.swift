import Testing
import ComposableArchitecture
@testable import Features

@Suite("AIAssistantFeature Tests")
struct AIAssistantFeatureTests {

    // MARK: - expandTapped

    @Test("expandTapped toggles isExpanded from false to true")
    func testExpandTapped_expandsCard() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
        }
        await store.send(.expandTapped) { $0.isExpanded = true }
    }

    @Test("expandTapped toggles isExpanded from true to false")
    func testExpandTapped_collapsesCard() async {
        var initial = AIAssistantFeature.State()
        initial.isExpanded = true
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
        }
        await store.send(.expandTapped) { $0.isExpanded = false }
    }

    // MARK: - task

    @Test("task sets isAvailable true when AI is available")
    func testTask_setsIsAvailableTrue() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { true }
        }
        await store.send(.task) { $0.isAvailable = true }
    }

    @Test("task sets isAvailable false when AI is unavailable")
    func testTask_setsIsAvailableFalse() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
        }
        await store.send(.task)
    }

    // MARK: - inputChanged

    @Test("inputChanged updates inputText")
    func testInputChanged() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
        }
        await store.send(.inputChanged("上個月花了多少？")) { $0.inputText = "上個月花了多少？" }
    }

    // MARK: - submitTapped (guard: empty input)

    @Test("submitTapped does nothing when inputText is empty")
    func testSubmitTapped_guardEmpty() async {
        let store = await TestStore(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
            $0.aiUseCase.answerFinancialQuestion = { _ in
                Issue.record("should not be called"); return ""
            }
        }
        await store.send(.submitTapped)
        // No state change, no effects
    }

    // MARK: - submitTapped (guard: already loading)

    @Test("submitTapped does nothing when already loading")
    func testSubmitTapped_guardLoading() async {
        var initial = AIAssistantFeature.State()
        initial.inputText = "test"
        initial.isLoading = true
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
            $0.aiUseCase.answerFinancialQuestion = { _ in
                Issue.record("should not be called"); return ""
            }
        }
        await store.send(.submitTapped)
    }

    // MARK: - submitTapped → answerReceived

    @Test("submitTapped appends user message, clears input, sets isLoading")
    func testSubmitTapped_appendsUserMessage() async {
        var initial = AIAssistantFeature.State()
        initial.inputText = "上個月花了多少？"
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
            $0.aiUseCase.answerFinancialQuestion = { _ in "NT$12,300" }
        }
        store.exhaustivity = .off

        await store.send(.submitTapped) {
            $0.inputText = ""
            $0.isLoading = true
            $0.errorMessage = nil
            // messages has 1 user message
            #expect($0.messages.count == 1)
            #expect($0.messages[0].role == .user)
            #expect($0.messages[0].text == "上個月花了多少？")
        }
        await store.receive(\.answerReceived) {
            $0.isLoading = false
            #expect($0.messages.count == 2)
            #expect($0.messages[1].role == .assistant)
            #expect($0.messages[1].text == "NT$12,300")
        }
    }

    // MARK: - answerFailed

    @Test("answerFailed sets errorMessage and clears isLoading")
    func testAnswerFailed_setsError() async {
        var initial = AIAssistantFeature.State()
        initial.inputText = "test"
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
            $0.aiUseCase.answerFinancialQuestion = { _ in
                struct Err: Error {}
                throw Err()
            }
        }
        store.exhaustivity = .off

        await store.send(.submitTapped) {
            $0.inputText = ""
            $0.isLoading = true
            #expect($0.messages.count == 1)
        }
        await store.receive(\.answerFailed) {
            $0.isLoading = false
            #expect($0.errorMessage != nil)
        }
    }

    // MARK: - dismissError

    @Test("dismissError clears errorMessage")
    func testDismissError() async {
        var initial = AIAssistantFeature.State()
        initial.errorMessage = "some error"
        let store = await TestStore(initialState: initial) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
        }
        await store.send(.dismissError) { $0.errorMessage = nil }
    }
}
