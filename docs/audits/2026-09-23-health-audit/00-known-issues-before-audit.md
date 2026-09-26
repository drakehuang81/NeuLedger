# 已知問題（請勿重複發現；可用一行確認仍存在，主力放在「新」問題）

## 已確認的 bug / 缺口
- `Features/Sources/Features/Transactions/FilterFeature.swift` `.task` 的 `.run` 沒有 catch：ledger client 拋錯時 runtimeWarning + 篩選頁靜默空白。
- `Features/Sources/Features/BudgetManagement/BudgetFormFeature.swift` `saveTapped` 的 `.run` 沒有 catch、沒有 saveFailed action。
- `Features/Sources/Features/Transactions/TransactionsView.swift:244-246` 交易列只顯示 note / type，不顯示分類（`TransactionsFeature` 把 `EnrichedTransaction` map 成 `Transaction` 丟掉了 join）。
- `AnalysisFeature` 分類佔比名稱用原始 seed 英文名（未走 `Category.localizedName`）；PR B（plan Task 6-7）會修。
- `TransactionAnalyticsKernel.weeklySpending` / `budgetGauges` 帳戶預篩仍是單向（`tx.accountId == id`），與 `Transaction.involves(account:)` 雙向語意不一致；`detailStats` 用 `cal.dateInterval(of: .month)` 未走 `BudgetPeriod`。PR B 處理。
- `TransactionAnalyticsKernel.scalarTransaction` 與 `SDTransaction+Mapping.toDomain()` 是兩份 SD→Domain 投影。
- Domain `ExtractedTransaction` / `CategorySuggestions` / `CaptureClient` / `AIAdapter` 的 `#if canImport(FoundationModels)` 在 Xcode 27 的 watchOS SDK 會編譯失敗（需 `&& !os(watchOS)`）。
- `Core/Adapters/Watch/WatchMidnightTimer` 是死碼（從未被 arm）；`WatchSyncObserver.rebuildAndPush` / `WatchMidnightTimer.fire` / `PlatformClient+Live.pushWatchContext` 三處 catch 吞錯無 log。
- `WatchSessionDelegate` 入站 Watch 記帳直寫 store，繞過 `ledgerClient.record` 的 invariant（預算警告、鏡像推送）。
- `RecurringTransactionFormFeature` `accountChanged` 時同帳戶的 toAccountId UI 死角；`AddTransactionFeature` transfer 驗證缺 toAccount nil 必填（與 RecurringForm 不對稱）。
- `DashboardFeature` / `SettingsFeature` State 肥大（已知，另開單）；Dashboard 三張 follow-up：StatsRow 連動、InsightCarousel 連動＋AI 失效策略、stale `selectedAccountID` 清理（程式碼錨點 `TODO(stats-follow-up)` / `TODO(insights-follow-up)`）。
- 跨領域聚合 PR C（plan Task 8-14）待做：NumberFormatter 重複 ×4、`"NT$"` 切字串 ×3、`parsedAmountDecimal` 只有 AddTransaction 用、CarrierType icon/color/hint 重複、Code128 三套渲染、App Group 常數 ×4、`SettingsFeature` 自己做 JSON export。
