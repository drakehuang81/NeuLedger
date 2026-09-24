import Foundation
import SwiftData
import Dependencies
import Domain

/// Recurring section of `LedgerClient.liveValue` (step-5a3 internalisation).
///
/// Recurring templates are read/written through `SwiftDataStore` directly,
/// replacing the former `\.recurringTransactionClient` (CRUD/list) and
/// `\.recurringUseCase` (`tick`) delegation.
///
/// ## Notification scheduling 上收 (new behaviour, 5a3)
///
/// Previously each Feature reducer manually called
/// `notificationAdapter.scheduleRecurringReminder` / `cancelRecurringReminder`
/// alongside its CRUD call (`RecurringTransactionFormFeature`,
/// `RecurringTransactionManagementFeature`, `MainTabFeature`,
/// `AddTransactionFeature`). Those calls are now owned by the Client so the
/// reminder lifecycle is a guaranteed post-condition of the persistence
/// mutation, not a thing each call-site must remember:
///
/// - `createRecurring` / `updateRecurring` → persist, then **sync** the
///   reminder（啟用排程 / 暫停取消，health-audit A5）via the shared
///   `makeSyncRecurringReminder` closure keyed on the template id (same id ⇒
///   rescheduling replaces the previous request). Title/body use the same
///   localized keys the Feature call-sites used
///   (`recurring_transaction_notification_title` / `_body`), and
///   `template.nextDueDate` as the fire date — matching the Form feature's
///   save path verbatim.
/// - `deleteRecurring` → cancel the reminder, then delete the template.
///
/// ## tick() 補跑重寫（health-audit A2 / B5）
///
/// `tick` 由 `MainTabFeature` 在 App 進前景時觸發（`.task` + scenePhase
/// `.active`），不是背景排程（Info.plist 沒有、也不會加 `BGAppRefreshTask`）。
/// 舊版每次呼叫只推進一期——若使用者超過一期沒開 App，會漏記中間的到期次數。
/// 現在改成迴圈補跑每個啟用範本**所有**逾期期數：
///
/// - **逐期落地**（R5）：每 materialise 一筆就把推進後的 `nextDueDate` 寫回
///   store，不是整批跑完才寫。中途被取消或當掉時，已補記的期數不會在下次
///   tick 重複補記。
/// - **提醒只重排一次**：迴圈跑完整個範本後，若 `nextDueDate` 有變才呼叫
///   `syncReminder`，不在迴圈內每期重排。
/// - **12 個月補記窗**（R4）：到期日早於 `today - 12 個月` 的期數不入帳，但
///   仍要快轉游標，避免久未開啟或還原舊備份時一次灌進上百筆交易。
/// - **防呆**：硬性迴圈上限 500；`nextDate(after:)` 回傳值沒有前進（資料異常）
///   時 `break`，不無限迴圈。
///
/// materialise 出的交易一律經由這個 Client 自己的共用 `recordTransaction`
/// closure（§3.1 budget invariant + reactive Watch/Widget mirror），跟使用者
/// 手動 record 走同一條路徑。回傳值是實際 materialise 的筆數（被窗擋掉的不算）。
extension LedgerClient {
    static func makeListRecurring(
        _ store: RecurringTransactionStore
    ) -> @Sendable () async throws -> [RecurringTransaction] {
        {
            try await store.fetchAll()
        }
    }

    /// 提醒生命週期的單一出口：啟用中就排程、暫停就取消。
    ///
    /// `createRecurring` / `updateRecurring` / `tick` 三條路徑共用同一顆，
    /// 避免「暫停了卻還照排」這種各自實作的分歧（health-audit A5）。
    static func makeSyncRecurringReminder(
        _ notificationAdapter: NotificationAdapter
    ) -> @Sendable (RecurringTransaction) async throws -> Void {
        { template in
            guard template.isActive else {
                await notificationAdapter.cancelRecurringReminder(template.id)
                return
            }
            try await notificationAdapter.scheduleRecurringReminder(
                template.id,
                template.nextDueDate,
                String(localized: "recurring_transaction_notification_title"),
                String(localized: "recurring_transaction_notification_body")
            )
        }
    }

