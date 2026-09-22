# 跨領域共用邏輯聚合 — 設計文件

**日期：** 2026-09-22
**狀態：** 已裁定，待實作（計劃：`docs/superpowers/plans/2026-09-22-cross-domain-aggregation.md`）

## 1. 背景與目標

2026-09-22 對 `Features/Sources`、`Shared/`、`NeuLedgerWidget/`、`NeuLedgerWatchComplication/` 做靜態掃描，找到 14 組「同一條規則在多層各寫一份」的重複。`docs/architecture.md` §3.1 明文規定「要跨 Client 共用的計算，抽成 pure entity/VO 方法」，但實際上純計算規則散落在 Feature、Application、Core、Watch 四層，且有三處語意互相矛盾。

**目標：** 每一條跨領域規則只存在一處（Domain 放純規則、Common 放呈現格式化、Domain 放跨 target 常數），其餘呼叫端全部改用，並以測試釘住每個聚合點。

**非目標：** 不改 UI 版面、不改 SwiftData schema、不新增 Client、不動 `docs/architecture.md` 的層級規則。

## 2. 發現清單（掃描結果）

### A. 純計算規則未進 Domain

| # | 規則 | 份數 | 落點 |
|---|---|---|---|
| A1 | BudgetPeriod → 當期日期區間 | 6 | `TransactionAnalyticsKernel.swift:317`、`PlanningClient+Live.swift:119`、`AnalysisFeature.swift:345` 與 `:361`、`FilterView.swift:470`、`WatchContextBuilder.swift:84` |
| A2 | 預算「當期已花」 | 5 | `Budget.evaluate`、`PlanningClient.currentStatus`、Kernel `budgetGauges`、`AnalysisFeature.computeBudgetMetrics`、`WatchContextBuilder.monthBudgetProgress` |
| A3 | 交易「屬於某帳戶」 | 5 | `TransactionFilter.accountIds`（只看 `accountId`）、`LedgerClient.balance/balances`（雙向）、`deleteAccount`（雙向）、`DashboardFeature.transactionsEffect`（雙向）、Kernel（單向） |
| A4 | Analysis 自行重算 Insights 已有的投影 | — | `insightsClient.dailyBars / categoryProportions / budgetGauges` 在 Features 零呼叫者；`AnalysisFeature.loadData` 自己算 summary / 分類佔比 / 每日趨勢 / gauges |
| A5 | 今日支出總額 | 2 | Kernel `statsSnapshot`、`WatchContextBuilder` |
| A6 | 週期交易下次到期日 | 2 | `RecurringTransaction.nextDate(after:)` 已存在，`AddTransactionFeature.swift:297` 內聯重寫 |
| A7 | `AnalysisFeature.State.Period`（week/month/year） | — | 是 `BudgetPeriod` 的翻版 |

**語意矛盾（現況可見 bug）：**
- A1：Kernel / Planning 算整個期間（end − 1ms），Analysis 算 `start...now`。
- A3：Transactions 頁用帳戶篩選時漏掉「轉入該帳戶」的轉帳，Dashboard 選同一帳戶卻列出來。
- A1 補充：`FilterView.QuickDateRange` 的上界是「最後一天 00:00」，套用後最後一天整天的交易被排除。

### B. 呈現層格式化未進 Common

| # | 規則 | 落點 |
|---|---|---|
| B1 | 金額千分位格式化 | `Decimal.twdFormatted`（Common）之外另有 `AmountKeypadView:70`、`ConfirmView:75`、`ComplicationEntry:48`、`Decimal+Budget.swift:47`（Domain）四份 NumberFormatter；`KPIStrip:66`、`DailyBarsCard:91`、`CategoryDonutCard:145,199` 用字串切掉 `"NT$"` |
| B2 | 金額輸入解析 | `String.parsedAmountDecimal` 只有 `AddTransactionFeature` 用；`BudgetFormFeature:127`、`RecurringTransactionFormFeature:168` 用裸 `Decimal(string:)`，`"1,000"` 被判無效 |
| B3 | CarrierType 顯示對照 | icon / color / 格式提示在 `CarrierManagementView:271-282` 與 `AddEditCarrierView:277-302` 逐字重複，兩處裸 `Color(red:green:blue:)`；Watch `WatchCarrierView:99` 另一組 icon；本地化名稱在 `AddEditCarrierFeature:155` 與 `Shared/WidgetAppGroup.swift:103` |
| B4 | 條碼渲染 | Common `Code128`（Watch 用）、`CarrierManagementView:290` CIFilter、`CarrierWidget:73` CIFilter |
| B5 | `Category.localizedName` 漏網 | Kernel / Insights / Analysis 名稱字典取原始 `name`；`RecurringTransactionFormView:168,184`、Watch `ConfirmView:30` |
| B6 | Seed 分類 ↔ 本地化 key | `Category+Localized.seedLocalizationMap` 註明「要與 PersistenceBootstrap 手動同步」 |
| B7 | View 內做業務彙總 | `RecurringTransactionManagementView:210-218` 每月收支淨額在 body 算，且只算 monthly；`:445-465` 到期天數算兩遍 |
| B8 | `Decimal+Budget.perPeriodBreakdown` | 在 Domain 組本地化 UI 字串，錯層 |

