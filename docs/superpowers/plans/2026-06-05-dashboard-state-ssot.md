# Dashboard State SSOT（單一資料源重構 + 四個 Bug 修復）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 DashboardFeature 的 state 重塑為「查詢參數 + 查詢結果 + computed 衍生」的單一資料源結構，並讓交易列表跟著帳戶 chip 的選擇重新查詢（含轉入轉帳），一併修掉四個 bug。

**Architecture:** Dashboard 每個 section = `f(selectedAccountID)`。chip 切換只改 `selectedAccountID` 並重發「依賴選擇的查詢」（交易、sparkline）；本地推導得出的值（篩選餘額、排序帳戶、總額）一律 computed，禁止 stored 影子。本次只動 Features 層 —— StatsRow / InsightCarousel 連動需要 Domain 介面變更，留 `TODO` seam 另開單。

**Tech Stack:** TCA 1.23.1（`@Reducer` / `@ObservableState` / TestStore）、Swift Testing（`@Suite` / `@Test`）、xcodebuild（**不可用 `swift test`**）。

---

## 背景：修掉的四個 Bug

| # | Bug | 根因 |
|---|-----|------|
| 1 | 點帳戶 chip 後列表縮成 ≤3 筆、取消選擇剩 3 筆、資料更新又跳回 6 筆 | `accountChipSelected` 用被 `prefix(3)` 截斷的 `recentTransactions` 重算 `filteredRecent`，與 `transactionsUpdated` 的完整來源不一致 |
| 2 | 交易列表第 4–6 列點「開啟詳情」沒反應 | `transactionTapped` 查找只有 3 筆的 `recentTransactions`，view 卻顯示 `filteredRecent.prefix(6)` |
| 3 | AI insight 快取失效（每次更新都重打） | 比較端用 `transactions.count`（≤20），寫回端存 `recentTransactions.count`（≤3），永遠不相等 |
| 4 | 活躍使用者（3 天記 20 筆）看不到 sparkline | `earliestTransactionDate` 取自「最近 20 筆」的最小日期，不是帳本真正最早日期，暖身判斷誤判為新用戶 |

另含三項整理：`hasAccounts` / `hasTransactions` 殭屍欄位刪除（無 view 消費）、`topAccounts` 更名 `accounts` + computed `orderedAccounts`、手刻 per-account balance task group 換成既有的 `ledger.balances()`、三段重複的 mutation-reload effect 收斂成 helper。

## 已確認的產品決策

1. **Model B**：chip 切換＝重發 scope 查詢。選帳戶 A 顯示「A 自己的近期交易」，不是全域 20 筆的切片。
2. **轉帳雙向**：選中帳戶的列表包含轉入（`toAccountId == id`），與 `ledger.balance` 的雙向語意對齊（`LedgerClient+Live.swift:254-256`）。在 Features 層 effect 內本地過濾，**不改 `listAll` 的全域語意**。
3. **本次只動 Features 層**。StatsRow / InsightCarousel 連動留 `TODO(stats-follow-up)` / `TODO(insights-follow-up)` 註解，另開單（見文末 Follow-ups）。
4. **AI insight 跟著 scope 走**（輸入從被截斷的 3 筆變成 scope 近期 20 筆）；count 比較與寫回統一同一來源。已知限制：等量編輯（改金額不改筆數）不觸發重打 —— 沿用舊行為，併入 insights follow-up。

## Module Boundary 標注

- 所有修改都在 **Features SPM target**（`Features/Sources/Features/`）與 **NeuLedgerTests xcodeproj target**。
- `Transaction` / `Account` / `TransactionFilter` / `EnrichedTransaction` 來自 `Domain`（Features 已 import）。
- **禁止** import SwiftData、禁止注入 Adapter/Store —— 只透過 `\.ledgerClient` / `\.insightsClient`。
- **不可修改** Domain / Application / Core / Common 任何檔案。若發現清單外檔案編譯錯誤，回報 `BLOCKED`。

## File Structure

| 動作 | 檔案 | 責任 |
|---|---|---|
| Modify | `Features/Sources/Features/Dashboard/DashboardFeature.swift` | State 重塑、Action 簽名、reducer、4 個 effect helpers |
| Modify | `Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift` | `filteredRecent` → `recentTransactions` |
| Modify | `Features/Sources/Features/Dashboard/Sections/AccountChipsStrip.swift` | `topAccounts` → `orderedAccounts` |
| Modify | `Features/Sources/Features/Dashboard/Sections/HeroBalanceCard.swift` | Preview helper 改設 `accountBalances`（`filteredBalance` 已是 computed 不可賦值） |
| Create | `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureScopeTests.swift` | 四個 bug 的回歸測試 |
| Modify | `NeuLedgerTests/Tests/FeaturesTests/DashboardFeatureTests.swift` | 對齊新 State/Action 形狀 |
| Modify | `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureChipTests.swift` | 重寫為 scope 重查行為 |
| Modify | `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureSectionPhaseTests.swift` | 微調 stubs |

