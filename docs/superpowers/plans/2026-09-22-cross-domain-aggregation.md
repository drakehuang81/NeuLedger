# 跨領域共用邏輯聚合 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 14 組散落在 Feature / Application / Core / Watch / Widget 的跨領域規則各收斂到唯一一處（Domain 純規則、Common 呈現格式化、Domain 跨 target 常數），每個聚合點都有測試釘住。

**Architecture:** 依 `docs/architecture.md` §3.1「共用計算抽成 pure entity/VO」：純規則做成 Domain entity / enum 的 extension（`BudgetPeriod+Calendar`、`Budget+Spending`、`Transaction+Accounts`、`TransactionFilter+Matching`），Application / Core / Features 只呼叫不重寫；Analysis 頁改為完全透過 `insightsClient` 取投影；呈現格式化收進 Common；App Group 常數與 Widget DTO 收進 Domain 並讓 Widget target 連結 Domain。

**Tech Stack:** Swift 6 language mode、iOS 26 / watchOS 26、TCA 1.23.2、swift-dependencies 1.11.0、SwiftData、Swift Testing（`@Suite` / `@Test` / `#expect`）、xcodebuild。

**Spec:** `docs/superpowers/specs/2026-09-22-cross-domain-aggregation-design.md`

## Global Constraints

- iOS 26.0 minimum；不加 `#available`。
- Features / WatchFeatures **不得** `import SwiftData`，**不得**注入 Adapter 或 `SwiftDataStore`，只能用六個 Client。
- Client→Client 呼叫禁止，唯一白名單是 `LedgerClient.record/update → PlanningClient.evaluateAfterTransaction`。
- 所有 `Color` 走 `Color.Design`（`Common/DesignSystem/Color+extension.swift`），所有 `.font(...)` 走 `Font.Design`。禁止裸 `Color(red:green:blue:)`、`Font.system(size:)`。
- 所有使用者可見字串用 `String(localized:)`；本計劃**不新增** localization key，只重用既有 key。
- 金額一律 TWD、整數顯示、前綴 `NT$`。
- 測試用 Swift Testing，不用 XCTest。`@DependencyClient` 的 `testValue = Self()` 是 unimplemented stub：reducer 路徑會碰到的每個 closure 都要在 `withDependencies` 覆寫。
- `swift test` 不可用，一律 xcodebuild。
- Domain target 只能 `import Foundation` / `Dependencies` / `DependenciesMacros` / `CasePaths`；Common 只能 `import Domain`（+ SwiftUI / Foundation）。
- Commit subject 一律加 `[ci skip]`（使用者明確說要跑 CI 的那一顆 commit 才拿掉）。PR title **不加** `[ci skip]`。
- 分支：PR A `fix/aggregation-a-domain-rules`、PR B `fix/aggregation-b-analysis-insights`、PR C `fix/aggregation-c-presentation`。每個 PR 從最新 `developer` 開分支；PR B 依賴 PR A merge 後的 `developer`，PR C 依賴 PR B。
- **每個 Task 的最後一步都必須跑完整 `NeuLedger` test scheme**（不是只跑該 suite）；碰到 Watch / Widget 檔案的 Task 額外跑 watch 測試或 Widget build。

## 指令速查

```bash
# 單一 suite（<Suite> 換成 @Suite 對應的 struct 名稱）
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/<Suite> -quiet

# 完整 iOS test scheme（每個 Task 結尾必跑）
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# watch 測試（Task 5、8、10、14 結尾加跑）
xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -quiet

# Widget extension 編譯（Task 10、14 結尾加跑）
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedgerWidget \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

`-quiet` 模式下成功會印 `** TEST SUCCEEDED **`，失敗印 `** TEST FAILED **` 與失敗清單。**不要**同時跑兩個 xcodebuild（同一份 DerivedData 會撞 lock）。

測試檔放在 `NeuLedgerTests/Tests/...` 底下即自動納入 target（xcodeproj 使用 synchronized folder），不需改 pbxproj。

---

# PR A — Domain 純規則（分支 `fix/aggregation-a-domain-rules`）

### Task 1: `BudgetPeriod` 日曆規則（Domain）

**Files:**
- Create: `Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift`
- Modify: `Features/Sources/Domain/Entities/RecurringTransaction.swift:33-39`（`nextDate(after:calendar:)` 本體）
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:295-301`（內聯 switch）
- Test: `NeuLedgerTests/Tests/DomainTests/Enums/BudgetPeriodCalendarTests.swift`

**Interfaces:**
- Produces（後續每個 Task 都用）：
  ```swift
  extension BudgetPeriod {
      var calendarComponent: Calendar.Component
      func dateInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval      // [start, end)
      func closedRange(containing date: Date, calendar: Calendar = .current) -> ClosedRange<Date>  // start...(end − 1ms)
      func previousInterval(before date: Date, calendar: Calendar = .current) -> DateInterval
      func next(after date: Date, calendar: Calendar = .current) -> Date
  }
  ```

- [ ] **Step 1: 寫失敗測試**

建立 `NeuLedgerTests/Tests/DomainTests/Enums/BudgetPeriodCalendarTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

/// `BudgetPeriod+Calendar`：全 App 唯一的「期間 → 日期區間」定義。
@Suite("BudgetPeriod+Calendar")
struct BudgetPeriodCalendarTests {

    /// 固定 gregorian + 台北時區 + 週一起算，避免機器設定影響。
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        cal.firstWeekday = 2
        return cal
    }

    private static func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }

    @Test("calendarComponent maps weekly/monthly/yearly")
    func calendarComponent() {
        #expect(BudgetPeriod.weekly.calendarComponent == .weekOfYear)
        #expect(BudgetPeriod.monthly.calendarComponent == .month)
        #expect(BudgetPeriod.yearly.calendarComponent == .year)
    }

    @Test("monthly interval is [1st 00:00, next 1st 00:00)")
    func monthlyInterval() {
        let i = BudgetPeriod.monthly.dateInterval(containing: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(i.start == Self.d(2026, 1, 1, 0))
        #expect(i.end == Self.d(2026, 2, 1, 0))
    }

    @Test("weekly interval starts on firstWeekday and spans 7 days")
    func weeklyInterval() {
        // 2026-01-15 是週四；firstWeekday = 2（週一）→ 起點 2026-01-12
        let i = BudgetPeriod.weekly.dateInterval(containing: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(i.start == Self.d(2026, 1, 12, 0))
        #expect(i.duration == 7 * 86_400)
    }

    @Test("yearly interval is [Jan 1, next Jan 1)")
    func yearlyInterval() {
        let i = BudgetPeriod.yearly.dateInterval(containing: Self.d(2026, 6, 30), calendar: Self.calendar)
        #expect(i.start == Self.d(2026, 1, 1, 0))
        #expect(i.end == Self.d(2027, 1, 1, 0))
    }

    @Test("closedRange keeps the whole last day and excludes the next period's first instant")
    func closedRangeBounds() {
        let r = BudgetPeriod.monthly.closedRange(containing: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(r.lowerBound == Self.d(2026, 1, 1, 0))
        #expect(r.contains(Self.d(2026, 1, 31, 23)))
        #expect(!r.contains(Self.d(2026, 2, 1, 0)))
    }

    @Test("previousInterval(before:) is the immediately preceding period")
    func previousInterval() {
        let p = BudgetPeriod.monthly.previousInterval(before: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(p.start == Self.d(2025, 12, 1, 0))
        #expect(p.end == Self.d(2026, 1, 1, 0))
    }

    @Test("next(after:) adds exactly one period (month-end clamps)")
    func nextAfter() {
        #expect(BudgetPeriod.weekly.next(after: Self.d(2026, 1, 15), calendar: Self.calendar) == Self.d(2026, 1, 22))
        #expect(BudgetPeriod.monthly.next(after: Self.d(2026, 1, 31), calendar: Self.calendar) == Self.d(2026, 2, 28))
        #expect(BudgetPeriod.yearly.next(after: Self.d(2026, 1, 15), calendar: Self.calendar) == Self.d(2027, 1, 15))
    }

    @Test("RecurringTransaction.nextDate delegates to frequency.next(after:)")
    func recurringDelegates() {
        let template = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .weekly, nextDueDate: Self.d(2026, 1, 15),
            isActive: true, createdAt: Self.d(2026, 1, 1)
        )
        let expected = BudgetPeriod.weekly.next(after: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(template.nextDate(after: Self.d(2026, 1, 15), calendar: Self.calendar) == expected)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/BudgetPeriodCalendarTests -quiet`
Expected: 編譯錯誤 `value of type 'BudgetPeriod' has no member 'calendarComponent'`（等同 FAIL）。

- [ ] **Step 3: 實作**

建立 `Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift`：

```swift
import Foundation

/// 全 App 唯一的「BudgetPeriod → 日曆區間」定義。
/// Kernel / Planning / Analysis / Filter / Watch 一律呼叫這裡，不得自行 `dateInterval(of:)`。
public extension BudgetPeriod {

    /// weekly → `.weekOfYear`、monthly → `.month`、yearly → `.year`。
    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }

    /// 包含 `date` 的日曆對齊期間，半開區間 `[start, end)`。SwiftData predicate 用這個。
    func dateInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: calendarComponent, for: date)
            ?? DateInterval(start: date, duration: 0)
    }

    /// 同一期間的閉區間版本：上界 = 下一期起點減 1 毫秒。
    /// 給 `TransactionFilter.dateRange`（`ClosedRange<Date>`）使用。
    func closedRange(containing date: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let interval = dateInterval(containing: date, calendar: calendar)
        return interval.start...interval.end.addingTimeInterval(-0.001)
    }

    /// 緊接在「包含 `date` 的期間」之前的那一期（例如「上個月」）。
    func previousInterval(before date: Date, calendar: Calendar = .current) -> DateInterval {
        let current = dateInterval(containing: date, calendar: calendar)
        return dateInterval(containing: current.start.addingTimeInterval(-1), calendar: calendar)
    }

    /// 把 `date` 往後推一個期間（週期交易的下次到期日）。
    func next(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: calendarComponent, value: 1, to: date) ?? date
    }
}
```

把 `Features/Sources/Domain/Entities/RecurringTransaction.swift` 的 `nextDate` 本體換成委派：

```swift
    /// Returns the next due date after `base` according to `frequency`.
    public func nextDate(after base: Date, calendar: Calendar = .current) -> Date {
        frequency.next(after: base, calendar: calendar)
    }
```

把 `Features/Sources/Features/Dashboard/AddTransactionFeature.swift` 內：

```swift
                            let nextDue: Date
                            switch frequency {
                            case .weekly:  nextDue = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
                            case .monthly: nextDue = Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
                            case .yearly:  nextDue = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
                            }
```

換成：

```swift
                            let nextDue = frequency.next(after: date)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `-only-testing:NeuLedgerTests/BudgetPeriodCalendarTests`、`-only-testing:NeuLedgerTests/AddTransactionFeatureTests`、`-only-testing:NeuLedgerTests/LedgerClientRecurringTests`
Expected: 全部 `** TEST SUCCEEDED **`。`AddTransactionFeatureTests` 的 `testSaveTappedCreatesRecurringTemplateMonthly` 期望值 `Calendar.current.date(byAdding: .month, value: 1, to:)` 與新實作等價，不需改。

- [ ] **Step 5: 完整 scheme + commit**

Run: 完整 `NeuLedger` test scheme。Expected: `** TEST SUCCEEDED **`。

```bash
git add Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift \
        Features/Sources/Domain/Entities/RecurringTransaction.swift \
        Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
        NeuLedgerTests/Tests/DomainTests/Enums/BudgetPeriodCalendarTests.swift
git commit -m "refactor(domain): BudgetPeriod owns calendar interval and next-date rules [ci skip]"
```

---

### Task 2: 期間區間六處改用 `BudgetPeriod`（Kernel / Planning / Watch / Filter）

**Files:**
- Modify: `Features/Sources/Core/Analytics/TransactionAnalyticsKernel.swift:262-266`（budgetGauges 期間）與 `:315-328`（刪 `currentPeriodRange`）
- Modify: `Features/Sources/Application/Planning/PlanningClient+Live.swift:41-56, 65-75, 110-128`
- Modify: `Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift:84-89`
- Modify: `Features/Sources/Features/Transactions/FilterFeature.swift`（State + Action + reducer）
- Modify: `Features/Sources/Features/Transactions/FilterView.swift:346-351, 464-492`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/PlanningClientLiveTests.swift`（新增 1 測）
- Test: `NeuLedgerTests/Tests/FeaturesTests/FilterFeatureTests.swift`（新增 2 測）

**Interfaces:**
- Consumes: Task 1 的 `dateInterval(containing:)` / `closedRange(containing:)` / `previousInterval(before:)`。
- Produces：
  ```swift
  extension FilterFeature {
      public enum QuickDateRange: Equatable, Sendable, CaseIterable { case thisWeek, thisMonth, lastMonth, thisYear
          public func range(now: Date, calendar: Calendar) -> ClosedRange<Date> }
  }
  FilterFeature.State.activeQuickRange: QuickDateRange?
  FilterFeature.Action.quickRangeSelected(QuickDateRange)
  ```
  （AnalysisFeature 的兩份在 Task 7 一併刪除。）

- [ ] **Step 1: 寫失敗測試（Planning）**

在 `PlanningClientLiveTests.swift` 的 `// MARK: - CRUD` 前加入：

```swift
    // MARK: - Period bounds (single source: BudgetPeriod+Calendar)

    @Test("currentStatus period bounds equal BudgetPeriod.closedRange(containing: today)")
    func testCurrentStatusPeriodBounds() async throws {
        let container = try freshContainer()
        let client = sut(container)
        let b = budget()   // monthly
        let status = try await client.currentStatus(b)
        let expected = BudgetPeriod.monthly.closedRange(containing: Date())
        #expect(status.periodStart == expected.lowerBound)
        #expect(status.periodEnd == expected.upperBound)
    }
```

- [ ] **Step 2: 寫失敗測試（FilterFeature）**

在 `FilterFeatureTests.swift` 的 struct 末尾（最後一個 `}` 之前）加入：

```swift
    // MARK: - Quick date range（來源：BudgetPeriod+Calendar）

    private static var taipei: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return cal
    }

    @Test("quickRangeSelected(.lastMonth) sets the previous calendar month with the last day fully included")
    func testQuickRangeLastMonth() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
        }
        let prev = BudgetPeriod.monthly.previousInterval(before: now, calendar: cal)
        let lastDayEvening = cal.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 23))!

        await store.send(.quickRangeSelected(.lastMonth)) {
            $0.startDate = prev.start
            $0.endDate = prev.end.addingTimeInterval(-0.001)
            $0.activeQuickRange = .lastMonth
            #expect($0.endDate! > lastDayEvening)   // 修掉「最後一天 00:00 截止」的舊 bug
        }
    }

    @Test("manual startDateChanged clears activeQuickRange")
    func testManualDateClearsQuickRange() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
        }
        let thisMonth = BudgetPeriod.monthly.closedRange(containing: now, calendar: cal)
        await store.send(.quickRangeSelected(.thisMonth)) {
            $0.startDate = thisMonth.lowerBound
            $0.endDate = thisMonth.upperBound
            $0.activeQuickRange = .thisMonth
        }
        let custom = cal.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        await store.send(.startDateChanged(custom)) {
            $0.startDate = custom
            $0.activeQuickRange = nil
        }
    }
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/FilterFeatureTests` → 編譯錯誤 `type 'FilterFeature.Action' has no member 'quickRangeSelected'`。
Run: `-only-testing:NeuLedgerTests/PlanningClientLiveTests` → 可能通過（舊實作語意相同）；這條測試的價值是釘住 Step 4 之後的來源唯一性。

- [ ] **Step 4: 實作 — Kernel**

`TransactionAnalyticsKernel.swift` 的 `budgetGauges` 內：

```swift
            let (periodStart, periodEnd) = currentPeriodRange(for: budget.period)
            let typeRaw = TransactionType.expense.rawValue
            let rows = try fetch(
                container: container,
                predicate: #Predicate<SDTransaction> { tx in
                    tx.type == typeRaw
                        && tx.date >= periodStart
                        && tx.date <= periodEnd
                },
                sortBy: []
            )
```

