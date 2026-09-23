# 週期交易自動入帳 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓週期交易真的會自動入帳——App 進前景時把所有到期（含逾期多期）的啟用範本materialise 成交易，到期日以原始日錨定不漂移，暫停即取消提醒，並移除與自動入帳衝突的「通知 → 確認表單」整條流程。

**Architecture:** `LedgerClient.tick()` 目前是零呼叫點的死碼。本計劃把它接到 `MainTabFeature`（`.task` 與 scenePhase 回前景），改寫成「補跑所有逾期期數、逐期落地、回傳筆數」，並把提醒排程／取消抽成 `syncRecurringReminder` 共用 closure，讓 create / update / tick 三條路徑的提醒生命週期一致。到期日改以 `anchorDate`（系列錨點 = 使用者設定的首次到期日）計算，`anchor + n 期` 取代「從上一次結果再加一期」，消除月底 clamp 累積漂移。確認表單流程（`RouteLinkDestination.recurringConfirmation` → `AddTransactionFeature.Mode.addRecurringConfirmation` → `savedRecurringConfirmation` delegate 鏈）整條移除，否則同一期會被 tick 與確認流程各記一次。

**Tech Stack:** Swift 6、TCA 1.23.2（`@Reducer` / `@ObservableState` / `TestStore`）、swift-dependencies、SwiftData（`SDRecurringTransaction`，CloudKit 同步中）、Swift Testing（`@Suite` / `@Test` / `#expect`）、String Catalog（`Localizable.xcstrings`，en + zh-Hant）。

**Spec:** `docs/audits/2026-09-23-health-audit/README.md`（#1、#12、#13、#21）與原始報告 `02-application-core.md`（A2、A5、A10、B5）、`01-features.md`（A5）。**這兩份是 binding spec，每個 Task 開工前先讀對應條目。**

## Global Constraints

- Features 層**不得** `import SwiftData`；持久化一律經 Client / Adapter。
- 顏色與字體一律走 `Color.Design` / `Font.Design` gateway，不得裸用 `Color(...)` / `Font.system(...)`。
- 每顆 commit subject **結尾加 `[ci skip]`**；PR 標題**不加**。
- 新增 effect 一律 `.run(operation:catch:)`，沿用穩定性 PR 的錯誤形狀（`isSaving`/`saveError`、`loadError`/`loadFailed`、`actionError`/`actionFailed`），不得留無 catch 的 `.run`。
- 本 PR **不新增** localization key；只允許修改既有 key 的值，且 `en` 與 `zh-Hant` 兩個 locale 都要改。
- 不得 `git push`、不得 force push、不得 `git stash`（worktree 共用 stash stack）。
- 每個 Task 收尾都要跑一次**完整 `NeuLedger` test scheme**（前景執行、長 timeout），只跑 `-only-testing:` 的綠燈不算數。
- 環境：全域 `xcode-select` 指向未授權的 Xcode，所有 `xcodebuild` / `git` / `python3` 前面都要加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`；**不得** `sudo` 或 `xcode-select`。
- 測試數以不重複測試名計算：`grep -oE "Test case '[^']+' passed" LOG | sort -u | wc -l`（平行 clone 會讓 `passed on` 行重複；偶有一行被平行輸出截斷，數字差 1 時用 `comm` 比對名稱而不是寫「浮動」）。

## Rulings（開工前已裁定，實作時不要重開）

- **R1（使用者裁定）到期行為 = 自動入帳。** 開 App 時到期範本自動記成交易；「通知 → 確認表單 → 記帳」整條移除。使用者要改金額就事後編輯那筆交易。
- **R2（使用者裁定）觸發點只做前景。** `MainTabFeature.task` + scenePhase 回到 `.active`。**不**加 `BGAppRefreshTask`、不動 `Info.plist` 背景模式、不動專案設定。
- **R3 錨點設計。** Domain 加 `anchorDate: Date?`（系列錨點 = 使用者設定的到期日）。Mapper 讀取時 `anchorDate ?? nextDueDate` 回填，所以從 store 讀出來的範本一定有錨點；Client 寫入時同樣正規化。建立與編輯（使用者明確設定到期日）時重新錨定；`toggleActiveTapped` 重新啟用時**不**重新錨定（房租仍在原本那一天）。既有資料已經漂移過的日期無法還原，以當下 `nextDueDate` 為錨，只保證不再繼續漂。
- **R4 補記窗 12 個月。** 只 materialise 到期日在 `today - 12 months` 之後的期數；更早的直接快轉不入帳，避免久未開啟或還原舊備份時一次灌入上百筆。另設硬性迴圈上限 500 期，並在 `nextDate(after:)` 不前進時 `break`，防止資料異常造成無限迴圈。
- **R5 逐期落地。** 每記一筆就把推進後的 `nextDueDate` 寫回 store，不是整批跑完才寫。中途被取消或當掉時，已記過的期數不會在下次 tick 重複補記。提醒重排只在整個 template 跑完後做一次。
- **R6 tick 失敗沒有 UI 承接。** `recurringTickFailed(String)` 是明確的 action 但不顯示任何東西（下次進前景自動重試）。**不要**為此新增 banner / toast / os_log —— 專案目前沒有 logging 基礎建設，統一補 os_log 是另一張單。
- **R7 通知文案改既有 key 的值**（`recurring_transaction_notification_body`），不新增 key。自動入帳後文案要說「開啟 App 即自動記帳」，不能說「已自動記帳」（前景才會記，通知響的當下還沒記）。
- **R8 `tick` 簽章改成回傳 `Int`**（materialise 的筆數）。`count > 0` 才刷新 Dashboard / Transactions，避免每次進前景都多打一輪查詢。
- **R9 冷啟動 route 暫存只做 `.splash`。** Onboarding 期間收到的 deep link 仍然丟棄（使用者連帳戶都還沒有，replay 沒有意義），明文記在 PR body。

---

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift` | 修改 | 新增 `occurrence(after:anchoredAt:calendar:)`，錨定系列日期 |
| `Features/Sources/Domain/Entities/RecurringTransaction.swift` | 修改 | 新增 `anchorDate`，`nextDate(after:)` 改走錨定 |
| `Features/Sources/Core/Persistence/Models/SDRecurringTransaction.swift` | 修改 | 新增 `anchorDate: Date?` 欄位（additive、CloudKit 相容） |
| `Features/Sources/Core/Mappers/SDRecurringTransaction+Mapping.swift` | 修改 | 三個方向都帶上 `anchorDate`，讀取時回填 |
| `Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift` | 修改 | `syncRecurringReminder` 共用 closure、錨點正規化、`tick` 重寫 |
| `Features/Sources/Application/Ledger/LedgerClient+Live.swift` | 修改 | 組裝四個 recurring endpoint 的新參數 |
| `Features/Sources/Domain/Clients/LedgerClient.swift` | 修改 | `tick` 簽章 `-> Int` |
| `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift` | 修改 | 建立／編輯時設定 `anchorDate` |
| `Features/Sources/Domain/ValueObjects/RouteLinkDestination.swift` | 修改 | 移除 `.recurringConfirmation` |
| `Features/Sources/Domain/Clients/PlatformClient.swift` | 修改 | 移除 `pendingRecurringConfirmations`、`resolveRecurringConfirmation` |
| `Features/Sources/Application/Platform/PlatformClient+Live.swift` | 修改 | 移除上述兩個實作 |
| `Features/Sources/Domain/Adapters/NotificationAdapter.swift` | 修改 | 移除 `pendingConfirmations` |
| `Features/Sources/Core/Adapters/NotificationAdapter+Live.swift` | 修改 | 移除 `pendingConfirmations` 實作 |
| `Features/Sources/Core/Adapters/RecurringNotificationDelegate.swift` | 修改 | 精簡成只負責前景橫幅呈現 |
| `Features/Sources/Features/AppView.swift` | 修改 | Composition Root 註冊通知 delegate、移除 `.task` |
| `Features/Sources/Features/AppFeature.swift` | 修改 | 移除 `.task` 訂閱與 `.recurringConfirmation` route；新增 `.splash` route 暫存 |
| `Features/Sources/Features/Dashboard/AddTransactionFeature.swift` | 修改 | 移除 `.addRecurringConfirmation` mode 與其 delegate |
| `Features/Sources/Features/Dashboard/DashboardFeature.swift` | 修改 | 移除 `savedRecurringConfirmation` delegate 轉送 |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | 修改 | 移除確認 delegate handler；接上 tick |
| `Features/Sources/Features/MainTab/MainTabView.swift` | 修改 | scenePhase 回前景送 action |
| `NeuLedger/Resources/Localizable.xcstrings` | 修改 | 更新通知 body 文案（en + zh-Hant） |
| `docs/architecture.md` | 修改 | §5 invariant 3 改寫成「tick 由前景觸發」 |

