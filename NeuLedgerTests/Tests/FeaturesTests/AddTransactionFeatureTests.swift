import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AddTransactionFeature Tests")
struct AddTransactionFeatureTests {

    private static let account1 = Account(
        id: "00000000-0000-0000-0000-000000000001",
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )
    private static let account2 = Account(
        id: "00000000-0000-0000-0000-000000000002",
        name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6"
    )

    // P1-F: Task loads accounts and categories and populates state
    @Test(".task loads accounts and categories and sets default accountId from userSettings")
    func testTaskLoadsOptionsAndAppliesDefaultAccount() async {
        let cash = Account(
            id: "AA000000-0000-0000-0000-000000000001",
            name: "現金", type: .cash, icon: "banknote", color: "#34C759"
        )
        let bank = Account(
            id: "AA000000-0000-0000-0000-000000000002",
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
            $0.ledgerClient.listActiveAccounts = { [cash, bank] }
            $0.ledgerClient.listCategories = { _ in [food] }
            // defaultAccountId set to bank.id → state.accountId should match bank.id
            $0.ledgerClient.defaultAccountId = { bank.id }
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
            id: "AB000000-0000-0000-0000-000000000001",
            name: "現金", type: .cash, icon: "banknote", color: "#34C759"
        )

        let store = await TestStore(
            initialState: AddTransactionFeature.State(mode: .add(.expense))
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [cash] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }   // nil = no default
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
            $0.ledgerClient.record = { _ in }
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
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { aiAvailable }
            if aiAvailable {
                $0.captureClient.extractFromText = { _ in ExtractedTransaction() }
                $0.captureClient.suggestCategories = { _, _ in
                    CategorySuggestions(suggestions: [], confidence: "low")
                }
            }
        }
    }

    @Test("saveTapped in .addPrefilled mode creates new transaction")
    func saveTappedPrefilledCreatesTransaction() async {
        let saved = LockIsolated<Transaction?>(nil)
        let account = Account(
            id: "00000000-0000-0000-0000-000000000010",
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
            $0.ledgerClient.listActiveAccounts = { [account] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
            $0.ledgerClient.record = { saved.setValue($0) }
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
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
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
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
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
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
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
        let accountId = "00000000-0000-0000-0000-000000000001"
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
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.record = { addedTransaction.setValue($0) }
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
            $0.ledgerClient.listActiveAccounts = { [Self.account1] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
            $0.ledgerClient.update = { updatedCapture.setValue($0) }
        }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfullyWithTransaction)
        await store.receive(\.delegate.savedWithTransaction)

        #expect(updatedCapture.value?.amount == 250)
        #expect(updatedCapture.value?.id == existing.id)
    }
}

// MARK: - Recurring template creation (Task 4 & 5)

@Suite("AddTransactionFeature — recurring template")
struct AddTransactionRecurringTemplateTests {

    private static let account = Account(
        id: "00000000-0000-0000-0000-000000000020",
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )
    private static let category = Domain.Category(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
        name: "餐飲", icon: "fork.knife", color: "#FF6B6B", type: .expense
    )

    // Task 4：saveTapped 在 .add 模式 + recurringFrequency != nil
    // → spy ledger.createRecurring，斷言 template 的 frequency / amount / accountId / nextDueDate
    @Test("saveTapped with recurringFrequency .monthly creates recurring template with correct fields")
    func testSaveTappedCreatesRecurringTemplateMonthly() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let expectedNextDue = Calendar.current.date(byAdding: .month, value: 1, to: fixedDate)!

        let createdTemplate = LockIsolated<RecurringTransaction?>(nil)
        let recordedTx = LockIsolated<Transaction?>(nil)

