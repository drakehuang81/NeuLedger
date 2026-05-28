import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AddTransactionFeature Tests")
struct AddTransactionFeatureTests {

    private static let account1 = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )
    private static let account2 = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6"
    )

    // P1-F: Task loads accounts and categories and populates state
    @Test(".task loads accounts and categories and sets default accountId from userSettings")
    func testTaskLoadsOptionsAndAppliesDefaultAccount() async {
        let cash = Account(
            id: UUID(uuidString: "AA000000-0000-0000-0000-000000000001")!,
            name: "現金", type: .cash, icon: "banknote", color: "#34C759"
        )
        let bank = Account(
            id: UUID(uuidString: "AA000000-0000-0000-0000-000000000002")!,
            name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6"
        )
        let food = Domain.Category(
            id: UUID(uuidString: "CC000000-0000-0000-0000-000000000001")!,
            name: "餐飲", icon: "fork.knife", color: "#FF6B6B", type: .expense
        )

        let store = await TestStore(
            initialState: AddTransactionFeature.State(mode: .add(.expense))
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [cash, bank] }
            $0.categoryClient.fetchAll = { [food] }
            // defaultAccountId set to bank.id → state.accountId should match bank.id
            $0.userSettingsRepository.string = { _ in bank.id.uuidString }
        }

        await store.send(.task) { $0.isLoading = true }

        await store.receive(\.optionsLoaded) {
            $0.isLoading = false
            $0.accounts = [cash, bank]
            $0.categories = [food]
            $0.accountId = bank.id
        }
    }

    @Test(".task falls back to first account when userSettings has no defaultAccountId")
    func testTaskFallsBackToFirstAccountWhenNoDefault() async {
        let cash = Account(
            id: UUID(uuidString: "AB000000-0000-0000-0000-000000000001")!,
            name: "現金", type: .cash, icon: "banknote", color: "#34C759"
        )

        let store = await TestStore(
            initialState: AddTransactionFeature.State(mode: .add(.expense))
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [cash] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }   // empty = no default
        }

        await store.send(.task) { $0.isLoading = true }

        await store.receive(\.optionsLoaded) {
            $0.isLoading = false
            $0.accounts = [cash]
            $0.categories = []
            $0.accountId = cash.id
        }
    }

    @Test("saveTapped with same source and destination sets transferError")
    func testTransferSameAccountValidation() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.amountText = "100"
        state.accountId = Self.account1.id
        state.toAccountId = Self.account1.id

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        }

        await store.send(.saveTapped) {
            $0.transferError = String(localized: "add_transaction_error_same_account")
        }
    }

    @Test("saveTapped with different source and destination proceeds")
    func testTransferDifferentAccountsNoError() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.amountText = "100"
        state.accountId = Self.account1.id
        state.toAccountId = Self.account2.id

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledger.record = { _ in }
        }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)
    }

    @Test("toAccountSelected clears transferError")
    func testToAccountSelectedClearsError() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.transferError = "來源與目標帳戶不能相同"

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        }

        await store.send(.toAccountSelected(Self.account2.id)) {
            $0.toAccountId = Self.account2.id
            $0.transferError = nil
        }
    }

    @Test(".addPrefilled mode pre-fills form fields from ExtractedTransaction")
    func addPrefilledModePreFillsFields() async {
        let extracted = ExtractedTransaction(
            amount: 150,
            suggestedCategory: "食物",
            description: "午餐便當",
            type: "expense"
        )
        let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
        #expect(state.amountText == "150")
        #expect(state.note == "午餐便當")
        #expect(state.type == .expense)
        #expect(state.categoryId == nil)
    }

    @Test(".addPrefilled with all-nil fields uses sensible defaults")
    func addPrefilledNilFieldsDefaults() async {
        let extracted = ExtractedTransaction()
        let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
        #expect(state.amountText == "")
        #expect(state.note == "")
        #expect(state.type == .expense)
    }

    // MARK: - Task 13: AI mode, prefilled routing, and category suggest tests

    // Helper to create a store with AI disabled (prevents unimplemented stub calls)
    private func makeStore(
        mode: AddTransactionFeature.Mode = .add(.expense),
        aiAvailable: Bool = false
    ) async -> TestStoreOf<AddTransactionFeature> {
        await TestStore(
            initialState: AddTransactionFeature.State(mode: mode)
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }
            $0.aiUseCase.isAvailable = { aiAvailable }
            if aiAvailable {
                $0.aiUseCase.extractFromText = { _ in ExtractedTransaction() }
                $0.aiUseCase.suggestCategories = { _, _ in
                    CategorySuggestions(suggestions: [], confidence: "low")
                }
            }
        }
    }

    @Test("saveTapped in .addPrefilled mode creates new transaction")
    func saveTappedPrefilledCreatesTransaction() async {
        let saved = LockIsolated<Transaction?>(nil)
        let account = Account(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            name: "現金", type: .cash, icon: "banknote", color: "#00FF00"
        )
        // Use .transfer type to skip category validation; manually set both accountId and toAccountId
        var initialState = AddTransactionFeature.State(mode: .addPrefilled(ExtractedTransaction()))
        initialState.amountText = "200"
        initialState.type = .transfer
        initialState.accountId = account.id
        initialState.toAccountId = Self.account2.id

        let store = await TestStore(initialState: initialState) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [account] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }
            $0.aiUseCase.isAvailable = { false }
            $0.ledger.record = { saved.setValue($0) }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)
        #expect(saved.value != nil)
        #expect(saved.value?.amount == 200)
    }

    @Test("suggestCategoryTapped is no-op when AI unavailable")
    func suggestCategoryTappedUnavailable() async {
        let store = await makeStore(aiAvailable: false)
        await store.send(.suggestCategoryTapped) {
            $0.categorySuggestionError = String(localized: "add_transaction_ai_unavailable")
        }
    }

    @Test("backgroundExtractionCompleted fills only empty fields")
    func backgroundExtractionFillsOnlyEmptyFields() async {
        let store = await makeStore(aiAvailable: false)
        // Pre-set amountText so it should NOT be overwritten
        await store.send(\.binding.amountText, "999") { $0.amountText = "999" }
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: nil, description: "午餐", type: "income")
        await store.send(.backgroundExtractionCompleted(extracted)) {
            $0.isBackgroundParsingNote = false
            // amount NOT overwritten (was "999")
            // type updated (.add(.expense) initial → income)
            $0.type = .income
            // amountText remains "999" — not overwritten by AI
            #expect($0.amountText == "999")
        }
    }

    @Test("backgroundExtractionCompleted nil clears loading flag only")
    func backgroundExtractionNilClearsLoading() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.isBackgroundParsingNote = true
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }
            $0.aiUseCase.isAvailable = { false }
        }
        await store.send(.backgroundExtractionCompleted(nil)) {
            $0.isBackgroundParsingNote = false
        }
    }

    // MARK: - Recurring toggle tests

    @Test("recurringToggled true sets recurringFrequency to .monthly")
    func testRecurringToggledOn() async {
        let store = await TestStore(
            initialState: AddTransactionFeature.State(mode: .add(.expense))
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.recurringToggled(true)) {
            $0.recurringFrequency = .monthly
        }
    }

    @Test("recurringToggled false clears recurringFrequency")
    func testRecurringToggledOff() async {
        var initialState = AddTransactionFeature.State(mode: .add(.expense))
        initialState.recurringFrequency = .monthly
        let store = await TestStore(initialState: initialState) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.recurringToggled(false)) {
            $0.recurringFrequency = nil
        }
    }

    @Test("saveTapped in addRecurringConfirmation mode emits savedRecurringConfirmation delegate")
    func testSaveTappedRecurringConfirmationEmitsDelegate() async {
        let recurringId = UUID()
        let accountId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let categoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let template = RecurringTransaction(
            id: recurringId, amount: 500, note: "房租",
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: nil, type: .expense, tags: [],
            frequency: .monthly, nextDueDate: Date(),
            isActive: true, createdAt: Date()
        )
        let addedTransaction = LockIsolated<Transaction?>(nil)
        let store = await TestStore(
            initialState: AddTransactionFeature.State(mode: .addRecurringConfirmation(template))
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.ledger.record = { addedTransaction.setValue($0) }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.saveTapped)
        await store.receive(\.delegate.savedRecurringConfirmation) { _ in }

        #expect(addedTransaction.value?.amount == 500)
    }

    @Test("saveTapped in .edit mode sends savedWithTransaction carrying updated values")
    func testEditModeSavedDelegateCarriesTransaction() async {
        let existing = Transaction(
            id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            amount: 100,
            date: Date(timeIntervalSince1970: 0),
            note: "old note",
            categoryId: nil,
            accountId: Self.account1.id,
            toAccountId: nil,
            type: .expense
        )
        var state = AddTransactionFeature.State(mode: .edit(existing))
        state.amountText = "250"
        state.accountId = Self.account1.id

        let updatedCapture: LockIsolated<Transaction?> = LockIsolated(nil)

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [Self.account1] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }
            $0.aiUseCase.isAvailable = { false }
            $0.ledger.update = { updatedCapture.setValue($0) }
        }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfullyWithTransaction)
        await store.receive(\.delegate.savedWithTransaction)

        #expect(updatedCapture.value?.amount == 250)
        #expect(updatedCapture.value?.id == existing.id)
    }
}

