import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("RecurringTransactionManagementFeature Tests")
struct RecurringTransactionManagementFeatureTests {

    static func sample(id: UUID = UUID()) -> RecurringTransaction {
        RecurringTransaction(
            id: id, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID(), toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
    }

    @Test(".task loads recurring transactions")
    func testTaskLoads() async {
        let rt = Self.sample()
        let store = await TestStore(initialState: RecurringTransactionManagementFeature.State()) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [rt] }
        }

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.items = [rt]
        }
    }

    @Test("toggleActiveTapped flips isActive")
    func testToggleActive() async {
        let updated = LockIsolated<RecurringTransaction?>(nil)
        let rt = Self.sample()
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.update = { updated.setValue($0) }
            $0.recurringTransactionClient.fetchAll = { [rt] }
            $0.notificationClient.cancelRecurringReminder = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.toggleActiveTapped(rt))
        #expect(updated.value?.isActive == false)
    }

    @Test("deleteTapped removes item and cancels notification")
    func testDeleteTapped() async {
        let deletedId = LockIsolated<RecurringTransaction.ID?>(nil)
        let cancelledId = LockIsolated<RecurringTransaction.ID?>(nil)
        let rt = Self.sample()
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.delete = { deletedId.setValue($0) }
            $0.recurringTransactionClient.fetchAll = { [] }
            $0.notificationClient.cancelRecurringReminder = { cancelledId.setValue($0) }
        }

        await store.send(.deleteTapped(rt.id))
        await store.receive(\.loaded) { $0.items = [] }
        #expect(deletedId.value == rt.id)
        #expect(cancelledId.value == rt.id)
    }
}
