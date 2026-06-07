import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("TransactionDetailFeature Tests")
struct TransactionDetailFeatureTests {

    private static let account = Account(
        id: "11000000-0000-0000-0000-000000000001",
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )

    private static let sampleTransaction = Transaction(
        id: UUID(uuidString: "22000000-0000-0000-0000-000000000001")!,
        amount: 150,
        date: Date(timeIntervalSince1970: 0),
        note: "午餐",
        categoryId: nil,
        accountId: account.id,
        toAccountId: nil,
        type: .expense
    )

    // MARK: - Edit Flow

    @Test("editTapped presents edit form with .edit mode")
    func testEditTappedPresentsEditForm() async {
        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        ) {
            TransactionDetailFeature()
        }

        await store.send(.editTapped) {
            $0.editTransaction = AddTransactionFeature.State(mode: .edit(Self.sampleTransaction))
        }
    }

    @Test("savedWithTransaction updates state.transaction, dismisses sheet, sends delegate")
    func testEditSavedWithTransactionUpdatesStateAndSendsDelegate() async {
        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.editTransaction = AddTransactionFeature.State(mode: .edit(Self.sampleTransaction))

        let updatedTransaction = Transaction(
            id: Self.sampleTransaction.id,
            amount: 300,
            date: Self.sampleTransaction.date,
            note: "晚餐",
            categoryId: nil,
            accountId: Self.account.id,
            toAccountId: nil,
            type: .expense
        )

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        }

        await store.send(.editTransaction(.presented(.delegate(.savedWithTransaction(updatedTransaction))))) {
            $0.transaction = updatedTransaction
            $0.editTransaction = nil
        }
        await store.receive(\.delegate.updated)
    }

    // MARK: - Delete Flow

    @Test("deleteTapped shows delete confirmation")
    func testDeleteTappedShowsConfirmation() async {
        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        ) {
            TransactionDetailFeature()
        }

        await store.send(.deleteTapped) {
            $0.showDeleteConfirmation = true
        }
    }

    @Test("deleteCancelled clears showDeleteConfirmation flag")
    func testDeleteCancelledClearsFlag() async {
        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.showDeleteConfirmation = true

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        }

        await store.send(.deleteCancelled) {
            $0.showDeleteConfirmation = false
        }
    }

    // MARK: - Task (initial load of names)

    @Test(".task loads category name and accounts via namesLoaded")
    func testTaskLoadsNames() async {
        let account = Account(
            id: Self.account.id,
            name: "現金", type: .cash, icon: "banknote", color: "#34C759"
        )
        let toAccount = Account(
            id: "11000000-0000-0000-0000-000000000002",
            name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6"
        )
        let category = Domain.Category(
            id: UUID(uuidString: "33000000-0000-0000-0000-000000000001")!,
            name: "餐飲", icon: "fork.knife", color: "#FF6B6B", type: .expense
        )

        let txn = Transaction(
            id: Self.sampleTransaction.id,
            amount: 200,
            date: Self.sampleTransaction.date,
            note: "午餐",
            categoryId: category.id,
            accountId: account.id,
            toAccountId: toAccount.id,
            type: .expense
        )

        let stubInsight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))

        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: txn)
        ) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.ledgerClient.listAccounts = { [account, toAccount] }
            $0.ledgerClient.listCategories = { _ in [category] }
            $0.insightsClient.detailStats = { _ in stubInsight }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task)
        // namesLoaded and insightLoaded arrive concurrently; exhaust both regardless of order.
        await store.receive(\.namesLoaded) {
            $0.categoryName = "餐飲"
            $0.account = account
            $0.toAccount = toAccount
        }
        // insightLoaded may have arrived before namesLoaded; drain any remaining actions.
        await store.skipReceivedActions(strict: false)
    }

    // MARK: - B4 補強：dismiss、editTransaction dismissed、deleteFailureAlert dismiss、task 失敗

    @Test("dismiss action calls DismissEffect")
    func testDismissCallsDismissEffect() async {
        let dismissed = LockIsolated(false)
        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        ) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.dismiss)
        await store.finish()
        #expect(dismissed.value == true)
    }

    @Test("editTransaction delegate dismissed clears editTransaction sheet")
    func testEditTransactionDismissedClearsSheet() async {
        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.editTransaction = AddTransactionFeature.State(mode: .edit(Self.sampleTransaction))

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        }

        await store.send(.editTransaction(.presented(.delegate(.dismissed)))) {
            $0.editTransaction = nil
        }
    }

    @Test("deleteFailureAlert dismiss clears the alert")
    func testDeleteFailureAlertDismissClearsAlert() async {
        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.deleteFailureAlert = AlertState {
            TextState("transaction_detail_delete_failed_title")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("common_ok")
            }
        } message: {
            TextState("transaction_detail_delete_failed_body")
        }

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        }

        await store.send(.deleteFailureAlert(.presented(.dismiss))) {
            $0.deleteFailureAlert = nil
        }
    }

    @Test(".task 中 detailStats 拋錯時 receive insightFailed 並清 insight")
    func testTaskInsightsClientThrowSendsInsightFailed() async {
        struct InsightError: Error {}
        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.insight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.ledgerClient.listAccounts = { [Self.account] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.detailStats = { _ in throw InsightError() }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.task)
        await store.receive(\.insightFailed) {
            $0.insight = nil
        }
        await store.finish()
    }

    @Test("deleteConfirmed enters pending state; window expiry triggers delete + delegate")
    func testDeleteConfirmedCallsDeleteAndDismisses() async {
        let deletedId: LockIsolated<Transaction.ID?> = LockIsolated(nil)
        let id = Self.sampleTransaction.id

        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.showDeleteConfirmation = true

        let clock = TestClock()
        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.ledgerClient.delete = { deletedId.setValue($0) }
            $0.continuousClock = clock
            $0.dismiss = DismissEffect { }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.pendingDelete = true
        }
        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowExpired) {
            $0.pendingDelete = false
        }
        await store.receive(\.delegate.deleted)

        #expect(deletedId.value == id)
    }
}