@Suite("AddTransactionFeature — voice input")
struct AddTransactionVoiceTests {

    // MARK: - permission denied

    @Test("recordingTapped: permission denied sets speechError")
    func recordingTappedPermissionDenied() async {
        let store = await TestStore(initialState: AddTransactionFeature.State()) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechAdapter.requestPermission = { false }
            $0.aiUseCase.isAvailable = { false }
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
            $0.speechAdapter.requestPermission = { true }
            $0.speechAdapter.startRecording = { stream }
            $0.speechAdapter.stopRecording = { }
            $0.aiUseCase.isAvailable = { false }
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
            $0.speechAdapter.stopRecording = { }
            $0.aiUseCase.isAvailable = { false }
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
            $0.speechAdapter.stopRecording = { }
            $0.aiUseCase.isAvailable = { false }
        }

        await store.send(.transcriptionUpdated("午餐便當")) {
            $0.note = "午餐便當"
        }
    }

    @Test("transcriptionUpdated: second update uses original prefix, not cumulative note")
    func transcriptionUpdatedSecondUpdateUsesOriginalPrefix() async {
        var initial = AddTransactionFeature.State()
        initial.isRecording = true
        initial.noteBeforeRecording = "早餐"
        initial.note = "早餐 五十五元"   // result of first update already applied

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { }
            $0.aiUseCase.isAvailable = { false }
        }

        // SpeechAdapter emits FULL transcript each time (not delta).
        // Second emission should replace the note from the original prefix, not stack.
        await store.send(.transcriptionUpdated("六十元")) {
            $0.note = "早餐 六十元"
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
            $0.speechAdapter.stopRecording = { stopCalled.setValue(true) }
            $0.aiUseCase.isAvailable = { false }
        }

        await store.send(.transcriptionFailed) {
            $0.isRecording = false
            $0.speechError = String(localized: "speech_recognition_failed_error")
            // noteBeforeRecording should remain unchanged — spec does not reset it on failure
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
            $0.speechAdapter.stopRecording = { stopCalled.setValue(true) }
            $0.aiUseCase.isAvailable = { false }
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
            $0.speechAdapter.stopRecording = { stopCalled.setValue(true) }
            $0.aiUseCase.isAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.dismiss) {
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }
}
