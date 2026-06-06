import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("RecurringTransactionFormFeature Tests")
struct RecurringTransactionFormFeatureTests {

    static let sampleAccount = Account(
        id: "00000000-0000-0000-0000-000000000001",
        name: "現金", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false, createdAt: Date()
    )

    static let sampleAccount2 = Account(
        id: "00000000-0000-0000-0000-000000000002",
        name: "銀行", type: .bank, icon: "building.columns", color: "#0A84FF",
        sortOrder: 1, isArchived: false, createdAt: Date()
    )

    // MARK: - Transfer support (audit A1)

    @Test("toAccountChanged updates toAccountId and clears transferError")
    func testToAccountChanged() async {
        var initialState = RecurringTransactionFormFeature.State(mode: .add)
        initialState.transferError = "stale"
        let store = await TestStore(initialState: initialState) {
            RecurringTransactionFormFeature()
        }
        await store.send(.toAccountChanged(Self.sampleAccount2.id)) {
            $0.toAccountId = Self.sampleAccount2.id
            $0.transferError = nil
        }
    }

    @Test("saveTapped transfer without toAccount sets transferError")
    func testSaveTransferWithoutToAccountSetsError() async {
        let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
            RecurringTransactionFormFeature()
        }
        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
        await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
        await store.send(.saveTapped) {
            $0.transferError = String(localized: "recurring_transaction_error_to_account")
        }
    }

    @Test("saveTapped transfer to the same account sets transferError")
    func testSaveTransferSameAccountSetsError() async {
        let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
            RecurringTransactionFormFeature()
        }
        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
        await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
        await store.send(.toAccountChanged(Self.sampleAccount.id)) { $0.toAccountId = Self.sampleAccount.id }
        await store.send(.saveTapped) {
            $0.transferError = String(localized: "add_transaction_error_same_account")
        }
    }

    @Test("saveTapped valid transfer persists toAccountId on the created template")
    func testSaveTransferValidPersistsToAccountId() async {
        let added = LockIsolated<RecurringTransaction?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
        let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.ledgerClient.createRecurring = { template in added.setValue(template) }
            $0.dismiss = DismissEffect {}
        }
        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
        await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
        await store.send(.toAccountChanged(Self.sampleAccount2.id)) { $0.toAccountId = Self.sampleAccount2.id }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)
        #expect(added.value?.type == .transfer)
        #expect(added.value?.toAccountId == Self.sampleAccount2.id)
    }

    @Test("non-transfer save nils out a previously picked toAccountId")
    func testNonTransferSaveNilsToAccountId() async {
        let added = LockIsolated<RecurringTransaction?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
        let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.ledgerClient.createRecurring = { template in added.setValue(template) }
            $0.dismiss = DismissEffect {}
        }
        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
        await store.send(.toAccountChanged(Self.sampleAccount2.id)) { $0.toAccountId = Self.sampleAccount2.id }
        await store.send(.typeChanged(.expense)) { $0.type = .expense }
        await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)
        #expect(added.value?.toAccountId == nil)
    }

    @Test("saveTapped with empty amount sets amountError")
    func testSaveTappedEmptyAmount() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }

        await store.send(.saveTapped) {
            $0.amountError = String(localized: "recurring_transaction_error_amount")
        }
    }

    @Test("saveTapped with no account sets accountError")
    func testSaveTappedNoAccount() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }

        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.saveTapped) {
            $0.accountError = String(localized: "recurring_transaction_error_account")
        }
    }

    @Test("saveTapped with valid inputs calls add and emits saved delegate")
    func testSaveTappedValid() async {
        let added = LockIsolated<RecurringTransaction?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.ledgerClient.listActiveAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.createRecurring = { added.setValue($0) }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.amountChanged("15000")) { $0.amountText = "15000" }
        await store.send(.accountChanged(Self.sampleAccount.id)) {
            $0.accountId = Self.sampleAccount.id
        }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)

        #expect(added.value?.amount == 15000)
        #expect(added.value?.accountId == Self.sampleAccount.id)
    }

    // P0-1: Frequency change rebases nextDueDate
    @Test("frequencyChanged from weekly to yearly rebases firstRunDate to ~1 year later")
    func testFrequencyChangedRebasesNextDueDate() async {
        // Fixed reference date: 2025-06-15 00:00:00 UTC
        let referenceNow = Date(timeIntervalSinceReferenceDate: 771_638_400) // 2025-06-15

        var initialState = RecurringTransactionFormFeature.State(mode: .add)
        initialState.frequency = .weekly

        let store = await TestStore(initialState: initialState) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(referenceNow)
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }

        await store.send(.frequencyChanged(.yearly)) { state in
            state.frequency = .yearly
            // After rebasing, firstRunDate must be set to ~1 year after referenceNow
            let cal = Calendar.current
            let expectedBase = cal.date(byAdding: .year, value: 1, to: referenceNow)!
            let expectedDay = cal.startOfDay(for: expectedBase)
            state.firstRunDate = expectedDay
        }
    }

    @Test("frequencyChanged to same value does not mutate state")
    func testFrequencyChangedSameValueIsNoOp() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }
        // Default frequency is .monthly; sending .monthly again is a no-op
        await store.send(.frequencyChanged(.monthly))
        // No state mutation expected — TestStore in strict mode would fail if there were changes
    }

    // P0-2: Add mode exposes firstRunDate for user to pick
    @Test("add mode allows user to pick first run date")
    func testAddModeAllowsUserToPickFirstDate() async throws {
        let added = LockIsolated<RecurringTransaction?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)

        var initialState = RecurringTransactionFormFeature.State(mode: .add)
        // Simulate user picking a specific date 3 days from now
        let userChosenDate = Calendar.current.date(byAdding: .day, value: 3, to: fixedNow)!
        initialState.firstRunDate = Calendar.current.startOfDay(for: userChosenDate)
        initialState.accountId = Self.sampleAccount.id
        initialState.amountText = "500"

        let store = await TestStore(initialState: initialState) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date.now = fixedNow
            $0.ledgerClient.listActiveAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.createRecurring = { added.setValue($0) }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)

        // The saved nextDueDate date portion should match user-chosen date
        let saved = try #require(added.value)
        let savedDay = Calendar.current.startOfDay(for: saved.nextDueDate)
        #expect(savedDay == Calendar.current.startOfDay(for: userChosenDate))
    }

    // P0-3: Save failure shows error inline
    @Test("saveFailed sets saveError on state")
    func testSaveFailedShowsError() async {
        struct FakeError: Error { var localizedDescription: String { "저장 실패" } }
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)

        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.ledgerClient.listActiveAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.createRecurring = { _ in throw FakeError() }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.amountChanged("100")) { $0.amountText = "100" }
        await store.send(.accountChanged(Self.sampleAccount.id)) {
            $0.accountId = Self.sampleAccount.id
        }
        await store.send(.saveTapped)
        await store.receive(\.saveFailed) { state in
            #expect(state.saveError != nil)
        }
    }

    // P1-7: Monthly next date from the 31st — smoke test using domain helper
    @Test("nextDate monthly from the 31st rolls to last day of next month")
    func testNextDateMonthlyFrom1_31() {
        // Jan 31
        var components = DateComponents()
        components.year = 2025; components.month = 1; components.day = 31
        let jan31 = Calendar.current.date(from: components)!

        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .monthly, nextDueDate: jan31,
            isActive: true, createdAt: jan31
        )

        let next = rt.nextDate(after: jan31)
        let nextComponents = Calendar.current.dateComponents([.month, .day], from: next)
        // Feb has max 28/29 days; Calendar clamps to last day
        #expect(nextComponents.month == 2)
        #expect((nextComponents.day ?? 0) <= 29)
    }
}