測試檔（全部既有）：`DomainTests/Enums/BudgetPeriodCalendarTests.swift`、`DomainTests/Entities/RecurringTransactionTests.swift`（**新建**）、`CoreTests/Mappers/SDRecurringTransactionMappingTests.swift`、`CoreTests/Clients/LedgerClientRecurringTests.swift`、`DomainTests/Clients/LedgerClientTests.swift`、`DomainTests/Clients/PlatformClientTests.swift`、`CoreTests/Clients/PlatformClientLiveTests.swift`、`FeaturesTests/RecurringTransactionFormFeatureTests.swift`、`FeaturesTests/AppFeatureTests.swift`、`FeaturesTests/AddTransactionFeatureTests.swift`、`FeaturesTests/MainTabFeatureTests.swift`、`FeaturesTests/Dashboard/DashboardFeatureMutationTests.swift`。

---

## Task 1：Domain — 到期日錨定（audit #13 / Core A10）

**Files:**
- Modify: `Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift:37-40`
- Modify: `Features/Sources/Domain/Entities/RecurringTransaction.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/Enums/BudgetPeriodCalendarTests.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/RecurringTransactionTests.swift`（新建）

**Interfaces:**
- Produces：`BudgetPeriod.occurrence(after:anchoredAt:calendar:) -> Date`；`RecurringTransaction.anchorDate: Date?`；`RecurringTransaction.init(..., createdAt: Date, anchorDate: Date? = nil)`（新參數**加在最後且有預設值**，既有呼叫端不用改）；`RecurringTransaction.nextDate(after:calendar:)` 行為改變。
- Consumes：無。

- [ ] **Step 1: 寫失敗測試（BudgetPeriod）**

加到 `NeuLedgerTests/Tests/DomainTests/Enums/BudgetPeriodCalendarTests.swift` 既有 suite 內：

```swift
    // MARK: - occurrence(after:anchoredAt:) — health-audit A10 月底漂移

    /// 固定用西曆 + UTC，避免 CI 與本機時區造成日期跳動。
    private static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    @Test("monthly series anchored on the 31st comes back to 31 instead of sticking at 28")
    func testMonthlyAnchorDoesNotDrift() {
        let anchor = Self.date(2026, 1, 31)
        let cal = Self.utcCalendar

        let feb = BudgetPeriod.monthly.occurrence(after: anchor, anchoredAt: anchor, calendar: cal)
        #expect(feb == Self.date(2026, 2, 28))

        let mar = BudgetPeriod.monthly.occurrence(after: feb, anchoredAt: anchor, calendar: cal)
        #expect(mar == Self.date(2026, 3, 31))

        let apr = BudgetPeriod.monthly.occurrence(after: mar, anchoredAt: anchor, calendar: cal)
        #expect(apr == Self.date(2026, 4, 30))

        let may = BudgetPeriod.monthly.occurrence(after: apr, anchoredAt: anchor, calendar: cal)
        #expect(may == Self.date(2026, 5, 31))
    }

    @Test("yearly series anchored on Feb 29 returns to Feb 29 on the next leap year")
    func testYearlyAnchorSurvivesLeapDay() {
        let anchor = Self.date(2024, 2, 29)
        let cal = Self.utcCalendar

        let y2025 = BudgetPeriod.yearly.occurrence(after: anchor, anchoredAt: anchor, calendar: cal)
        #expect(y2025 == Self.date(2025, 2, 28))

        let y2026 = BudgetPeriod.yearly.occurrence(after: y2025, anchoredAt: anchor, calendar: cal)
        #expect(y2026 == Self.date(2026, 2, 28))

        let y2027 = BudgetPeriod.yearly.occurrence(after: y2026, anchoredAt: anchor, calendar: cal)
        #expect(y2027 == Self.date(2027, 2, 28))

        let y2028 = BudgetPeriod.yearly.occurrence(after: y2027, anchoredAt: anchor, calendar: cal)
        #expect(y2028 == Self.date(2028, 2, 29))
    }

    @Test("weekly series keeps the anchor weekday across a long gap")
    func testWeeklyAnchorAcrossLongGap() {
        let anchor = Self.date(2026, 1, 5)          // 週一
        let cal = Self.utcCalendar
        let far = Self.date(2026, 3, 18)            // 十週後的週三

        let next = BudgetPeriod.weekly.occurrence(after: far, anchoredAt: anchor, calendar: cal)
        #expect(next == Self.date(2026, 3, 23))     // 下一個週一
    }

    @Test("an anchor in the future is itself the next occurrence")
    func testFutureAnchorReturnsAnchor() {
        let anchor = Self.date(2026, 6, 1)
        let cal = Self.utcCalendar
        let result = BudgetPeriod.monthly.occurrence(after: Self.date(2026, 5, 20), anchoredAt: anchor, calendar: cal)
        #expect(result == anchor)
    }

    @Test("the returned occurrence is always strictly after the given date")
    func testOccurrenceIsStrictlyAfter() {
        let anchor = Self.date(2026, 1, 31)
        let cal = Self.utcCalendar
        var cursor = anchor
        for _ in 0..<40 {
            let next = BudgetPeriod.monthly.occurrence(after: cursor, anchoredAt: anchor, calendar: cal)
            #expect(next > cursor)
            cursor = next
        }
    }
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/BudgetPeriodCalendarTests 2>&1 | tail -40
```
Expected: 編譯失敗，`value of type 'BudgetPeriod' has no member 'occurrence'`。