**注意：** 本重構是「編譯耦合」變更 —— State 欄位刪除後，source 與三個既有測試檔必須同時對齊才能編譯。因此 red-green 循環以「新測試檔編譯失敗」為紅燈，Task 2–4 完成後一次轉綠。中途 **不可** 跑測試期待部分通過。

---

### Task 0: 建立分支

**現況：** 目前在 `PR/client-consolidation`（六領域 Client 重構，developer 尚未合併）。本工作依賴該重構，**必須堆疊在其上**，不可從 developer 開分支。

- [ ] **Step 0.1: 確認工作區乾淨並開分支**

```bash
git -C /Users/drakehuang/SideProject/iOSProject/NeuLedger status --short
# 預期：只有 xcuserdata 的 plist（不需處理）
git -C /Users/drakehuang/SideProject/iOSProject/NeuLedger checkout -b fix/dashboard-state-ssot
```

預期：`Switched to a new branch 'fix/dashboard-state-ssot'`

---

### Task 1: 回歸測試先行（紅燈 = 編譯失敗）

**Files:**
- Create: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureScopeTests.swift`

- [ ] **Step 1.1: 建立測試檔（完整內容如下）**

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

/// Regression tests for the Dashboard state SSOT refactor.
///
/// Covers the four bugs fixed by the refactor:
/// 1. Chip selection re-queries scoped transactions (was: local slice of a
///    truncated array).
/// 2. `transactionTapped` finds rows beyond the old top-3 cap.
/// 3. AI-insight count cache compares and stores the same number.
/// 4. `earliestTransactionDate` is the scope's true earliest, not
///    min(recent 20).
@Suite("DashboardFeature Scope Query")
struct DashboardFeatureScopeTests {
    private static let accA = Account(name: "A", type: .cash, icon: "", color: "#000000")
    private static let accB = Account(name: "B", type: .bank, icon: "", color: "#000000")

    // MARK: - Bug 1 + 轉帳雙向

    @Test("Selecting an account re-queries scoped transactions, including incoming transfers")
    func testChipSelectReloadsScopedTransactions() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let txA = Transaction(
            amount: 100, date: base.addingTimeInterval(-100), note: "a",
            accountId: Self.accA.id, type: .expense
        )
        let txB = Transaction(
            amount: 200, date: base.addingTimeInterval(-200), note: "b",
            accountId: Self.accB.id, type: .expense
        )
        // 轉入 accA 的轉帳：accountId 是 accB（轉出方），toAccountId 是 accA。
        // 雙向語意下它必須出現在 accA 的列表（與 ledger.balance 的雙向一致）。
        let transferIn = Transaction(
            amount: 500, date: base.addingTimeInterval(-300), note: "t",
            accountId: Self.accB.id, toAccountId: Self.accA.id, type: .transfer
        )

        var initial = DashboardFeature.State()
        initial.accounts = [Self.accA, Self.accB]
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in
                [txA, txB, transferIn].map { EnrichedTransaction(transaction: $0) }
            }
            $0.insightsClient.weeklySparkline = { _ in [0, 0, 0, 0, 0, 0, 0] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA, transferIn]   // txB 被排除；轉入包含
            $0.earliestTransactionDate = transferIn.date
            $0.transactionsPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
            #expect(store.state.filteredBalance == 300)         // computed：選中帳戶餘額
            #expect(store.state.weeklySpending == [0, 0, 0, 0, 0, 0, 0])
        }
    }

    @Test("Selecting nil chip re-queries the full ledger scope")
    func testChipSelectAllReloadsGlobalScope() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let txA = Transaction(
            amount: 100, date: base.addingTimeInterval(-100), note: "a",
            accountId: Self.accA.id, type: .expense
        )
        let txB = Transaction(
            amount: 200, date: base.addingTimeInterval(-200), note: "b",
            accountId: Self.accB.id, type: .expense
        )

        var initial = DashboardFeature.State()
        initial.selectedAccountID = Self.accA.id
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in
                [txA, txB].map { EnrichedTransaction(transaction: $0) }
            }
            $0.insightsClient.weeklySparkline = { _ in [1, 1, 1, 1, 1, 1, 1] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(nil)) {
            $0.selectedAccountID = nil
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA, txB]
            $0.earliestTransactionDate = txB.date
            $0.transactionsPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
            #expect(store.state.filteredBalance == 1000)        // computed：totalBalance
        }
    }

    // MARK: - Bug 2

    @Test("transactionTapped finds rows beyond the old top-3 cap")
    func testTransactionTappedBeyondTopThree() async {
        let txs = (0 ..< 6).map { i in
            Transaction(
                amount: Decimal(i + 1),
                date: Date(timeIntervalSince1970: TimeInterval(1_000_000 - i)),
                note: "tx\(i)", accountId: "acc", type: .expense
            )
        }
        var initial = DashboardFeature.State()
        initial.recentTransactions = txs

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }
        let fifth = txs[4]   // 第 5 列 —— 舊實作只查得到前 3 筆
        await store.send(.transactionTapped(fifth.id)) {
            $0.detail = TransactionDetailFeature.State(transaction: fifth)
        }
    }

    // MARK: - Bug 3

    @Test("transactionsUpdated with unchanged count does not refetch AI insight")
    func testAIInsightSkippedWhenCountUnchanged() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let tx1 = Transaction(amount: 1, date: base, note: "1", accountId: "acc", type: .expense)
        let tx2 = Transaction(amount: 2, date: base.addingTimeInterval(-60), note: "2", accountId: "acc", type: .expense)

        var initial = DashboardFeature.State()
        initial.lastInsightTransactionCount = 2

        // Exhaustive TestStore：若 fetchAIInsight 被誤觸發，未接收的 action 會讓測試失敗。
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }
        await store.send(.transactionsUpdated(recent: [tx1, tx2], earliestDate: tx2.date)) {
            $0.recentTransactions = [tx1, tx2]
            $0.earliestTransactionDate = tx2.date
            $0.transactionsPhase = .loaded
        }
    }

    @Test("AI insight response stores the same count the trigger compared against")
    func testAIInsightCountConsistency() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let txs = (0 ..< 4).map { i in
            Transaction(
                amount: Decimal(i + 1), date: base.addingTimeInterval(TimeInterval(-i * 60)),
                note: "t\(i)", accountId: "acc", type: .expense
            )
        }
        var initial = DashboardFeature.State()
        initial.lastInsightTransactionCount = 2   // 與新 count(4) 不同 → 觸發

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in "insight" }
        }
        await store.send(.transactionsUpdated(recent: txs, earliestDate: txs.last?.date)) {
            $0.recentTransactions = txs
            $0.earliestTransactionDate = txs.last?.date
            $0.transactionsPhase = .loaded
        }
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }
        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "insight"
            $0.lastInsightTransactionCount = 4   // 寫回 == 比較來源（修 Bug 3）
        }
    }

    // MARK: - Bug 4

    @Test("earliestTransactionDate reflects the scope's true earliest, not min(recent 20)")
    func testEarliestDateBeyondRecentWindow() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        // 25 筆、每天一筆：recent 20 不含最舊那 5 筆。
        let txs = (0 ..< 25).map { i in
            Transaction(
                amount: 1, date: base.addingTimeInterval(TimeInterval(-i * 86_400)),
                note: "t\(i)", accountId: "acc", type: .expense
            )
        }
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in txs.map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.isAIAvailable = { false }
        }
        await store.send(.retrySection(.transactions)) {
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = Array(txs.prefix(20))
            $0.earliestTransactionDate = txs.last!.date   // 第 25 筆：最舊、不在 recent 20 內
            $0.transactionsPhase = .loaded
        }
        // count(20) != lastInsightTransactionCount(nil) → 觸發；isAIAvailable false → 無 state 變化
        await store.receive(\.fetchAIInsight)
    }
}
```