### C. 跨 target 常數與 DTO

| # | 規則 | 落點 |
|---|---|---|
| C1 | App Group suite 字串 | `Shared/WidgetAppGroup.swift:9`、`WidgetSyncAdapter+Live.swift:18`、`PersistenceBootstrap.swift:40`、`WatchCacheStore.swift:14` |
| C2 | `CarrierEntry` DTO 與 5 個 key | `WidgetSyncAdapter+Live.swift:44-50` 手動鏡像 `Shared/` 的 struct，檔頭註明「MUST stay in sync」 |
| C3 | 匯出 | `SettingsFeature.exportCSVTapped` 自己組 CSV（`ledgerClient.exportCSV` 零呼叫者）；`exportJSONTapped` 自己 encode 並寫到固定 temp 路徑（§9 反模式） |

### 已聚合良好（不動）

`ledger.balances()`（Dashboard 與 AccountManagement 共用）、`Transaction+Presentation` / `TransactionType+UIColor` / `TransactionType+Display`、Color/Font gateway、recurring `tick` 使用 entity 的 `nextDate`。

## 3. 設計決策

### D1 期間規則 → `BudgetPeriod`（Domain）
新增 `BudgetPeriod+Calendar.swift`：`calendarComponent`、`dateInterval(containing:calendar:)`（半開）、`closedRange(containing:calendar:)`（上界 = 下期起點 − 1ms）、`previousInterval(before:calendar:)`、`next(after:calendar:)`。
- Kernel / Planning / Watch / FilterFeature / Analysis 全部改用；`RecurringTransaction.nextDate` 委派 `frequency.next(after:)`。
- **語意統一為「整個日曆期間」**（Analysis 原本的 `start...now` 改為整期；對「本期」數字無差異，因為未來沒有交易）。
- `AnalysisFeature.State.Period` 刪除，改用 `BudgetPeriod`；Analysis 專屬標籤（「週 / 月 / 年」）保留既有 `analysis_period_*` key，放在 Features 內的 `BudgetPeriod+AnalysisLabel.swift`。
- `FilterView.QuickDateRange` 搬進 `FilterFeature`（public enum + `quickRangeSelected` action），上界改為期末 23:59:59.999，修掉最後一天被排除的 bug。State 新增 `activeQuickRange: QuickDateRange?`，手動改日期即清空。

### D2 預算已花 → `Budget.spent(in:)`（Domain）
新增 `Budget+Spending.swift`：`appliesTo(_:)`、`spent(in:)`、`progress(spent:)`。`Budget.evaluate` 改用 `spent(in:)`；Planning `currentStatus` / `evaluateAfterTransaction`、Kernel `budgetGauges`、Watch `monthBudgetProgress` 全部改用。

### D3 帳戶歸屬 → `Transaction.involves(account:)` / `signedEffect(on:)`（Domain）
- `Transaction+Accounts.swift`：`involves(account:)`（雙向）、`signedEffect(on:)`。
- `Transaction+Aggregation.swift`：`Sequence<Transaction>.total(of:)`、`.balance(of:)`。
- `TransactionFilter+Matching.swift`：`matches(_:)` 是唯一篩選語意；`accountIds` 改為雙向。
- `LedgerClient.listAll` / `balance` / `balances` / `deleteAccount`、`InsightsClient` 的 `QueryTransactionsTool`、`DashboardFeature.transactionsEffect` 全部改用。
- **行為變更：** Transactions 頁帳戶篩選開始包含轉入的轉帳（與 Dashboard、餘額一致）。

### D4 Analysis 改走 InsightsClient
- `InsightsClient` 新增 `financialSummary(range:accountId:)`；`dailyBars` / `categoryProportions` 加 `accountId` 參數。
- Kernel 對應方法加 `accountId`，分類名稱一律用 `Category.localizedName`，未分類桶固定 `CategoryProportion.uncategorizedId == "uncategorized"`，名稱用 `analysis_other_category`。
- `AnalysisFeature.loadData` 只呼叫 insightsClient；刪除本地彙總、`computeBudgetMetrics`、`@Dependency(\.planningClient)`；改用 `@Dependency(\.date.now)` 與 `@Dependency(\.calendar)` 讓測試可控。
- **行為變更：** 空狀態判定從「無交易」改為「收入與支出皆為 0」（只有轉帳的期間會顯示空狀態）；分類 drill-down 加上帳戶範圍（原本未套用，與圓餅圖不一致）。