- [ ] **Step 3: 實作 `occurrence(after:anchoredAt:)`**

`BudgetPeriod+Calendar.swift`，加在既有 `next(after:)`（`:37-40`）之後：

```swift
    /// 以 `anchor` 為系列起點，回傳第一個嚴格大於 `date` 的到期日。
    ///
    /// 一律用「anchor + n 期」計算，**不是**從上一次（可能已被月份長度 clamp 的）
    /// 結果再往後加一期，所以 1/31 的月繳系列是 1/31 → 2/28 → 3/31 → 4/30 → 5/31，
    /// 不會像 `next(after:)` 那樣一旦被 clamp 成 28 就永遠停在 28（health-audit A10）。
    func occurrence(after date: Date, anchoredAt anchor: Date, calendar: Calendar = .current) -> Date {
        guard anchor <= date else { return anchor }

        let component = calendarComponent
        // 先估算已經過了幾期，再往後找第一個嚴格大於 date 的系列日期。
        // clamp（例如 1/31 → 2/28）會讓 dateComponents 少算一期，所以要留修正空間。
        let elapsed = calendar.dateComponents([component], from: anchor, to: date).value(for: component) ?? 0
        var step = max(elapsed, 0)

        for _ in 0..<4 {
            step += 1
            if let candidate = calendar.date(byAdding: component, value: step, to: anchor), candidate > date {
                return candidate
            }
        }

        // 理論上到不了這裡；真的到了就退回舊行為，保證回傳值仍然大於 date。
        return next(after: date, calendar: calendar)
    }
```

- [ ] **Step 4: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（5 條新測試）。

- [ ] **Step 5: 寫失敗測試（RecurringTransaction）**

新建 `NeuLedgerTests/Tests/DomainTests/Entities/RecurringTransactionTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

@Suite("RecurringTransaction")
struct RecurringTransactionTests {

    private static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    private static func template(
        frequency: BudgetPeriod = .monthly,
        nextDueDate: Date,
        anchorDate: Date? = nil
    ) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(), amount: 18_000, note: "rent",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: frequency,
            nextDueDate: nextDueDate, isActive: true, createdAt: nextDueDate,
            anchorDate: anchorDate
        )
    }

    @Test("anchorDate defaults to nil so existing call sites keep compiling")
    func testAnchorDateDefaultsToNil() {
        let t = Self.template(nextDueDate: Self.date(2026, 1, 31))
        #expect(t.anchorDate == nil)
    }

    @Test("nextDate uses the anchored series when anchorDate is set")
    func testNextDateUsesAnchor() {
        let anchor = Self.date(2026, 1, 31)
        let t = Self.template(nextDueDate: Self.date(2026, 2, 28), anchorDate: anchor)
        #expect(t.nextDate(after: t.nextDueDate, calendar: Self.utcCalendar) == Self.date(2026, 3, 31))
    }

    @Test("nextDate keeps the legacy drifting behaviour when anchorDate is nil")
    func testNextDateWithoutAnchorKeepsLegacyBehaviour() {
        let t = Self.template(nextDueDate: Self.date(2026, 2, 28))
        #expect(t.nextDate(after: t.nextDueDate, calendar: Self.utcCalendar) == Self.date(2026, 3, 28))
    }
}
```

- [ ] **Step 6: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/RecurringTransactionTests 2>&1 | tail -40
```
Expected: 編譯失敗，`extra argument 'anchorDate' in call`。

- [ ] **Step 7: 加上 `anchorDate` 並改寫 `nextDate(after:)`**

`RecurringTransaction.swift`：欄位加在 `createdAt` 之後：

```swift
    public var createdAt: Date

    /// 系列錨點 = 使用者設定的到期日（建立或編輯時寫入）。
    /// 推進到期日時一律用 `anchor + n 期` 計算，避免月底被 clamp 後累積漂移
    /// （health-audit A10）。`nil` 代表舊資料尚未回填；從 store 讀出來的範本
    /// 一定非 nil（mapper 用 `nextDueDate` 回填）。
    public var anchorDate: Date?
```

`init` 的參數表尾端加 `anchorDate: Date? = nil`（**一定要有預設值且放最後**，否則所有既有呼叫端都要改），並在 body 尾端 `self.anchorDate = anchorDate`：

```swift
    public init(
        id: UUID, amount: Decimal, note: String?,
        categoryId: Category.ID?, accountId: Account.ID,
        toAccountId: Account.ID?, type: TransactionType,
        tags: [Tag], frequency: BudgetPeriod,
        nextDueDate: Date, isActive: Bool, createdAt: Date,
        anchorDate: Date? = nil
    ) {
        self.id = id; self.amount = amount; self.note = note
        self.categoryId = categoryId; self.accountId = accountId
        self.toAccountId = toAccountId; self.type = type
        self.tags = tags; self.frequency = frequency
        self.nextDueDate = nextDueDate; self.isActive = isActive
        self.createdAt = createdAt; self.anchorDate = anchorDate
    }
```

`nextDate(after:)` 改成：

```swift
    /// Returns the next due date after `base` according to `frequency`.
    ///
    /// 有錨點就走錨定系列（不漂移）；沒有錨點是尚未回填的舊資料，維持舊行為。
    public func nextDate(after base: Date, calendar: Calendar = .current) -> Date {
        guard let anchorDate else {
            return frequency.next(after: base, calendar: calendar)
        }
        return frequency.occurrence(after: base, anchoredAt: anchorDate, calendar: calendar)
    }
```

- [ ] **Step 8: 跑測試確認通過**

同 Step 6 的指令。Expected: PASS（3 條新測試）。

- [ ] **Step 9: 跑完整 scheme**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" > /tmp/task1-full.log 2>&1; echo "exit=$?"
grep -c 'failed on' /tmp/task1-full.log
grep -oE "Test case '[^']+' passed" /tmp/task1-full.log | sort -u | wc -l
```
Expected: exit=0、`failed on` = 0、不重複測試名 = 基準 + 8。

- [ ] **Step 10: Commit**

```bash
git add Features/Sources/Domain NeuLedgerTests/Tests/DomainTests
git commit -m "feat(domain): anchor recurring due dates so month-end templates stop drifting [ci skip]"
```

---

## Task 2：Core — `anchorDate` 落地與回填（audit #13 持久化）

**Files:**
- Modify: `Features/Sources/Core/Persistence/Models/SDRecurringTransaction.swift`
- Modify: `Features/Sources/Core/Mappers/SDRecurringTransaction+Mapping.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/Mappers/SDRecurringTransactionMappingTests.swift`

**Interfaces:**
- Consumes：Task 1 的 `RecurringTransaction.anchorDate`。
- Produces：從 store 讀出來的 `RecurringTransaction.anchorDate` **保證非 nil**（舊資料以 `nextDueDate` 回填）。Task 3、4 依賴這個保證。

