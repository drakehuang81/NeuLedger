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
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
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
            $0.accountClient.fetchActive = { [Self.sampleAccount] }
            $0.categoryClient.fetchAll = { [] }
            $0.recurringTransactionClient.add = { added.setValue($0) }
            $0.notificationAdapter.scheduleRecurringReminder = { _, _, _, _ in }
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
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
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
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
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
            $0.accountClient.fetchActive = { [Self.sampleAccount] }
            $0.categoryClient.fetchAll = { [] }
            $0.recurringTransactionClient.add = { added.setValue($0) }
            $0.notificationAdapter.scheduleRecurringReminder = { _, _, _, _ in }
            $0.dismiss = DismissEffect { }
        }
        store.exhaustivity = .off

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
            $0.accountClient.fetchActive = { [Self.sampleAccount] }
            $0.categoryClient.fetchAll = { [] }
            $0.recurringTransactionClient.add = { _ in throw FakeError() }
            $0.dismiss = DismissEffect { }
        }
        store.exhaustivity = .off

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
            accountId: UUID(), toAccountId: nil, type: .expense,
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
