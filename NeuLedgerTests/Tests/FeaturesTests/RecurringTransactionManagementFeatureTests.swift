import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("RecurringTransactionManagementFeature Tests")
struct RecurringTransactionManagementFeatureTests {

    static func sample(
        id: UUID = UUID(),
        frequency: BudgetPeriod = .monthly,
        nextDueDate: Date = Date(),
        isActive: Bool = true
    ) -> RecurringTransaction {
        RecurringTransaction(
            id: id, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID(), toAccountId: nil,
            type: .expense, tags: [], frequency: frequency,
            nextDueDate: nextDueDate, isActive: isActive, createdAt: Date()
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
        let deactivated = LockIsolated<RecurringTransaction>({ var r = rt; r.isActive = false; return r }())
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.date = .constant(Date())
            $0.recurringTransactionClient.update = { updated.setValue($0) }
            $0.recurringTransactionClient.fetchAll = { [deactivated.value] }
            $0.notificationAdapter.cancelRecurringReminder = { _ in }
        }

        await store.send(.toggleActiveTapped(rt))
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.items = [deactivated.value]
        }
        #expect(updated.value?.isActive == false)
    }

    // P1-5 step 1: deleteRequested presents confirmation alert
    @Test("deleteRequested presents confirmation alert")
    func testDeleteRequestedShowsAlert() async {
        let rt = Self.sample()
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [rt] }
        }

        await store.send(.deleteRequested(rt.id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_recurring_transaction"))
            } actions: {
                ButtonState(role: .destructive, action: .deleteConfirmed(rt.id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(localized: "alert_delete_recurring_transaction_message"))
            }
        }
    }

    // P1-5 step 2: deleteConfirmed removes item and cancels notification
    @Test("deleteConfirmed removes item and cancels notification")
    func testDeleteShowsAlertAndConfirmation() async {
        let deletedId = LockIsolated<RecurringTransaction.ID?>(nil)
        let cancelledId = LockIsolated<RecurringTransaction.ID?>(nil)
        let rt = Self.sample()
        // Start with alert pre-presented (after deleteRequested)
        var initialState = RecurringTransactionManagementFeature.State(items: [rt])
        initialState.alert = AlertState {
            TextState(String(localized: "alert_delete_recurring_transaction"))
        } actions: {
            ButtonState(
                role: .destructive,
                action: RecurringTransactionManagementFeature.Action.Alert.deleteConfirmed(rt.id)
            ) {
                TextState(String(localized: "common_delete"))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel"))
            }
        } message: {
            TextState(String(localized: "alert_delete_recurring_transaction_message"))
        }

        let store = await TestStore(initialState: initialState) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.delete = { deletedId.setValue($0) }
            $0.recurringTransactionClient.fetchAll = { [] }
            $0.notificationAdapter.cancelRecurringReminder = { cancelledId.setValue($0) }
        }

        await store.send(.alert(.presented(.deleteConfirmed(rt.id)))) {
            $0.alert = nil
        }
        await store.receive(\.loaded) { $0.items = [] }

        #expect(deletedId.value == rt.id)
        #expect(cancelledId.value == rt.id)
    }

    // P0-4: Re-enabling item with past nextDueDate reschedules to future
    @Test("toggleActiveTapped true with overdue nextDueDate schedules to future")
    func testToggleActiveTruePushesOverdueToFuture() async throws {
        let scheduledDate = LockIsolated<Date?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400) // 2025-06-15
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: fixedNow)!
        let rt = Self.sample(nextDueDate: pastDate, isActive: false)
        let reactivated: RecurringTransaction = {
            var r = rt; r.isActive = true; return r
        }()

        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.recurringTransactionClient.update = { _ in }
            $0.recurringTransactionClient.fetchAll = { [reactivated] }
            $0.notificationAdapter.scheduleRecurringReminder = { _, date, _, _ in
                scheduledDate.setValue(date)
            }
        }

        await store.send(.toggleActiveTapped(rt))
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.items = [reactivated]
        }

        let saved = try #require(scheduledDate.value)
        #expect(saved > fixedNow)
    }

    // P1-D: Month-end boundary — 2026/01/31 + 1 month should clamp to 2026/02/28
    @Test("nextDate from 2026/01/31 (monthly) returns 2026/02/28")
    func testNextDateCrossesMonthEndBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var startComponents = DateComponents()
        startComponents.year = 2026
        startComponents.month = 1
        startComponents.day = 31
        startComponents.hour = 9
        startComponents.minute = 0
        let jan31 = try #require(calendar.date(from: startComponents))

        let rt = Self.sample(frequency: .monthly, nextDueDate: jan31)
        let next = rt.nextDate(after: jan31, calendar: calendar)

        let nextComponents = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(nextComponents.year == 2026)
        #expect(nextComponents.month == 2)
        // February 2026 has 28 days (not a leap year). Calendar clamps day 31 → 28.
        #expect(nextComponents.day == 28)
    }

    // P0-1 smoke: edit mode form state carries correct firstRunDate
    @Test("edit mode form state reflects existing nextDueDate date portion")
    func testEditFormStateReflectsExistingNextDueDate() async {
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 20
        components.hour = 8; components.minute = 30
        let specificDate = Calendar.current.date(from: components)!
        let rt = Self.sample(nextDueDate: specificDate)

        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [rt] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.itemTapped(rt)) { state in
            #expect(state.form != nil)
            let expectedDay = Calendar.current.startOfDay(for: specificDate)
            #expect(state.form?.firstRunDate == expectedDay)
        }
    }
}
