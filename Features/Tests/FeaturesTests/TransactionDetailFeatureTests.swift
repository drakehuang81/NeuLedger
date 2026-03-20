import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("TransactionDetailFeature Tests")
struct TransactionDetailFeatureTests {

    private static let account = Account(
        id: UUID(uuidString: "11000000-0000-0000-0000-000000000001")!,
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

    @Test("deleteConfirmed calls transactionClient.delete and sends delegate")
    func testDeleteConfirmedCallsDeleteAndDismisses() async {
        let deletedId: LockIsolated<Transaction.ID?> = LockIsolated(nil)
        let id = Self.sampleTransaction.id

        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.showDeleteConfirmation = true

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.transactionClient.delete = { deletedId.setValue($0) }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
        }
        await store.receive(\.delegate.deleted)

        #expect(deletedId.value == id)
    }
}
