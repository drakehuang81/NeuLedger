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
///
/// `.serialized` (fix round 1 / F1): `LedgerClient.recurringTickGate` is a
/// process-wide `static let` on purpose (production correctness must not
/// depend on `liveValue`'s per-call re-evaluation — see the gate's doc
/// comment). That means every test in this suite that calls the live
/// `tick()` shares the same real gate. Swift Testing parallelises `@Test`
/// methods within a suite by default, so without `.serialized` two unrelated
/// tick tests running concurrently would steal each other's gate slot and
/// intermittently see `0` instead of their expected count — a real
/// cross-test race, not a flaky assertion, confirmed by a failing run before
/// this trait was added.
@Suite("LedgerClient Live (Recurring) Integration Tests", .serialized)
struct LedgerClientRecurringTests {

    /// Records every recurring-reminder call routed through the Client.
    /// Synchronous (lock-protected) so the closures record on the calling task
    /// before the awaited mutation returns, keeping assertions race-free.
    final class NotificationSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _scheduled: [RecurringTransaction.ID] = []
        private var _scheduledDates: [RecurringTransaction.ID: Date] = [:]
        private var _cancelled: [RecurringTransaction.ID] = []
        /// fix round 2 / F9：設定後，`scheduleRecurringReminder` 對這個 id 會拋錯，
        /// 用來注入「單一範本 materialise 收尾時失敗」的情境。預設 nil，既有測試不受影響。
        private var _failingID: RecurringTransaction.ID?

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
        var failingID: RecurringTransaction.ID? {
            get { lock.lock(); defer { lock.unlock() }; return _failingID }
            set { lock.lock(); _failingID = newValue; lock.unlock() }
        }
    }

    /// fix round 2 / F9：`scheduleRecurringReminder` 對 `NotificationSpy.failingID`
    /// 拋出，用來驗證 per-template 錯誤隔離（F2）。
    struct ReminderFailure: Error {}

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
                if id == spy.failingID { throw ReminderFailure() }
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
        // 改用 store 直接寫入是為了跳過 `createRecurring` 的提醒排程——暫停中的
        // 範本不該收到提醒，走 `sut.createRecurring` 會誤排一次（fix round 1 / F7）。
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
        // fix round 1 / F4：只驗數量會被「窗判斷寫反、改記最舊 12 期」的實作騙過；
        // 明確驗證入帳的是窗內最早與最晚兩期。
        let dates = try await sut.listAll(TransactionFilter()).map(\.transaction.date).sorted()
        #expect(dates.first == Self.date(2022, 12, 1), "窗內最早的一期")
        #expect(dates.last == Self.date(2023, 11, 1), "窗內最晚的一期")
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
        // fix round 1 / F5：沒有這條計次斷言時，「把 syncReminder 搬進迴圈、
        // 每期都重排」的實作一樣會讓上面那條綠燈——`scheduledDate(for:)` 是字典，
        // 只看得到最後一次寫入。createRecurring 排一次 + tick 收尾重排一次，
        // tick 不得每期都重排。
        #expect(spy.scheduled == [template.id, template.id],
                "createRecurring 排一次 + tick 重排一次；tick 不得每期都重排")
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

    // MARK: - tick 並行安全（fix round 1 / F1）

    @Test("two overlapping ticks do not double-post the same occurrence")
    func testConcurrentTicksDoNotDoublePost() async throws {
        let start = monthsBefore(3)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        async let first = sut.tick()
        async let second = sut.tick()
        let counts = try await [first, second]

        // 一條做完四期、另一條被閘門擋下回 0；順序不保證，所以比對集合。
        #expect(counts.sorted() == [0, 4])
        let txns = try await sut.listAll(TransactionFilter())
        #expect(txns.count == 4, "重疊的 tick 不得重複入帳")
    }

    // MARK: - tick per-template 錯誤隔離（fix round 2 / F9）

    @Test("a template that fails mid-materialisation does not stop the other templates")
    func testTickIsolatesPerTemplateFailures() async throws {
        // 會失敗的範本 A：直接寫 store，跳過 createRecurring 的排程——
        // failingID 設好後走 sut.createRecurring 會在建立階段就先拋錯。
        let failingId = UUID()
        let startA = monthsBefore(1)
        var failing = makeTemplate(id: failingId, nextDueDate: startA, frequency: .monthly)
        failing.anchorDate = startA
        let store = RecurringTransactionStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(failing)
        }

        // 健康的範本 B：唯一到期日是昨天，日期不與 A 的兩期重疊，方便斷言。
        let healthyId = UUID()
        let startB = fixedNow.addingTimeInterval(-86400)
        var healthy = makeTemplate(id: healthyId, nextDueDate: startB, frequency: .monthly)
        healthy.anchorDate = startB
        try await sut.createRecurring(healthy)

        // A 收尾重排提醒時拋錯。沒有 per-template 隔離時，這個錯誤會直接穿出 tick()。
        spy.failingID = failingId

        let count = try await sut.tick()

        // A 補 2 期（一個月前、今天），B 補 1 期（昨天）。
        #expect(count == 3, "一個範本失敗不得吃掉其他範本的筆數")
        let dates = try await sut.listAll(TransactionFilter()).map(\.transaction.date).sorted()
        #expect(dates.count == 3)
        #expect(dates.contains(startB), "健康的範本仍必須被補記")
        #expect(dates.contains(startA))
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

    // MARK: - 補記的冪等性

    @Test("tick stamps the source template and period onto what it records")
    func testTickStampsSourceOnMaterialisedTransactions() async throws {
        let start = monthsBefore(1)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        _ = try await sut.tick()

        let txns = try await sut.listAll(TransactionFilter())
        #expect(txns.isEmpty == false)
        for row in txns {
            #expect(row.transaction.sourceTemplateId == template.id)
            // fix round 1 / G5：只驗 != nil 擋不住「戳成 today 而不是 dueDate」的突變。
            // tick 建立交易時 `date` 就是 `dueDate`（見 makeTick 的 Transaction 初始化），
            // 兩者必須相等；這條斷言能直接擋住那個突變。
            #expect(row.transaction.sourcePeriodDueDate == row.transaction.date)
        }
    }

    @Test("a period that was already recorded is not recorded again when the cursor did not advance")
    func testTickSkipsAnAlreadyRecordedPeriod() async throws {
        // 模擬「交易已寫入、游標沒前進」的當掉視窗：先跑一次 tick，
        // 再把範本的 nextDueDate 手動倒回去，然後重跑 tick。
        let start = monthsBefore(1)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        let first = try await sut.tick()
        let afterFirst = try await sut.listAll(TransactionFilter()).count
        #expect(first > 0)

        // 把游標倒回原點，等同於「寫回進度那一步沒有成功」。
        var rewound = try await sut.listRecurring().first { $0.id == template.id }!
        rewound.nextDueDate = start
        try await sut.updateRecurring(rewound)

        let second = try await sut.tick()

        #expect(second == 0, "同一期不得被重複補記")
        #expect(try await sut.listAll(TransactionFilter()).count == afterFirst,
                "交易總數不得增加")
    }

    @Test("the occurrence landing exactly on the catch-up window's lower bound is recorded once, and only once")
    func testTickHandlesTheOccurrenceExactlyOnTheWindowLowerBound() async throws {
        // `earliest = today - recurringCatchUpWindowMonths`（12 個月），窗判斷的兩處
        // 都是 `>=`，所以「剛好等於 earliest」那一期是**窗內**。錨點與首次到期日
        // 都取 `monthsBefore(12)`，就正好踩在 earliest 上（此 suite 的 fixedNow
        // 就是生產碼注入的 `now`，同曆法同時區）。
        //
        // 這條同時釘住兩個各自獨立的 `>=` → `>` 突變，缺任何一邊都只有這條會紅：
        // - `LedgerClient+LiveRecurring.swift` 的 `dueDate >= earliest`：寫成 `>`
        //   會讓邊界那一期**整期漏記**（步驟 1 的 sourcePeriodDueDate 斷言變紅）。
        // - `LedgerClient+Live.swift` 的 `due >= earliest`（去重集合的下界）：寫成
        //   `>` 會讓邊界期被記錄卻不進集合，下次 tick 重複入帳（步驟 2 變紅）。
        //
        // 這條測試的鑑別力綁在「12 就是窗寬」上：窗寬改了而這裡的 12 沒跟著改，
        // 它會靜默退化成一條普通的窗內測試、兩個突變重新全活。把前提釘住。
        #expect(LedgerClient.recurringCatchUpWindowMonths == 12,
                "窗寬改了就要一起改下面的 monthsBefore(12)，否則這條測試不再踩在邊界上")
        let boundary = monthsBefore(12)
        var template = makeTemplate(nextDueDate: boundary, frequency: .monthly)
        template.anchorDate = boundary
        try await sut.createRecurring(template)

        // 1. 邊界那一期必須真的被記進去。
        let first = try await sut.tick()
        #expect(first > 0)

        let afterFirst = try await sut.listAll(TransactionFilter())
        #expect(afterFirst.contains { $0.transaction.sourcePeriodDueDate == boundary },
                "剛好落在窗下界的那一期必須被補記——窗判斷是 `>=`，不是 `>`")

        // 2. 把游標倒回邊界那一期（等同「寫回進度那一步沒有成功」）：去重集合的
        //    下界同樣要含到邊界，否則這一期會被記第二遍。
        var rewound = try await sut.listRecurring().first { $0.id == template.id }!
        rewound.nextDueDate = boundary
        try await sut.updateRecurring(rewound)

        let second = try await sut.tick()

        #expect(second == 0, "落在窗下界的那一期不得被重複補記")
        #expect(try await sut.listAll(TransactionFilter()).count == afterFirst.count,
                "交易總數不得增加")
    }

    @Test("a manually recorded transaction never blocks a materialisation")
    func testManualTransactionsDoNotBlockMaterialisation() async throws {
        // 使用者自己在同一天記了一筆一模一樣的帳，不該讓 tick 誤判為已補記。
        let start = monthsBefore(1)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        try await sut.record(
            Transaction(
                amount: 1200, date: start, note: "Rent",
                accountId: template.accountId, type: .expense
            )
        )

        let count = try await sut.tick()
        #expect(count > 0, "手動記的交易沒有來源欄位，不得被當成已補記")
    }

    // MARK: - fix round 1 / G3：窗外前綴後，第一個窗內期記帳前游標必須先落地

    /// 在 `evaluateAfterTransaction`（`recordTransaction` 內、`transactionStore.add`
    /// 完成之後才會觸發）第一次命中我們的範本時，讀一次 DB 裡這個範本當下的
    /// `nextDueDate` 並記下來——只記第一次命中，之後的呼叫略過。
    private final class CursorSnapshotCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var captured = false
        private var value: Date?

        // `NSLock.lock()/.unlock()` 在 Swift 6 不能直接寫在 `async` 函式主體裡
        // （"unavailable from asynchronous contexts"）；鎖的操作拆成同步 helper，
        // `captureIfFirst` 本身只呼叫這兩個同步方法，不直接碰鎖。
        private func testAndSetCaptured() -> Bool {
            lock.lock(); defer { lock.unlock() }
            let isFirst = !captured
            if isFirst { captured = true }
            return isFirst
        }

        private func setValue(_ newValue: Date?) {
            lock.lock(); defer { lock.unlock() }
            value = newValue
        }

        func captureIfFirst(_ resolve: () async throws -> Date?) async {
            guard testAndSetCaptured() else { return }
            let resolved = try? await resolve()
            setValue(resolved.flatMap { $0 })
        }

        var nextDueDateAtFirstRecord: Date? {
            lock.lock(); defer { lock.unlock() }; return value
        }
    }

    @Test("the cursor lands in the store before the first in-window record, so a crash cannot recompute a different dueDate for it")
    func testTickLandsCursorBeforeFirstInWindowRecord() async throws {
        // 錨在兩年前的月繳範本：補記窗只有 12 個月，所以前面一整年在窗外，
        // 只快轉、不寫 DB（F3）。在 fix round 1 / G3 之前，記第一筆窗內交易的
        // 那一刻，DB 裡這個範本的 nextDueDate 還停在兩年前的原始錨點——不是
        // 這一期的到期日。G3 修法要求記帳前先把游標落地一次，讓這一刻 DB 裡
        // 的值已經等於這一期的到期日（否則當掉後重算前綴，換時區或跨 DST
        // 可能算出不同值，去重失效）。
        let anchor = Calendar.current.date(byAdding: .month, value: -24, to: fixedNow)!
        var template = makeTemplate(nextDueDate: anchor, frequency: .monthly)
        template.anchorDate = anchor
        let templateId = template.id

        // 直接寫 store，跳過 createRecurring 的排程（這條測試不需要提醒）。
        let store = RecurringTransactionStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(template)
        }

        let capture = CursorSnapshotCapture()

        try await withDependencies { dependencies in
            dependencies.modelContainer = container
            dependencies.date = .constant(fixedNow)
            dependencies.planningClient.evaluateAfterTransaction = { transaction in
                guard transaction.sourceTemplateId == templateId else { return }
                await capture.captureIfFirst {
                    try await withDependencies { inner in
                        inner.modelContainer = container
                    } operation: {
                        try await RecurringTransactionStore().fetch(id: templateId)?.nextDueDate
                    }
                }
            }
            dependencies.notificationAdapter.scheduleRecurringReminder = { _, _, _, _ in }
            dependencies.notificationAdapter.cancelRecurringReminder = { _ in }
        } operation: {
            // 這個 client 跟 sut 共用同一個 container，但用自己的
            // evaluateAfterTransaction 攔截點——不能重用 sut，因為 sut 的
            // evaluateAfterTransaction 在 init() 就固定綁死了 evaluatedSpy。
            let probe = LedgerClient.liveValue
            _ = try await probe.tick()
        }

        let txns = try await sut.listAll(TransactionFilter())
        let firstTx = txns.map(\.transaction)
            .filter { $0.sourceTemplateId == templateId }
            .min { ($0.sourcePeriodDueDate ?? .distantFuture) < ($1.sourcePeriodDueDate ?? .distantFuture) }

        #expect(firstTx != nil, "至少要補記到窗內的第一期")
        #expect(capture.nextDueDateAtFirstRecord == firstTx?.sourcePeriodDueDate,
                "記第一筆窗內交易的那一刻，DB 裡的 nextDueDate 必須已經等於這一期的到期日，不能還停在原始錨點")
    }
}