- [ ] **Step 1.2: 跑新套件確認紅燈（編譯失敗）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/DashboardFeatureScopeTests 2>&1 | tail -20
```

預期：**BUILD FAILED** —— `transactionsUpdated(recent:earliestDate:)` 等新 API 尚不存在。這就是本任務的紅燈。

---

### Task 2: DashboardFeature.swift 改寫

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`

- [ ] **Step 2.1: 重塑 State（行 49–102 一帶）**

刪除 stored：`totalBalance`、`topAccounts`、`filteredBalance`、`filteredRecent`、`hasAccounts`、`hasTransactions`。新增 computed 區塊。完整新 State：

```swift
    @ObservableState
    public struct State: Equatable {
        // ═══ 查詢參數（chip 唯一控制的東西）═══
        public var selectedAccountID: Account.ID? = nil

        // ═══ 查詢結果 —— 每個欄位只有一個寫入 action ═══
        public var accounts: [Account] = []                                  // accountsUpdated
        /// 餘額是全帳本 fold（`ledger.balances()`），recent 20 推導不出來，必須 stored。
        public var accountBalances: [Account.ID: Decimal] = [:]              // accountBalancesComputed
        /// 當前 scope（selectedAccountID）的近期 20 筆，已按日期降冪。
        public var recentTransactions: [Transaction] = []                    // transactionsUpdated
        /// 當前 scope「真正」最早一筆的日期（非 recent 20 的 min）——驅動 sparkline 暖身判斷。
        public var earliestTransactionDate: Date? = nil                      // transactionsUpdated
        public var categoryMap: [Domain.Category.ID: Domain.Category] = [:]  // categoriesLoaded
        public var weeklySpending: [Decimal] = []                            // weeklySpendingComputed

        // AI Insight
        public var aiInsight: String?
        public var isLoadingInsight: Bool = false
        public var lastInsightTransactionCount: Int?

        // Stats（全域數字 —— TODO(stats-follow-up): 連動需 todayStats 增加 accountId 參數）
        public var todaySpending: Decimal = 0
        public var weekSpending: Decimal = 0
        public var savingsPercentage: Double = 0

        // Insight carousel（populated by Slice 7）
        public var insights: [InsightData] = []
        public var insightIndex: Int = 0

        // Loading & UI state
        public var isLoading: Bool = false
        public var expandedTransactionID: Transaction.ID? = nil

        // Per-section view state
        public var heroPhase: SectionPhase = .idle
        public var statsPhase: SectionPhase = .idle
        public var transactionsPhase: SectionPhase = .idle
        public var insightPhase: SectionPhase = .idle
        public var accountsPhase: SectionPhase = .idle

        // Navigation
        public var path: StackState<Destination.State> = StackState()

        // Presentation
        @Presents var addTransaction: AddTransactionFeature.State?
        @Presents var detail: TransactionDetailFeature.State?

        // ═══ Computed 衍生 —— 禁止為這些值新增 stored 影子 ═══
        /// Chip 顯示順序（sortOrder 升冪）。
        public var orderedAccounts: [Account] {
            accounts.sorted { $0.sortOrder < $1.sortOrder }
        }
        public var totalBalance: Decimal {
            accountBalances.values.reduce(0, +)
        }
        /// Hero 卡顯示的餘額：選中帳戶的餘額，未選則總額。
        public var filteredBalance: Decimal {
            selectedAccountID.flatMap { accountBalances[$0] } ?? totalBalance
        }

        public init() {}
    }
```