### D5 金額格式化 → Common
- `Decimal.twdDigits`（千分位、無符號）、`Decimal.twdParts`（`(symbol, digits)`，symbol 來自 `Currency.TWD.symbol`）。
- Watch 三處、Analysis 三張卡片改用；`perPeriodBreakdown` 從 Domain 搬到 `Common/Extensions/Decimal+Budget.swift`，測試同步搬到 CommonTests。
- Budget / Recurring 表單改用 `parsedAmountDecimal`。

### D6 CarrierType 顯示對照
- Domain `CarrierType+Display.swift`：`localizedName`、`barcodePlaceholder`、`barcodeFormatHint`。
- Common `CarrierType+UI.swift`：`systemImageName`（`iphone` / `creditcard`）、`tint`（`accentOrange` / 新 token `Color.Design.carrierCertIndigo = transferPurple`，取代裸 `Color(red:0.37, green:0.36, blue:0.90)`，同色）。
- iOS 條碼改用 Common `Code128BarcodeView`（與 Watch 同一套）；**Widget 保留 CIFilter**（Widget 不連結 Common，避免把 asset-catalog 色票拉進 extension），在檔頭註明為已知例外。
- **行為變更：** Watch 載具 icon 從 `iphone.gen3 / person.text.rectangle` 統一為 `iphone / creditcard`。

### D7 Category 名稱與 seed 守門
- Kernel / Insights 名稱字典、`RecurringTransactionFormView`、Watch `ConfirmView` 改用 `localizedName`。
- `Category.seedLocalizationKey(forSeedName:)` 公開；`DefaultDataSeederTests` 新增守門測試：每個 `SeedCategory` 名稱都必須有對應 key（取代「手動同步」註解）。

### D8 Recurring 摘要與到期天數
- Domain `RecurringTransaction.monthlyEquivalentAmount`（weekly × 52 ÷ 12、monthly × 1、yearly ÷ 12）。
- `RecurringTransactionManagementFeature.State` 新增 computed `monthlyIncome` / `monthlyExpense` / `monthlyNet` / `activeCount`；View 只讀。
- Common `Date.days(until:calendar:)`；View 的 `dueDateText` / `dueDateColor` 共用一次計算。
- **行為變更：** 摘要卡把 weekly / yearly 項目換算成每月等值一起計入（原本只算 monthly）。

### D9 匯出收回 LedgerClient
- `LedgerClient.exportJSON: () async throws -> URL`，live 實作與 `exportCSV` 同檔、同「唯一子目錄」規則。
- `SettingsFeature` 兩個 export action 改為呼叫 client；刪除 Feature 內的 CSV / JSON 組裝。

### D10 App Group 常數與 DTO → Domain
- Domain `AppGroup.swift`：`suiteName`、`carrierWidgetKind`、`CarrierKey.*`；`CarrierWidgetEntry`（欄位名 = 既有 JSON 線上格式，不可改）。
- `WidgetSyncAdapter+Live` 改為 `live(defaults:reload:)` 工廠以便測試；`PersistenceBootstrap`、`WatchCacheStore` 改引用常數。
- Widget target 新增 `Domain` package product 依賴（pbxproj）；`Shared/WidgetAppGroup.swift` 改為 `import Domain`、`typealias CarrierEntry = CarrierWidgetEntry`，刪除自己的常數與 struct。

## 4. 交付切分

三個 PR，每個 PR 內任務依序、每任務獨立可測：

| PR | 分支 | 內容 |
|---|---|---|
| A | `fix/aggregation-a-domain-rules` | D1、D2、D3（Task 1–5） |
| B | `fix/aggregation-b-analysis-insights` | D4（Task 6–7） |
| C | `fix/aggregation-c-presentation` | D5–D10（Task 8–14） |

## 5. 驗收

- 每個 PR 完整 `NeuLedger` scheme 測試綠燈；`NeuLedgerWatchTests` 綠燈。
- CLAUDE.md 四條 ast-grep audit 輸出符合預期。
- 以下 grep 在 PR C 完成後應為空：
  - `grep -rn 'NumberFormatter()' Features/Sources/WatchFeatures Features/Sources/Domain`
  - `grep -rn 'replacingOccurrences(of: "NT$"' Features/Sources`
  - `grep -rn 'Decimal(string: state.amountText)' Features/Sources/Features`
  - `grep -rn '"group.com.drake.NeuLedger"' Features/Sources Shared NeuLedgerWidget`（只允許 `Domain/AppGroup.swift` 一處）
  - `grep -rn 'dateInterval(of:' Features/Sources`（只允許 `BudgetPeriod+Calendar.swift` 一處）