換成：

```swift
            let interval = budget.period.dateInterval(containing: Date())
            let periodStart = interval.start
            let periodEnd = interval.end
            let typeRaw = TransactionType.expense.rawValue
            let rows = try fetch(
                container: container,
                predicate: #Predicate<SDTransaction> { tx in
                    tx.type == typeRaw
                        && tx.date >= periodStart
                        && tx.date < periodEnd
                },
                sortBy: []
            )
```

刪除檔案底部整個 `private func currentPeriodRange(for period: BudgetPeriod) -> (start: Date, end: Date)`（含 doc comment）。

- [ ] **Step 5: 實作 — Planning**

`PlanningClient+Live.swift` `currentStatus`：

```swift
            currentStatus: { budget in
                let range = budget.period.closedRange(containing: Date())
                let all = try await transactionStore.fetchAll()
                let inPeriod = all.filter { txn in
                    guard range.contains(txn.date) else { return false }
                    guard txn.type == .expense else { return false }
                    guard let scopedCategoryId = budget.categoryId else { return true }
                    return txn.categoryId == scopedCategoryId
                }
                let spent = inPeriod.reduce(Decimal.zero) { $0 + $1.amount }
                return BudgetStatus(
                    budget: budget,
                    periodStart: range.lowerBound,
                    periodEnd: range.upperBound,
                    spent: spent
                )
            },
```

`evaluateAfterTransaction` 迴圈內：

```swift
                    let (start, end) = currentPeriodBounds(for: budget.period, today: today)
                    let inPeriod = all.filter { (start...end).contains($0.date) }

                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate]
                    let pKey = formatter.string(from: start)
```

換成：

```swift
                    let range = budget.period.closedRange(containing: today)
                    let inPeriod = all.filter { range.contains($0.date) }

                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate]
                    let pKey = formatter.string(from: range.lowerBound)
```

刪除檔案底部整個 `private func currentPeriodBounds(for:today:)`（含 doc comment）。

- [ ] **Step 6: 實作 — WatchContextBuilder**

`WatchContextBuilder.monthBudgetProgress` 內：

```swift
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let startOfNextMonth = calendar.date(
                byAdding: .month, value: 1, to: startOfMonth
              ) else { return nil }
        let monthRange = startOfMonth..<startOfNextMonth
```

換成：

```swift
        let monthRange = BudgetPeriod.monthly.dateInterval(containing: now, calendar: calendar)
```

（下一行 `monthRange.contains($0.date)` 對 `DateInterval` 同樣成立，不需改。）

- [ ] **Step 7: 實作 — FilterFeature**

在 `FilterFeature.State` 的 `public var tags: [Tag]` 之後加：

```swift
        /// 目前套用的快捷區間；使用者手動改起訖日即清空。
        public var activeQuickRange: QuickDateRange? = nil
```

在 `FilterFeature` struct 內（`// MARK: - State` 之前）加：

```swift
    // MARK: - Quick date range

    /// 篩選頁的四個快捷區間。區間定義唯一來源是 `BudgetPeriod+Calendar`。
    public enum QuickDateRange: Equatable, Sendable, CaseIterable {
        case thisWeek, thisMonth, lastMonth, thisYear

        /// 閉區間：上界是該期最後一天 23:59:59.999。
        public func range(now: Date, calendar: Calendar) -> ClosedRange<Date> {
            switch self {
            case .thisWeek:  return BudgetPeriod.weekly.closedRange(containing: now, calendar: calendar)
            case .thisMonth: return BudgetPeriod.monthly.closedRange(containing: now, calendar: calendar)
            case .thisYear:  return BudgetPeriod.yearly.closedRange(containing: now, calendar: calendar)
            case .lastMonth:
                let previous = BudgetPeriod.monthly.previousInterval(before: now, calendar: calendar)
                return previous.start...previous.end.addingTimeInterval(-0.001)
            }
        }
    }
```

在 `Action` 的 `case endDateChanged(Date?)` 之後加：

```swift
        case quickRangeSelected(QuickDateRange)
```

在 `@Dependency` 區加：

```swift
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar
```

reducer 內把兩個日期 case 改成會清空快捷狀態，並新增 quick case：

```swift
            case let .startDateChanged(date):
                state.startDate = date
                state.activeQuickRange = nil
                return .none

            case let .endDateChanged(date):
                state.endDate = date
                state.activeQuickRange = nil
                return .none

            case let .quickRangeSelected(quick):
                let range = quick.range(now: now, calendar: calendar)
                state.startDate = range.lowerBound
                state.endDate = range.upperBound
                state.activeQuickRange = quick
                return .none
```

- [ ] **Step 8: 實作 — FilterView**

`quickDateChip` 開頭：

```swift
    private func quickDateChip(label: String, range: QuickDateRange) -> some View {
        let (start, end) = range.dates
        let isActive = store.startDate == start && store.endDate == end
        return Button {
            store.send(.startDateChanged(start))
            store.send(.endDateChanged(end))
        } label: {
```

換成：

```swift
    private func quickDateChip(label: String, range: FilterFeature.QuickDateRange) -> some View {
        let isActive = store.activeQuickRange == range
        return Button {
            store.send(.quickRangeSelected(range))
        } label: {
```

刪除檔案底部 `// MARK: - Quick Date Range` 起的整個 `private enum QuickDateRange { ... }`。呼叫端的 `range: .thisWeek` 等字面不用改。

- [ ] **Step 9: 跑測試確認通過**

Run: `-only-testing:NeuLedgerTests/FilterFeatureTests`、`PlanningClientLiveTests`、`PlanningClientEvaluateTests`、`InsightsClientLiveTests`、`WatchContextBuilderTests`。Expected: 全部 SUCCEEDED。

- [ ] **Step 10: 確認來源唯一 + 完整 scheme + commit**

```bash
grep -rn 'dateInterval(of:' Features/Sources
```
Expected: 只有 `Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift` 一行，加上 `TransactionAnalyticsKernel.swift` 的 `detailStats`（`cal.dateInterval(of: .month, for: now)`，它不是 BudgetPeriod 語意，本 PR 不動）。

Run: 完整 `NeuLedger` test scheme → SUCCEEDED。

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor: route Kernel/Planning/Watch/Filter period ranges through BudgetPeriod+Calendar [ci skip]"
```

---

### Task 3: `Transaction` 帳戶歸屬、彙總與 `TransactionFilter.matches`（Domain）

**Files:**
- Create: `Features/Sources/Domain/Entities/Transaction+Accounts.swift`
- Create: `Features/Sources/Domain/Entities/Transaction+Aggregation.swift`
- Create: `Features/Sources/Domain/Entities/TransactionFilter+Matching.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/TransactionAccountsTests.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/TransactionFilterMatchingTests.swift`

**Interfaces:**
- Produces：
  ```swift
  extension Transaction { func involves(account id: Account.ID) -> Bool; func signedEffect(on id: Account.ID) -> Decimal }
  extension Sequence where Element == Transaction { func total(of type: TransactionType) -> Decimal; func balance(of accountId: Account.ID) -> Decimal }
  extension TransactionFilter { func matches(_ transaction: Transaction) -> Bool }
  ```

- [ ] **Step 1: 寫失敗測試**

`TransactionAccountsTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

/// 全 App 唯一的「交易屬於帳戶」與「對帳戶餘額的影響」定義。
@Suite("Transaction+Accounts / +Aggregation")
struct TransactionAccountsTests {
    private static let accA = "acc-A"
    private static let accB = "acc-B"

    private static func tx(_ amount: Decimal, _ type: TransactionType, from: String, to: String? = nil) -> Transaction {
        Transaction(amount: amount, date: Date(), accountId: from, toAccountId: to, type: type)
    }

    @Test("involves(account:) is bidirectional for transfers")
    func involves() {
        let transfer = Self.tx(500, .transfer, from: Self.accA, to: Self.accB)
        #expect(transfer.involves(account: Self.accA))
        #expect(transfer.involves(account: Self.accB))
        #expect(!transfer.involves(account: "acc-C"))
        #expect(Self.tx(100, .expense, from: Self.accA).involves(account: Self.accA))
        #expect(!Self.tx(100, .expense, from: Self.accA).involves(account: Self.accB))
    }

    @Test("signedEffect: income +, expense −, transfer out −, transfer in +, unrelated 0")
    func signedEffect() {
        #expect(Self.tx(100, .income, from: Self.accA).signedEffect(on: Self.accA) == 100)
        #expect(Self.tx(100, .expense, from: Self.accA).signedEffect(on: Self.accA) == -100)
        let transfer = Self.tx(500, .transfer, from: Self.accA, to: Self.accB)
        #expect(transfer.signedEffect(on: Self.accA) == -500)
        #expect(transfer.signedEffect(on: Self.accB) == 500)
        #expect(transfer.signedEffect(on: "acc-C") == 0)
    }

    @Test("total(of:) sums one type only")
    func totalOfType() {
        let list = [
            Self.tx(100, .expense, from: Self.accA),
            Self.tx(250, .expense, from: Self.accA),
            Self.tx(900, .income, from: Self.accA),
            Self.tx(400, .transfer, from: Self.accA, to: Self.accB),
        ]
        #expect(list.total(of: .expense) == 350)
        #expect(list.total(of: .income) == 900)
        #expect(list.total(of: .transfer) == 400)
    }

    @Test("balance(of:) folds signedEffect")
    func balanceOfAccount() {
        let list = [
            Self.tx(1000, .income, from: Self.accA),
            Self.tx(300, .expense, from: Self.accA),
            Self.tx(200, .transfer, from: Self.accA, to: Self.accB),
            Self.tx(50, .expense, from: Self.accB),
        ]
        #expect(list.balance(of: Self.accA) == 500)
        #expect(list.balance(of: Self.accB) == 150)
    }
}
```

`TransactionFilterMatchingTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

/// `TransactionFilter.matches(_:)` 是唯一的篩選語意；`accountIds` 採雙向。
@Suite("TransactionFilter.matches")
struct TransactionFilterMatchingTests {
    private static let accA = "acc-A"
    private static let accB = "acc-B"
    private static let catFood = UUID()
    private static let tagTravel = Tag(id: UUID(), name: "Travel", color: "#FFF")
    private static let day = Date(timeIntervalSince1970: 1_700_000_000)

    private static let expense = Transaction(
        amount: 100, date: day, note: "Sushi dinner", categoryId: catFood,
        accountId: accA, type: .expense, tags: [tagTravel]
    )
    private static let transferIn = Transaction(
        amount: 500, date: day, note: nil, categoryId: nil,
        accountId: accB, toAccountId: accA, type: .transfer
    )

    @Test("empty filter matches everything")
    func emptyFilter() {
        #expect(TransactionFilter().matches(Self.expense))
        #expect(TransactionFilter().matches(Self.transferIn))
    }

    @Test("accountIds includes transfers INTO the account")
    func accountIdsBidirectional() {
        let f = TransactionFilter(accountIds: [Self.accA])
        #expect(f.matches(Self.expense))
        #expect(f.matches(Self.transferIn))
        #expect(!TransactionFilter(accountIds: ["acc-C"]).matches(Self.transferIn))
    }

    @Test("categoryIds excludes uncategorized rows")
    func categoryIds() {
        let f = TransactionFilter(categoryIds: [Self.catFood])
        #expect(f.matches(Self.expense))
        #expect(!f.matches(Self.transferIn))
    }

    @Test("tagIds / types / dateRange / searchText each narrow the match")
    func otherDimensions() {
        #expect(TransactionFilter(tagIds: [Self.tagTravel.id]).matches(Self.expense))
        #expect(!TransactionFilter(tagIds: [UUID()]).matches(Self.expense))
        #expect(TransactionFilter(types: [.expense]).matches(Self.expense))
        #expect(!TransactionFilter(types: [.income]).matches(Self.expense))
        let inRange = Self.day.addingTimeInterval(-60)...Self.day.addingTimeInterval(60)
        let outRange = Self.day.addingTimeInterval(60)...Self.day.addingTimeInterval(120)
        #expect(TransactionFilter(dateRange: inRange).matches(Self.expense))
        #expect(!TransactionFilter(dateRange: outRange).matches(Self.expense))
        #expect(TransactionFilter(searchText: "DINNER").matches(Self.expense))
        #expect(!TransactionFilter(searchText: "taxi").matches(Self.expense))
        #expect(TransactionFilter(searchText: "").matches(Self.transferIn))   // 空字串不篩
    }