**注意（schema）：** `SDRecurringTransaction` 已經在 CloudKit 同步的 schema 裡（`PersistenceBootstrap.schema`）。CloudKit 要求新欄位必須 optional 或有預設值——`Date?` optional 兩者皆滿足，屬 SwiftData lightweight migration，**不需要**寫 `VersionedSchema` / `MigrationPlan`（專案目前也沒有）。不要把它宣告成非 optional。

- [ ] **Step 1: 寫失敗測試**

加到 `SDRecurringTransactionMappingTests.swift` 既有 suite 內（沿用該檔既有的 in-memory container / context 建法，不要自己另外造一套）：

```swift
    @Test("anchorDate round-trips through the SwiftData model")
    func testAnchorDateRoundTrips() throws {
        let anchor = Date(timeIntervalSince1970: 1_767_139_200)   // 2026-01-31
        let domain = RecurringTransaction(
            id: UUID(), amount: 18_000, note: "rent",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: anchor, isActive: true, createdAt: anchor,
            anchorDate: anchor
        )
        let model = SDRecurringTransaction.from(domain, context: context)
        #expect(model.anchorDate == anchor)
        #expect(model.toDomain().anchorDate == anchor)
    }

    @Test("a legacy row with no anchorDate reads back anchored at its nextDueDate")
    func testLegacyRowBackfillsAnchorFromNextDueDate() throws {
        let due = Date(timeIntervalSince1970: 1_767_139_200)
        let model = SDRecurringTransaction(
            amount: 18_000, accountId: UUID().uuidString,
            typeRaw: TransactionType.expense.rawValue,
            frequencyRaw: BudgetPeriod.monthly.rawValue,
            nextDueDate: due
        )
        model.anchorDate = nil                       // 模擬遷移前寫入的資料列
        #expect(model.toDomain().anchorDate == due)
    }

    @Test("applyChanges persists a re-anchored template")
    func testApplyChangesWritesAnchorDate() throws {
        let due = Date(timeIntervalSince1970: 1_767_139_200)
        let later = due.addingTimeInterval(86_400 * 40)
        var domain = RecurringTransaction(
            id: UUID(), amount: 1, note: nil,
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: due, isActive: true, createdAt: due,
            anchorDate: due
        )
        let model = SDRecurringTransaction.from(domain, context: context)

        domain.nextDueDate = later
        domain.anchorDate = later
        model.applyChanges(from: domain, context: context)

        #expect(model.anchorDate == later)
    }
```

若該測試檔沒有現成的 `context` helper，就照它既有測試的寫法在每個 test 內自行建立 in-memory `ModelContext`。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/SDRecurringTransactionMappingTests 2>&1 | tail -40
```
Expected: 編譯失敗，`value of type 'SDRecurringTransaction' has no member 'anchorDate'`。

- [ ] **Step 3: 加欄位**

`SDRecurringTransaction.swift`：欄位加在 `createdAt` 之後（**保持 optional，不要給非 nil 預設值**）：

```swift
    /// The date this recurring transaction was first created.
    var createdAt: Date = Date()

    /// 系列錨點（使用者設定的到期日）。舊資料為 `nil`，讀取時以 `nextDueDate` 回填。
    /// CloudKit 要求新增欄位必須 optional：維持 `Date?`，不要改成非 optional。
    var anchorDate: Date?
```

`init` 參數尾端加 `anchorDate: Date? = nil`，body 尾端 `self.anchorDate = anchorDate`。

- [ ] **Step 4: 改 mapper 三個方向**

`SDRecurringTransaction+Mapping.swift`：

`toDomain()` 的 `createdAt: createdAt` 之後加一行（**回填就發生在這裡**）：

```swift
            createdAt: createdAt,
            // 舊資料沒有錨點，讀取時就以當下的到期日回填，讓後續推進不再漂移
            // （已經漂走的日期無法還原，只保證不再繼續漂）。
            anchorDate: anchorDate ?? nextDueDate
```

`from(_:context:)` 的 `createdAt: domain.createdAt` 之後加：

```swift
            createdAt: domain.createdAt,
            anchorDate: domain.anchorDate ?? domain.nextDueDate
```

`applyChanges(from:context:)` 的 `isActive = domain.isActive` 之後加：

```swift
        isActive = domain.isActive
        anchorDate = domain.anchorDate ?? domain.nextDueDate
```

- [ ] **Step 5: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（3 條新測試）。

- [ ] **Step 6: 跑完整 scheme**

同 Task 1 Step 9（log 改 `/tmp/task2-full.log`）。Expected: exit=0、0 failed、不重複測試名 +3。

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Core NeuLedgerTests/Tests/CoreTests
git commit -m "feat(core): persist the recurring anchor date and backfill legacy rows [ci skip]"
```

---

## Task 3：Application — 提醒生命週期與錨定寫入（audit #12 / Core A5）

**Files:**
- Modify: `Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift:48-86`
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift:252-254`
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift:210-239`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientRecurringTests.swift`
- Test: `NeuLedgerTests/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift`

**Interfaces:**
- Consumes：Task 1 的 `anchorDate`、Task 2 的回填保證。
- Produces：`LedgerClient.makeSyncRecurringReminder(_:) -> @Sendable (RecurringTransaction) async throws -> Void`（Task 4 的 `makeTick` 會用同一顆）；`makeCreateRecurring` / `makeUpdateRecurring` 的參數改成 `(store, syncReminder)`。

- [ ] **Step 1: 寫失敗測試（Client）**

加到 `LedgerClientRecurringTests.swift`。該 suite 的 `init()` 已經建好 `sut`（`LedgerClient.liveValue` 綁 in-memory container）、`spy`（`NotificationSpy`，記錄 `scheduled` / `cancelled` / `scheduledDate(for:)`）、`fixedNow` 與 `makeTemplate(id:nextDueDate:isActive:frequency:)`。**直接沿用，不要另造 fixture。**

```swift
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
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/LedgerClientRecurringTests 2>&1 | tail -40
```
Expected: `testUpdateCancelsReminderWhenInactive` 與 `testCreateInactiveDoesNotSchedule` FAIL（目前無條件排程）。

- [ ] **Step 3: 抽出共用的提醒同步 closure**

`LedgerClient+LiveRecurring.swift`，加在 `makeListRecurring` 之後：

```swift
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
```

- [ ] **Step 4: 改寫 create / update**

同檔 `makeCreateRecurring`（`:48-61`）與 `makeUpdateRecurring`（`:63-76`）整段換成：

```swift
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
```

同時更新檔頭文件註解：把「`createRecurring` / `updateRecurring` → persist, then schedule a due-date reminder」改成「→ persist, then **sync** the reminder（啟用排程 / 暫停取消）」。

- [ ] **Step 5: 改組裝**

`LedgerClient+Live.swift:252-253`。在建立 client 的同一個 scope 內先做出共用 closure（放在 `recordTransaction` 附近即可）：

```swift
        let syncRecurringReminder = Self.makeSyncRecurringReminder(notificationAdapter)
```

再把兩行改成：

```swift
            createRecurring: Self.makeCreateRecurring(recurringStore, syncRecurringReminder),
            updateRecurring: Self.makeUpdateRecurring(recurringStore, syncRecurringReminder),
