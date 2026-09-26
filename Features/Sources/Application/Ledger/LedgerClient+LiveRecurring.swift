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
/// - **提醒只重排一次**：迴圈跑完整個範本後，若 `nextDueDate` 有變且已推進到
///   未來（`> today`）才呼叫 `syncReminder`，不在迴圈內每期重排；撞到迴圈上限
///   時 cursor 還停在過去，這時不重排（維持原排程，等下一次 tick 推完再說），
///   避免拿過去的日期去排一個永遠不會觸發的 `UNCalendarNotificationTrigger`。
/// - **12 個月補記窗**（R4）：到期日早於 `today - 12 個月` 的期數不入帳，但
///   仍要快轉游標，避免久未開啟或還原舊備份時一次灌進上百筆交易。窗外的期數
///   什麼都沒記，所以**不逐期寫 DB**（重跑不會重複），只在整個範本跑完後、
///   `nextDueDate` 真的變了才補寫一次（fix round 1 / F3——否則錨在數年前的
///   週繳範本會有數百次沒有結果的 fetch + save 往返）。
/// - **防呆**：硬性迴圈上限 500；`nextDate(after:)` 回傳值沒有前進（資料異常）
///   時 `break`，不無限迴圈。
/// - **並行安全**（fix round 1 / F1）：`recurringTickGate` 這個 process-wide
///   actor 確保同時只有一條 tick 在跑；`SwiftDataStore.update` 的
///   read-modify-write 不是原子的，兩條重疊的 tick 會各自記到同一期造成無法
///   事後辨識的重複帳。Feature 層的 `cancelInFlight` 擋不住這個——Swift 的
///   取消是協作式的，tick 的迴圈裡沒有任何檢查點。
/// - **per-template 錯誤隔離**（fix round 1 / F2）：任一範本 materialise 失敗
///   不會中止其他範本（`continue` 到下一個），避免一個壞掉的範本靜默凍結全
///   App 的週期記帳（配合 R6「tick 失敗不顯示任何東西」的既定裁定）。
///
/// materialise 出的交易一律經由這個 Client 自己的共用 `recordTransaction`
/// closure（§3.1 budget invariant + reactive Watch/Widget mirror），跟使用者
/// 手動 record 走同一條路徑。回傳值是實際 materialise 的筆數（被窗擋掉的不算；
/// 另一條 tick 正在跑而被閘門擋下時也回 0）。
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

    /// process-wide 單例，不依賴 `liveValue` 的快取語意（fix round 1 / F1）：
    /// `liveValue` 是 computed property，若把閘門宣告成 `makeTick` 組裝時捕獲的
    /// 區域變數，正確性就押在 swift-dependencies 的快取行為上——而測試每個
    /// suite 都會重新求值 `liveValue` 一次，區域變數形式會各自拿到獨立的閘門，
    /// 完全擋不住並行。`static let` 才能保證整個 process 共用同一顆。
    ///
    /// **測試端的涵蓋範圍（fix round 1 / F10）**：因為這是 process-wide 單例，
    /// `LedgerClientRecurringTests` 靠 `@Suite(..., .serialized)` 讓 suite **內**
    /// 每條測試序列化執行，避免同 suite 裡多條測試搶同一顆閘門互相干擾。但
    /// `.serialized` 不跨 suite——它只防同一個 suite 內的並行，不會讓這個 suite
    /// 跟另一個 suite 序列化。目前安全，因為整個 test target 只有
    /// `LedgerClientRecurringTests` 會呼叫 live 的 `tick()`（`LedgerClientTests`
    /// 的 `testTickMock` 只是覆寫 `\.ledgerClient.tick` 的純 mock，碰不到這顆
    /// 閘門）。這個前提是易碎的：未來任何新 suite 只要建構
    /// `LedgerClient.liveValue` 並呼叫 `tick()`，就會重新引入跨 suite 的競態，
    /// 而且症狀會出現在跟改動看似無關的測試上——新增這類 suite 時要一併處理
    /// （例如同樣標記 `.serialized`，或改成不共用 process-wide 閘門的測試替身）。
    static let recurringTickGate = RecurringTickGate()

    static func makeTick(
        _ store: RecurringTransactionStore,
        _ recordTransaction: @escaping @Sendable (Transaction) async throws -> Void,
        _ syncReminder: @escaping @Sendable (RecurringTransaction) async throws -> Void,
        _ alreadyMaterialised: @escaping @Sendable (Date) async throws -> Set<MaterialisedPeriod>
    ) -> @Sendable () async throws -> Int {
        // Resolve the clock at assembly time, matching `RecurringUseCase+Live`
        // (which read `@Dependency(\.date.now)` outside its tick closure).
        @Dependency(\.date.now) var now

        // 補記迴圈本體，抽出來是為了讓最外層的閘門 begin/end 包住它（見下方
        // 回傳的 closure）。維持原本的邏輯不變，只補上 F2/F3/F6/F8 的修正。
        let runTick: @Sendable () async throws -> Int = {
            let today = now
            let calendar = Calendar.current
            // F6：曆法加法失敗時 fail-open（寧可全記也不要靜默全丟）——`?? Date.distantPast`
            // 會讓 earliest 退化成極早的日期，等於沒有下限，所有待補期數都視為窗內、一筆不丟。
            let earliest = calendar.date(
                byAdding: .month, value: -Self.recurringCatchUpWindowMonths, to: today
            ) ?? Date.distantPast

            let due = try await store.fetchAll(sortBy: [SortDescriptor(\.nextDueDate)]).filter {
                $0.isActive && $0.nextDueDate <= today
            }

            // 沒有任何期到期就直接收工——tick 每次進前景都會跑，而絕大多數前景
            // 都沒有到期期數。不短路的話，光是下面那個去重查詢就會在每次切回
            // App 時把所有補記過的交易讀出來（還會逐列 fault 進 tags）再丟掉。
            guard !due.isEmpty else { return 0 }

            // 已經補記過的期數：中途當掉會留下「交易已寫入、游標沒前進」的狀態，
            // 下一次 tick 必須跳過那些期，否則同一期會被記兩遍（spec：materialise 非冪等）。
            // 下界用 earliest（fix round 1 / G2）：去重只對窗內期數有意義，窗外的
            // 期數根本走不到 recorded.contains，不設下界集合會隨 App 壽命無界成長。
            let recorded = try await alreadyMaterialised(earliest)

            var materialised = 0

            for template in due {
                do {
                    var cursor = Self.anchored(template)
                    var iterations = 0
                    // 旗標語意：「cursor 目前的值是否與 DB 一致」，不是「是否已落地」
                    // （fix round 1 / G3）。從 store 讀出來時本來就一致；`Self.anchored`
                    // 只補 anchorDate、不動 nextDueDate，所以初值 true 是安全的。
                    var cursorMatchesStore = true

                    while cursor.nextDueDate <= today, iterations < Self.recurringCatchUpIterationLimit {
                        iterations += 1
                        let dueDate = cursor.nextDueDate
                        let advanced = cursor.nextDate(after: dueDate)
                        // 日期沒有前進代表資料異常；停手而不是無限迴圈。
                        guard advanced > dueDate else { break }

                        if dueDate >= earliest {
                            let period = MaterialisedPeriod(templateId: cursor.id, dueDate: dueDate)
                            if recorded.contains(period) {
                                // 這一期上次已經記進去了，只是游標沒來得及前進。
                                // 跳過記帳但仍要推進，否則會永遠卡在這一期。
                                cursor.nextDueDate = advanced
                                try await store.update(cursor)
                                cursorMatchesStore = true
                                continue
                            }

                            if !cursorMatchesStore {
                                // 剛跑完一段「只快轉、不寫 DB」的窗外前綴，此刻 cursor 的
                                // 值只存在記憶體裡。先落地一次，讓等一下戳到交易上的
                                // 這個 dueDate 也能在下次 tick 從 DB 原值讀回來——否則
                                // 當掉後會用當下曆法重算前綴，換時區或跨 DST 就算出
                                // 不同的值，去重失效（fix round 1 / G3）。
                                try await store.update(cursor)
                                cursorMatchesStore = true
                            }

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
                                updatedAt: today,
                                sourceTemplateId: cursor.id,
                                sourcePeriodDueDate: dueDate
                            )

                            // INVARIANT (architecture.md §3.1 Scenario A): recurring tick
                            // materialises due templates into real transactions through this
                            // Client's own record path, so the budget warning invariant
                            // (§3.1 Scenario B) is preserved for scheduler-emitted
                            // transactions too.
                            try await recordTransaction(tx)
                            materialised += 1

                            cursor.nextDueDate = advanced
                            // 逐期落地：中途被取消或當掉時，已補記的期數不會在下次 tick 重來（plan R5）。
                            try await store.update(cursor)
                            cursorMatchesStore = true
                        } else {
                            // F3：窗外——只快轉、不入帳、不寫 DB。什麼都沒記，重跑不會重複，
                            // 不必每期都跑一輪 fetch + save。
                            cursor.nextDueDate = advanced
                            // cursor 的值現在只存在記憶體裡，還沒寫回 DB（fix round 1 / G3）。
                            cursorMatchesStore = false
                        }
                    }

                    if cursor.nextDueDate != template.nextDueDate {
                        // F3：涵蓋「整段都在窗外」或「撞到迴圈上限」的情況——一次寫入，
                        // 不是幾百次（窗內路徑這裡會是第二次寫入同一個值，可接受）。
                        try await store.update(cursor)
                        if cursor.nextDueDate > today {
                            // 撞到迴圈上限時 cursor 還停在過去；這時不要用過去的日期
                            // 去排一個永遠不會觸發的提醒，維持原排程，等下次 tick 推完再重排。
                            try await syncReminder(cursor)
                        }
                    }
                } catch let error as CancellationError {
                    // F11：取消要真的停下來——繼續跑完其餘範本沒有意義，而且會多佔著
                    // 閘門。已補記的期數都已逐期落地，下次 tick 會從正確的位置接上。
                    // 往外拋之後閘門仍會被釋放：`makeTick` 外層的 catch 會 end() 再 rethrow。
                    throw error
                } catch {
                    // F2：單一範本失敗不得拖垮其他範本（下次 tick 會重試這一個）。
                    // 配合 R6「tick 失敗不顯示任何東西」——沒有 UI 承接，只能靠隔離
                    // 避免一個壞掉的範本靜默凍結全 App 的週期記帳。
                    continue
                }
            }

            return materialised
        }

        return {
            // F1：閘門必須包住整個 runTick，且成功/拋錯兩條路徑都要 end()——
            // `defer` 內不能 `await`，所以不能用 defer 收尾。
            guard await Self.recurringTickGate.begin() else { return 0 }
            do {
                let materialised = try await runTick()
                await Self.recurringTickGate.end()
                return materialised
            } catch {
                await Self.recurringTickGate.end()
                throw error
            }
        }
    }
}

/// 「某個範本的某一期」的識別鍵，用來判斷這一期是否已經補記過。
struct MaterialisedPeriod: Hashable, Sendable {
    let templateId: UUID
    let dueDate: Date
}

/// `tick()` 的串行化閘門。
///
/// 兩條重疊的 tick 會各自 `fetchAll` 到同一個 `nextDueDate` 並各記一筆，而
/// `Transaction` 沒有指回範本的欄位，這種重複帳事後認不出來也清不掉。Feature 層的
/// `cancelInFlight` 擋不住：Swift 的取消是協作式的，而 tick 的迴圈沒有任何檢查點，
/// 被取消的那條會照跑到底。
///
/// `begin()` 內部沒有 `await`，從讀 `isRunning` 到設成 `true` 之間不會讓出，所以是
/// 原子的。**不要**改成「把整段 tick 本體在 actor method 裡 await」的形狀——actor 在
/// await 點會釋放，第二條照樣進得來，完全擋不住。
actor RecurringTickGate {
    private var isRunning = false

    func begin() -> Bool {
        if isRunning { return false }
        isRunning = true
        return true
    }

    func end() { isRunning = false }
}