    @Test("dimensions are ANDed")
    func combined() {
        let f = TransactionFilter(accountIds: [Self.accA], types: [.transfer])
        #expect(f.matches(Self.transferIn))
        #expect(!f.matches(Self.expense))
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/TransactionAccountsTests`、`TransactionFilterMatchingTests` → 編譯錯誤 `no member 'involves'` / `'matches'`。

- [ ] **Step 3: 實作**

`Transaction+Accounts.swift`：

```swift
import Foundation

/// 全 App 唯一的「交易 ↔ 帳戶」規則。餘額、帳戶篩選、Dashboard 範圍、刪帳戶保護一律用這裡。
public extension Transaction {

    /// 交易是否牽涉此帳戶：轉出方 `accountId` 或轉入方 `toAccountId`。
    func involves(account id: Account.ID) -> Bool {
        accountId == id || toAccountId == id
    }

    /// 此交易對指定帳戶餘額的淨影響：收入 +、支出 −、轉帳轉出 −、轉入 +；無關帳戶為 0。
    func signedEffect(on id: Account.ID) -> Decimal {
        switch type {
        case .income:
            return accountId == id ? amount : 0
        case .expense:
            return accountId == id ? -amount : 0
        case .transfer:
            var effect: Decimal = 0
            if accountId == id { effect -= amount }
            if toAccountId == id { effect += amount }
            return effect
        }
    }
}
```

`Transaction+Aggregation.swift`：

```swift
import Foundation

public extension Sequence where Element == Transaction {

    /// 指定類型的金額總和；其他類型不計。
    func total(of type: TransactionType) -> Decimal {
        reduce(Decimal.zero) { $1.type == type ? $0 + $1.amount : $0 }
    }

    /// 指定帳戶的餘額（`signedEffect(on:)` 的總和）。
    func balance(of accountId: Account.ID) -> Decimal {
        reduce(Decimal.zero) { $0 + $1.signedEffect(on: accountId) }
    }
}
```

`TransactionFilter+Matching.swift`：

```swift
import Foundation

public extension TransactionFilter {

    /// 唯一的篩選語意。`accountIds` 採雙向（含轉入），與 `Transaction.involves(account:)` 一致。
    /// 各維度為 AND；`nil` 維度不篩；`searchText` 空字串不篩。
    func matches(_ transaction: Transaction) -> Bool {
        if let categoryIds {
            guard let categoryId = transaction.categoryId, categoryIds.contains(categoryId) else { return false }
        }
        if let accountIds {
            guard accountIds.contains(where: { transaction.involves(account: $0) }) else { return false }
        }
        if let tagIds {
            guard transaction.tags.contains(where: { tagIds.contains($0.id) }) else { return false }
        }
        if let types {
            guard types.contains(transaction.type) else { return false }
        }
        if let dateRange {
            guard dateRange.contains(transaction.date) else { return false }
        }
        if let searchText, !searchText.isEmpty {
            let lowered = searchText.lowercased()
            guard transaction.note?.lowercased().contains(lowered) == true else { return false }
        }
        return true
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: 兩個新 suite → SUCCEEDED。

- [ ] **Step 5: 完整 scheme + commit**

Run: 完整 scheme → SUCCEEDED。

```bash
git add Features/Sources/Domain/Entities/Transaction+Accounts.swift \
        Features/Sources/Domain/Entities/Transaction+Aggregation.swift \
        Features/Sources/Domain/Entities/TransactionFilter+Matching.swift \
        NeuLedgerTests/Tests/DomainTests/Entities/TransactionAccountsTests.swift \
        NeuLedgerTests/Tests/DomainTests/Entities/TransactionFilterMatchingTests.swift
git commit -m "feat(domain): Transaction account involvement, aggregation, and TransactionFilter.matches [ci skip]"
```

---

### Task 4: Ledger / Insights tool / Dashboard 改用 Domain 規則

**Files:**
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift:143-175`（listAll）、`:227-230`（deleteAccount）、`:245-283`（balance / balances）
- Modify: `Features/Sources/Application/Insights/InsightsClient+Live.swift:44-66`（`QueryTransactionsTool.call` 的內聯 filter）
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift:390-393`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientLiveTests.swift`（改 1 斷言、加 2 測）

**Interfaces:**
- Consumes: Task 3 的 `matches(_:)`、`involves(account:)`、`balance(of:)`。
- Produces: `TransactionFilter(accountIds:)` 從此雙向（行為變更，見 spec D3）。

- [ ] **Step 1: 寫失敗測試**

`LedgerClientLiveTests.testListAllFilters` 內把

```swift
        results = try await sut.listAll(TransactionFilter(accountIds: [acc1]))
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.transaction.accountId == acc1 })
```

改為

```swift
        results = try await sut.listAll(TransactionFilter(accountIds: [acc1]))
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.transaction.involves(account: acc1) })
```

並在 `testSearch` 之前加入：

```swift
    @Test("listAll(accountIds:) includes transfers INTO the account — same semantics as balance")
    func testListAllAccountFilterIncludesIncomingTransfers() async throws {
        let accA = UUID().uuidString
        let accB = UUID().uuidString
        let out = Transaction(amount: 100, date: Date(), accountId: accA, type: .expense)
        let transferIn = Transaction(amount: 500, date: Date(), accountId: accB, toAccountId: accA, type: .transfer)
        let unrelated = Transaction(amount: 50, date: Date(), accountId: accB, type: .expense)
        try await sut.record(out)
        try await sut.record(transferIn)
        try await sut.record(unrelated)

        let results = try await sut.listAll(TransactionFilter(accountIds: [accA]))
        #expect(Set(results.map(\.transaction.id)) == Set([out.id, transferIn.id]))
    }

    @Test("balance folds signedEffect: income +, expense −, transfer out −, transfer in +")
    func testBalanceSignedEffect() async throws {
        let accA = UUID().uuidString
        let accB = UUID().uuidString
        try await sut.record(Transaction(amount: 1000, date: Date(), accountId: accA, type: .income))
        try await sut.record(Transaction(amount: 300, date: Date(), accountId: accA, type: .expense))
        try await sut.record(Transaction(amount: 200, date: Date(), accountId: accA, toAccountId: accB, type: .transfer))
        try await sut.record(Transaction(amount: 50, date: Date(), accountId: accB, type: .expense))

        #expect(try await sut.balance(accA) == 500)
        #expect(try await sut.balance(accB) == 150)
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/LedgerClientLiveTests`
Expected: `testListAllAccountFilterIncludesIncomingTransfers` FAIL（舊實作只回 `out`）；`testBalanceSignedEffect` PASS（舊實作語意已對）。

- [ ] **Step 3: 實作 — LedgerClient+Live**

`listAll` 整段換成：

```swift
            listAll: { filter in
                let all = try await transactionStore.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                return try await enrich(all.filter(filter.matches))
            },
```

`deleteAccount` 內 `$0.accountId == id || $0.toAccountId == id` 換成 `$0.involves(account: id)`。

`balance` / `balances` 換成：

```swift
            balance: { id in
                try await transactionStore.fetchAll().balance(of: id)
            },
            balances: {
                let active = try await accountStore.fetchAll(
                    sortBy: [SortDescriptor(\.sortOrder)]
                ).filter { !$0.isArchived }
                let transactions = try await transactionStore.fetchAll()
                var result: [Account.ID: Decimal] = [:]
                for account in active {
                    result[account.id] = transactions.balance(of: account.id)
                }
                return result
            },
```

- [ ] **Step 4: 實作 — QueryTransactionsTool**

`InsightsClient+Live.swift` 內：

```swift
        // Inline filter mirroring the former `transactionClient.fetch(filter)`.
        let all = try await transactionStore.fetchAll()
        let transactions = all.filter { txn in
            if let categoryIds {
                guard let cid = txn.categoryId, categoryIds.contains(cid) else { return false }
            }
            if let dateRange {
                guard dateRange.contains(txn.date) else { return false }
            }
            return true
        }
```

換成：

```swift
        let filter = TransactionFilter(categoryIds: categoryIds, dateRange: dateRange)
        let transactions = try await transactionStore.fetchAll().filter(filter.matches)
```

- [ ] **Step 5: 實作 — DashboardFeature**

`transactionsEffect` 內 `all.filter { $0.accountId == id || $0.toAccountId == id }` 換成 `all.filter { $0.involves(account: id) }`。

- [ ] **Step 6: 跑測試確認通過**

Run: `LedgerClientLiveTests`、`InsightsClientLiveTests`、`DashboardFeatureScopeTests`、`TransactionsFeatureTests` → SUCCEEDED。

- [ ] **Step 7: 完整 scheme + commit**

Run: 完整 scheme → SUCCEEDED。

```bash
git add Features/Sources/Application/Ledger/LedgerClient+Live.swift \
        Features/Sources/Application/Insights/InsightsClient+Live.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift \
        NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientLiveTests.swift
git commit -m "refactor: account scoping and filter matching go through Domain rules (bidirectional accountIds) [ci skip]"
```

---

### Task 5: `Budget.spent(in:)`（Domain）+ Planning / Kernel / Watch 改用

**Files:**
- Create: `Features/Sources/Domain/Entities/Budget+Spending.swift`
- Modify: `Features/Sources/Domain/Entities/Budget.swift:70-78`（`evaluate` 內 totalSpent）
- Modify: `Features/Sources/Application/Planning/PlanningClient+Live.swift`（`currentStatus`）
- Modify: `Features/Sources/Core/Analytics/TransactionAnalyticsKernel.swift`（`budgetGauges` 的 scoped/spent）
- Modify: `Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift`（today total + monthBudgetProgress）
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/BudgetSpendingTests.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/WatchContextBuilderTests.swift`（加 1 測）

**Interfaces:**
- Produces：
  ```swift
  extension Budget { func appliesTo(_ transaction: Transaction) -> Bool
                     func spent(in transactionsInPeriod: some Sequence<Transaction>) -> Decimal
                     func progress(spent: Decimal) -> Double? }
  ```

- [ ] **Step 1: 寫失敗測試（Domain）**

`BudgetSpendingTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

/// `Budget+Spending`：全 App 唯一的「預算已花多少」定義。
@Suite("Budget+Spending")
struct BudgetSpendingTests {
    private static let food = UUID()
    private static let transport = UUID()

    private static func budget(amount: Decimal, categoryId: UUID? = nil) -> Budget {
        Budget(name: "B", amount: amount, categoryId: categoryId, period: .monthly, startDate: Date())
    }
    private static func tx(_ amount: Decimal, _ type: TransactionType, category: UUID?) -> Transaction {
        Transaction(amount: amount, date: Date(), categoryId: category, accountId: "acc", type: type)
    }

    private static let sample: [Transaction] = [
        tx(100, .expense, category: food),
        tx(250, .expense, category: transport),
        tx(30,  .expense, category: nil),
        tx(900, .income,  category: food),
        tx(400, .transfer, category: nil),
    ]

    @Test("appliesTo: expense only; category-scoped budget only its category")
    func appliesTo() {
        let overall = Self.budget(amount: 1000)
        let foodOnly = Self.budget(amount: 1000, categoryId: Self.food)
        #expect(overall.appliesTo(Self.tx(1, .expense, category: nil)))
        #expect(!overall.appliesTo(Self.tx(1, .income, category: nil)))
        #expect(!overall.appliesTo(Self.tx(1, .transfer, category: nil)))
        #expect(foodOnly.appliesTo(Self.tx(1, .expense, category: Self.food)))
        #expect(!foodOnly.appliesTo(Self.tx(1, .expense, category: Self.transport)))
        #expect(!foodOnly.appliesTo(Self.tx(1, .expense, category: nil)))
    }

    @Test("spent(in:) sums applicable expenses only")
    func spent() {
        #expect(Self.budget(amount: 1000).spent(in: Self.sample) == 380)
        #expect(Self.budget(amount: 1000, categoryId: Self.food).spent(in: Self.sample) == 100)
        #expect(Self.budget(amount: 1000).spent(in: []) == 0)
    }

    @Test("progress(spent:) is spent/amount, nil for non-positive amount")
    func progress() {
        #expect(Self.budget(amount: 1000).progress(spent: 250) == 0.25)
        #expect(Self.budget(amount: 0).progress(spent: 250) == nil)
        #expect(Self.budget(amount: -5).progress(spent: 0) == nil)
    }

    @Test("evaluate uses spent(in:) — same usedPercent as manual sum")
    func evaluateConsistent() {
        let outcome = Self.budget(amount: 1000).evaluate(
            transactionsInPeriod: Self.sample, threshold: 30, lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 38)
        #expect(outcome.shouldWarn)
    }
}
```

- [ ] **Step 2: 寫失敗測試（Watch）**

`WatchContextBuilderTests.swift` 在 `monthBudgetProgressNilWhenNoBudgetActive` 之後加：

```swift
    @Test("monthBudgetProgress = overall monthly budget spent ratio, in-month expenses only, category budgets ignored")
    func monthBudgetProgressRatio() async throws {
        let accountId = UUID().uuidString
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!
        let txns: [Transaction] = [
            Transaction(amount: 250, date: now, accountId: accountId, type: .expense),
            Transaction(amount: 400, date: lastMonth, accountId: accountId, type: .expense),
            Transaction(amount: 900, date: now, accountId: accountId, type: .income),
        ]
        let container = try await makeSeededContainer(transactions: txns)
        let overall = Budget(name: "總預算", amount: 1000, categoryId: nil, period: .monthly, startDate: now)
        let scoped = Budget(name: "餐費", amount: 100, categoryId: UUID(), period: .monthly, startDate: now)

        let snapshot = try await withDependencies {
            $0.calendar = cal
            $0.modelContainer = container
            $0.planningClient.listActive = { @Sendable in [scoped, overall] }
            $0.carrierClient.listAll = { @Sendable in [] }
        } operation: {
            try await WatchContextBuilder.build(now: now, defaultAccountId: accountId)
        }

        #expect(snapshot.monthBudgetProgress == 0.25)
        #expect(snapshot.todayTotal == 250)
    }
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/BudgetSpendingTests` → 編譯錯誤 `no member 'appliesTo'`。

- [ ] **Step 4: 實作 — Domain**

`Budget+Spending.swift`：

```swift
import Foundation

/// 全 App 唯一的「預算已花多少」規則。Planning / Insights Kernel / Watch 一律呼叫這裡。
public extension Budget {

    /// 此預算是否計入這筆交易：只計支出；有 `categoryId` 時只計該分類。
    func appliesTo(_ transaction: Transaction) -> Bool {
        guard transaction.type == .expense else { return false }
        guard let scopedCategoryId = categoryId else { return true }
        return transaction.categoryId == scopedCategoryId
    }

    /// 已花金額。呼叫端負責先用 `period.dateInterval(containing:)` 篩出期內交易。
    func spent(in transactionsInPeriod: some Sequence<Transaction>) -> Decimal {
        transactionsInPeriod.reduce(Decimal.zero) { appliesTo($1) ? $0 + $1.amount : $0 }
    }

    /// 已用比例（0.25 = 花了 25%）；`amount <= 0` 回 `nil`。
    func progress(spent: Decimal) -> Double? {
        guard amount > 0 else { return nil }
        return NSDecimalNumber(decimal: spent / amount).doubleValue
    }
}
```

`Budget.swift` 的 `evaluate` 內：

```swift
        let totalSpent = transactionsInPeriod
            .filter { txn in
                guard txn.type == .expense else { return false }
                guard let scopedCategoryId = categoryId else { return true }
                return txn.categoryId == scopedCategoryId
            }
            .reduce(into: Decimal(0)) { $0 += $1.amount }
```

換成：

```swift
        let totalSpent = spent(in: transactionsInPeriod)
```

- [ ] **Step 5: 實作 — Planning**

`currentStatus` 換成：

```swift
            currentStatus: { budget in
                let range = budget.period.closedRange(containing: Date())
                let all = try await transactionStore.fetchAll()
                let spent = budget.spent(in: all.filter { range.contains($0.date) })
                return BudgetStatus(
                    budget: budget,
                    periodStart: range.lowerBound,
                    periodEnd: range.upperBound,
                    spent: spent
                )
            },
```

- [ ] **Step 6: 實作 — Kernel**

`budgetGauges` 內：

```swift
            let categoryFilter = budget.categoryId
            let scoped = rows.filter { tx in
                guard let catId = categoryFilter else { return true }
                return tx.categoryId == catId
            }
            let spent = scoped.reduce(Decimal.zero) { $0 + $1.amount }
```

換成：

```swift
            let spent = budget.spent(in: rows.map(scalarTransaction))
```

並在 Kernel 的 `// MARK: - Internals` 區（`private static func fetch` 之前）加入純量轉換 helper。**不要**用 `SDTransaction.toDomain()`：它會讀 `tags` 關聯，而 `fetch` 回傳的 rows 其 `ModelContext` 已離開作用域，關聯 fault 可能失敗；純量欄位已載入所以安全（既有程式碼也只讀純量）。

```swift
    /// 只讀純量欄位的 Domain 投影（不碰 `tags` 關聯），給 `Budget.spent(in:)` /
    /// `Transaction.involves(account:)` 等 Domain 規則使用。
    private static func scalarTransaction(_ tx: SDTransaction) -> Transaction {
        Transaction(
            id: tx.id,
            amount: tx.amount,
            date: tx.date,
            note: tx.note,
            categoryId: tx.categoryId,
            accountId: tx.accountId,
            toAccountId: tx.toAccountId,
            type: TransactionType(rawValue: tx.type) ?? .expense,
            tags: [],
            aiSuggested: tx.aiSuggested,
            createdAt: tx.createdAt,
            updatedAt: tx.updatedAt
        )
    }
```

（欄位名已對照 `Features/Sources/Core/Persistence/Models/SDTransaction.swift`：`note: String?`、`toAccountId: String?`、`type: String`，與上面一致。）

- [ ] **Step 7: 實作 — WatchContextBuilder**

`build` 內：

```swift
        let todayExpenses = allTxns.filter {
            $0.type == .expense && todayRange.contains($0.date)
        }
        let todayTotal = todayExpenses.reduce(Decimal(0)) { $0 + $1.amount }
```

換成：

```swift
        let todayExpenses = allTxns.filter {
            $0.type == .expense && todayRange.contains($0.date)
        }
        let todayTotal = todayExpenses.total(of: .expense)
```

`monthBudgetProgress` 內從 `let monthRange = ...` 之後整段換成：

```swift
        let monthRange = BudgetPeriod.monthly.dateInterval(containing: now, calendar: calendar)
        let spent = overall.spent(in: transactions.filter { monthRange.contains($0.date) })
        return overall.progress(spent: spent)
```

（刪掉原本的 `monthExpenseTotal`、`guard overall.amount > 0`、`ratio` 三段。）

- [ ] **Step 8: 跑測試確認通過**

Run: `BudgetSpendingTests`、`BudgetEvaluateTests`、`PlanningClientLiveTests`、`PlanningClientEvaluateTests`、`InsightsClientLiveTests`、`WatchContextBuilderTests` → SUCCEEDED。

- [ ] **Step 9: 完整 scheme + watch 測試 + commit + 開 PR A**

Run: 完整 `NeuLedger` scheme → SUCCEEDED；watch 測試 → SUCCEEDED。

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor: Budget.spent(in:) is the single source for period spend (Planning/Kernel/Watch) [ci skip]"
```

跑 CLAUDE.md 的四條 ast-grep audit，確認輸出符合預期後，用 `commit-commands:commit-push-pr` 開 PR，標題 `refactor: aggregate cross-domain calendar/budget/account rules into Domain`（不含 `[ci skip]`），body 連結 spec 並列出 D1–D3 的行為變更。

---

# PR B — Analysis 改走 Insights（分支 `fix/aggregation-b-analysis-insights`，自 PR A merge 後的 `developer` 開）

### Task 6: `InsightsClient` 介面擴充與 Kernel 帳戶範圍 / 在地化名稱

**Files:**
- Modify: `Features/Sources/Domain/Clients/InsightsClient.swift:32-36`
- Modify: `Features/Sources/Domain/Analysis/Models/CategoryProportion.swift`（加 `uncategorizedId`）
- Modify: `Features/Sources/Core/Analytics/TransactionAnalyticsKernel.swift`（`dailyBars`、`categoryProportions` 加參數；新增 `financialSummary`）
- Modify: `Features/Sources/Application/Insights/InsightsClient+Live.swift:120-160`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/InsightsClientLiveTests.swift`（加 3 測）
- Test: `NeuLedgerTests/Tests/DomainTests/Clients/InsightsClientTests.swift:39-62`（改 stub 參數個數）

**Interfaces:**
- Produces（Task 7 用）：
  ```swift
  InsightsClient.financialSummary:    (_ range: DateInterval, _ accountId: Account.ID?) async throws -> FinancialSummary
  InsightsClient.dailyBars:           (_ range: DateInterval, _ accountId: Account.ID?) async throws -> [DailyTrend]
  InsightsClient.categoryProportions: (_ range: DateInterval, _ accountId: Account.ID?) async throws -> [CategoryProportion]
  CategoryProportion.uncategorizedId == "uncategorized"
  ```

- [ ] **Step 1: 更新 Domain stub 測試**

`InsightsClientTests.swift` 兩處：

```swift
            $0.insightsClient.dailyBars = { _, _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.dailyBars(DateInterval(start: day, duration: 86_400), nil)
```

```swift
            $0.insightsClient.categoryProportions = { _, _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.categoryProportions(DateInterval(start: Date(), duration: 86_400), nil)
```

- [ ] **Step 2: 寫失敗測試（Live）**

`InsightsClientLiveTests.swift` 在 `// MARK: - isAIAvailable` 之前加：

```swift
    // MARK: - Analysis projections (financialSummary / dailyBars / categoryProportions)

    private func incomeTx(amount: Decimal, date: Date, accountId: String) -> SDTransaction {
        SDTransaction(
            id: UUID(), amount: amount, date: date, note: "",
            categoryId: nil, accountId: accountId, toAccountId: nil,
            type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: date, updatedAt: date
        )
    }

    @Test("financialSummary sums income/expense in range, excludes transfers, scopes to account")
    func testFinancialSummary() async throws {
        let container = try freshContainer()
        let now = Date()
        let range = BudgetPeriod.monthly.dateInterval(containing: now)
        let a = UUID().uuidString
        let b = UUID().uuidString
        try insert(expenseTx(amount: 300, date: now, accountId: a), into: container)
        try insert(expenseTx(amount: 120, date: now, accountId: b), into: container)
        try insert(incomeTx(amount: 5000, date: now, accountId: a), into: container)
        let transfer = SDTransaction(
            id: UUID(), amount: 999, date: now, note: "",
            categoryId: nil, accountId: a, toAccountId: b,
            type: TransactionType.transfer.rawValue,
            aiSuggested: false, createdAt: now, updatedAt: now
        )
        try insert(transfer, into: container)
        try insert(expenseTx(amount: 777, date: range.start.addingTimeInterval(-60), accountId: a), into: container)

        let client = sut(container)
        let all = try await client.financialSummary(range, nil)
        #expect(all == FinancialSummary(totalIncome: 5000, totalExpense: 420))
        let onlyA = try await client.financialSummary(range, a)
        #expect(onlyA == FinancialSummary(totalIncome: 5000, totalExpense: 300))
    }

    @Test("dailyBars scoped to account only counts that account's expenses")
    func testDailyBarsAccountScope() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let range = BudgetPeriod.monthly.dateInterval(containing: today)
        let a = UUID().uuidString
        let b = UUID().uuidString
        try insert(expenseTx(amount: 100, date: today.addingTimeInterval(3600), accountId: a), into: container)
        try insert(expenseTx(amount: 50, date: today.addingTimeInterval(7200), accountId: b), into: container)

        let client = sut(container)
        let all = try await client.dailyBars(range, nil)
        #expect(all == [DailyTrend(date: today, amount: 150)])
        let onlyA = try await client.dailyBars(range, a)
        #expect(onlyA == [DailyTrend(date: today, amount: 100)])
    }

    @Test("categoryProportions resolves seed names via localizedName and buckets uncategorized under the stable id")
    func testCategoryProportionsNamesAndUncategorized() async throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let food = Category(name: "Food", icon: "fork.knife", color: "#FF6B6B", type: .expense, isDefault: true)
        SDCategory.from(food, context: ctx)
        try ctx.save()

        let now = Date()
        let range = BudgetPeriod.monthly.dateInterval(containing: now)
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 300, date: now, accountId: acct, categoryId: food.id), into: container)
        try insert(expenseTx(amount: 120, date: now, accountId: acct, categoryId: nil), into: container)

        let result = try await sut(container).categoryProportions(range, nil)
        #expect(result.count == 2)
        #expect(result[0].id == food.id.uuidString)
        #expect(result[0].name == food.localizedName)   // zh-Hant → "餐飲"，en → "Food"
        #expect(result[0].amount == 300)
        #expect(result[1].id == CategoryProportion.uncategorizedId)
        #expect(result[1].name == String(localized: "analysis_other_category", bundle: .main))
        #expect(result[1].amount == 120)
    }
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/InsightsClientLiveTests` → 編譯錯誤（`financialSummary` 不存在、參數個數不符）。

- [ ] **Step 4: 實作 — Domain 介面**

`InsightsClient.swift` 把 `dailyBars` / `categoryProportions` 兩行換成三行：

```swift
    /// 區間內收入 / 支出總額（排除轉帳），可限定帳戶。Analysis KPI 用。
    public var financialSummary: @Sendable (_ range: DateInterval, _ accountId: Account.ID?) async throws -> FinancialSummary = { _, _ in FinancialSummary(totalIncome: 0, totalExpense: 0) }

    /// 區間內每日支出長條（無支出的日子省略），可限定帳戶。
    public var dailyBars: @Sendable (_ range: DateInterval, _ accountId: Account.ID?) async throws -> [DailyTrend] = { _, _ in [] }

    /// 區間內分類支出佔比（金額降冪；未分類桶 id = `CategoryProportion.uncategorizedId`），可限定帳戶。
    public var categoryProportions: @Sendable (_ range: DateInterval, _ accountId: Account.ID?) async throws -> [CategoryProportion] = { _, _ in [] }
```

`CategoryProportion.swift` 在 `public let amount: Decimal` 之後加：

```swift
    /// 未分類支出桶的固定 id；Analysis drill-down 靠它判斷「不帶 categoryIds 篩選」。
    public static let uncategorizedId = "uncategorized"
```

- [ ] **Step 5: 實作 — Kernel**

在 `statsSnapshot` 之後新增：

```swift
    /// 區間內收入 / 支出總額（排除轉帳），可限定帳戶。
    static func financialSummary(
        range: DateInterval,
        accountId: Account.ID?,
        container: ModelContainer
    ) throws -> FinancialSummary {
        let start = range.start
        let end = range.end
        let rows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in tx.date >= start && tx.date < end },
            sortBy: []
        )
        let scoped = rows.map(scalarTransaction).filter { tx in
            accountId.map { tx.involves(account: $0) } ?? true
        }
        return FinancialSummary(
            totalIncome: scoped.total(of: .income),
            totalExpense: scoped.total(of: .expense)
        )
    }
```

`dailyBars` 簽名加 `accountId: Account.ID?`（放在 `range` 之後），迴圈第一行加帳戶篩選：

```swift
    static func dailyBars(
        range: DateInterval,
        accountId: Account.ID?,
        container: ModelContainer
    ) throws -> [DailyTrend] {
        ...
        for tx in rows {
            if let accountId, tx.accountId != accountId { continue }
            let day = cal.startOfDay(for: tx.date)
            sums[day, default: 0] += tx.amount
        }
```

`categoryProportions` 同樣加 `accountId: Account.ID?` 參數與迴圈篩選，並把未分類桶改為：

```swift
        if unassigned > 0 {
            result.append(CategoryProportion(
                id: CategoryProportion.uncategorizedId,
                name: String(localized: "analysis_other_category", bundle: .main),
                amount: unassigned
            ))
        }
```

- [ ] **Step 6: 實作 — Live wiring**

`InsightsClient+Live.swift` 的 `return InsightsClient(` 內，`dailyBars` / `categoryProportions` / `budgetGauges` 換成：

```swift
            financialSummary: { range, accountId in
                try TransactionAnalyticsKernel.financialSummary(
                    range: range,
                    accountId: accountId,
                    container: persistenceBootstrap.modelContainer()
                )
            },
            dailyBars: { range, accountId in
                try TransactionAnalyticsKernel.dailyBars(
                    range: range,
                    accountId: accountId,
                    container: persistenceBootstrap.modelContainer()
                )
            },
            categoryProportions: { range, accountId in
                let categories = try await categoryStore.fetchAll()
                let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.localizedName) })
                return try TransactionAnalyticsKernel.categoryProportions(
                    range: range,
                    accountId: accountId,
                    container: persistenceBootstrap.modelContainer(),
                    categoryNamesById: names
                )
            },
            budgetGauges: { accountId in
                do {
                    let active = try await budgetStore.fetchAll().filter { $0.isActive }
                    let categories = try await categoryStore.fetchAll()
                    let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.localizedName) })
                    return try TransactionAnalyticsKernel.budgetGauges(
                        accountId: accountId,
                        activeBudgets: active,
                        categoryNamesById: names,
                        container: persistenceBootstrap.modelContainer()
                    )
                } catch {
                    return []
                }
            },
```

（`financialSummary` 是 memberwise init 的新參數，位置要放在 `weeklySparkline` 之後、`dailyBars` 之前，與 struct 宣告順序一致。）

- [ ] **Step 7: 跑測試確認通過**

Run: `InsightsClientLiveTests`、`InsightsClientTests` → SUCCEEDED。此時 `AnalysisFeatureTests` 仍編得過（它還沒呼叫這三個 endpoint）。

- [ ] **Step 8: 完整 scheme + commit**

Run: 完整 scheme → SUCCEEDED。

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "feat(insights): account-scoped financialSummary/dailyBars/categoryProportions with localized names [ci skip]"
```

---

### Task 7: `AnalysisFeature` 改走 `insightsClient`、移除 `State.Period`

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisFeature.swift`（整檔重寫，見下）
- Create: `Features/Sources/Features/Analysis/BudgetPeriod+AnalysisLabel.swift`
- Modify: `Features/Sources/Features/Analysis/Sections/AnalysisTopBar.swift:43-52, 105-123`
- Test: `NeuLedgerTests/Tests/FeaturesTests/AnalysisFeatureTests.swift`（整檔重寫）

**Interfaces:**
- Consumes: Task 6 的三個 endpoint、Task 1 的 `dateInterval` / `closedRange`。
- Produces: `AnalysisFeature.State.selectedPeriod: BudgetPeriod`、`Action.periodChanged(BudgetPeriod)`；`BudgetPeriod.analysisLabel`（Features 內部）。

- [ ] **Step 1: 重寫測試檔**

把 `AnalysisFeatureTests.swift` 整檔換成：

```swift
import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

/// Analysis 改為完全透過 `insightsClient` 取投影後的 reducer 測試。
/// 彙總正確性由 `InsightsClientLiveTests` 負責；這裡只驗 reducer 的協調與參數傳遞。
@Suite("AnalysisFeature Tests")
struct AnalysisFeatureTests {

    // MARK: - Shared Helpers

    private static let categoryId = UUID()
    private static let accountId = UUID().uuidString

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return cal
    }
    private static let now: Date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

    private static let sampleSummary = FinancialSummary(totalIncome: 5000, totalExpense: 500)
    private static let sampleProportions = [
        CategoryProportion(id: categoryId.uuidString, name: "飲食", amount: 500)
    ]
    private static let sampleTrends = [DailyTrend(date: calendar.startOfDay(for: now), amount: 500)]

    /// 所有 loadData 路徑會碰到的 closure 一次覆寫；個別測試再覆蓋需要的部分。
    private static func baseDependencies(_ deps: inout DependencyValues) {
        deps.date = .constant(now)
        deps.calendar = calendar
        deps.insightsClient.financialSummary = { _, _ in sampleSummary }
        deps.insightsClient.categoryProportions = { _, _ in sampleProportions }
        deps.insightsClient.dailyBars = { _, _ in sampleTrends }
        deps.insightsClient.budgetGauges = { _ in [] }
        deps.insightsClient.isAIAvailable = { false }
    }

    private static func makeStore(
        _ initial: AnalysisFeature.State = AnalysisFeature.State(),
        _ configure: @escaping (inout DependencyValues) -> Void = { _ in }
    ) async -> TestStoreOf<AnalysisFeature> {
        let store = await TestStore(initialState: initial) {
            AnalysisFeature()
        } withDependencies: {
            baseDependencies(&$0)
            configure(&$0)
        }
        await MainActor.run { store.exhaustivity = .off }
        return store
    }

    // MARK: - Period / account selection

    @Test("periodChanged updates selectedPeriod and reloads")
    func testPeriodChanged() async {
        let store = await Self.makeStore()
        await store.send(.periodChanged(.weekly)) { $0.selectedPeriod = .weekly }
        await store.receive(\.loadData) { $0.isLoading = true }
    }

    @Test("accountSelected updates selectedAccountId and reloads")
    func testAccountSelected() async {
        let store = await Self.makeStore()
        await store.send(.accountSelected(Self.accountId)) { $0.selectedAccountId = Self.accountId }
        await store.receive(\.loadData) { $0.isLoading = true }
    }

    @Test("loadData passes the full calendar interval of the selected period and the selected account to every projection")
    func testLoadDataPassesIntervalAndAccount() async {
        let captured = LockIsolated<[(DateInterval, Account.ID?)]>([])
        var initial = AnalysisFeature.State(selectedPeriod: .weekly)
        initial.selectedAccountId = Self.accountId
        let store = await Self.makeStore(initial) {
            $0.insightsClient.financialSummary = { r, a in captured.withValue { $0.append((r, a)) }; return Self.sampleSummary }
            $0.insightsClient.categoryProportions = { r, a in captured.withValue { $0.append((r, a)) }; return [] }
            $0.insightsClient.dailyBars = { r, a in captured.withValue { $0.append((r, a)) }; return [] }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData)

        let expected = BudgetPeriod.weekly.dateInterval(containing: Self.now, calendar: Self.calendar)
        #expect(captured.value.count == 3)
        #expect(captured.value.allSatisfy { $0.0 == expected && $0.1 == Self.accountId })
    }

    // MARK: - loadData outcomes

    @Test("loadData stores summary, proportions, trends from insightsClient")
    func testLoadDataHappyPath() async {
        let store = await Self.makeStore()
        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = Self.sampleSummary
            $0.categoryProportions = Self.sampleProportions
            $0.dailyTrends = Self.sampleTrends
            $0.insight = nil
        }
    }

    @Test("loadData with zero income and zero expense clears state (empty period)")
    func testLoadDataEmptyPeriod() async {
        var initial = AnalysisFeature.State()
        initial.summary = Self.sampleSummary
        initial.categoryProportions = Self.sampleProportions
        let store = await Self.makeStore(initial) {
            $0.insightsClient.financialSummary = { _, _ in FinancialSummary(totalIncome: 0, totalExpense: 0) }
            $0.insightsClient.categoryProportions = { _, _ in [] }
            $0.insightsClient.dailyBars = { _, _ in [] }
        }
        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = nil
            $0.categoryProportions = []
            $0.dailyTrends = []
            $0.insight = nil
        }
    }

    @Test("loadedData failure only clears isLoading")
    func testLoadedDataFailure() async {
        let store = await Self.makeStore() {
            $0.insightsClient.financialSummary = { _, _ in throw URLError(.badServerResponse) }
        }
        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) { $0.isLoading = false }
    }

    // MARK: - AI insight

    @Test("loadData generates AI insight from the projections when available")
    func testLoadDataAIInsightAvailable() async {
        let insightText = "本月消費偏高，建議減少外食。"
        let capturedSummary = LockIsolated<SpendingSummary?>(nil)
        let store = await Self.makeStore() {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { summary in
                capturedSummary.setValue(summary)
                return insightText
            }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData) {
            $0.insight = InsightDetail(
                id: $0.insight?.id ?? "",
                title: String(localized: "analysis_ai_insight_title"),
                description: insightText
            )
        }
        #expect(capturedSummary.value?.totalExpense == 500)
        #expect(capturedSummary.value?.categoryBreakdown == ["飲食": 500])
        #expect(capturedSummary.value?.periodDescription == BudgetPeriod.monthly.analysisLabel)
    }

    @Test("loadData keeps data and sets insight nil when generateAIInsight throws")
    func testLoadDataAIInsightFailsGracefully() async {
        struct AIError: Error {}
        let store = await Self.makeStore() {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in throw AIError() }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.insight = nil
            $0.summary = Self.sampleSummary
        }
    }

    // MARK: - Budget gauges

    @Test("budgetMetricsLoaded stores metrics")
    func testBudgetMetricsLoaded() async {
        let metrics = [BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)]
        let store = await TestStore(initialState: AnalysisFeature.State()) { AnalysisFeature() }
        await store.send(.budgetMetricsLoaded(metrics)) { $0.budgetMetrics = metrics }
    }

    @Test("loadData asks insightsClient.budgetGauges with the selected account")
    func testLoadDataBudgetGaugesAccount() async {
        let metrics = [BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)]
        let capturedAccount = LockIsolated<Account.ID?>(nil)
        var initial = AnalysisFeature.State()
        initial.selectedAccountId = Self.accountId
        let store = await Self.makeStore(initial) {
            $0.insightsClient.budgetGauges = { account in
                capturedAccount.setValue(account)
                return metrics
            }
        }
        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) { $0.budgetMetrics = metrics }   // 收到 metrics 即證明有被呼叫
        #expect(capturedAccount.value == Self.accountId)
    }

    @Test("budgetGauges failure yields empty metrics")
    func testBudgetGaugesFailure() async {
        struct GaugeError: Error {}
        var initial = AnalysisFeature.State()
        initial.budgetMetrics = [BudgetGaugeMetrics(id: "stale", categoryName: "x", spentAmount: 1, totalBudget: 2)]
        let store = await Self.makeStore(initial) {
            $0.insightsClient.budgetGauges = { _ in throw GaugeError() }
        }
        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) { $0.budgetMetrics = [] }
    }

    @Test("loadData sends both loadedData and budgetMetricsLoaded")
    func testLoadDataBothEffectsArrive() async {
        let metrics = [BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)]
        let store = await Self.makeStore() {
            $0.insightsClient.budgetGauges = { _ in metrics }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData)
        await store.receive(\.budgetMetricsLoaded)
        await store.finish()
        await MainActor.run {
            #expect(store.state.isLoading == false)
            #expect(store.state.summary == Self.sampleSummary)
            #expect(store.state.budgetMetrics == metrics)
        }
    }

    @Test("consecutive loadData: cancelInFlight keeps only the second budget result")
    func testLoadDataCancelInFlightBudgetEffect() async {
        let first = [BudgetGaugeMetrics(id: "first", categoryName: "a", spentAmount: 1, totalBudget: 10)]
        let second = [BudgetGaugeMetrics(id: "second", categoryName: "b", spentAmount: 2, totalBudget: 20)]
        let callCount = LockIsolated(0)
        let store = await Self.makeStore() {
            $0.insightsClient.budgetGauges = { _ in
                let n = callCount.withValue { $0 += 1; return $0 }
                return n == 1 ? first : second
            }
        }
        await store.send(.loadData)
        await store.send(.loadData)
        await store.receive(\.loadedData)
        await store.receive(\.budgetMetricsLoaded)
        await store.finish()
        await MainActor.run {
            #expect(store.state.budgetMetrics.map(\.id) == ["second"])
        }
    }

    // MARK: - Category drill-down

    @Test("categoryTapped fetches expenses scoped to category + account + period closedRange")
    func testCategoryTapped() async {
        let proportion = Self.sampleProportions[0]
        let expected: [Transaction] = [
            Transaction(amount: 300, date: Self.now, note: "午餐", categoryId: Self.categoryId, accountId: Self.accountId, type: .expense),
        ]
        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        var initial = AnalysisFeature.State()
        initial.selectedAccountId = Self.accountId
        let store = await Self.makeStore(initial) {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return expected.map { EnrichedTransaction(transaction: $0) }
            }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(categoryName: "飲食", transactions: expected)
        }
        let f = capturedFilter.value
        #expect(f?.categoryIds == Set([Self.categoryId]))
        #expect(f?.accountIds == Set([Self.accountId]))
        #expect(f?.types == Set([.expense]))
        #expect(f?.dateRange == BudgetPeriod.monthly.closedRange(containing: Self.now, calendar: Self.calendar))
    }

    @Test("categoryTapped with the uncategorized bucket omits categoryIds")
    func testCategoryTappedUncategorized() async {
        let proportion = CategoryProportion(id: CategoryProportion.uncategorizedId, name: "其他", amount: 150)
        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        let store = await Self.makeStore() {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return []
            }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded)
        #expect(capturedFilter.value?.categoryIds == nil)
    }

    @Test("categoryTapped fetch failure results in empty drilldown")
    func testCategoryTappedFetchFailure() async {
        struct FetchError: Error {}
        let proportion = CategoryProportion(id: UUID().uuidString, name: "飲食", amount: 300)
        let store = await Self.makeStore() {
            $0.ledgerClient.listAll = { _ in throw FetchError() }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(categoryName: "飲食", transactions: [])
        }
    }

    @Test("categoryDrilldownDismissed clears drilldown")
    func testCategoryDrilldownDismissed() async {
        var initial = AnalysisFeature.State()
        initial.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(categoryName: "飲食", transactions: [])
        let store = await TestStore(initialState: initial) { AnalysisFeature() }
        await store.send(.categoryDrilldownDismissed) { $0.categoryDrilldown = nil }
    }

    // MARK: - task

    @Test("task loads active accounts and forwards aiAssistant.task")
    func testTask() async {
        let accounts = [
            Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759", sortOrder: 0),
        ]
        let store = await Self.makeStore() {
            $0.ledgerClient.listActiveAccounts = { accounts }
            $0.insightsClient.isAIAvailable = { true }
        }
        await store.send(.task)
        await store.receive(\.accountsLoaded) { $0.accounts = accounts }
        await store.receive(\.aiAssistant.task) { $0.aiAssistant.isAvailable = true }
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/AnalysisFeatureTests` → 編譯錯誤（`selectedPeriod` 型別、`analysisLabel` 不存在）。

- [ ] **Step 3: 實作 — `BudgetPeriod+AnalysisLabel.swift`**

```swift
import Domain
import Foundation

extension BudgetPeriod {
    /// Analysis 頁的期間標籤（「週 / 月 / 年」語氣），沿用既有 `analysis_period_*` key；
    /// 與預算表單的 `localizedName`（「每週 / 每月 / 每年」）刻意分開。
    var analysisLabel: String {
        switch self {
        case .weekly:  return String(localized: "analysis_period_week")
        case .monthly: return String(localized: "analysis_period_month")
        case .yearly:  return String(localized: "analysis_period_year")
        }
    }
}
```

- [ ] **Step 4: 實作 — `AnalysisFeature.swift` 整檔**

```swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AnalysisFeature: Sendable {
    public init() {}

    public struct CategoryDrilldownState: Equatable, Sendable, Identifiable {
        public var id: String { categoryName }
        public let categoryName: String
        public let transactions: [Transaction]

        public init(categoryName: String, transactions: [Transaction]) {
            self.categoryName = categoryName
            self.transactions = transactions
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var selectedPeriod: BudgetPeriod = .monthly
        public var selectedAccountId: Account.ID? = nil
        public var accounts: [Account] = []
        public var isLoading: Bool = false

        public var summary: FinancialSummary?
        public var categoryProportions: [CategoryProportion] = []
        public var dailyTrends: [DailyTrend] = []
        public var budgetMetrics: [BudgetGaugeMetrics] = []
        public var insight: InsightDetail?
        public var categoryDrilldown: CategoryDrilldownState?
        public var aiAssistant: AIAssistantFeature.State = .init()

        public var hasData: Bool {
            summary != nil
        }

        public init(selectedPeriod: BudgetPeriod = .monthly, selectedAccountId: Account.ID? = nil) {
            self.selectedPeriod = selectedPeriod
            self.selectedAccountId = selectedAccountId
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case accountsLoaded([Account])
        case accountSelected(Account.ID?)
        case periodChanged(BudgetPeriod)
        case loadData
        case loadedData(TaskResult<AnalysisData?>)
        case budgetMetricsLoaded([BudgetGaugeMetrics])
        case categoryTapped(CategoryProportion)
        case categoryTransactionsLoaded(categoryName: String, [Transaction])
        case categoryDrilldownDismissed
        case aiAssistant(AIAssistantFeature.Action)
    }

    public struct AnalysisData: Equatable, Sendable {
        let summary: FinancialSummary
        let categoryProportions: [CategoryProportion]
        let dailyTrends: [DailyTrend]
        let insight: InsightDetail?
    }

    // MARK: - Dependencies

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.insightsClient) var insightsClient
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    private enum CancelID { case budgets }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [ledger] send in
                        let accounts = (try? await ledger.listActiveAccounts()) ?? []
                        await send(.accountsLoaded(accounts))
                    },
                    .send(.loadData),
                    .send(.aiAssistant(.task))
                )

            case let .accountsLoaded(accounts):
                state.accounts = accounts
                return .none

            case let .accountSelected(id):
                state.selectedAccountId = id
                return .send(.loadData)

            case let .periodChanged(period):
                state.selectedPeriod = period
                return .send(.loadData)

            case .loadData:
                state.isLoading = true
                let interval = state.selectedPeriod.dateInterval(containing: now, calendar: calendar)
                let periodName = state.selectedPeriod.analysisLabel
                let selectedAccountId = state.selectedAccountId
                return .merge(
                    .run { [insightsClient] send in
                        do {
                            async let summaryTask = insightsClient.financialSummary(interval, selectedAccountId)
                            async let proportionsTask = insightsClient.categoryProportions(interval, selectedAccountId)
                            async let trendsTask = insightsClient.dailyBars(interval, selectedAccountId)
                            let (summary, proportions, trends) = try await (summaryTask, proportionsTask, trendsTask)

                            // 收入與支出皆為 0 視為空期間（只有轉帳也算空）。
                            guard summary.totalIncome > 0 || summary.totalExpense > 0 else {
                                await send(.loadedData(.success(nil)))
                                return
                            }

                            var insight: InsightDetail? = nil
                            if insightsClient.isAIAvailable() {
                                let breakdown = Dictionary(
                                    proportions.map { ($0.name, $0.amount) },
                                    uniquingKeysWith: { $0 + $1 }
                                )
                                let spendingSummary = SpendingSummary(
                                    totalIncome: summary.totalIncome,
                                    totalExpense: summary.totalExpense,
                                    categoryBreakdown: breakdown,
                                    periodDescription: periodName
                                )
                                if let text = try? await insightsClient.generateAIInsight(spendingSummary) {
                                    insight = InsightDetail(
                                        title: String(localized: "analysis_ai_insight_title"),
                                        description: text
                                    )
                                }
                            }

                            await send(.loadedData(.success(AnalysisData(
                                summary: summary,
                                categoryProportions: proportions,
                                dailyTrends: trends,
                                insight: insight
                            ))))
                        } catch {
                            await send(.loadedData(.failure(error)))
                        }
                    },
                    .run { [insightsClient] send in
                        let metrics = (try? await insightsClient.budgetGauges(selectedAccountId)) ?? []
                        await send(.budgetMetricsLoaded(metrics))
                    }
                    .cancellable(id: CancelID.budgets, cancelInFlight: true)
                )

            case let .categoryTapped(proportion):
                let categoryId = UUID(uuidString: proportion.id)
                let filter = TransactionFilter(
                    categoryIds: categoryId.map { Set([$0]) },
                    accountIds: state.selectedAccountId.map { Set([$0]) },
                    types: [.expense],
                    dateRange: state.selectedPeriod.closedRange(containing: now, calendar: calendar)
                )
                let name = proportion.name
                return .run { [ledger] send in
                    let transactions = ((try? await ledger.listAll(filter)) ?? []).map(\.transaction)
                    await send(.categoryTransactionsLoaded(categoryName: name, transactions))
                }

            case let .categoryTransactionsLoaded(categoryName, transactions):
                state.categoryDrilldown = CategoryDrilldownState(
                    categoryName: categoryName,
                    transactions: transactions
                )
                return .none

            case .categoryDrilldownDismissed:
                state.categoryDrilldown = nil
                return .none

            case let .budgetMetricsLoaded(metrics):
                state.budgetMetrics = metrics
                return .none

            case let .loadedData(.success(data)):
                state.isLoading = false
                guard let data else {
                    state.summary = nil
                    state.categoryProportions = []
                    state.dailyTrends = []
                    state.insight = nil
                    return .none
                }
                state.summary = data.summary
                state.categoryProportions = data.categoryProportions
                state.dailyTrends = data.dailyTrends
                state.insight = data.insight
                return .none

            case .loadedData(.failure):
                state.isLoading = false
                return .none

            case .aiAssistant:
                return .none
            }
        }
        Scope(state: \.aiAssistant, action: \.aiAssistant) {
            AIAssistantFeature()
        }
    }
}
```

（刪掉的東西：`State.Period`、`@Dependency(\.planningClient)`、`computeBudgetMetrics`、`currentPeriodRange`、`dateRange(for:)`。）

- [ ] **Step 5: 實作 — `AnalysisTopBar.swift`**

```swift
            ForEach(AnalysisFeature.State.Period.allCases) { period in
                periodPill(period)
            }
```
→
```swift
            ForEach(BudgetPeriod.allCases, id: \.self) { period in
                periodPill(period)
            }
```

`private func periodPill(_ period: AnalysisFeature.State.Period)` → `private func periodPill(_ period: BudgetPeriod)`；其內 `Text(period.displayName)` → `Text(period.analysisLabel)`。

`private func eyebrowLabel(for period: AnalysisFeature.State.Period)` → `private func eyebrowLabel(for period: BudgetPeriod)`；switch 三個 case `.week` / `.month` / `.year` 改為 `.weekly` / `.monthly` / `.yearly`（本體不動）。

- [ ] **Step 6: 跑測試確認通過**

Run: `-only-testing:NeuLedgerTests/AnalysisFeatureTests` → SUCCEEDED。
Run: `grep -rn 'State.Period' Features/Sources NeuLedgerTests` → 無輸出。
Run: `grep -rn 'planningClient' Features/Sources/Features/Analysis` → 無輸出。

- [ ] **Step 7: 完整 scheme + commit + 開 PR B**

Run: 完整 scheme → SUCCEEDED。

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor(analysis): consume insightsClient projections; drop local aggregation and State.Period [ci skip]"
```

跑四條 ast-grep audit，開 PR：`refactor: Analysis reads projections from InsightsClient`。

---

# PR C — 呈現層與跨 target（分支 `fix/aggregation-c-presentation`，自 PR B merge 後的 `developer` 開）

### Task 8: `Decimal.twdDigits` / `twdParts`（Common）與五處改用；`perPeriodBreakdown` 搬到 Common

**Files:**
- Modify: `Features/Sources/Common/Extensions/Decimal+Currency.swift`
- Move: `Features/Sources/Domain/Extensions/Decimal+Budget.swift` → `Features/Sources/Common/Extensions/Decimal+Budget.swift`
- Move: `NeuLedgerTests/Tests/DomainTests/Extensions/DecimalPerPeriodBreakdownTests.swift` → `NeuLedgerTests/Tests/CommonTests/DecimalPerPeriodBreakdownTests.swift`
- Modify: `Features/Sources/WatchFeatures/Record/AmountKeypadView.swift:40, 70-76`
- Modify: `Features/Sources/WatchFeatures/Record/ConfirmView.swift:34, 75-80`
- Modify: `Features/Sources/WatchFeatures/Complication/ComplicationEntry.swift`
- Modify: `Features/Sources/Features/Analysis/Sections/KPIStrip.swift`
- Modify: `Features/Sources/Features/Analysis/Sections/DailyBarsCard.swift:66-76, 86-92`
- Modify: `Features/Sources/Features/Analysis/Sections/CategoryDonutCard.swift:145, 199`
- Test: `NeuLedgerTests/Tests/CommonTests/CommonTests.swift`（加 1 suite）

**Interfaces:**
- Produces：`Decimal.twdDigits: String`（"12,500"）、`Decimal.twdParts: (symbol: String, digits: String)`（負數 symbol 為 "-NT$"，digits 取絕對值）。

- [ ] **Step 1: 寫失敗測試**

`CommonTests.swift` 末尾加：

```swift
@Suite("Decimal+Currency parts")
struct DecimalCurrencyPartsTests {
    @Test("twdDigits is thousands-separated integer without symbol")
    func twdDigits() {
        #expect(Decimal(0).twdDigits == "0")
        #expect(Decimal(480).twdDigits == "480")
        #expect(Decimal(12_500).twdDigits == "12,500")
        #expect(Decimal(1_234_567).twdDigits == "1,234,567")
    }

    @Test("twdParts splits symbol and digits; sign stays on the symbol")
    func twdParts() {
        let positive = Decimal(1_234).twdParts
        #expect(positive.symbol == "NT$")
        #expect(positive.digits == "1,234")
        let negative = Decimal(-1_234).twdParts
        #expect(negative.symbol == "-NT$")
        #expect(negative.digits == "1,234")
        #expect(positive.symbol + positive.digits == Decimal(1_234).twdFormatted)
        #expect(negative.symbol + negative.digits == Decimal(-1_234).twdFormatted)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/DecimalCurrencyPartsTests` → 編譯錯誤 `no member 'twdDigits'`。

- [ ] **Step 3: 實作 — Common**

`Decimal+Currency.swift` 檔頭加 `import Domain`，在 `twdCompact` 之後加：

```swift
    /// 千分位整數字串、不含貨幣符號："12,500"。Watch / Complication / 需要把符號另排的卡片用這個。
    var twdDigits: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let magnitude = self < 0 ? -self : self
        return formatter.string(from: magnitude as NSDecimalNumber) ?? "0"
    }

    /// (符號, 數字) 兩段，供「小字 NT$ + 大字數字」排版。負號留在符號上："-NT$" + "1,234"。
    var twdParts: (symbol: String, digits: String) {
        let symbol = Currency.TWD.symbol
        return (self < 0 ? "-" + symbol : symbol, twdDigits)
    }
```

`git mv Features/Sources/Domain/Extensions/Decimal+Budget.swift Features/Sources/Common/Extensions/Decimal+Budget.swift`，檔頭改為 `import Domain` + `import Foundation`，刪除 `private static func formatted(_:)`，三處 `Self.formatted(x)` 改為 `x.twdDigits`。

`git mv NeuLedgerTests/Tests/DomainTests/Extensions/DecimalPerPeriodBreakdownTests.swift NeuLedgerTests/Tests/CommonTests/DecimalPerPeriodBreakdownTests.swift`，`@testable import Domain` 改為 `@testable import Common` 並加 `import Domain`。若 `DomainTests/Extensions/` 因此變空目錄，`rmdir` 掉。

- [ ] **Step 4: 實作 — Watch**

`AmountKeypadView.swift`：`Text("NT$ \(formatted(store.draft?.amount ?? 0))")` → `Text("NT$ \((store.draft?.amount ?? 0).twdDigits)")`；刪除 `private func formatted(_ amount: Decimal) -> String { ... }`。
`ConfirmView.swift`：同樣替換與刪除。
`ComplicationEntry.swift`：檔頭加 `import Common`；`displayAmount` 本體改為 `todayTotal.twdDigits`。`ComplicationEntryTests` 既有斷言（"480"、"12,500"）不變。

- [ ] **Step 5: 實作 — Analysis 卡片**

`KPIStrip.swift`：四個 `kpiCard(key:value:valueColor:showCurrencyPrefix:)` 呼叫改為：

```swift
            kpiCard(key: "analysis_kpi_expense", prefix: expense.twdParts.symbol, body: expense.twdParts.digits, valueColor: Color.Design.textPrimary)
            kpiCard(key: "analysis_kpi_income", prefix: income.twdParts.symbol, body: income.twdParts.digits, valueColor: Color.Design.incomeGreen)
            kpiCard(key: "analysis_kpi_net", prefix: net.twdParts.symbol, body: net.twdParts.digits,
                    valueColor: net >= 0 ? Color.Design.accentOrange : Color.Design.expenseRed)
            kpiCard(key: "analysis_kpi_savings_rate", prefix: nil, body: savingsRate, valueColor: Color.Design.textPrimary)
```

`kpiCard` 簽名改為 `(key: String.LocalizationValue, prefix: String?, body: String, valueColor: Color)`，刪除 `let trimmed: ... = { ... }()` 閉包，本體內 `trimmed.prefix` → `prefix`、`trimmed.body` → `body`。

`DailyBarsCard.swift`：`average.twdFormatted.replacingOccurrences(of: "NT$", with: "")` → `average.twdDigits`；`totalBodyText` 本體改為 `total.twdDigits`（刪掉 hasPrefix 判斷與註解）。
`CategoryDonutCard.swift`：兩處 `x.twdFormatted.replacingOccurrences(of: "NT$", with: "")` → `x.twdDigits`。

- [ ] **Step 6: 跑測試確認通過**

Run: `DecimalCurrencyPartsTests`、`DecimalPerPeriodBreakdownTests`、`BudgetFormFeatureTests`；watch 測試（含 `ComplicationEntryTests`）→ SUCCEEDED。
Run: `grep -rn 'NumberFormatter()' Features/Sources/WatchFeatures Features/Sources/Domain` → 無輸出。
Run: `grep -rn 'replacingOccurrences(of: "NT$"' Features/Sources` → 無輸出。

- [ ] **Step 7: 完整 scheme + commit**

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor(common): twdDigits/twdParts replace ad-hoc NumberFormatters; move perPeriodBreakdown out of Domain [ci skip]"
```

---

### Task 9: 金額輸入解析統一（Budget / Recurring 表單）

**Files:**
- Modify: `Features/Sources/Features/BudgetManagement/BudgetFormFeature.swift:127`
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift:168`
- Test: `NeuLedgerTests/Tests/FeaturesTests/BudgetFormFeatureTests.swift`（加 1 測）
- Test: `NeuLedgerTests/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift`（加 1 測）

- [ ] **Step 1: 寫失敗測試**

`BudgetFormFeatureTests.swift` 在 `// MARK: - Validation` 區加：

```swift
    @Test("saveTapped accepts thousands-separated amount via parsedAmountDecimal")
    func testSaveTappedAcceptsGroupedAmount() async {
        let created = LockIsolated<Budget?>(nil)
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in [] }
            $0.planningClient.create = { created.setValue($0) }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.nameChanged("餐費")) { $0.name = "餐費" }
        await store.send(.amountChanged("1,000")) { $0.amountText = "1,000" }
        await store.send(.saveTapped)
        await store.finish()
        #expect(created.value?.amount == 1000)
    }
```

（`nameChanged` / `amountChanged` / `planningClient.create` 均為既有 action 與 closure；若 `BudgetFormFeature` 的 save 成功路徑還會呼叫其他 closure，依 `saveTapped` case 內的 `.run` 內容補齊覆寫。）

`RecurringTransactionFormFeatureTests.swift` 在 `// MARK: - Transfer support` 區前加：

```swift
    @Test("saveTapped accepts thousands-separated amount via parsedAmountDecimal")
    func testSaveTappedAcceptsGroupedAmount() async {
        var initial = RecurringTransactionFormFeature.State(mode: .add)
        initial.accountId = Self.sampleAccount.id
        let store = await TestStore(initialState: initial) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.createRecurring = { _ in }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.amountChanged("15,000")) { $0.amountText = "15,000" }
        await store.send(.saveTapped) {
            $0.amountError = nil   // 舊實作：Decimal(string: "15,000") == nil → 設 amountError
        }
    }
```

（`saveTapped` 後續 effect 需要的 closure 依該 case 的 `.run` 內容補齊；`exhaustivity = .off` 下只驗 `amountError == nil`。）

- [ ] **Step 2: 跑測試確認失敗**

Run: 兩個 suite → 新測試 FAIL（`amountError` 被設為錯誤訊息 / `created.value == nil`）。

- [ ] **Step 3: 實作**

`BudgetFormFeature.swift`：
```swift
                guard let amount = Decimal(string: state.amountText), amount > 0 else {
```
→
```swift
                guard let amount = state.amountText.parsedAmountDecimal, amount > 0 else {
```

`RecurringTransactionFormFeature.swift` 同樣替換。兩檔都已 `import Common`（若沒有，加上）。

- [ ] **Step 4: 跑測試確認通過 + 完整 scheme + commit**

Run: `grep -rn 'Decimal(string: state.amountText)' Features/Sources/Features` → 無輸出。完整 scheme → SUCCEEDED。

```bash
git add -A Features/Sources/Features NeuLedgerTests
git commit -m "fix(forms): budget and recurring amount fields parse grouped digits via parsedAmountDecimal [ci skip]"
```

---

### Task 10: `CarrierType` 顯示對照集中 + iOS 條碼改用 `Code128BarcodeView`

**Files:**
- Create: `Features/Sources/Domain/Entities/CarrierType+Display.swift`
- Create: `Features/Sources/Common/Extensions/CarrierType+UI.swift`
- Modify: `Features/Sources/Common/DesignSystem/Color+extension.swift`（`transferPurple` 之後加 1 token）
- Modify: `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift`（imports、`:139-141`、`:241-252`、刪 `:269-300`）
- Modify: `Features/Sources/Features/CarrierManagement/AddEditCarrierView.swift`（`:66-77`、`:112-131`、`:197`、`:241`、刪 `:275-304`）
- Modify: `Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift:85, 154-161`
- Modify: `Features/Sources/WatchFeatures/Carrier/WatchCarrierView.swift:65, 99-104`
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/CarrierTypeDisplayTests.swift`
- Test: `NeuLedgerTests/Tests/CommonTests/CommonTests.swift`（加 1 suite）

**Interfaces:**
- Produces：
  ```swift
  extension CarrierType { var localizedName: String; var barcodePlaceholder: String; var barcodeFormatHint: String }   // Domain
  extension CarrierType { var systemImageName: String; var tint: Color }                                              // Common
  Color.Design.carrierCertIndigo
  ```

- [ ] **Step 1: 寫失敗測試**

`CarrierTypeDisplayTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

@Suite("CarrierType+Display")
struct CarrierTypeDisplayTests {
    @Test("localizedName resolves keys, never echoes the key back")
    func localizedName() {
        for type in CarrierType.allCases {
            #expect(!type.localizedName.isEmpty)
            #expect(!type.localizedName.hasPrefix("carrier_type_"))
        }
        #expect(CarrierType.phoneBarcodeCarrier.localizedName != CarrierType.citizenDigitalCertificate.localizedName)
    }

    @Test("barcodePlaceholder mirrors the validation regex shape")
    func placeholder() {
        #expect(CarrierType.phoneBarcodeCarrier.barcodePlaceholder == "/XXXXXXX")
        #expect(CarrierType.citizenDigitalCertificate.barcodePlaceholder == "/PXXXXXXXXXXXXXXXX")
    }

    @Test("barcodeFormatHint is localized per type")
    func hint() {
        #expect(!CarrierType.phoneBarcodeCarrier.barcodeFormatHint.hasPrefix("carrier_form_"))
        #expect(CarrierType.phoneBarcodeCarrier.barcodeFormatHint != CarrierType.citizenDigitalCertificate.barcodeFormatHint)
    }
}
```

`CommonTests.swift` 末尾加：

```swift
@Suite("CarrierType+UI")
struct CarrierTypeUITests {
    @Test("systemImageName is stable per type")
    func icons() {
        #expect(CarrierType.phoneBarcodeCarrier.systemImageName == "iphone")
        #expect(CarrierType.citizenDigitalCertificate.systemImageName == "creditcard")
    }

    @Test("tint uses design tokens")
    func tints() {
        #expect(CarrierType.phoneBarcodeCarrier.tint == Color.Design.accentOrange)
        #expect(CarrierType.citizenDigitalCertificate.tint == Color.Design.carrierCertIndigo)
    }
}
```

`CommonTests.swift` 目前只有 `import Testing` / `import Foundation` / `@testable import Common`；在檔頭補上 `import SwiftUI` 與 `import Domain`（`Color` 與 `CarrierType` 需要）。

- [ ] **Step 2: 跑測試確認失敗**

Run: 兩個 suite → 編譯錯誤 `no member 'localizedName'` / `'systemImageName'`。

- [ ] **Step 3: 實作 — Domain / Common**

`CarrierType+Display.swift`：

```swift
import Foundation

/// CarrierType 的文字呈現，全 App（iOS / Watch / Widget）唯一定義。
public extension CarrierType {
    var localizedName: String {
        switch self {
        case .phoneBarcodeCarrier:       return String(localized: "carrier_type_phone_barcode", bundle: .main)
        case .citizenDigitalCertificate: return String(localized: "carrier_type_citizen_cert", bundle: .main)
        }
    }

    /// 表單 placeholder；形狀對應 `AddEditCarrierFeature.validate` 的 regex。
    var barcodePlaceholder: String {
        switch self {
        case .phoneBarcodeCarrier:       return "/XXXXXXX"
        case .citizenDigitalCertificate: return "/PXXXXXXXXXXXXXXXX"
        }
    }

    var barcodeFormatHint: String {
        switch self {
        case .phoneBarcodeCarrier:       return String(localized: "carrier_form_barcode_hint_phone", bundle: .main)
        case .citizenDigitalCertificate: return String(localized: "carrier_form_barcode_hint_cert", bundle: .main)
        }
    }
}
```

`CarrierType+UI.swift`（Common）：

```swift
import Domain
import SwiftUI

/// CarrierType 的圖示與色彩，iOS 與 Watch 共用。
public extension CarrierType {
    var systemImageName: String {
        switch self {
        case .phoneBarcodeCarrier:       return "iphone"
        case .citizenDigitalCertificate: return "creditcard"
        }
    }

    var tint: Color {
        switch self {
        case .phoneBarcodeCarrier:       return Color.Design.accentOrange
        case .citizenDigitalCertificate: return Color.Design.carrierCertIndigo
        }
    }
}
```

`Color+extension.swift` 在 `public static let transferPurple = ...` 下一行加：

```swift
        /// 自然人憑證載具的識別色；與 transferPurple 同色（原 View 內裸寫的 #5E5CE6）。
        public static let carrierCertIndigo = transferPurple
```

- [ ] **Step 4: 實作 — iOS views**

`CarrierManagementView.swift`：
- 刪 `import CoreImage`、`import CoreImage.CIFilterBuiltins`、`import UIKit`。
- `:139` `.fill(carrierColor(carrier.type))` → `.fill(carrier.type.tint)`；`:141` `Image(systemName: carrierIcon(carrier.type))` → `Image(systemName: carrier.type.systemImageName)`。
- 條碼區塊整段：

```swift
            if let barcodeImage = generateBarcode(from: carrier.barcode) {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 6)
```
換成
```swift
            if let modules = Code128.modules(for: carrier.barcode) {
                Code128BarcodeView(modules: modules, orientation: .horizontal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.Design.barcodeSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 6)
```
（區塊後面的 `}` / `else` 分支保持原樣。）
- 刪除 `// MARK: - Helpers` 底下的 `carrierIcon` / `carrierColor`，以及 `// MARK: - Barcode Generation (Code 128)` 底下的 `ciContext` 與 `generateBarcode`。

`AddEditCarrierView.swift`：
- `typeColor(x)` → `x.tint`（`:66`、`:68`、`:112`）；`typeIcon(x)` → `x.systemImageName`（`:69`、`:122`）；`typeBarcodeFormat(x)` → `x.barcodePlaceholder`（`:131`、`:197`）；`barcodeFormatHint(x)` → `x.barcodeFormatHint`（`:241`）；`x.defaultName` → `x.localizedName`（`:77`、`:127`）。
- 刪除 `// MARK: - Type Helpers` 底下四個 private func。

`AddEditCarrierFeature.swift`：`:85` `state.type.defaultName` → `state.type.localizedName`；刪除檔尾 `extension CarrierType { var defaultName ... }`。

`WatchCarrierView.swift`：`:65` `Image(systemName: typeIcon(for: carrier.type))` → `Image(systemName: carrier.type.systemImageName)`；刪除 `private func typeIcon(for:)`。

- [ ] **Step 5: 跑測試確認通過**

Run: `CarrierTypeDisplayTests`、`CarrierTypeUITests`、`CarrierManagementFeatureTests`；watch 測試；Widget build → 全部成功。
Run: `grep -rn 'Color(red:' Features/Sources` → 只允許 `Color+extension.swift` 內的定義（若有）；`grep -rn 'CIFilter' Features/Sources` → 無輸出。

- [ ] **Step 6: 完整 scheme + commit**

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor(carrier): CarrierType display/UI mappings live in Domain+Common; iOS barcode uses Code128BarcodeView [ci skip]"
```

---

### Task 11: `Category.localizedName` 補齊與 seed 守門測試

**Files:**
- Modify: `Features/Sources/Domain/Entities/Category+Localized.swift`（`seedLocalizationMap` 公開成 static func）
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormView.swift:168, 184`
- Modify: `Features/Sources/WatchFeatures/Record/ConfirmView.swift:30`
- Test: `NeuLedgerTests/Tests/CoreTests/Seeding/DefaultDataSeederTests.swift`（加 1 測）
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/CategoryLocalizedNameTests.swift`（加 1 測）

**Interfaces:**
- Produces：`Category.seedLocalizationKey(forSeedName:) -> String?`（public static）。

- [ ] **Step 1: 寫失敗測試**

`DefaultDataSeederTests.swift` 末尾加：

```swift
    @Test("Every seed category name has a Domain localization key (replaces the keep-in-sync comment)")
    func testSeedNamesHaveLocalizationKeys() {
        let seeds = SeedCategory.defaultExpenseCategories + SeedCategory.defaultIncomeCategories
        for seed in seeds {
            #expect(Category.seedLocalizationKey(forSeedName: seed.name) != nil,
                    "Seed '\(seed.name)' has no entry in Category.seedLocalizationMap")
        }
    }
```

`CategoryLocalizedNameTests.swift` 末尾加：

```swift
    @Test("seedLocalizationKey exposes the map for seed guards")
    func testSeedLocalizationKey() {
        #expect(Category.seedLocalizationKey(forSeedName: "Food") == "category_seed_food")
        #expect(Category.seedLocalizationKey(forSeedName: "Nope") == nil)
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: 兩個 suite → 編譯錯誤 `no member 'seedLocalizationKey'`。

- [ ] **Step 3: 實作**

`Category+Localized.swift`：在 `localizedName` 之後加

```swift
    /// Seed 英文名 → i18n key。`DefaultDataSeederTests` 用它守門，確保每個 seed 都有 key。
    static func seedLocalizationKey(forSeedName name: String) -> String? {
        seedLocalizationMap[name]
    }
```

並把 doc comment 中「Keep in sync if seeds change.」改為「`DefaultDataSeederTests.testSeedNamesHaveLocalizationKeys` 會在 seed 缺 key 時失敗。」

`RecurringTransactionFormView.swift`：`Label(cat.name, systemImage: cat.icon)` → `Label(cat.localizedName, systemImage: cat.icon)`；`Text(cat.name)` → `Text(cat.localizedName)`（帳戶的 `acc.name` 不動）。
`ConfirmView.swift`：`Text(category.name)` → `Text(category.localizedName)`。

- [ ] **Step 4: 跑測試確認通過 + 完整 scheme + watch 測試 + commit**

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "fix(i18n): route remaining category names through localizedName; guard seed keys with a test [ci skip]"
```

---

### Task 12: Recurring 摘要與到期天數搬出 View

**Files:**
- Create: `Features/Sources/Domain/Entities/RecurringTransaction+MonthlyEquivalent.swift`
- Create: `Features/Sources/Common/Extensions/Date+Relative.swift`
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift`（State 加 computed）
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementView.swift:210-220, 445-465`
- Modify: `Features/Sources/Features/Dashboard/Sections/HeroBalanceCard.swift:85-92`
- Test: `NeuLedgerTests/Tests/DomainTests/Entities/RecurringTransactionMonthlyEquivalentTests.swift`
- Test: `NeuLedgerTests/Tests/CommonTests/CommonTests.swift`（加 1 suite）
- Test: `NeuLedgerTests/Tests/FeaturesTests/RecurringTransactionManagementFeatureTests.swift`（加 1 測）

**Interfaces:**
- Produces：
  ```swift
  extension RecurringTransaction { var monthlyEquivalentAmount: Decimal }
  extension Date { func days(until other: Date, calendar: Calendar = .current) -> Int }
  RecurringTransactionManagementFeature.State { var monthlyIncome / monthlyExpense / monthlyNet: Decimal; var activeCount: Int }
  ```

- [ ] **Step 1: 寫失敗測試**

`RecurringTransactionMonthlyEquivalentTests.swift`：

```swift
import Foundation
import Testing
@testable import Domain

@Suite("RecurringTransaction.monthlyEquivalentAmount")
struct RecurringTransactionMonthlyEquivalentTests {
    private static func rt(_ amount: Decimal, _ frequency: BudgetPeriod) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(), amount: amount, note: nil, categoryId: nil,
            accountId: "acc", toAccountId: nil, type: .expense, tags: [],
            frequency: frequency, nextDueDate: Date(), isActive: true, createdAt: Date()
        )
    }

    @Test("monthly is identity")
    func monthly() { #expect(Self.rt(1500, .monthly).monthlyEquivalentAmount == 1500) }

    @Test("weekly × 52 ÷ 12")
    func weekly() { #expect(Self.rt(120, .weekly).monthlyEquivalentAmount == 520) }

    @Test("yearly ÷ 12")
    func yearly() { #expect(Self.rt(12_000, .yearly).monthlyEquivalentAmount == 1000) }
}
```

`CommonTests.swift` 末尾加：

```swift
@Suite("Date+Relative")
struct DateRelativeTests {
    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }
    private static func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }

    @Test("days(until:) counts calendar days, ignoring time of day")
    func daysUntil() {
        #expect(Self.d(2026, 1, 15, 23).days(until: Self.d(2026, 1, 16, 1), calendar: Self.cal) == 1)
        #expect(Self.d(2026, 1, 15, 1).days(until: Self.d(2026, 1, 15, 23), calendar: Self.cal) == 0)
        #expect(Self.d(2026, 1, 15, 12).days(until: Self.d(2026, 1, 10, 12), calendar: Self.cal) == -5)
    }
}
```

`RecurringTransactionManagementFeatureTests.swift` 末尾加：

```swift
    @Test("State summary folds active items into monthly equivalents; inactive items excluded")
    func testMonthlySummary() {
        var state = RecurringTransactionManagementFeature.State(items: [
            Self.sample(frequency: .monthly),                       // 15000 expense
            Self.sample(frequency: .weekly, isActive: false),       // excluded
        ])
        var salary = Self.sample(frequency: .yearly)
        salary.type = .income
        salary.amount = 120_000                                     // 10000 / month
        state.items.append(salary)

        #expect(state.monthlyExpense == 15_000)
        #expect(state.monthlyIncome == 10_000)
        #expect(state.monthlyNet == -5_000)
        #expect(state.activeCount == 2)
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: 三個 suite → 編譯錯誤。

- [ ] **Step 3: 實作**

`RecurringTransaction+MonthlyEquivalent.swift`（Domain）：

```swift
import Foundation

public extension RecurringTransaction {
    /// 換算成「每月等值」金額：weekly × 52 ÷ 12、monthly × 1、yearly ÷ 12。摘要卡用。
    var monthlyEquivalentAmount: Decimal {
        switch frequency {
        case .weekly:  return amount * 52 / 12
        case .monthly: return amount
        case .yearly:  return amount / 12
        }
    }
}
```

`Date+Relative.swift`（Common）：

```swift
import Foundation

public extension Date {
    /// 從 self 到 other 的日曆天數（只看日期、不看時刻；過去為負）。
    func days(until other: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: self)
        let to = calendar.startOfDay(for: other)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
```

`RecurringTransactionManagementFeature.State` 在 `init` 之前加：

```swift
        // MARK: 摘要（computed；View 只讀）
        public var activeItems: [RecurringTransaction] { items.filter(\.isActive) }
        public var activeCount: Int { activeItems.count }
        public var monthlyIncome: Decimal {
            activeItems.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.monthlyEquivalentAmount }
        }
        public var monthlyExpense: Decimal {
            activeItems.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.monthlyEquivalentAmount }
        }
        public var monthlyNet: Decimal { monthlyIncome - monthlyExpense }
```

`RecurringTransactionManagementView.summaryCard` 開頭的七行本地計算：

```swift
        let activeMonthly = store.items.filter { $0.isActive && $0.frequency == .monthly }
        let monthlyIn = activeMonthly
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let monthlyOut = activeMonthly
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let net = monthlyIn - monthlyOut
        let activeCount = store.items.filter { $0.isActive }.count
        let totalCount = store.items.count
```
換成
```swift
        let monthlyIn = store.monthlyIncome
        let monthlyOut = store.monthlyExpense
        let net = store.monthlyNet
        let activeCount = store.activeCount
        let totalCount = store.items.count
```

`dueDateText` / `dueDateColor` 換成：

```swift
    private func dueDateText(_ date: Date) -> String {
        if Date().days(until: date) == 0 {
            return String(localized: "recurring_due_today")
        }
        let formatted = date.formatted(.dateTime.month().day())
        return String(format: String(localized: "recurring_due_format"), formatted)
    }

    private func dueDateColor(_ date: Date) -> Color {
        Date().days(until: date) <= 3 ? Color.Design.brandAccent : Color.Design.textSecondary
    }
```

`HeroBalanceCard.swift` 的 `daysUntilSparklineReady` 本體：

```swift
    guard let earliest else { return 7 }
    return max(0, 7 - earliest.days(until: now))
```

- [ ] **Step 4: 跑測試確認通過 + 完整 scheme + commit**

Run: 三個 suite + `DashboardFeatureTests` → SUCCEEDED；完整 scheme → SUCCEEDED。

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor(recurring): monthly-equivalent summary lives in State/Domain; Date.days(until:) in Common [ci skip]"
```

---

### Task 13: 匯出 CSV / JSON 收回 `LedgerClient`

**Files:**
- Modify: `Features/Sources/Domain/Clients/LedgerClient.swift:66-68`
- Modify: `Features/Sources/Application/Ledger/LedgerClient+LiveExport.swift`（加 `makeExportJSON`）
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift:310`
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift:253-318`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientLiveTests.swift`（加 1 測）
- Test: `NeuLedgerTests/Tests/FeaturesTests/SettingsFeatureTests.swift:178-262`（改 2 測）

**Interfaces:**
- Produces：`LedgerClient.exportJSON: @Sendable () async throws -> URL`。

- [ ] **Step 1: 寫失敗測試（Live）**

`LedgerClientLiveTests.swift` 在 `exportCSV escapes fields` 測試之後加：

```swift
    @Test("exportJSON writes an ISO8601 pretty-printed [Transaction] into a unique temp subdirectory")
    func testExportJSON() async throws {
        let t = Transaction(amount: 150, date: Date(timeIntervalSince1970: 1_700_000_000), note: "午餐",
                            accountId: UUID().uuidString, type: .expense)
        try await sut.record(t)

        let url = try await sut.exportJSON()
        #expect(url.lastPathComponent == "NeuLedger_export.json")
        #expect(url.deletingLastPathComponent().lastPathComponent != FileManager.default.temporaryDirectory.lastPathComponent)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([Transaction].self, from: Data(contentsOf: url))
        #expect(decoded.map(\.id) == [t.id])
        #expect(decoded.first?.note == "午餐")
    }
```

- [ ] **Step 2: 改 Settings 測試**

`SettingsFeatureTests.testExportCSVSuccess` 整個換成：

```swift
    @Test("exportCSVTapped delegates to ledgerClient.exportCSV and stores the returned URL")
    func testExportCSVSuccess() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("NeuLedger_export.csv")
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.ledgerClient.exportCSV = { url }
        }
        await store.send(.exportCSVTapped) { $0.exportingFormat = .csv }
        await store.receive(\.exportCompleted) {
            $0.exportingFormat = nil
            $0.exportedFileURL = url
        }
    }
```

`testExportJSONSuccess` 同樣換成呼叫 `$0.ledgerClient.exportJSON = { url }`（檔名 `NeuLedger_export.json`），並加一條失敗測試：

```swift
    @Test("exportJSONTapped surfaces client failure via exportFailed")
    func testExportJSONFailure() async {
        struct ExportError: Error {}
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.ledgerClient.exportJSON = { throw ExportError() }
        }
        await store.send(.exportJSONTapped) { $0.exportingFormat = .json }
        await store.receive(\.exportFailed) {
            $0.exportingFormat = nil
            $0.exportError = ExportError().localizedDescription
        }
    }
```

（`exportError` 是既有 State 欄位；若 `exportFailed` case 的實際賦值不同，以 reducer 為準調整斷言。）

- [ ] **Step 3: 跑測試確認失敗**

Run: `LedgerClientLiveTests`、`SettingsFeatureTests` → 編譯錯誤 `no member 'exportJSON'`。

- [ ] **Step 4: 實作**

`LedgerClient.swift` 在 `exportCSV` 下加：

```swift
    public var exportJSON: @Sendable () async throws -> URL
```

`LedgerClient+LiveExport.swift` 在 `makeExportCSV` 之後加：

```swift
    static func makeExportJSON(
        _ transactionStore: TransactionStore
    ) -> @Sendable () async throws -> URL {
        {
            let transactions = try await transactionStore.fetchAll()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(transactions)
            // 與 exportCSV 同一規則：唯一子目錄，避免固定 temp 路徑互撞（architecture.md §9）。
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("NeuLedger_export.json")
            try data.write(to: url, options: .atomic)
            return url
        }
    }
```

`LedgerClient+Live.swift:310` 之後加一行：

```swift
            exportCSV: Self.makeExportCSV(transactionStore, categoryStore, accountStore),
            exportJSON: Self.makeExportJSON(transactionStore)
```

`SettingsFeature.swift` 兩個 case 換成：

```swift
            case .exportCSVTapped:
                state.exportingFormat = .csv
                state.exportError = nil
                return .run { [ledger] send in
                    do {
                        await send(.exportCompleted(try await ledger.exportCSV()))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }

            case .exportJSONTapped:
                state.exportingFormat = .json
                state.exportError = nil
                return .run { [ledger] send in
                    do {
                        await send(.exportCompleted(try await ledger.exportJSON()))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }
```

若 SettingsFeature 因此不再用到 `csvField` 之類的 private helper，一併刪除。

- [ ] **Step 5: 跑測試確認通過 + 完整 scheme + commit**

Run: `grep -rn 'NeuLedger_export' Features/Sources/Features` → 無輸出。完整 scheme → SUCCEEDED。

```bash
git add -A Features/Sources NeuLedgerTests
git commit -m "refactor(export): SettingsFeature delegates CSV/JSON export to LedgerClient (unique temp dirs) [ci skip]"
```

---

### Task 14: App Group 常數與 `CarrierWidgetEntry` 收進 Domain；Widget target 連結 Domain

**Files:**
- Create: `Features/Sources/Domain/AppGroup.swift`
- Modify: `Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift`（整檔）
- Modify: `Features/Sources/Core/Persistence/PersistenceBootstrap.swift:40`
- Modify: `Features/Sources/WatchFeatures/Persistence/WatchCacheStore.swift:14`
- Modify: `Shared/WidgetAppGroup.swift`（整檔）
- Modify: `NeuLedger.xcodeproj/project.pbxproj`（Widget target 加 Domain 依賴，3 處）
- Test: `NeuLedgerTests/Tests/DomainTests/AppGroupTests.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/WidgetSyncAdapterLiveTests.swift`

**Interfaces:**
- Produces：
  ```swift
  public enum AppGroup { static let suiteName; static let carrierWidgetKind; enum CarrierKey { barcode, type, name, updatedAt, list } }
  public struct CarrierWidgetEntry: Codable, Hashable, Sendable { id, barcode, typeRawValue, name, updatedAt; init(carrier:updatedAt:); var type: CarrierType? }
  WidgetSyncAdapter.live(defaults:reload:) -> WidgetSyncAdapter
  ```

- [ ] **Step 1: 寫失敗測試**

`AppGroupTests.swift`（Domain）：

```swift
import Foundation
import Testing
@testable import Domain

/// 釘住 App Group 線上格式：suite 名稱、key 名稱、DTO 欄位。改任何一個都會讓舊版 Widget 讀不到。
@Suite("AppGroup constants")
struct AppGroupTests {
    @Test("suite name and widget kind are stable")
    func constants() {
        #expect(AppGroup.suiteName == "group.com.drake.NeuLedger")
        #expect(AppGroup.carrierWidgetKind == "CarrierWidget")
        #expect(AppGroup.CarrierKey.barcode == "carrierBarcode")
        #expect(AppGroup.CarrierKey.type == "carrierType")
        #expect(AppGroup.CarrierKey.name == "carrierName")
        #expect(AppGroup.CarrierKey.updatedAt == "carrierUpdatedAt")
        #expect(AppGroup.CarrierKey.list == "carrierList")
    }

    @Test("CarrierWidgetEntry JSON keys match the legacy wire format")
    func wireFormat() throws {
        let carrier = Carrier(name: "我的載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let entry = CarrierWidgetEntry(carrier: carrier, updatedAt: Date(timeIntervalSince1970: 0))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as! [String: Any]
        #expect(Set(json.keys) == ["id", "barcode", "typeRawValue", "name", "updatedAt"])
        #expect(json["id"] as? String == carrier.id.uuidString)
        #expect(json["typeRawValue"] as? String == "phoneBarcodeCarrier")
        #expect(entry.type == .phoneBarcodeCarrier)
    }
}
```

`WidgetSyncAdapterLiveTests.swift`（Core）：

```swift
import Foundation
import Testing
import Domain
@testable import Core

@Suite("WidgetSyncAdapter Live")
struct WidgetSyncAdapterLiveTests {
    private func makeSUT() -> (WidgetSyncAdapter, UserDefaults, LockIsolated<Int>) {
        let suite = "WidgetSyncAdapterLiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let reloads = LockIsolated(0)
        let sut = WidgetSyncAdapter.live(
            defaults: { defaults },
            reload: { reloads.withValue { $0 += 1 } }
        )
        return (sut, defaults, reloads)
    }

    @Test("syncAllCarriers writes [CarrierWidgetEntry] under CarrierKey.list and reloads the widget")
    func syncAll() async throws {
        let (sut, defaults, reloads) = makeSUT()
        let carrier = Carrier(name: "A", type: .citizenDigitalCertificate, barcode: "/P0123456789ABCDEF")
        await sut.syncAllCarriers([carrier])

        let data = try #require(defaults.data(forKey: AppGroup.CarrierKey.list))
        let entries = try JSONDecoder().decode([CarrierWidgetEntry].self, from: data)
        #expect(entries.map(\.id) == [carrier.id.uuidString])
        #expect(entries.first?.typeRawValue == "citizenDigitalCertificate")
        #expect(reloads.value == 1)
    }

    @Test("syncCarrier / clearCarrier round-trip the legacy single-carrier keys")
    func legacyKeys() async {
        let (sut, defaults, _) = makeSUT()
        await sut.syncCarrier("/ABC1234", "phoneBarcodeCarrier", "Legacy")
        #expect(defaults.string(forKey: AppGroup.CarrierKey.barcode) == "/ABC1234")
        #expect(defaults.string(forKey: AppGroup.CarrierKey.type) == "phoneBarcodeCarrier")
        #expect(defaults.string(forKey: AppGroup.CarrierKey.name) == "Legacy")
        #expect(defaults.object(forKey: AppGroup.CarrierKey.updatedAt) is Date)
        await sut.clearCarrier()
        #expect(defaults.string(forKey: AppGroup.CarrierKey.barcode) == nil)
    }
}
```

（`LockIsolated` 來自 `ConcurrencyExtras`；CoreTests 既有檔案若沒 import，加 `import ConcurrencyExtras`。）

- [ ] **Step 2: 跑測試確認失敗**

Run: 兩個 suite → 編譯錯誤 `cannot find 'AppGroup'`。

- [ ] **Step 3: 實作 — Domain**

`Features/Sources/Domain/AppGroup.swift`：

```swift
import Foundation

/// App Group 線上格式的唯一定義：iPhone app、Core adapter、Watch cache、Widget extension 都從這裡讀。
/// 改任何常數都是資料格式變更，需要遷移。
public enum AppGroup {
    public static let suiteName = "group.com.drake.NeuLedger"

    /// `WidgetCenter.reloadTimelines(ofKind:)` 用；與 `NeuLedgerWidget/CarrierWidget.swift` 的 `kind` 相同。
    public static let carrierWidgetKind = "CarrierWidget"

    /// 載具 Widget 的 UserDefaults key。
    public enum CarrierKey {
        public static let barcode = "carrierBarcode"        // legacy 單一載具
        public static let type = "carrierType"              // legacy 單一載具
        public static let name = "carrierName"              // legacy 單一載具
        public static let updatedAt = "carrierUpdatedAt"    // legacy 單一載具
        public static let list = "carrierList"              // JSON [CarrierWidgetEntry]
    }
}

/// Widget 端讀取的載具 DTO。JSON 欄位名是既有線上格式，**不可改名**。
public struct CarrierWidgetEntry: Codable, Hashable, Sendable {
    public let id: String            // UUID string（legacy 遷移項為 "legacy"）
    public let barcode: String
    public let typeRawValue: String  // CarrierType.rawValue
    public let name: String
    public let updatedAt: Date?

    public init(id: String, barcode: String, typeRawValue: String, name: String, updatedAt: Date?) {
        self.id = id
        self.barcode = barcode
        self.typeRawValue = typeRawValue
        self.name = name
        self.updatedAt = updatedAt
    }

    public init(carrier: Carrier, updatedAt: Date = Date()) {
        self.init(
            id: carrier.id.uuidString,
            barcode: carrier.barcode,
            typeRawValue: carrier.type.rawValue,
            name: carrier.name,
            updatedAt: updatedAt
        )
    }

    public var type: CarrierType? { CarrierType(rawValue: typeRawValue) }
}
```

- [ ] **Step 4: 實作 — Core / WatchFeatures**

`WidgetSyncAdapter+Live.swift` 整檔換成：

```swift
import Foundation
import WidgetKit
import Dependencies
import Domain

/// App Group 常數與 DTO 的唯一來源是 `Domain/AppGroup.swift`；此處只做寫入。
extension WidgetSyncAdapter: DependencyKey {

    public static let liveValue = live(
        defaults: { UserDefaults(suiteName: AppGroup.suiteName) },
        reload: { WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.carrierWidgetKind) }
    )

    /// 可注入 defaults / reload 的工廠，供測試用。
    static func live(
        defaults: @escaping @Sendable () -> UserDefaults?,
        reload: @escaping @Sendable () -> Void
    ) -> WidgetSyncAdapter {
        WidgetSyncAdapter(
            syncCarrier: { barcode, type, name in
                guard let defaults = defaults() else { return }
                defaults.set(barcode, forKey: AppGroup.CarrierKey.barcode)
                defaults.set(type,    forKey: AppGroup.CarrierKey.type)
                defaults.set(name,    forKey: AppGroup.CarrierKey.name)
                defaults.set(Date(),  forKey: AppGroup.CarrierKey.updatedAt)
                reload()
            },
            clearCarrier: {
                guard let defaults = defaults() else { return }
                for key in [AppGroup.CarrierKey.barcode, AppGroup.CarrierKey.type,
                            AppGroup.CarrierKey.name, AppGroup.CarrierKey.updatedAt] {
                    defaults.removeObject(forKey: key)
                }
                reload()
            },
            syncAllCarriers: { carriers in
                guard let defaults = defaults() else { return }
                let entries = carriers.map { CarrierWidgetEntry(carrier: $0) }
                guard let data = try? JSONEncoder().encode(entries) else { return }
                defaults.set(data, forKey: AppGroup.CarrierKey.list)
                reload()
            }
        )
    }
}
```

`PersistenceBootstrap.swift:40`：`private static let appGroupID = "group.com.drake.NeuLedger"` → `private static let appGroupID = AppGroup.suiteName`。
`WatchCacheStore.swift:14`：`public static let appGroupSuite = "group.com.drake.NeuLedger"` → `public static let appGroupSuite = AppGroup.suiteName`。

- [ ] **Step 5: 實作 — Widget target 連結 Domain（pbxproj）**

用文字編輯 `NeuLedger.xcodeproj/project.pbxproj`，三處：

(a) `/* Begin PBXBuildFile section */` 內，在 `BA24DB8F2F418E0E00CBA03D /* Core in Frameworks */` 那行之後加：
```
		A2C0DE0000000000000000A1 /* Domain in Frameworks */ = {isa = PBXBuildFile; productRef = A2C0DE0000000000000000A2 /* Domain */; };
```

(b) Widget 的 Frameworks build phase `A226632F2F8376A300F95069 /* Frameworks */` 的 `files = (` 內（`A22663362F8376A300F95069 /* SwiftUI.framework in Frameworks */,` 之前）加：
```
				A2C0DE0000000000000000A1 /* Domain in Frameworks */,
```

(c) Widget target `A22663312F8376A300F95069 /* NeuLedgerWidget */`（pbxproj 第 372 行起、`isa = PBXNativeTarget;` 且 `name = NeuLedgerWidget;` 的那個區塊；**不是**第 159 行同名的 `PBXFileSystemSynchronizedRootGroup`）的
```
			packageProductDependencies = (
			);
```
改為
```
			packageProductDependencies = (
				A2C0DE0000000000000000A2 /* Domain */,
			);
```

(d) `/* Begin XCSwiftPackageProductDependency section */` 內，在 `BA24DB8E2F418E0E00CBA03D /* Core */` 區塊之前加：
```
		A2C0DE0000000000000000A2 /* Domain */ = {
			isa = XCSwiftPackageProductDependency;
			package = BA24DB8D2F418E0E00CBA03D /* XCLocalSwiftPackageReference "Features" */;
			productName = Domain;
		};
```

驗證：`xcodebuild -list -project NeuLedger.xcodeproj -quiet` 能列出 schemes（pbxproj 未損壞）。若文字編輯出錯，退路是在 Xcode 開專案 → NeuLedgerWidget target → General → Frameworks and Libraries → `+` → `Domain`。

- [ ] **Step 6: 實作 — `Shared/WidgetAppGroup.swift` 整檔**

```swift
// Shared/WidgetAppGroup.swift
import Domain
import Foundation

/// App Group 讀取端（Widget Extension 與主 app 共同編譯）。
/// 常數與 DTO 的唯一來源是 `Domain/AppGroup.swift`；主 app 是唯一寫入者（`WidgetSyncAdapter`）。
typealias CarrierEntry = CarrierWidgetEntry

extension CarrierWidgetEntry {
    /// Widget 顯示用的載具類型名稱。
    var typeDisplayName: String {
        type?.localizedName ?? typeRawValue
    }
}

enum WidgetAppGroup {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.suiteName)
    }

    // MARK: - Legacy single-carrier read (kept for compat)

    static func readCarrier() -> CarrierEntry? {
        guard let defaults,
              let barcode = defaults.string(forKey: AppGroup.CarrierKey.barcode),
              !barcode.isEmpty,
              let typeRaw = defaults.string(forKey: AppGroup.CarrierKey.type),
              !typeRaw.isEmpty else {
            return nil
        }
        let name = defaults.string(forKey: AppGroup.CarrierKey.name) ?? ""
        let updatedAt = defaults.object(forKey: AppGroup.CarrierKey.updatedAt) as? Date
        return CarrierEntry(id: "legacy", barcode: barcode, typeRawValue: typeRaw, name: name, updatedAt: updatedAt)
    }

    // MARK: - Full carrier list read

    static func readAllCarriers() -> [CarrierEntry] {
        guard let defaults,
              let data = defaults.data(forKey: AppGroup.CarrierKey.list) else {
            return []
        }
        return (try? JSONDecoder().decode([CarrierEntry].self, from: data)) ?? []
    }
}
```

（原本的 `writeCarrier` / `clearCarrier` / `writeAllCarriers` 是主 app 端的寫入，主 app 已由 `WidgetSyncAdapter` 負責，刪除；先 `grep -rn 'WidgetAppGroup\.write\|WidgetAppGroup\.clear' NeuLedger NeuLedgerWidget Shared` 確認沒有呼叫端。）

- [ ] **Step 7: 跑測試 / 編譯確認通過**

Run: `AppGroupTests`、`WidgetSyncAdapterLiveTests`、`CarrierClientLiveTests` → SUCCEEDED。
Run: Widget build → 成功；watch 測試 → SUCCEEDED；iOS app build（`xcodebuild build -scheme NeuLedger ...`）→ 成功（Shared/ 也在 app target 內編譯）。
Run: `grep -rn '"group.com.drake.NeuLedger"' Features/Sources Shared NeuLedgerWidget` → 只有 `Features/Sources/Domain/AppGroup.swift` 一行。

- [ ] **Step 8: 完整 scheme + commit + 開 PR C**

Run: 完整 scheme → SUCCEEDED。

```bash
git add -A Features/Sources Shared NeuLedgerTests NeuLedger.xcodeproj/project.pbxproj
git commit -m "refactor(appgroup): App Group constants and CarrierWidgetEntry live in Domain; Widget links Domain [ci skip]"
```

跑四條 ast-grep audit，並跑 spec §5 的五條驗收 grep 全部符合後，開 PR：`refactor: consolidate presentation formatting, carrier display, export, and App Group constants`，body 列出 D5–D10 的行為變更（Watch 載具 icon 統一、Recurring 摘要納入 weekly/yearly 等值、Analysis 空狀態判定）。

---

## Self-review

**Spec coverage：**
- A1 → Task 1, 2, 7；A2 → Task 5；A3 → Task 3, 4；A4 → Task 6, 7；A5 → Task 5；A6 → Task 1；A7 → Task 7。
- B1 → Task 8；B2 → Task 9；B3 → Task 10；B4 → Task 10（Widget 例外已在 spec D6 註明）；B5 → Task 6, 11；B6 → Task 11；B7 → Task 12；B8 → Task 8。
- C1、C2 → Task 14；C3 → Task 13。

**型別一致性：** `BudgetPeriod.dateInterval(containing:calendar:)` / `closedRange(containing:calendar:)` 在 Task 2、5、6、7 的用法一致；`Transaction.involves(account:)` 在 Task 3、4、6 一致；`InsightsClient.financialSummary/dailyBars/categoryProportions` 的 `(range, accountId)` 順序在 Task 6 介面、Live wiring、Task 7 reducer 與測試一致；`CarrierWidgetEntry(carrier:updatedAt:)` 在 Task 14 Core 與 Domain 測試一致。

**已知的實作者裁量點（不是 placeholder）：**
- Task 9 的兩條表單測試要依各 reducer `saveTapped` 成功路徑實際碰到的 closure 補覆寫（檔案已標明位置）。
- Task 13 的 `exportFailed` 斷言以 reducer 實際賦值為準。
- Task 14 pbxproj 若文字編輯失敗，改用 Xcode UI 加依賴，其餘步驟不變。