```

`deleteRecurring`（`:254`）維持原樣（它本來就是取消 + 刪除）。

- [ ] **Step 6: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（4 條新測試）。

- [ ] **Step 7: 表單建立／編輯時錨定**

`RecurringTransactionFormFeature.swift:210-239`，兩個分支都要設定 `anchorDate`——使用者明確設定到期日就重新錨定：

`.edit` 分支在 `updated.nextDueDate = combinedDate` 之後加一行：

```swift
                    updated.nextDueDate = combinedDate
                    // 使用者重新指定了到期日 → 重新錨定系列（health-audit A10）。
                    updated.anchorDate = combinedDate
```

`.add` 分支的 `createdAt: now` 之後加：

```swift
                        createdAt: now,
                        anchorDate: combinedDate
```

- [ ] **Step 8: 補表單測試**

加到 `RecurringTransactionFormFeatureTests.swift`，照該檔既有的 `testSaveTransferValidPersistsToAccountId`（`:64-83`）的寫法：

```swift
    // MARK: - 錨定（health-audit A10）

    @Test("saving a new template anchors the series at the chosen first-run date")
    func testSaveAddSetsAnchorDate() async {
        let added = LockIsolated<RecurringTransaction?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
        let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.ledgerClient.createRecurring = { added.setValue($0) }
            $0.dismiss = DismissEffect {}
        }
        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)

        #expect(added.value?.anchorDate != nil)
        #expect(added.value?.anchorDate == added.value?.nextDueDate)
    }

    @Test("editing a template re-anchors the series at the new due date")
    func testSaveEditReAnchors() async {
        let updated = LockIsolated<RecurringTransaction?>(nil)
        let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
        let oldAnchor = fixedNow.addingTimeInterval(-86400 * 40)
        let existing = RecurringTransaction(
            id: UUID(), amount: 1000, note: nil,
            categoryId: nil, accountId: Self.sampleAccount.id, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: fixedNow, isActive: true, createdAt: oldAnchor,
            anchorDate: oldAnchor
        )
        let newFirstRun = fixedNow.addingTimeInterval(86400 * 5)
        let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .edit(existing))) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.ledgerClient.updateRecurring = { updated.setValue($0) }
            $0.dismiss = DismissEffect {}
        }
        await store.send(.firstRunDateChanged(newFirstRun)) {
            $0.firstRunDate = Calendar.current.startOfDay(for: newFirstRun)
        }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)

        #expect(updated.value?.anchorDate != oldAnchor, "使用者重新指定到期日就要重新錨定")
        #expect(updated.value?.anchorDate == updated.value?.nextDueDate)
    }
```

`Self.sampleAccount` 是該檔既有 fixture。若 `.saveTapped` 之後還會 receive 其他 action，依 reducer 補上；**不要**用 `exhaustivity = .off`。

- [ ] **Step 9: 跑兩個 suite + 完整 scheme**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/RecurringTransactionFormFeatureTests 2>&1 | tail -40
```
然後跑完整 scheme（log `/tmp/task3-full.log`）。Expected: exit=0、0 failed、不重複測試名 +6。

- [ ] **Step 10: Commit**

```bash
git add Features/Sources NeuLedgerTests
git commit -m "fix(recurring): cancel the reminder when a template is paused and anchor it on save [ci skip]"
```

---

## Task 4：Application — `tick` 重寫（audit #1 / Core A2、B5）

**Files:**
- Modify: `Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift:88-134`
- Modify: `Features/Sources/Domain/Clients/LedgerClient.swift:64`
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift:255`（與 `:33-41,67-68` 的文件註解）
- Modify: `docs/architecture.md`（§5 invariant 3 附近，約 `:186`）
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientRecurringTests.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/Clients/LedgerClientTests.swift:186-193`

**Interfaces:**
- Consumes：Task 3 的 `makeSyncRecurringReminder`、`anchored(_:)`。
- Produces：`LedgerClient.tick: @Sendable () async throws -> Int`（回傳 materialise 的筆數）。Task 6 依賴這個回傳值。

- [ ] **Step 1: 寫失敗測試**

加到 `LedgerClientRecurringTests.swift`。該 suite 的「今天」是固定的 `fixedNow = Date(timeIntervalSince1970: 1_700_000_000)`（2023-11-14T22:13:20Z），由 `init()` 注入 `$0.date = .constant(fixedNow)`；**不要**去改 suite 的時鐘，改成用相對 `fixedNow` 的到期日來設計案例。

先在 suite 內補兩個 helper（**用 `Calendar.current`，與實作同一個曆法/時區，否則月份邊界會錯開**）：

```swift
    /// 與實作同曆法同時區，避免測試與 `makeTick` 在不同時區算月份邊界。
    private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func monthsBefore(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -n, to: fixedNow)!
    }
```

既有兩條 tick 測試（`:171-224`）的 `try await sut.tick()` 要改成 `_ = try await sut.tick()`（回傳值改成 `Int` 後不能丟棄）。`testTickSkipsInactiveTemplates`（`:205`）的註解「createRecurring would still schedule」在 Task 3 之後已不成立，一併更正成「改用 store 直接寫入以跳過錨點正規化」。

新測試：

```swift
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
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/LedgerClientRecurringTests 2>&1 | tail -40
```
Expected: 編譯失敗（`tick()` 回傳 `Void` 不能 `== 0`）。

- [ ] **Step 3: 改簽章**

`Features/Sources/Domain/Clients/LedgerClient.swift:64`：

```swift
    /// 把所有到期（含逾期）的啟用範本 materialise 成交易，回傳實際記了幾筆。
    /// 由前景觸發（`MainTabFeature`），不是背景排程。
    public var tick: @Sendable () async throws -> Int
```

- [ ] **Step 4: 重寫 `makeTick`**

`LedgerClient+LiveRecurring.swift:88-134` 整段換成：

```swift
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
```

同時把檔頭 `## tick() SAGA internalisation` 段落改寫：說明 tick 由前景觸發、會補跑所有逾期期數、12 個月窗與逐期落地。

- [ ] **Step 5: 改組裝**

`LedgerClient+Live.swift:255`：

```swift
            tick: Self.makeTick(recurringStore, recordTransaction, syncRecurringReminder),
```

並更新 `:33-41` 與 `:67-68` 的文件註解——原文說 tick 是 internalised SAGA，要補上「由 `MainTabFeature` 在前景觸發」。

- [ ] **Step 6: 修 Domain 的 mock 測試**

`NeuLedgerTests/Tests/DomainTests/Clients/LedgerClientTests.swift:186-193` 的 `tick mock override`：`$0.ledgerClient.tick = { 0 }`，斷言改成 `#expect(try await client.tick() == 0)`。

- [ ] **Step 7: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（既有 2 條改寫 + 5 條新測試）。

- [ ] **Step 8: 更新 architecture.md**

