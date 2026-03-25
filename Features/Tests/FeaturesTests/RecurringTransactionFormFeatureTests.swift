import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("RecurringTransactionFormFeature Tests")
struct RecurringTransactionFormFeatureTests {

    static let sampleAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false, createdAt: Date()
    )

    @Test("saveTapped with empty amount sets amountError")
    func testSaveTappedEmptyAmount() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.saveTapped) {
            $0.amountError = String(localized: "add_transaction_error_amount")
        }
    }

    @Test("saveTapped with no account sets accountError")
    func testSaveTappedNoAccount() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.saveTapped) {
            $0.accountError = String(localized: "add_transaction_error_account")
        }
    }

    @Test("saveTapped with valid inputs calls add and emits saved delegate")
    func testSaveTappedValid() async {
        let added = LockIsolated<RecurringTransaction?>(nil)
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [Self.sampleAccount] }
            $0.categoryClient.fetchAll = { [] }
            $0.recurringTransactionClient.add = { added.setValue($0) }
            $0.notificationClient.scheduleRecurringReminder = { _, _, _, _ in }
            $0.dismiss = DismissEffect { }
        }
        store.exhaustivity = .off

        await store.send(.amountChanged("15000")) { $0.amountText = "15000" }
        await store.send(.accountChanged(Self.sampleAccount.id)) {
            $0.accountId = Self.sampleAccount.id
        }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)

        #expect(added.value?.amount == 15000)
        #expect(added.value?.accountId == Self.sampleAccount.id)
    }
}