- [ ] **Step 2.2: 改 Action 簽名（行 113–115 一帶）**

```swift
        // Data responses
        case accountsUpdated([Account])
        case accountBalancesComputed([Account.ID: Decimal])                     // total 參數刪除（改 computed）
        case transactionsUpdated(recent: [Transaction], earliestDate: Date?)    // scope 查詢結果
        case categoriesLoaded([Domain.Category])
```

- [ ] **Step 2.3: CancelID 加 `balances`（行 37–45 一帶）**

```swift
    private enum CancelID {
        case accountObservation
        case transactionObservation
        case balances
        case categoryFetch
        case aiInsightFetch
        case weeklySpending
        case stats
        case insights
    }
```

- [ ] **Step 2.4: 新增三個 effect helpers + mutation 重載 helper（放在 `// MARK: - Helpers`，`loadAllSections` 之前）**

```swift
    /// Loads active accounts; routes failure into the accounts section phase.
    private func accountsEffect(cancelInFlight: Bool) -> Effect<Action> {
        .run { send in
            do {
                let accounts = try await ledger.listActiveAccounts()
                await send(.accountsUpdated(accounts))
            } catch {
                await send(.sectionFailed(.accounts, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.accountObservation, cancelInFlight: cancelInFlight)
    }

    /// Per-selection transactions query: fetch the ledger, scope it to the
    /// selected account（雙向：轉出 `accountId` / 轉入 `toAccountId`，與
    /// `ledger.balance` 的雙向語意對齊），sort desc, keep the recent 20.
    ///
    /// Also derives the scope's TRUE earliest date（Bug 4 fix —— 取 recent 20
    /// 的 min 會把「3 天記 20 筆」的活躍使用者誤判成新用戶而藏掉 sparkline）。
    /// 全取後本地過濾是專案慣例（fetchAll + Swift 過濾，瓶頸才下推）。
    private func transactionsEffect(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .run { send in
            do {
                let all = try await ledger.listAll(TransactionFilter()).map(\.transaction)
                let scoped = accountID.map { id in
                    all.filter { $0.accountId == id || $0.toAccountId == id }
                } ?? all
                let sorted = scoped.sorted { $0.date > $1.date }
                await send(.transactionsUpdated(
                    recent: Array(sorted.prefix(20)),
                    earliestDate: sorted.last?.date
                ))
            } catch {
                await send(.sectionFailed(.transactions, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.transactionObservation, cancelInFlight: cancelInFlight)
    }

    /// Loads the 7-day expense sparkline for the selected scope.
    private func sparklineEffect(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .run { send in
            do {
                let values = try await insightsClient.weeklySparkline(accountID)
                await send(.weeklySpendingComputed(values))
            } catch {
                await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.weeklySpending, cancelInFlight: cancelInFlight)
    }

    /// 任何帳本異動（新增 / 編輯 / 刪除交易）後的統一重載：
    /// 帳戶＋餘額、scope 交易、stats、sparkline。
    /// 取代原本在 saved / savedRecurringConfirmation / detail-updated 三處
    /// 重複且無錯誤處理的 inline effect。
    private func refreshAfterMutation(accountID: Account.ID?) -> Effect<Action> {
        .merge(
            accountsEffect(cancelInFlight: true),
            transactionsEffect(accountID: accountID, cancelInFlight: true),
            statsEffect(cancelInFlight: true),
            sparklineEffect(accountID: accountID, cancelInFlight: true)
        )
    }
```

- [ ] **Step 2.5: `loadAllSections` 改用 helpers**

```swift
    private func loadAllSections(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .merge(
            accountsEffect(cancelInFlight: cancelInFlight),
            transactionsEffect(accountID: accountID, cancelInFlight: cancelInFlight),
            .run { send in
                do {
                    let categories = try await ledger.listCategories(nil)
                    await send(.categoriesLoaded(categories))
                } catch {
                    // Categories feed UI styling; failure leaves the cached map intact.
                }
            }
            .cancellable(id: CancelID.categoryFetch, cancelInFlight: cancelInFlight),
            sparklineEffect(accountID: accountID, cancelInFlight: cancelInFlight),
            statsEffect(cancelInFlight: cancelInFlight),
            insightsEffect(cancelInFlight: cancelInFlight)
        )
    }
```