    /// 寫入前正規化：沒有錨點的範本（舊資料或呼叫端沒帶）以當下到期日為錨。
    static func anchored(_ template: RecurringTransaction) -> RecurringTransaction {
        guard template.anchorDate == nil else { return template }
        var normalised = template
        normalised.anchorDate = template.nextDueDate
        return normalised
    }

    static func makeCreateRecurring(
        _ store: RecurringTransactionStore,
        _ syncReminder: @escaping @Sendable (RecurringTransaction) async throws -> Void
    ) -> @Sendable (RecurringTransaction) async throws -> Void {
        { template in
            let normalised = Self.anchored(template)
            try await store.add(normalised)
            try await syncReminder(normalised)
        }
    }

    static func makeUpdateRecurring(
        _ store: RecurringTransactionStore,
        _ syncReminder: @escaping @Sendable (RecurringTransaction) async throws -> Void
    ) -> @Sendable (RecurringTransaction) async throws -> Void {
        { template in
            let normalised = Self.anchored(template)
            try await store.update(normalised)
            // 暫停的範本要取消提醒而不是重排（health-audit A5）——由 syncReminder 分流。
            try await syncReminder(normalised)
        }
    }

    static func makeDeleteRecurring(
        _ store: RecurringTransactionStore,
        _ notificationAdapter: NotificationAdapter
    ) -> @Sendable (RecurringTransaction.ID) async throws -> Void {
        { id in
            await notificationAdapter.cancelRecurringReminder(id)
            try await store.delete(id: id)
        }
    }

    /// 補記窗：只 materialise 到期日在 `today - 12 個月` 之後的期數。
    /// 更早的直接快轉不入帳，避免久未開啟或還原舊備份時一次灌進上百筆（plan R4）。
    static let recurringCatchUpWindowMonths = 12

    /// 硬性迴圈上限，防止資料異常（到期日不前進）造成無限迴圈。
    static let recurringCatchUpIterationLimit = 500

    static func makeTick(
        _ store: RecurringTransactionStore,
        _ recordTransaction: @escaping @Sendable (Transaction) async throws -> Void,
        _ syncReminder: @escaping @Sendable (RecurringTransaction) async throws -> Void
    ) -> @Sendable () async throws -> Int {
        // Resolve the clock at assembly time, matching `RecurringUseCase+Live`
        // (which read `@Dependency(\.date.now)` outside its tick closure).
        @Dependency(\.date.now) var now

        return {
            let today = now
            let calendar = Calendar.current
            let earliest = calendar.date(
                byAdding: .month, value: -recurringCatchUpWindowMonths, to: today
            ) ?? today

            let due = try await store.fetchAll().filter {
                $0.isActive && $0.nextDueDate <= today
            }

            var materialised = 0

            for template in due {
                var cursor = Self.anchored(template)
                var iterations = 0

                while cursor.nextDueDate <= today, iterations < recurringCatchUpIterationLimit {
                    iterations += 1
                    let dueDate = cursor.nextDueDate
                    let advanced = cursor.nextDate(after: dueDate)
                    // 日期沒有前進代表資料異常；停手而不是無限迴圈。
                    guard advanced > dueDate else { break }

                    if dueDate >= earliest {
                        let tx = Transaction(
                            id: UUID(),
                            amount: cursor.amount,
                            date: dueDate,
                            note: cursor.note,
                            categoryId: cursor.categoryId,
                            accountId: cursor.accountId,
                            toAccountId: cursor.toAccountId,
                            type: cursor.type,
                            tags: cursor.tags,
                            aiSuggested: false,
                            createdAt: today,
                            updatedAt: today
                        )

                        // INVARIANT (architecture.md §3.1 Scenario A): recurring tick
                        // materialises due templates into real transactions through this
                        // Client's own record path, so the budget warning invariant
                        // (§3.1 Scenario B) is preserved for scheduler-emitted
                        // transactions too.
                        try await recordTransaction(tx)
                        materialised += 1
                    }

                    cursor.nextDueDate = advanced
                    // 逐期落地：中途被取消或當掉時，已補記的期數不會在下次 tick 重來（plan R5）。
                    try await store.update(cursor)
                }

                if cursor.nextDueDate != template.nextDueDate {
                    // 提醒只在整個範本跑完後重排一次。
                    try await syncReminder(cursor)
                }
            }

            return materialised
        }
    }
}
