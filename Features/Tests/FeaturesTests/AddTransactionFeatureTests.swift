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
            $0.transactionClient.add = { _ in }
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
            $0.userSettingsClient.string = { _ in "" }
            $0.aiServiceClient.isAvailable = { aiAvailable }
            if aiAvailable {
                $0.aiServiceClient.extractTransaction = { _ in ExtractedTransaction() }
                $0.aiServiceClient.suggestCategories = { _, _ in
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
            $0.userSettingsClient.string = { _ in "" }
            $0.aiServiceClient.isAvailable = { false }
            $0.transactionClient.add = { saved.setValue($0) }
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
            $0.categorySuggestionError = "此裝置不支援 AI 功能"
        }
    }

    @Test("backgroundExtractionCompleted fills only empty fields")
    func backgroundExtractionFillsOnlyEmptyFields() async {
        let store = await makeStore(aiAvailable: false)
        // Pre-set amountText so it should NOT be overwritten
        await store.send(.amountTextChanged("999")) { $0.amountText = "999" }
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
            $0.userSettingsClient.string = { _ in "" }
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.backgroundExtractionCompleted(nil)) {
            $0.isBackgroundParsingNote = false
        }
    }
}