- [ ] **Step 2.6: 改寫 reducer cases（依現檔行號定位，逐一替換）**

`accountsUpdated`（原 206–226 行，task group 整段刪除）：

```swift
            case let .accountsUpdated(accounts):
                state.accounts = accounts
                state.accountsPhase = .loaded
                // 餘額一次查回 —— `ledger.balances()` 本就存在，
                // 取代原本手刻的 per-account task group。
                return .run { send in
                    do {
                        let balances = try await ledger.balances()
                        await send(.accountBalancesComputed(balances))
                    } catch {
                        await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                    }
                }
                .cancellable(id: CancelID.balances, cancelInFlight: true)
```

`accountBalancesComputed`（原 228–232 行）：

```swift
            case let .accountBalancesComputed(balances):
                state.accountBalances = balances
                return .none
```

`transactionsUpdated`（原 234–249 行）：

```swift
            case let .transactionsUpdated(recent, earliestDate):
                state.recentTransactions = recent
                state.earliestTransactionDate = earliestDate
                state.transactionsPhase = .loaded
                state.isLoading = false

                // AI insight 失效判斷：比較與寫回（aiInsightResponse.success）
                // 都用 recentTransactions.count —— 同一來源（Bug 3 fix）。
                // 已知限制：等量編輯（筆數不變、金額變）不會觸發重打，
                // 沿用舊行為 —— TODO(insights-follow-up) 一併重新設計。
                if state.lastInsightTransactionCount != recent.count {
                    return .send(.fetchAIInsight)
                }
                return .none
```

`retrySection`（原 277–318 行）—— 三個 loader 換成 helpers，transactions 補上 scope（順帶修掉「retry 無視 chip 選擇」的小 bug）：

```swift
            case let .retrySection(section):
                switch section {
                case .hero:
                    state.heroPhase = .loading
                    return sparklineEffect(accountID: state.selectedAccountID, cancelInFlight: true)
                case .accounts:
                    state.accountsPhase = .loading
                    return accountsEffect(cancelInFlight: true)
                case .transactions:
                    state.transactionsPhase = .loading
                    return transactionsEffect(accountID: state.selectedAccountID, cancelInFlight: true)
                case .stats:
                    state.statsPhase = .loading
                    return statsEffect(cancelInFlight: true)
                case .insight:
                    state.insightPhase = .loading
                    return insightsEffect(cancelInFlight: true)
                }
```

`accountChipSelected`（原 320–337 行）—— 影子重算整段刪除：

```swift
            case let .accountChipSelected(accountID):
                state.selectedAccountID = accountID
                state.heroPhase = .loading
                state.transactionsPhase = .loading
                // filteredBalance / 交易列表不需手動重算 —— 前者是 computed，
                // 後者由 scope 查詢寫回。
                // TODO(stats-follow-up): StatsRow 連動 —— `insightsClient.todayStats`
                //   需要 accountId 參數（Domain 介面 + Application 實作變更，另開單）。
                //   屆時在此 merge statsEffect 並將 statsPhase 轉 loading。
                // TODO(insights-follow-up): InsightCarousel 連動 —— generateInsights
                //   實作後帶 selectedAccountID 重查，並重新設計 AI insight 失效策略。
                return .merge(
                    transactionsEffect(accountID: accountID, cancelInFlight: true),
                    sparklineEffect(accountID: accountID, cancelInFlight: true)
                )
```

`fetchAIInsight`（原 363–385 行）—— 只改註解語境，邏輯不變（輸入現在是 scope 近期 20 筆而非截斷的 3 筆）：closure 開頭 `return .run { [transactions = state.recentTransactions] send in` 維持原樣。

`aiInsightResponse(.success)`（原 387–391 行）—— 程式碼不變：`state.lastInsightTransactionCount = state.recentTransactions.count`。改後與比較端同源，這行從 bug 變成正確實作。

`transactionTapped`（原 437–441 行）—— 程式碼不變；`recentTransactions` 現為 scope 近期 20 筆（view 顯示其 prefix(6) 的母集），Bug 2 自動修復。

三段 mutation-reload（原 444–464、466–486、494–514 行）：

```swift
            // MARK: Child features
            case .addTransaction(.presented(.delegate(.saved))),
                 .addTransaction(.presented(.delegate(.savedWithTransaction(_)))):
                return refreshAfterMutation(accountID: state.selectedAccountID)

            case let .addTransaction(.presented(.delegate(.savedRecurringConfirmation(id, newNextDueDate)))):
                return .merge(
                    refreshAfterMutation(accountID: state.selectedAccountID),
                    .send(.delegate(.savedRecurringConfirmation(id, newNextDueDate)))
                )
```

```swift
            case .detail(.presented(.delegate(.deleted))),
                 .detail(.presented(.delegate(.updated))):
                return refreshAfterMutation(accountID: state.selectedAccountID)
```

