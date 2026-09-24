import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

/// Integration tests for `LedgerClient.liveValue` — Recurring section (step-5a3
/// internalisation). Covers two behaviour additions on top of the CRUD lift from
/// `RecurringTransactionClient+Live`:
///
/// 1. **Notification scheduling 上收** — `createRecurring`/`updateRecurring`
///    schedule a due-date reminder and `deleteRecurring` cancels it, formerly
///    done by each Feature reducer. A spy `notificationAdapter` records the
///    calls.
/// 2. **`tick()` SAGA internalisation** — due templates are materialised through
///    the Client's own record path (preserving the §3.1 budget invariant) and
///    their `nextDueDate` is advanced.
@Suite("LedgerClient Live (Recurring) Integration Tests")
struct LedgerClientRecurringTests {

    /// Records every recurring-reminder call routed through the Client.
    /// Synchronous (lock-protected) so the closures record on the calling task
    /// before the awaited mutation returns, keeping assertions race-free.
    final class NotificationSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _scheduled: [RecurringTransaction.ID] = []
        private var _scheduledDates: [RecurringTransaction.ID: Date] = [:]
        private var _cancelled: [RecurringTransaction.ID] = []

        func recordSchedule(_ id: RecurringTransaction.ID, _ date: Date) {
            lock.lock(); _scheduled.append(id); _scheduledDates[id] = date; lock.unlock()
        }
        func recordCancel(_ id: RecurringTransaction.ID) {
            lock.lock(); _cancelled.append(id); lock.unlock()
        }
        var scheduled: [RecurringTransaction.ID] {
            lock.lock(); defer { lock.unlock() }; return _scheduled
        }
        func scheduledDate(for id: RecurringTransaction.ID) -> Date? {
            lock.lock(); defer { lock.unlock() }; return _scheduledDates[id]
        }
        var cancelled: [RecurringTransaction.ID] {
            lock.lock(); defer { lock.unlock() }; return _cancelled
        }
    }

    let container: ModelContainer
    let spy = NotificationSpy()
    let sut: LedgerClient
    /// Fixed "today" for deterministic `tick` due-date assertions.
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    /// Records every transaction routed through the budget post-condition,
    /// proving `tick` goes through the Client's own record path (INVARIANT §3.1).
    let evaluatedSpy = EvaluatedSpy()

    final class EvaluatedSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _ids: [Transaction.ID] = []
        func record(_ id: Transaction.ID) { lock.lock(); _ids.append(id); lock.unlock() }
        var ids: [Transaction.ID] { lock.lock(); defer { lock.unlock() }; return _ids }
    }

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
            SDRecurringTransaction.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container

        let testPersistenceBootstrap = PersistenceBootstrap(modelContainer: { _container })
        let spy = self.spy
        let evaluatedSpy = self.evaluatedSpy
        // Extract to a local so the `withDependencies` operation closure does not
        // capture `self` (which would read `self.sut` before it is initialised).
        let fixedNow = self.fixedNow

        self.sut = withDependencies {
            $0.persistenceBootstrap = testPersistenceBootstrap
            $0.modelContainer = _container
            $0.date = .constant(fixedNow)
            // Spy on the §3.1 post-condition instead of reaching PlanningClient's
            // live store, and prove tick routes through the Client record path.
            $0.planningClient.evaluateAfterTransaction = { evaluatedSpy.record($0.id) }
            $0.notificationAdapter.scheduleRecurringReminder = { id, date, _, _ in
                spy.recordSchedule(id, date)
            }
            $0.notificationAdapter.cancelRecurringReminder = { id in
                spy.recordCancel(id)
            }
        } operation: {
            LedgerClient.liveValue
        }
    }

    private func makeTemplate(
        id: UUID = UUID(),
        nextDueDate: Date,
        isActive: Bool = true,
        frequency: BudgetPeriod = .monthly
    ) -> RecurringTransaction {
        RecurringTransaction(
            id: id,
            amount: 1200,
            note: "Rent",
            categoryId: nil,
            accountId: UUID().uuidString,
            toAccountId: nil,
            type: .expense,
            tags: [],
            frequency: frequency,
            nextDueDate: nextDueDate,
            isActive: isActive,
            createdAt: fixedNow
        )
    }

    /// 與實作同曆法同時區，避免測試與 `makeTick` 在不同時區算月份邊界。
    private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func monthsBefore(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -n, to: fixedNow)!
    }

    // MARK: - CRUD + notification 上收

    @Test("createRecurring persists and schedules a reminder at the due date")
    func testCreateSchedulesReminder() async throws {
        let template = makeTemplate(nextDueDate: fixedNow.addingTimeInterval(86400))
        try await sut.createRecurring(template)

        let stored = try await sut.listRecurring()
        #expect(stored.count == 1)
        #expect(stored.first?.id == template.id)

        #expect(spy.scheduled == [template.id])
        #expect(spy.scheduledDate(for: template.id) == template.nextDueDate)
    }

    @Test("updateRecurring persists changes and reschedules the reminder")
    func testUpdateReschedulesReminder() async throws {
        let id = UUID()
        let template = makeTemplate(id: id, nextDueDate: fixedNow.addingTimeInterval(86400))
        try await sut.createRecurring(template)

        var updated = template
        updated.nextDueDate = fixedNow.addingTimeInterval(86400 * 7)
        updated.amount = 2000
        try await sut.updateRecurring(updated)

        let stored = try await sut.listRecurring().first
        #expect(stored?.amount == 2000)
        // Scheduled twice (create + update), the second at the new due date.
        #expect(spy.scheduled == [id, id])
        #expect(spy.scheduledDate(for: id) == updated.nextDueDate)
    }

    @Test("deleteRecurring cancels the reminder and removes the template")
    func testDeleteCancelsReminder() async throws {
        let id = UUID()
        let template = makeTemplate(id: id, nextDueDate: fixedNow.addingTimeInterval(86400))
        try await sut.createRecurring(template)

        try await sut.deleteRecurring(id)

        #expect(try await sut.listRecurring().isEmpty)
        #expect(spy.cancelled == [id])
    }

    // MARK: - tick() internalisation

    @Test("tick materialises due templates through the record path and advances nextDueDate")
    func testTickMaterialisesDueTemplates() async throws {
        // Due: nextDueDate is yesterday (<= today).
        let dueId = UUID()
        let due = makeTemplate(id: dueId, nextDueDate: fixedNow.addingTimeInterval(-86400), frequency: .monthly)
        try await sut.createRecurring(due)

        // Not due: nextDueDate is in the future.
        let futureId = UUID()
        let future = makeTemplate(id: futureId, nextDueDate: fixedNow.addingTimeInterval(86400 * 30))
        try await sut.createRecurring(future)

        _ = try await sut.tick()

        // Exactly one transaction materialised, from the due template.
        let txns = try await sut.listAll(TransactionFilter())
        #expect(txns.count == 1)
        #expect(txns.first?.transaction.amount == 1200)
        // It carries the due template's original nextDueDate as its date.
        #expect(txns.first?.transaction.date == due.nextDueDate)

        // INVARIANT §3.1: the materialised transaction went through the budget
        // post-condition (proving the internal record path, not a bypass).
        #expect(evaluatedSpy.ids.count == 1)
        #expect(evaluatedSpy.ids.first == txns.first?.transaction.id)

        // The due template advanced one month; the future template is untouched.
        let templates = try await sut.listRecurring()
        let advancedDue = templates.first { $0.id == dueId }
        let untouchedFuture = templates.first { $0.id == futureId }
        #expect(advancedDue?.nextDueDate == due.nextDate(after: due.nextDueDate))
        #expect(untouchedFuture?.nextDueDate == future.nextDueDate)
    }

    @Test("tick skips inactive templates even when their due date has passed")
    func testTickSkipsInactiveTemplates() async throws {
        let inactiveId = UUID()
        let inactive = makeTemplate(id: inactiveId, nextDueDate: fixedNow.addingTimeInterval(-86400), isActive: false)
        // 改用 store 直接寫入以跳過錨點正規化（Task 3 之後 createRecurring 一律經
        // `anchored(_:)` 補錨，這裡要驗證的是「無錨點舊資料」也不能被 tick 誤補）。
        let store = RecurringTransactionStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(inactive)
        }

        _ = try await sut.tick()

        #expect(try await sut.listAll(TransactionFilter()).isEmpty)
        // Inactive template's due date is unchanged.
        let stored = try await sut.listRecurring().first { $0.id == inactiveId }
        #expect(stored?.nextDueDate == inactive.nextDueDate)
    }

    // MARK: - tick 補跑（health-audit A2）

    @Test("tick materialises every missed occurrence, not just one")
    func testTickCatchesUpAllMissedOccurrences() async throws {
        // 三個月前開始的月繳範本：T-3、T-2、T-1、T-0（= fixedNow，等號也算到期）共四期。
        let start = monthsBefore(3)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        let count = try await sut.tick()

        #expect(count == 4)
        let txns = try await sut.listAll(TransactionFilter())
        #expect(txns.count == 4)
        #expect(evaluatedSpy.ids.count == 4, "每一筆都要走 Client 自己的 record path（INVARIANT §3.1）")

        let stored = try await sut.listRecurring().first { $0.id == template.id }
        #expect(stored?.nextDueDate == Calendar.current.date(byAdding: .month, value: 1, to: fixedNow)!)
    }

    @Test("tick keeps a month-end template on the 31st instead of drifting to the 30th")
    func testTickKeepsMonthEndAnchor() async throws {
        // anchor 2023-08-31，today = fixedNow（2023-11-14/15）：
        // 補記 8/31、9/30、10/31；舊的漂移實作在第三期會變成 10/30。
        let anchor = Self.date(2023, 8, 31)
        var template = makeTemplate(nextDueDate: anchor, frequency: .monthly)
        template.anchorDate = anchor
        try await sut.createRecurring(template)

        let count = try await sut.tick()

        #expect(count == 3)
        let dates = try await sut.listAll(TransactionFilter()).map(\.transaction.date).sorted()
        #expect(dates == [Self.date(2023, 8, 31), Self.date(2023, 9, 30), Self.date(2023, 10, 31)])

        let stored = try await sut.listRecurring().first { $0.id == template.id }
        #expect(stored?.nextDueDate == Self.date(2023, 11, 30))
    }

    @Test("tick skips occurrences older than the catch-up window but still fast-forwards")
    func testTickSkipsAncientOccurrences() async throws {
        // 2020-01-01 起的月繳、今天是 2023-11-14/15：窗 = today - 12 個月（2022-11-14/15）。
        // 窗內的到期日是 2022-12-01 … 2023-11-01 共 12 期；2022-11-01 以前的不入帳。
        let anchor = Self.date(2020, 1, 1)
        var template = makeTemplate(nextDueDate: anchor, frequency: .monthly)
        template.anchorDate = anchor
        try await sut.createRecurring(template)

        let count = try await sut.tick()

        #expect(count == 12)
        let stored = try await sut.listRecurring().first { $0.id == template.id }
        #expect(stored?.nextDueDate == Self.date(2023, 12, 1))
    }

    @Test("tick reschedules the reminder to the advanced due date")
    func testTickReschedulesReminder() async throws {
        let start = monthsBefore(2)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        _ = try await sut.tick()

        let expected = Calendar.current.date(byAdding: .month, value: 1, to: fixedNow)!
        #expect(spy.scheduledDate(for: template.id) == expected)
    }

    @Test("tick returns zero and records nothing when no template is due")
    func testTickWithNothingDueReturnsZero() async throws {
        let future = fixedNow.addingTimeInterval(86400 * 10)
        var template = makeTemplate(nextDueDate: future)
        template.anchorDate = future
        try await sut.createRecurring(template)

        #expect(try await sut.tick() == 0)
        #expect(try await sut.listAll(TransactionFilter()).isEmpty)
    }

    // MARK: - 暫停即取消提醒（health-audit A5）

    @Test("updateRecurring cancels the reminder when the template is paused")
    func testUpdateCancelsReminderWhenInactive() async throws {
        var template = makeTemplate(nextDueDate: fixedNow.addingTimeInterval(86400))
        try await sut.createRecurring(template)
        #expect(spy.scheduled == [template.id])

        template.isActive = false
        try await sut.updateRecurring(template)

        #expect(spy.cancelled == [template.id], "暫停時要取消提醒，不能重排")
        #expect(spy.scheduled == [template.id], "暫停時不得再排一次")
    }

    @Test("updateRecurring reschedules the reminder when the template is still active")
    func testUpdateReschedulesReminderWhenActive() async throws {
        var template = makeTemplate(nextDueDate: fixedNow.addingTimeInterval(86400))
        try await sut.createRecurring(template)

        let moved = template.nextDueDate.addingTimeInterval(86400)
        template.nextDueDate = moved
        try await sut.updateRecurring(template)

        #expect(spy.scheduledDate(for: template.id) == moved)
        #expect(spy.cancelled.isEmpty)
    }

    @Test("createRecurring does not schedule a reminder for an inactive template")
    func testCreateInactiveDoesNotSchedule() async throws {
        let template = makeTemplate(nextDueDate: fixedNow.addingTimeInterval(86400), isActive: false)
        try await sut.createRecurring(template)

        #expect(spy.scheduled.isEmpty)
    }

    @Test("a template written without an anchor comes back anchored at its due date")
    func testWritePathNormalisesAnchor() async throws {
        let template = makeTemplate(nextDueDate: fixedNow.addingTimeInterval(86400))
        #expect(template.anchorDate == nil, "makeTemplate 不帶錨點，正好當作舊資料")
        try await sut.createRecurring(template)

        let stored = try await sut.listRecurring().first { $0.id == template.id }
        #expect(stored?.anchorDate == template.nextDueDate)
    }

    @Test("anchored() fills a missing anchor with the due date and never overwrites an existing one")
    func testAnchoredNormalisesOnlyWhenMissing() {
        let due = fixedNow.addingTimeInterval(86400)

        let withoutAnchor = makeTemplate(nextDueDate: due)
        #expect(withoutAnchor.anchorDate == nil)
        #expect(LedgerClient.anchored(withoutAnchor).anchorDate == due)

        var withAnchor = makeTemplate(nextDueDate: due)
        let original = due.addingTimeInterval(-86400 * 30)
        withAnchor.anchorDate = original
        #expect(LedgerClient.anchored(withAnchor).anchorDate == original, "既有錨點不得被覆蓋")
        #expect(LedgerClient.anchored(withAnchor).nextDueDate == due, "正規化不得動到其他欄位")
    }
}