`docs/architecture.md` §5 invariant 3（約 `:186`）：原文把 `tick()` → internal `record` 描述成一條既存路徑，但它在 production 從未執行過（health-audit B5）。改成明確描述現況：tick 由 `MainTabFeature` 在 App 進前景時呼叫，補跑所有逾期期數，materialise 走 Client 自己的 `recordTransaction`，因此預算警示 invariant 對排程產生的交易同樣成立。

- [ ] **Step 9: 跑完整 scheme**

同 Task 1 Step 9（log `/tmp/task4-full.log`）。Expected: exit=0、0 failed、不重複測試名 +5。

- [ ] **Step 10: Commit**

```bash
git add Features/Sources NeuLedgerTests docs/architecture.md
git commit -m "feat(recurring): tick catches up every missed occurrence and reports how many it recorded [ci skip]"
```

---

## Task 5：Features — 移除確認流程與通知文案（audit #1 / Core B5）

**Files:**
- Modify: `Features/Sources/Domain/ValueObjects/RouteLinkDestination.swift:16`
- Modify: `Features/Sources/Domain/Clients/PlatformClient.swift:77,106`
- Modify: `Features/Sources/Application/Platform/PlatformClient+Live.swift:104-106,191-...`
- Modify: `Features/Sources/Domain/Adapters/NotificationAdapter.swift:56`
- Modify: `Features/Sources/Core/Adapters/NotificationAdapter+Live.swift:104-106`
- Modify: `Features/Sources/Core/Adapters/RecurringNotificationDelegate.swift`
- Modify: `Features/Sources/Features/AppView.swift:22-32,72-74`
- Modify: `Features/Sources/Features/AppFeature.swift:39,44,51-58,97-104`
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:16,99-106,143,367-381`
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift:156,330-334`
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift:118-131`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`
- Test: `AppFeatureTests.swift`、`AddTransactionFeatureTests.swift`、`MainTabFeatureTests.swift`、`Dashboard/DashboardFeatureMutationTests.swift`、`DomainTests/Clients/PlatformClientTests.swift`、`CoreTests/Clients/PlatformClientLiveTests.swift`

**Interfaces:**
- Consumes：Task 4 的 tick（已能取代確認流程）。
- Produces：`RouteLinkDestination` 不再有 `.recurringConfirmation`；`PlatformClient` 少兩個 endpoint；`AddTransactionFeature.Mode` 少一個 case。Task 6、7 在此之上改 `MainTabFeature` 與 `AppFeature`。

**為什麼要整條移除：** tick 會自動記帳，若通知點擊仍開確認表單，同一期會被記兩次。這不是「順手清理」，是正確性要求。

- [ ] **Step 1: 先刪測試，確認紅燈範圍**

刪掉／改寫這些既有測試（它們把現行行為釘成預期）：
- `AppFeatureTests.swift`：`recurringConfirmationRoutesInMain`（`:56-77`）、`recurringConfirmationIgnoredOutsideMain`（`:78-92`）整條刪除；`:110` 覆寫 `resolveRecurringConfirmation` 的測試一併處理（該測試若只為驗證訂閱，整條刪）。
- `AddTransactionFeatureTests.swift`：所有 `addRecurringConfirmation` / `savedRecurringConfirmation` 相關測試刪除。
- `MainTabFeatureTests.swift`：`savedRecurringConfirmation` delegate 的測試刪除。
- `DashboardFeatureMutationTests.swift`：轉送 `savedRecurringConfirmation` 的測試刪除。
- `DomainTests/Clients/PlatformClientTests.swift`、`CoreTests/Clients/PlatformClientLiveTests.swift`：兩個被移除 endpoint 的測試刪除。

先只刪測試不動 production code，跑一次完整 scheme 確認仍綠（刪測試不該讓別的測試壞掉），記錄此時的不重複測試名數。

- [ ] **Step 2: 移除 Domain 層的入口**

`RouteLinkDestination.swift`：刪 `case recurringConfirmation(RecurringTransaction)`。

`PlatformClient.swift`：刪 `pendingRecurringConfirmations`（`:77`）與 `resolveRecurringConfirmation`（`:106`）兩個屬性（含其文件註解）。

`NotificationAdapter.swift`：刪 `pendingConfirmations`（`:56`）。

- [ ] **Step 3: 移除 Application / Core 層的實作**

`PlatformClient+Live.swift`：刪 `pendingRecurringConfirmations`（`:104-106`）與 `resolveRecurringConfirmation`（`:191` 起）兩個 closure。

`NotificationAdapter+Live.swift`：刪 `pendingConfirmations`（`:104-106`）。

`RecurringNotificationDelegate.swift`：精簡成只保留前景橫幅呈現——刪掉 `confirmationStream()`、`continuations`、`lock`、`removeContinuation(id:)` 與 `didReceive` 的廣播邏輯。保留 singleton 與 `willPresent`，並把型別註解改寫：

```swift
/// 註冊為通知中心 delegate，讓 App 在前景時仍然顯示橫幅。
///
/// 自動入帳改由 `LedgerClient.tick()` 在 App 進前景時處理（health-audit A2），
/// 所以這裡不再需要把點擊事件廣播給任何人——點通知只要把 App 帶到前景就夠了。
final class RecurringNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = RecurringNotificationDelegate()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

**關鍵：** 這個 singleton 原本是被 `NotificationAdapter.pendingConfirmations` 第一次存取時才建立／註冊的。那條路徑沒了之後**必須**在 Composition Root 主動註冊，否則前景橫幅會失效。在 `AppView.swift` 的 `init()`（`:22-32`）加上：

```swift
        // Composition Root: 註冊通知 delegate，讓 App 在前景時也顯示到期橫幅。
        // （原本靠 pendingConfirmations 第一次存取時才建立，那條路徑已隨確認流程移除。）
        NotificationCenterBootstrap.start()