其餘 cases（`task`、`pulledToRefresh`、`refreshCompleted`、`categoriesLoaded`、`weeklySpendingComputed`、`sectionFailed`、`statsComputed`、`transactionRowToggled`、`insightsLoaded`、`insightIndexChanged`、所有 user-interaction 與 navigation cases）**不變**。

- [ ] **Step 2.7: 確認 Features target 可編譯（測試先不跑）**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```

預期：**BUILD FAILED** —— 三個 view 檔還引用舊欄位（Task 3 處理）。若錯誤只來自 `TransactionsSection` / `AccountChipsStrip` / `HeroBalanceCard`，屬預期；出現其他檔案錯誤則回報 BLOCKED。

---

### Task 3: View 對齊

**Files:**
- Modify: `Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift`
- Modify: `Features/Sources/Features/Dashboard/Sections/AccountChipsStrip.swift`
- Modify: `Features/Sources/Features/Dashboard/Sections/HeroBalanceCard.swift`

- [ ] **Step 3.1: TransactionsSection —— 資料源換成 scope 查詢結果**

行 39：

```swift
        let rows = Array(store.recentTransactions.prefix(6))
```

行 8 的 doc comment 同步更新：

```swift
/// Renders up to 6 rows from `store.recentTransactions`. Each row can expand to
```

- [ ] **Step 3.2: AccountChipsStrip —— 改用 computed 排序**

行 31：

```swift
                ForEach(store.orderedAccounts) { account in
```

- [ ] **Step 3.3: HeroBalanceCard —— Preview helper 改設 stored 來源**

`filteredBalance` 已是 computed 不可賦值。行 96–108 的 preview helper 改為：

```swift
private func heroPreviewState(
    phase: DashboardFeature.SectionPhase,
    balance: Decimal,
    weekly: [Decimal] = [],
    earliestTransactionDate: Date? = Calendar.current.date(byAdding: .day, value: -30, to: Date())
) -> DashboardFeature.State {
    var state = DashboardFeature.State()
    state.heroPhase = phase
    state.accountBalances = ["preview-account": balance]   // filteredBalance（computed）由此推導
    state.weeklySpending = weekly
    state.earliestTransactionDate = earliestTransactionDate
    return state
}
```

- [ ] **Step 3.4: 確認 Features target 編譯通過**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```

預期：**BUILD SUCCEEDED**。失敗則檢查是否漏改本 Task 清單內的檔案；清單外錯誤回報 BLOCKED。

---

### Task 4: 既有測試對齊

**Files:**
- Modify: `NeuLedgerTests/Tests/FeaturesTests/DashboardFeatureTests.swift`
- Modify: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureChipTests.swift`
- Modify: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureSectionPhaseTests.swift`

通用替換規則（血淚規則①：reducer 路徑碰到的每個 closure 都要 stub）：

| 舊 | 新 |
|---|---|
| `$0.ledgerClient.listRecent = { _ in ... }` | `$0.ledgerClient.listAll = { _ in ... }`（Dashboard 不再呼叫 `listRecent`） |
| `$0.ledgerClient.balance = { id in ... }`（逐帳戶） | `$0.ledgerClient.balances = { [id0: x, id1: y] }`（一次回傳） |
| 斷言 `$0.topAccounts = ...sorted...` | `$0.accounts = ...`（stub 回傳值原樣，不再 reducer 內排序） |
| 斷言 `$0.hasAccounts` / `$0.hasTransactions` | 刪除（欄位已不存在） |
| 斷言 `$0.totalBalance` / `$0.filteredBalance` / `$0.filteredRecent` | 刪除（computed 不參與 TestStore diff；需要時用 `#expect(store.state.xxx == ...)`） |
| 斷言 `$0.recentTransactions = Array(sorted.prefix(3))` | `$0.recentTransactions = sorted`（全量，上限 20） |
| `store.send(.transactionsUpdated(txs))` | `store.send(.transactionsUpdated(recent: ..., earliestDate: ...))` |

- [ ] **Step 4.1: DashboardFeatureTests 逐測試更新**

`testTaskUpdatesState`：
- stubs：刪 `$0.ledgerClient.balance`，加 `$0.ledgerClient.balances = { [Self.sampleAccounts[0].id: 45000, Self.sampleAccounts[1].id: 1200] }`；`listRecent` stub 改 `listAll`（回傳值同樣是 `Self.sampleTransactions.map { EnrichedTransaction(transaction: $0) }`）
- `receive(\.accountsUpdated)` 斷言改為：

```swift
        await store.receive(\.accountsUpdated) {
            $0.accounts = Self.sampleAccounts
            $0.accountsPhase = .loaded
        }
```

- `receive(\.transactionsUpdated)` 斷言改為：

```swift
        await store.receive(\.transactionsUpdated) {
            let sorted = Self.sampleTransactions.sorted { $0.date > $1.date }
            $0.recentTransactions = sorted
            $0.earliestTransactionDate = sorted.last?.date
            $0.transactionsPhase = .loaded
            $0.isLoading = false
        }
```

- `receive(\.accountBalancesComputed)` 斷言改為（totalBalance/filteredBalance 刪除）：

```swift
        await store.receive(\.accountBalancesComputed) {
            $0.accountBalances = [
                Self.sampleAccounts[0].id: 45000,
                Self.sampleAccounts[1].id: 1200,
            ]
        }
```

- 末段 `aiInsightResponse.success` 的 `$0.lastInsightTransactionCount = 3` 改為 `= 4`（全量 4 筆）。

`testAICacheInvalidationOnNewTransaction`：
- 初始 `initialState.recentTransactions = Array(Self.sampleTransactions.prefix(3))` 維持（語意：先前 scope 有 3 筆）；`initialState.hasTransactions = true` 刪除。
- send 改為：

```swift
        let sorted = Self.sampleTransactions.sorted { $0.date > $1.date }
        await store.send(.transactionsUpdated(recent: sorted, earliestDate: sorted.last?.date)) {
            $0.recentTransactions = sorted
            $0.earliestTransactionDate = sorted.last?.date
            $0.transactionsPhase = .loaded
        }
```

- 末段 `$0.lastInsightTransactionCount = 3` 改為 `= 4`。

`testCategoriesLoadedBuildsCategoryMap`：不變。
`testTaskFetchesCategoriesAndPopulatesCategoryMap`：stubs 中 `listRecent` 改 `listAll`、`balance` 改 `balances = { [:] }`。

`testPullToRefreshForcesAIUpdate`：
- stubs：`balance` → `balances = { [Self.sampleAccounts[0].id: 1000, Self.sampleAccounts[1].id: 1000] }`；`listRecent`（回傳 prefix(3)）→ `listAll`（回傳同樣 3 筆）。
- `initialState.hasTransactions = true` 刪除。
- `receive(\.accountsUpdated)` 改：`$0.accounts = Self.sampleAccounts`（hasAccounts/topAccounts 刪除）。
- `receive(\.transactionsUpdated)` 改：

```swift
        await store.receive(\.transactionsUpdated) {
            let sorted = Array(Self.sampleTransactions.prefix(3)).sorted { $0.date > $1.date }
            $0.recentTransactions = sorted
            $0.earliestTransactionDate = sorted.last?.date
            $0.isLoading = false
        }
```

- `receive(\.accountBalancesComputed)` 改：只剩 `$0.accountBalances = [...]`（totalBalance 行刪除）。
- 其餘 receive 順序與 lastInsightTransactionCount（0 → 3）邏輯不變。

`testTransactionTappedPresentsDetail` / `testTransactionTappedUnknownId` / 各 presentation 測試：不變（`recentTransactions` 仍存在）。
`addTransactionWithPrefilledDataPresents`：stubs 中 `listRecent` 改 `listAll`（presentation-only，stub 不會被呼叫，但保持一致）。

- [ ] **Step 4.2: DashboardFeatureChipTests 重寫（chip 行為已從本地重算變成 scope 重查）**

全檔替換為：

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@Suite("DashboardFeature Chip Selection")
struct DashboardFeatureChipTests {
    private static let accA = Account(name: "A", type: .cash, icon: "", color: "#000000")
    private static let accB = Account(name: "B", type: .bank, icon: "", color: "#000000")

    private static func makeTxs() -> (a: Transaction, b: Transaction) {
        let base = Date(timeIntervalSince1970: 2_000_000)
        return (
            Transaction(amount: 100, date: base, note: "x", accountId: accA.id, type: .expense),
            Transaction(amount: 200, date: base.addingTimeInterval(-60), note: "y", accountId: accB.id, type: .expense)
        )
    }

    @Test("Selecting an account sets selectedAccountID and reloads scoped data")
    func testChipSelectAccount() async {
        let (txA, txB) = Self.makeTxs()
        var initial = DashboardFeature.State()
        initial.accounts = [Self.accA, Self.accB]
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [txA, txB].map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.weeklySparkline = { _ in [0, 0, 0, 0, 0, 0, 0] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA]
            $0.earliestTransactionDate = txA.date
            $0.transactionsPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
            #expect(store.state.filteredBalance == 300)
            #expect(store.state.weeklySpending == [0, 0, 0, 0, 0, 0, 0])
            #expect(store.state.heroPhase == .loaded)
        }
    }

    @Test("Selecting nil chip resets to the global scope")
    func testChipSelectAll() async {
        let (txA, txB) = Self.makeTxs()
        var initial = DashboardFeature.State()
        initial.accounts = [Self.accA, Self.accB]
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]
        initial.selectedAccountID = Self.accA.id
        initial.recentTransactions = [txA]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [txA, txB].map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.weeklySparkline = { _ in [0, 0, 0, 0, 0, 0, 0] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(nil)) {
            $0.selectedAccountID = nil
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA, txB]
            $0.earliestTransactionDate = txB.date
            $0.transactionsPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
            #expect(store.state.filteredBalance == 1000)   // computed：回到 totalBalance
        }
    }

    @Test("Chip switch does not change statsPhase / insightPhase")
    func testChipDoesNotAffectStatsOrInsight() async {
        var initial = DashboardFeature.State()
        initial.statsPhase = .loaded
        initial.insightPhase = .loaded

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.insightsClient.weeklySparkline = { _ in [1, 2, 3, 4, 5, 6, 7] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.finish()
        await MainActor.run {
            // TODO(stats-follow-up): StatsRow 連動實作後，此測試改為斷言 statsPhase 轉 loading。
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.insightPhase == .loaded)
        }
    }
}
```

- [ ] **Step 4.3: DashboardFeatureSectionPhaseTests 微調**

- `testHeroSuccess` / `testHeroFailure`：stubs 已含 `listAll`，刪除多餘的 `$0.ledgerClient.listRecent = { _ in [] }`，並補 `$0.ledgerClient.balances = { [:] }`（`accountsUpdated` 現在會呼叫它）。其餘不變（exhaustivity .off + skipReceivedActions 吸收新動作流）。
- `testRetryHero` / `testRetryStats` / `testSectionFailedRouting`：不變。

- [ ] **Step 4.4: 跑四個 Dashboard 套件（綠燈）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/DashboardFeatureTests \
  -only-testing:NeuLedgerTests/DashboardFeatureChipTests \
  -only-testing:NeuLedgerTests/DashboardFeatureSectionPhaseTests \
  -only-testing:NeuLedgerTests/DashboardFeatureScopeTests 2>&1 | tail -20
```

