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
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
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
            $0.ledgerClient.listRecurring = { [rt] }
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
            $0.ledgerClient.updateRecurring = { updated.setValue($0) }
            $0.ledgerClient.listRecurring = { [deactivated.value] }
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
            $0.ledgerClient.listRecurring = { [rt] }
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

    // P1-5 step 2: deleteConfirmed removes item (reminder cancellation is now a
    // post-condition of ledgerClient.deleteRecurring, internalised into the client).
    @Test("deleteConfirmed removes item via deleteRecurring")
    func testDeleteShowsAlertAndConfirmation() async {
        let deletedId = LockIsolated<RecurringTransaction.ID?>(nil)
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
            $0.ledgerClient.deleteRecurring = { deletedId.setValue($0) }
            $0.ledgerClient.listRecurring = { [] }
        }

        await store.send(.alert(.presented(.deleteConfirmed(rt.id)))) {
            $0.alert = nil
        }
        await store.receive(\.loaded) { $0.items = [] }

        #expect(deletedId.value == rt.id)
    }

    // P0-4: Re-enabling item with past nextDueDate rebases nextDueDate to a future
    // date before persisting, so the (Client-owned) reminder fires in the future.
    @Test("toggleActiveTapped true with overdue nextDueDate rebases to future")
    func testToggleActiveTruePushesOverdueToFuture() async throws {
        let persisted = LockIsolated<RecurringTransaction?>(nil)
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
            $0.ledgerClient.updateRecurring = { persisted.setValue($0) }
            $0.ledgerClient.listRecurring = { [reactivated] }
        }

        await store.send(.toggleActiveTapped(rt))
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.items = [reactivated]
        }

        let saved = try #require(persisted.value)
        #expect(saved.isActive == true)
        #expect(saved.nextDueDate > fixedNow)
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

    // MARK: - deleteTapped 委派分支

    @Test("deleteTapped 委派為 deleteRequested 並彈出確認 alert")
    func testDeleteTappedDelegatesToDeleteRequested() async {
        let rt = Self.sample()
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listRecurring = { [rt] }
        }

        // deleteTapped 應委派為 deleteRequested(id) 並彈出 alert
        await store.send(.deleteTapped(rt.id))
        await store.receive(\.deleteRequested) {
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

    // MARK: - form delegate saved reload

    @Test("form delegate saved 觸發 listRecurring 並 reload items")
    func testFormDelegateSavedReloads() async {
        let rt = Self.sample()
        var initialState = RecurringTransactionManagementFeature.State(items: [rt])
        initialState.form = RecurringTransactionFormFeature.State(mode: .add)

        let store = await TestStore(initialState: initialState) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listRecurring = { [rt] }
            // 需 form 的 listRecurring（task effect）
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.form(.presented(.delegate(.saved))))

        await store.receive(\.loaded) {
            $0.items = [rt]
        }
    }

    // MARK: - alert 取消負向路徑

    @Test("alert cancel 取消刪除 → deleteRecurring 不被呼叫、無 loaded action")
    func testAlertCancelDoesNotDelete() async {
        let rt = Self.sample()
        var initialState = RecurringTransactionManagementFeature.State(items: [rt])
        initialState.alert = AlertState {
            TextState(String(localized: "alert_delete_recurring_transaction"))
        } actions: {
            ButtonState(role: .destructive, action: RecurringTransactionManagementFeature.Action.Alert.deleteConfirmed(rt.id)) {
                TextState(String(localized: "common_delete"))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel"))
            }
        } message: {
            TextState(String(localized: "alert_delete_recurring_transaction_message"))
        }

        let deleteRecurringCalled: LockIsolated<Bool> = LockIsolated(false)

        let store = await TestStore(initialState: initialState) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.ledgerClient.deleteRecurring = { _ in deleteRecurringCalled.setValue(true) }
        }

        // 按下「取消」按鈕（PresentationAction.dismiss）
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }

        // deleteRecurring 不應被呼叫
        #expect(deleteRecurringCalled.value == false, "取消刪除時 deleteRecurring 不應被呼叫")
        // 沒有 .loaded action 被 receive 到（TestStore exhaustive 會自動驗證）
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
            $0.ledgerClient.listRecurring = { [rt] }
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