        var initial = AddTransactionFeature.State(mode: .add(.expense), date: fixedDate)
        initial.amountText   = "500"
        initial.accountId    = Self.account.id
        initial.categoryId   = Self.category.id
        initial.recurringFrequency = .monthly

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [Self.account] }
            $0.ledgerClient.listCategories     = { _ in [Self.category] }
            $0.ledgerClient.defaultAccountId   = { nil }
            $0.captureClient.isAvailable       = { false }
            $0.ledgerClient.record             = { recordedTx.setValue($0) }
            $0.ledgerClient.createRecurring    = { createdTemplate.setValue($0) }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        // 交易本體必須被記錄
        #expect(recordedTx.value?.amount == 500)

        // Recurring template 必須被建立，且欄位正確
        let tpl = try #require(createdTemplate.value)
        #expect(tpl.frequency   == .monthly)
        #expect(tpl.amount      == 500)
        #expect(tpl.accountId   == Self.account.id)
        // nextDueDate 按 .monthly 計算（+1 個月）
        #expect(tpl.nextDueDate == expectedNextDue)
    }

    @Test("saveTapped with recurringFrequency .weekly creates recurring template with weekly nextDueDate")
    func testSaveTappedCreatesRecurringTemplateWeekly() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let expectedNextDue = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: fixedDate)!

        let createdTemplate = LockIsolated<RecurringTransaction?>(nil)

        var initial = AddTransactionFeature.State(mode: .add(.expense), date: fixedDate)
        initial.amountText   = "300"
        initial.accountId    = Self.account.id
        initial.categoryId   = Self.category.id
        initial.recurringFrequency = .weekly

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [Self.account] }
            $0.ledgerClient.listCategories     = { _ in [Self.category] }
            $0.ledgerClient.defaultAccountId   = { nil }
            $0.captureClient.isAvailable       = { false }
            $0.ledgerClient.record             = { _ in }
            $0.ledgerClient.createRecurring    = { createdTemplate.setValue($0) }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        let tpl = try #require(createdTemplate.value)
        #expect(tpl.frequency   == .weekly)
        #expect(tpl.nextDueDate == expectedNextDue)
    }

    // Task 5：負例 — recurringFrequency == nil → createRecurring 不被呼叫
    @Test("saveTapped with recurringFrequency nil does NOT call createRecurring")
    func testSaveTappedWithoutRecurringDoesNotCallCreateRecurring() async {
        let createRecurringCallCount = LockIsolated(0)

        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.amountText  = "100"
        initial.accountId   = Self.account.id
        initial.categoryId  = Self.category.id
        // recurringFrequency 預設為 nil

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [Self.account] }
            $0.ledgerClient.listCategories     = { _ in [Self.category] }
            $0.ledgerClient.defaultAccountId   = { nil }
            $0.captureClient.isAvailable       = { false }
            $0.ledgerClient.record             = { _ in }
            $0.ledgerClient.createRecurring    = { _ in createRecurringCallCount.withValue { $0 += 1 } }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        // createRecurring 不應被呼叫
        #expect(createRecurringCallCount.value == 0)
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
            $0.captureClient.requestVoicePermission = { false }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.requestVoicePermission = { true }
            $0.captureClient.startVoiceSession = { stream }
            $0.captureClient.stopVoiceSession = { }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.stopVoiceSession = { }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.stopVoiceSession = { }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.stopVoiceSession = { }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.stopVoiceSession = { stopCalled.setValue(true) }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.stopVoiceSession = { stopCalled.setValue(true) }
            $0.captureClient.isAvailable = { false }
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
            $0.captureClient.stopVoiceSession = { stopCalled.setValue(true) }
            $0.captureClient.isAvailable = { false }
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

// MARK: - B4 補強：typeChanged、recurringFrequencyChanged、categorySelected、accountSelected

@Suite("AddTransactionFeature — typeChanged / recurringFrequencyChanged / selection")
struct AddTransactionTypeAndSelectionTests {

    @Test("typeChanged 設定 type 並重置 categoryId")
    func typeChangedResetsCategory() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.categoryId = UUID(uuidString: "EEEEEEEE-0000-0000-0000-000000000001")
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }

        await store.send(.typeChanged(.income)) {
            $0.type = .income
            $0.categoryId = nil // 切換 type 後 categoryId 應被重置
        }
    }

    @Test("recurringFrequencyChanged 設定指定 frequency")
    func recurringFrequencyChangedSetsFrequency() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.recurringFrequency = .monthly

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }

        await store.send(.recurringFrequencyChanged(.yearly)) {
            $0.recurringFrequency = .yearly
        }
    }

    @Test("accountSelected 清除 accountError 與 transferError")
    func accountSelectedClearsErrors() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.accountError = "請選擇帳戶"
        initial.transferError = "來源與目標不可相同"
        let accountId = "FFFFFFFF-0000-0000-0000-000000000001"

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }

        await store.send(.accountSelected(accountId)) {
            $0.accountId = accountId
            $0.accountError = nil
            $0.transferError = nil
        }
    }

    @Test("categorySelected 清除 categoryError")
    func categorySelectedClearsCategoryError() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.categoryError = "請選擇分類"
        let categoryId = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000002")!

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }

        await store.send(.categorySelected(categoryId)) {
            $0.categoryId = categoryId
            $0.categoryError = nil
        }
    }
}