預期：**TEST SUCCEEDED**，Task 1 的回歸測試全綠。

---

### Task 5: 完整 Scheme 驗證 + Commit

- [ ] **Step 5.1: 跑完整 test scheme（血淚規則：局部通過不算數）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

預期：**TEST SUCCEEDED**。若 Dashboard 以外的套件失敗（例如其他 Feature 測試經 `Scope` 走到 Dashboard 依賴），依血淚規則②修正該測試的依賴注入；若失敗與本次變更無關，回報 BLOCKED。

- [ ] **Step 5.2: Commit（使用 `commit-commands:commit` skill）**

提交訊息（預設附 `[ci skip]`）：

```
fix(dashboard): rebuild state as single source of truth + scope-aware queries [ci skip]

- chip 切換改為重發 scope 查詢（交易含轉入轉帳，與餘額雙向語意對齊）
- filteredBalance/totalBalance/orderedAccounts 等改 computed，刪除 stored 影子
- 修復：chip 篩選資料源錯誤、第 4-6 列開不了詳情、AI insight 快取失效、
  sparkline 暖身誤判活躍使用者
- balances() 取代手刻 task group；mutation 重載收斂為 refreshAfterMutation
- StatsRow / InsightCarousel 連動留 TODO seam（另開單）
```

---

