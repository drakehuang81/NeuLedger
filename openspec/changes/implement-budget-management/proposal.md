## Why

預算管理是記帳 app 的核心功能之一，目前 `BudgetClient` 及 `Budget` domain 模型已完整實作，但缺少對應的 UI 層——Settings 中的「預算設定」列僅為佔位符，Analysis 頁的預算進度區塊也無法顯示真實資料。此變更補全最後一塊拼圖，讓使用者可以建立、管理、停用預算，並在 Analysis 頁看到即時進度。

## What Changes

- 新增 `BudgetManagementFeature`（TCA Reducer + View）：預算列表、新增/編輯表單、啟用/停用切換
- Settings 的「預算設定」佔位符替換為真實的 `NavigationLink(value:)` 導覽，進入 `BudgetManagementView`
- `SettingsRoute` 加入 `.budgetManagement` case，並在 `navigationDestination` 中處理
- `AnalysisFeature` 接入 `BudgetClient.fetchActive`，將真實預算進度傳入現有的 `BudgetGauge` 元件
- `screen-settings.md` 更新：將「預算設定」佈位符改為正式導覽需求

## Capabilities

### New Capabilities
- `screen-budget-management`: 預算管理畫面的 UI 結構、互動流程、表單驗證規則；涵蓋預算列表、新增/編輯 sheet、啟用/停用操作。表單欄位：`name`、`amount`、`period`（BudgetPeriod）、`startDate`、`categoryId`（optional，nil 表示全域預算）

### Modified Capabilities
- `screen-settings`: 將「預算設定」row 從佔位符升級為正式的 `NavigationLink(value:)` 導覽至 `BudgetManagementView`，並在 `SettingsRoute` 加入 `.budgetManagement` case
- `screen-analysis`: 明確要求 `AnalysisFeature` 透過 `BudgetClient` 載入真實預算資料並傳入 `BudgetGaugeMetrics`（原需求已存在，但缺少資料來源的實作規格）

## Impact

- **新增檔案：**
  - `Features/Sources/Features/BudgetManagement/BudgetManagementFeature.swift`
  - `Features/Sources/Features/BudgetManagement/BudgetManagementView.swift`
  - `Features/Sources/Features/BudgetManagement/Components/BudgetRow.swift`
  - `Features/Sources/Features/BudgetManagement/Components/BudgetFormView.swift`
- **修改檔案：**
  - `Features/Sources/Features/Settings/SettingsView.swift`（`SettingsRoute` 加入 `.budgetManagement`，替換佔位符為 `NavigationLink`，`navigationDestination` 加入對應 case）
  - `Features/Sources/Features/Analysis/AnalysisFeature.swift`（接入 BudgetClient）
- **依賴：** `BudgetClient`（已在 Core 層實作）、`Budget` domain entity、`BudgetGauge` 元件（Common 層已存在）
- **無 breaking changes**