// MARK: - B3 補強：categorySuggestionsReceived success / failure

@Suite("AddTransactionFeature — categorySuggestionsReceived")
struct AddTransactionCategorySuggestionsTests {

    private static let food = Domain.Category(
        id: UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000001")!,
        name: "餐飲", icon: "fork.knife", color: "#FF6B6B", type: .expense
    )
    private static let transport = Domain.Category(
        id: UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000002")!,
        name: "交通", icon: "car", color: "#3478F6", type: .expense
    )

    @Test("categorySuggestionsReceived success filters to existing category names")
    func categorySuggestionsReceivedSuccessFilters() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        // 提供兩個分類，AI 回傳三個建議（其中「無效」不在清單中）
        initial.categories = [Self.food, Self.transport]
        initial.isSuggestingCategory = true

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [Self.food, Self.transport] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { true }
        }

        let suggestions = CategorySuggestions(suggestions: ["餐飲", "無效分類", "交通"], confidence: "high")
        await store.send(.categorySuggestionsReceived(.success(suggestions))) {
            $0.isSuggestingCategory = false
            // 「無效分類」不在 filteredCategories 中，會被過濾掉
            $0.suggestedCategoryNames = ["餐飲", "交通"]
        }
    }

    @Test("categorySuggestionsReceived failure sets categorySuggestionError and clears isSuggestingCategory")
    func categorySuggestionsReceivedFailureSetsError() async {
        struct FakeAIError: Error {}
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.categories = [Self.food]
        initial.isSuggestingCategory = true

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [Self.food] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { true }
        }

        await store.send(.categorySuggestionsReceived(.failure(FakeAIError()))) {
            $0.isSuggestingCategory = false
            $0.categorySuggestionError = String(localized: "add_transaction_category_suggestion_failed")
        }
    }
}

// MARK: - B3 補強：note binding AI 擷取邏輯（note debounce 說明）
//
// AddTransactionFeature 的 note binding → extractFromText 防抖 effect 使用
// RunLoop.main scheduler（不可用 TestClock 控制）。
// 此 suite 改用「直接 send backgroundExtractionCompleted 下游 action」驗證
// 邏輯正確性，並補充 binding.note 設定 isBackgroundParsingNote 的同步行為。

@Suite("AddTransactionFeature — note binding AI extraction logic")
struct AddTransactionNoteDebounceTests {

    @Test("binding.note non-empty sets isBackgroundParsingNote to true synchronously")
    func noteBindingNonEmptySetsParsingFlag() async {
        let store = await TestStore(
            initialState: AddTransactionFeature.State(mode: .add(.expense))
        ) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
            $0.captureClient.extractFromText = { _ in ExtractedTransaction() }
        }
        await MainActor.run { store.exhaustivity = .off }

        // 送 binding.note — reducer 同步設 isBackgroundParsingNote = true
        await store.send(\.binding.note, "早餐100元") {
            $0.note = "早餐100元"
            $0.isBackgroundParsingNote = true
        }
        // RunLoop.main debounce 不可控，不 receive backgroundExtractionCompleted；
        // 用 finish() 讓 in-flight effect 靜默清理
        await store.finish()
    }

    @Test("binding.note cleared cancels noteDebounce and clears isBackgroundParsingNote")
    func noteBindingEmptyCancelsDebounce() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.note = "早餐100元"
        initial.isBackgroundParsingNote = true

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }

        // 清空 note → reducer 應取消 noteDebounce effect，isBackgroundParsingNote 被設為 false
        await store.send(\.binding.note, "") {
            $0.note = ""
            $0.isBackgroundParsingNote = false
        }
        // noteDebounce cancel — 無 in-flight effect 需等待
    }

    @Test("backgroundExtractionCompleted with extracted result fills empty fields")
    func backgroundExtractionCompletedFillsEmptyFields() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense))
        initial.isBackgroundParsingNote = true
        // note 有內容但 amountText 為空 → amount 應被填入
        initial.note = "午餐180元"

        let extracted = ExtractedTransaction(
            amount: 180,
            suggestedCategory: nil,
            description: "午餐180元",
            type: "expense"
        )

        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }

        await store.send(.backgroundExtractionCompleted(extracted)) {
            $0.isBackgroundParsingNote = false
            $0.amountText = "180"   // 空 amountText 被填入
        }
    }
}
