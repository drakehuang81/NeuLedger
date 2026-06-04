import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@Suite("TransactionDetailFeature Delete Window Tests")
struct TransactionDetailFeatureDeleteWindowTests {

    private static let sample = Transaction(
        id: UUID(uuidString: "44000000-0000-0000-0000-000000000001")!,
        amount: 100, date: .now, accountId: UUID().uuidString, type: .expense
    )

    @Test("undoTapped clears pendingDelete and cancels window — delete never runs")
    func testUndoCancelsWindow() async {
        let deleteCalled: LockIsolated<Bool> = LockIsolated(false)
        let clock = TestClock()

        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.showDeleteConfirmation = true

        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.ledgerClient.delete = { _ in deleteCalled.setValue(true) }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.pendingDelete = true
        }
        await store.send(.undoTapped) {
            $0.pendingDelete = false
        }
        await clock.advance(by: .seconds(10))
        #expect(deleteCalled.value == false)
    }

    @Test("window expiry triggers delete then delegate.deleted then dismiss")
    func testExpiryDeletesAndDismisses() async {
        let deletedId: LockIsolated<Transaction.ID?> = LockIsolated(nil)
        let dismissed: LockIsolated<Bool> = LockIsolated(false)
        let clock = TestClock()

        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.showDeleteConfirmation = true

        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.ledgerClient.delete = { deletedId.setValue($0) }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
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

        #expect(deletedId.value == Self.sample.id)
        #expect(dismissed.value == true)
    }

    @Test("delete failure during window expiry surfaces alert and preserves transaction")
    func testDeleteFailureShowsAlert() async {
        struct DeleteFailed: Error {}
        let dismissed: LockIsolated<Bool> = LockIsolated(false)
        let clock = TestClock()

        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.showDeleteConfirmation = true

        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.ledgerClient.delete = { _ in throw DeleteFailed() }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.pendingDelete = true
        }
        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowExpired) {
            $0.pendingDelete = false
        }
        await store.receive(\.deleteFailed) {
            $0.deleteFailureAlert = AlertState {
                TextState("transaction_detail_delete_failed_title")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("common_ok")
                }
            } message: {
                TextState("transaction_detail_delete_failed_body")
            }
        }

        #expect(dismissed.value == false)
    }
}