## Follow-ups（請使用者開單，本次不實作）

1. **StatsRow 連動 chip scope** —— `InsightsClient.todayStats` 增加 `accountId: Account.ID?` 參數：Domain 介面（`Domain/Clients/InsightsClient.swift:24`）+ Application 實作（`Application/Insights/InsightsClient+Live.swift`）+ `DashboardFeature.statsEffect` 帶 `selectedAccountID` + `accountChipSelected` merge statsEffect + 測試。程式碼內錨點：`TODO(stats-follow-up)`。
2. **InsightCarousel 連動 + AI insight 失效策略重設計** —— `generateInsights` 實作後帶 `selectedAccountID`；一併處理「等量編輯不觸發 AI 重打」的已知限制（count-based 失效改為內容感知）。注意現況的「半套連動」：chip 切換後單行 `aiInsight` 已 scope-aware（經 count diff 觸發重算），但 carousel 仍是全域——連動實作時兩者須同步 scope（最終審查 Minor-2）。程式碼內錨點：`TODO(insights-follow-up)`。
3. **（觀察項）`listAll(filter:)` 的 `accountIds` 只比對轉出** —— 與餘額雙向語意不一致；`TransactionsFeature` / `AnalysisFeature` 若有帳戶篩選同樣受影響，值得另開單盤點。
4. **Stale `selectedAccountID` 清理（code review I-1）** —— 選中帳戶被封存（如另一裝置 CloudKit 同步）後，`balances()` 不再回傳該 key，`filteredBalance` 回退總額但交易列表仍是該帳戶 scope，Hero 與列表矛盾；且 chip strip 只渲染非封存帳戶，使用者無法點回「全部」脫離。候選修法：`accountsUpdated` 時若 `selectedAccountID` 不在新 `accounts` 內則 reset 為 `nil` 並重發 scope 查詢（產品決策：封存是否保留選擇）。已在 `filteredBalance` doc comment 標注為已知行為。

## Self-Review 紀錄

- Spec 覆蓋：四個 bug 各有回歸測試（Task 1）；Model B（Task 2.6 accountChipSelected + transactionsEffect）；轉帳雙向（ScopeTests 第一測試 + transactionsEffect filter）；computed 衍生（Step 2.1）；TODO seam（Step 2.6 註解 + Follow-ups）；殭屍欄位刪除（Step 2.1 + Step 4 替換規則）。
- 型別一致：`transactionsUpdated(recent:earliestDate:)` 於 Task 1/2/4 簽名一致；`accountBalancesComputed([Account.ID: Decimal])` 於 Task 2/4 一致；`orderedAccounts`/`accounts` 命名於 Task 2/3/4 一致。
- 無 placeholder：所有步驟附完整程式碼或精確替換規則。