```

並在 `Core` 內提供該入口（放在 `RecurringNotificationDelegate.swift` 同檔即可）：

```swift
public enum NotificationCenterBootstrap {
    public static func start() {
        _ = RecurringNotificationDelegate.shared
    }
}
```

- [ ] **Step 4: 移除 AppFeature 的訂閱與 route**

`AppFeature.swift`：
- 刪 `case task`（`:39`）、`private enum CancelID { case recurringSubscription }`（`:44`）、`case .task:` 整段（`:51-58`）。
- 刪 `case let .recurringConfirmation(template):` 整段（`:97-104`）。
- `@Dependency(\.platformClient) var platformClient` 保留（`.splashCompleted` / `.deepLinkReceived` 還在用）。

`AppView.swift`：刪 `.task { await Self.store.send(.task).finish() }`（`:72-74`）。

- [ ] **Step 5: 移除 AddTransaction 的確認模式**

`AddTransactionFeature.swift`：
- `Mode` 刪 `case addRecurringConfirmation(RecurringTransaction)`（`:16`）。
- State init 刪 `case let .addRecurringConfirmation(template):` 分支（`:99-106`）。
- Delegate 刪 `case savedRecurringConfirmation(RecurringTransaction.ID, Date)`（`:143`）。
- save 的 `switch` 刪 `case let .addRecurringConfirmation(template):` 整段（`:367-381`）。

- [ ] **Step 6: 移除 Dashboard / MainTab 的轉送**

`DashboardFeature.swift`：刪 Delegate 的 `case savedRecurringConfirmation(RecurringTransaction.ID, Date)`（`:156`）與 `case let .addTransaction(.presented(.delegate(.savedRecurringConfirmation(...))))` 整段（`:330-334`）。

`MainTabFeature.swift`：刪 `case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):` 整段（`:118-131`）。

- [ ] **Step 7: 更新通知文案（不新增 key）**

`NeuLedger/Resources/Localizable.xcstrings` 的 `recurring_transaction_notification_body`：

| locale | 新值 |
|---|---|
| `en` | `A recurring transaction is due. Open NeuLedger to record it automatically.` |
| `zh-Hant` | `您有一筆定期交易到期，開啟 App 即自動記帳。` |

`recurring_transaction_notification_title` 維持不變。**只能改值，不得新增 key。** 改完用 `python3` 讀回驗證兩個 locale 都更新（記得加 `DEVELOPER_DIR`）。

- [ ] **Step 8: 跑完整 scheme**

同 Task 1 Step 9（log `/tmp/task5-full.log`）。Expected: exit=0、0 failed；不重複測試名相較 Step 1 記錄的數字**不變**（本步驟只刪 production code，不新增測試）。

- [ ] **Step 9: 確認沒有殘留**

```bash
grep -rn "recurringConfirmation\|pendingConfirmations\|addRecurringConfirmation\|savedRecurringConfirmation" Features/Sources NeuLedgerTests --include="*.swift"
```
Expected: 沒有任何輸出。

- [ ] **Step 10: Commit**

```bash
git add Features/Sources NeuLedgerTests NeuLedger/Resources/Localizable.xcstrings
git commit -m "refactor(recurring): drop the notification confirmation flow now that tick records automatically [ci skip]"
```

---

## Task 6：Features — 接上 tick（audit #1）

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift:45-47`
- Test: `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift`

**Interfaces:**
- Consumes：Task 4 的 `ledger.tick() -> Int`；Task 5 移除的 delegate handler（同一個 `switch` 區塊）。
- Produces：`MainTabFeature.Action.scenePhaseBecameActive`（View 送）、`.recurringTicked(Int)`、`.recurringTickFailed(String)`。

- [ ] **Step 1: 寫失敗測試**

**先修既有測試：** `taskForwardsLifecycleAndLoadsAccessoryBar`（`:10-28`）在 `.task` 多送一條 `recurringTickRequested` 之後會碰到未實作的 `ledgerClient.tick`，要補 `$0.ledgerClient.tick = { 0 }` 到它的 `withDependencies`，並在 `receive(\.accessoryBarVisibilityLoaded)` 之外補 `await store.receive(\.recurringTicked)`（順序以實際執行為準，`exhaustivity = .off` 下可彈性調整）。

新測試加到 `MainTabFeatureTests.swift`：

```swift
    // MARK: - 週期交易自動入帳（health-audit A2）

    private struct TickStubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("a tick that recorded something refreshes the dashboard and the transactions tab")
    func testTickRefreshesBothTabsWhenSomethingWasRecorded() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.ledgerClient.tick = { 2 }
            // dashboard 的 pulledToRefresh 會打六條 effect
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.balances           = { [:] }
            $0.ledgerClient.listAll            = { _ in [] }
            $0.ledgerClient.listCategories     = { _ in [] }
            $0.insightsClient.todayStats       = { _ in StatsSnapshot(today: 0, week: 0, savingsPercentage: 0) }
            $0.insightsClient.weeklySparkline  = { _ in [] }
            $0.insightsClient.generateInsights = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.recurringTickRequested)
        await store.receive(\.recurringTicked)
        await store.receive(\.dashboard.pulledToRefresh)
        await store.receive(\.transactions.task)
        await store.finish()
    }

    @Test("a tick that recorded nothing does not refresh the tabs")
    func testTickWithZeroDoesNotRefresh() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.tick = { 0 }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.recurringTickRequested)
        await store.receive(\.recurringTicked)
        // 沒有任何 dashboard / transactions 的重載：若 reducer 送了，未覆寫的
        // ledgerClient.listAll 等會以 unimplemented 讓這條測試失敗。
        await store.finish()
    }

    @Test("returning to the foreground runs the tick again")
    func testScenePhaseActiveRunsTick() async {
        let ticks = LockIsolated(0)
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.tick = { ticks.withValue { $0 += 1 }; return 0 }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.scenePhaseBecameActive)
        await store.receive(\.recurringTickRequested)
        await store.receive(\.recurringTicked)
        await store.finish()
        #expect(ticks.value == 1)
    }

    @Test("a failing tick surfaces recurringTickFailed and refreshes nothing")
    func testTickFailure() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.tick = { throw TickStubError() }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.recurringTickRequested)
        await store.receive(\.recurringTickFailed)
        await store.finish()
    }
```

用 `exhaustivity = .off` 是因為 `.task` 與子 reducer 會附帶其他 effect；**`receive` 的 action 比對與 closure 內的斷言仍然受檢**。`testTickWithZeroDoesNotRefresh` 刻意**不**覆寫查詢類依賴——這正是「沒有重載」的斷言機制。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/MainTabFeatureTests 2>&1 | tail -40
```
Expected: 編譯失敗，`type 'MainTabFeature.Action' has no member 'recurringTickRequested'`。

- [ ] **Step 3: 加 action 與 CancelID**

`MainTabFeature.swift` 的 `Action`（`:38-49`）加：

```swift
        // Lifecycle
        case task
        case accessoryBarVisibilityLoaded(Bool)

        /// App 回到前景（由 MainTabView 的 scenePhase 送出）。
        case scenePhaseBecameActive
        /// 跑一次週期交易補記。
        case recurringTickRequested
        /// 補記完成，附帶實際記了幾筆。
        case recurringTicked(Int)
        /// 補記失敗；沒有 UI 承接，下次進前景會自動重試（plan R6）。
        case recurringTickFailed(String)
```

`CancelID`（`:55-57`）加一個 case：

```swift
    private enum CancelID {
        case task
        case recurringTick
    }
```

- [ ] **Step 4: 實作**

`.task`（`:75-83`）改成同時跑既有工作與 tick：

```swift
            case .task:
                // Forward to the accessory bar's own load (availability + mode) when MainTabView appears,
                // so it runs regardless of whether the accessory is currently visible.
                return .merge(
                    .run { send in
                        await send(.accessory(.task))
                        let showAccessoryBar = platformClient.showAccessoryBar()
                        await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                    }
                    .cancellable(id: CancelID.task),
                    .send(.recurringTickRequested)
                )
```

在 `.accessoryBarVisibilityLoaded` 之後加三個 case：

```swift
            case .scenePhaseBecameActive:
                return .send(.recurringTickRequested)

            case .recurringTickRequested:
                // 週期交易的唯一推進點（health-audit A2：tick 原本零呼叫點）。
                // cancelInFlight：啟動時的 .task 與回前景可能連續觸發，只留最後一次。
                return .run { send in
                    let count = try await ledger.tick()
                    await send(.recurringTicked(count))
                } catch: { error, send in
                    await send(.recurringTickFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.recurringTick, cancelInFlight: true)

            case let .recurringTicked(count):
                // 沒補記到東西就不用多打一輪查詢（plan R8）。
                guard count > 0 else { return .none }
                return .merge(
                    .send(.dashboard(.pulledToRefresh)),
                    .send(.transactions(.task))
                )

            case .recurringTickFailed:
                // 刻意不顯示：MainTab 沒有自己的 UI 可以承接，且下次進前景就會重試（plan R6）。
                return .none
```

- [ ] **Step 5: View 送 scenePhase**

`MainTabView.swift`：在 `struct MainTabView` 加環境值，並在 `tabViewBase` 的 `.task`（`:45-47`）之後加 `onChange`：

```swift
    @Environment(\.scenePhase) private var scenePhase
```

```swift
        .task {
            await store.send(.task).finish()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 回到前景時再補記一次；App 留在記憶體好幾天時，只靠 .task 不會再跑。
            guard newPhase == .active else { return }
            store.send(.scenePhaseBecameActive)
        }
```

- [ ] **Step 6: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（4 條新測試）。

- [ ] **Step 7: 跑完整 scheme**

同 Task 1 Step 9（log `/tmp/task6-full.log`）。Expected: exit=0、0 failed、不重複測試名 +4。

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/MainTab NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "feat(recurring): run the tick on launch and on every return to the foreground [ci skip]"
```

---

## Task 7：Features — 冷啟動期間的 route 暫存（audit #21 / Features A5）

**Files:**
- Modify: `Features/Sources/Features/AppFeature.swift:23-29,83-107`
- Test: `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift`

**Interfaces:**
- Consumes：Task 5 之後的 `RouteLinkDestination`（已無 `.recurringConfirmation`）。
- Produces：`AppFeature.State.splash(pendingRoute:)`。

**範圍（R9）：** 只在 `.splash` 暫存。Onboarding 期間收到的 deep link 仍然丟棄——使用者連帳戶都還沒有，replay 過去沒有意義。

- [ ] **Step 1: 寫失敗測試**

加到 `AppFeatureTests.swift`：

```swift
    @Test("a deep link that arrives during splash is replayed once main is on screen")
    func testDeepLinkDuringSplashIsReplayed() async {
        let store = await TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.canSkipOnboarding = { true }
        }

        await store.send(.route(.carrierManagement)) {
            $0 = .splash(pendingRoute: .carrierManagement)
        }

        await store.send(\.splashCompleted)
        await store.receive(\.route) { state in
            // .main 落地後立刻 replay 暫存的 route
            guard case let .main(main) = state else { return }
            #expect(main.selectedTab == .settings)
        }
        await store.finish()
    }

    @Test("only the latest route is buffered during splash")
    func testSplashKeepsOnlyTheLatestPendingRoute() async {
        let store = await TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.route(.carrierManagement)) {
            $0 = .splash(pendingRoute: .carrierManagement)
        }
        await store.send(.route(.none)) {
            $0 = .splash(pendingRoute: nil)
        }
    }

    @Test("a route that arrives during onboarding is dropped")
    func testRouteDuringOnboardingIsDropped() async {
        let store = await TestStore(initialState: .onboarding(OnboardingFeature.State())) {
            AppFeature()
        }
        await store.send(.route(.carrierManagement))     // 無 state 變化
    }
```

`.route(.none)` 應該清掉暫存（`.none` 代表「解析不出任何目的地」）。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AppFeatureTests 2>&1 | tail -40
```
Expected: 編譯失敗，`enum case 'splash' has no associated values`。

- [ ] **Step 3: 讓 `.splash` 帶暫存的 route**

`AppFeature.swift` 的 `State`（`:23-29`）：

```swift
    enum State: Equatable {
        /// 冷啟動畫面。`pendingRoute` 暫存在 `.main` 還沒落地前就抵達的 deep link，
        /// 等 `.main` 出現後 replay（health-audit Features A5）。
        case splash(pendingRoute: RouteLinkDestination? = nil)
        case onboarding(OnboardingFeature.State)
        case main(MainTabFeature.State)

        init() { self = .splash(pendingRoute: nil) }
    }
```

- [ ] **Step 4: 暫存與 replay**

`.route` 的 `switch`（`:83-107`）：

`case .carrierManagement:` 的 `guard` 改成失敗時暫存：

```swift
                case .carrierManagement:
                    guard case .main(var mainState) = state else {
                        // 冷啟動途中抵達：暫存起來，等 .main 落地再 replay。
                        if case .splash = state { state = .splash(pendingRoute: action) }
                        return .none
                    }
                    mainState.selectedTab = .settings
                    mainState.settings.path.append(.carrierManagement(CarrierManagementFeature.State()))
                    state = .main(mainState)
                    return .none
```

`case .main:` 改成落地後 replay：

```swift
                case .main:
                    var pending: RouteLinkDestination?
                    if case let .splash(buffered) = state { pending = buffered }
                    state = .main(MainTabFeature.State())
                    guard let pending, pending != .main else { return .none }
                    return .send(.route(pending))
```

`case .none`（走 `default:`）要清掉暫存，避免舊的 route 卡在 buffer：

```swift
                default:
                    if case .splash = state { state = .splash(pendingRoute: nil) }
                    return .none
```

**注意：** `.onboarding` 那條分支維持原樣（不暫存，R9）。

- [ ] **Step 5: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（3 條新測試 + 既有測試不變）。

- [ ] **Step 6: 跑完整 scheme**

同 Task 1 Step 9（log `/tmp/task7-full.log`）。Expected: exit=0、0 failed、不重複測試名 +3。

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/AppFeature.swift NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift
git commit -m "fix(app): buffer deep links that arrive during splash and replay them on main [ci skip]"
```

---

## 收尾檢查（全部 Task 完成後）

- [ ] `grep -rn "recurringConfirmation\|pendingConfirmations" Features/Sources NeuLedgerTests --include="*.swift"` 無輸出。
- [ ] `grep -rn "ledger.tick\|ledgerClient.tick" Features/Sources --include="*.swift"` 至少一個 production 呼叫點（`MainTabFeature`）。
- [ ] CLAUDE.md 的五條 ast-grep 架構稽核全部通過。
- [ ] 完整 scheme exit=0、0 failed。
- [ ] 全分支 review（最強模型）→ 有發現就一輪 fix → re-review。

## 不在本 PR（已記錄，PR body 要寫）

- `BGAppRefreshTask` 背景補記（R2：使用者決定只做前景）。
- 自動入帳後的 App 內提示（banner / toast）——目前只靠 Dashboard 與交易列表重載呈現。
- tick 失敗的可觀測性（R6：專案尚無 logging 基礎建設，統一補 os_log 另開）。
- Onboarding 期間收到的 deep link 仍然丟棄（R9）。
- 已經漂移過的既有範本無法還原原始扣款日，只保證不再繼續漂（R3）。
- audit #11（刪分類／帳戶不清引用，含指向已刪帳戶的週期範本）留給資料完整性 PR。
