# PR A4 — 管理畫面群死碼清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 依審查報告與「死碼一律刪除」裁定，清理 8 個 feature 區域的 ~14 項死碼（死 action、死分支、死欄位、空轉機制、整檔死元件）。

**Architecture:** 純刪除型重構。驗證：grep 歸零（含活識別字反向確認）+ 編譯 + 相關 suite 綠 + 完整 scheme 綠。三個實作 task 檔案互不重疊，串行執行。

**分支：** `fix/management-screens-dead-code`（自 `integration/presentation-audit` 897e169 切出）。PR base = `integration/presentation-audit`。commit 帶 `[ci skip]` + Co-Authored-By。

---

### Task 1: Analysis + AIAssistant 清理（5 項）

**Files:** `AnalysisFeature.swift`、`AnalysisView.swift`、`Sections/AnalysisTopBar.swift`、**整檔刪** `Sections/MonthlyTrendCard.swift`、`AIAssistant/AIAssistantFeature.swift`、`AnalysisFeatureTests.swift`

1. **死 action `dismissInsight`**（Feature :70 宣告、:233 handler）— 無任何 View 送出（AIDock 只有 local `isOpen` toggle）、無 effect 回傳、parent 不轉送。刪 action + handler + 測試 `testDismissInsight`
2. **`AnalysisData.budgetMetrics` 死欄位**（:81 宣告、:214 恆 `[]` 初始化）— `loadedData(.success)` 從不讀它，實際 budget 指標走獨立的 `.budgetMetricsLoaded` effect。**`State.budgetMetrics`（:46）是活的（AnalysisView:99,107 消費）— 絕不可動**
3. **`hasMonthlyTrendData` 永 false 分支**（AnalysisView :17 `private let ... = false`、:87-88 不可達 render）+ **整檔刪 `MonthlyTrendCard.swift`**（唯一引用就是這個不可達分支）
4. **空轉 binding 機制**：全 repo 無任何 `$store.` 雙向綁定送 binding action。刪 `BindingReducer()`（Feature :94）、`case .binding:`（:97-98）、Action 的 `BindableAction` conformance 與 `case binding(BindingAction<State>)`；`AnalysisView:8` 與 `AnalysisTopBar:14` 的 `@Bindable var store` 改 `let store: StoreOf<AnalysisFeature>`
5. **AIAssistant `cancelInFlight` 不可達**（AIAssistantFeature :81）— `!state.isLoading` guard 使第二個 in-flight 請求不可能存在。`.cancellable(id: CancelID.ask, cancelInFlight: true)` → `.cancellable(id: CancelID.ask)`（保留 id 供 view 卸載取消）

歸零驗證：`dismissInsight`、`hasMonthlyTrendData`、`MonthlyTrendCard`、`BindingReducer|BindableAction|binding(BindingAction`（Analysis 範圍）全歸零；`store.budgetMetrics`（AnalysisView）反向必須還在。
Suite：`AnalysisFeatureTests` + `AIAssistantFeatureTests`。
Commit：`refactor(analysis): remove dead insight dismissal, phantom AnalysisData field, unreachable trend card and idle binding machinery [ci skip]`

---

### Task 2: 管理畫面群（AccountManagement / CategoryManagement / BudgetManagement，4 項）

**Files:** `AccountManagementFeature.swift`、`AccountManagementView.swift`（僅刪 TODO 註解，若 plan 範圍內）、`CategoryManagementFeature.swift`、`CategoryManagementView.swift`（僅 TODO 註解）、**整檔刪** `BudgetManagement/Components/BudgetRow.swift`、`BudgetManagementFeature.swift`、三個對應測試檔、`Localizable.xcstrings`（僅刪孤兒 key）

1. **AccountManagement 死 action `accountMoved`**（:40 宣告、:204-232 handler 含 sortOrder 重排 + `CancelID.reorder`）— View 的 drag-to-reorder 已移除（TODO 註解明示）。刪 action + handler + `CancelID.reorder`（CancelID enum 剩 `case task`）+ 測試 `testAccountMoved`（:319-335）。View 的 TODO 註解保留（標記未來功能）
2. **AccountManagement `accountTapped` 的 isArchived 死分支**（:105-117 alert 構造）— archived row 無 tap 入口（`archivedAccountRow` 無 Button 包裹；**unarchive 走 contextMenu 直接送 `.unarchiveTapped`（View:163-167）— 活路徑，絕不可動**）。刪：handler 內 `if account.isArchived { ... }` 分支（簡化為直接進 edit）、`Alert.unarchiveConfirmed` case、`.alert(.presented(.unarchiveConfirmed))` 轉送 handler（:185-186）。**`unarchiveTapped` action 與 handler（:191-202）保留**（contextMenu 消費）。孤兒 localization key：`alert_unarchive_account_message` 刪（先 grep 全 repo 確認唯一消費者是被刪的 alert；`account_management_unarchive` 被 contextMenu 共用 — 保留；若 alert title 另有專屬 key 同樣確認後刪）。測試：`unarchiveTapped calls update and reloads`（:288）保留；若有測 accountTapped(archived) → alert 的測試，刪
3. **CategoryManagement 死 action `categoriesMoved`**（:37 宣告、:95-124 整段含 `ledger.updateCategory` 迴圈 + `CancelID.reorder`）— 同 accountMoved 模式。刪 action + handler + CancelID.reorder + 測試（:88-105）。View TODO 註解保留
4. **BudgetManagement 死 action `toggleActive`**（:29 宣告、:73-80 handler）+ **整檔刪 `Components/BudgetRow.swift`**（全 repo 無 `BudgetRow(` 實例化；它是唯一會觸發 toggleActive 語義的 UI）+ 測試 `testToggleActive`（:43-56）與其 MARK

歸零驗證：`accountMoved`、`categoriesMoved`、`toggleActive`、`unarchiveConfirmed`、`BudgetRow`、`alert_unarchive_account_message` 歸零；`unarchiveTapped`（Feature + View + 測試）反向必須還在。
Suite：`AccountManagementFeatureTests` + `CategoryManagementFeatureTests` + `BudgetManagementFeatureTests`。
Commit：`refactor(management): remove dead reorder/toggle actions, unreachable unarchive alert and orphan BudgetRow [ci skip]`

---

### Task 3: AccessoryBar + Settings + CustomAccountForm/Onboarding（4 項）

**Files:** `MainTab/AccessoryBarFeature.swift`、`MainTab/AccessoryView.swift`、`Settings/SettingsFeature.swift`、`Onboarding/CustomAccountFormFeature.swift`、`Onboarding/OnboardingFeature.swift`、四個對應測試檔

1. **AccessoryBar 死 action `aiInputTextChanged`**（:29 宣告、:88-90 handler）— voice-only 重構後無 TextField。刪 action + handler；**連鎖檢查**：`state.aiInputText` 若唯一寫入者是此 action（voice 流程不寫它），property 連鎖刪（檢查 `aiInputSubmitted` 是否讀 aiInputText —— 若讀，改由 submit 參數傳入或保留 property，依實際碼判斷並回報）；對應測試斷言同步清
2. **AccessoryView `.font(.title)` 被覆蓋殘留**（:100）— 後接 `.font(Font.Design.size11Semibold)` 覆蓋。刪 `.font(.title)` 行
3. **Settings 死 action `seedRandomDataDismissed`**（:119 宣告、:469 handler）— View 無任何送出點。刪 action + handler；**Settings 殘留 property `widgetCarrierId`**（:46 宣告、:64 init 參數、:73 init 賦值、:339/:348 兩處寫入）— reducer 不讀、View 只讀 `widgetCarrierName`。刪 property + init 參數 + 兩處寫入 + 測試兩處斷言（SettingsFeatureTests :499、:521）
4. **CustomAccountForm 死 action `cancelTapped` 連鎖**（:36 宣告、:55-56 handler）— View 無 cancel 鈕（唯一 send 是 `.submitTapped`），sheet 由系統下滑回收。連鎖刪：`cancelTapped` + `Delegate.dismissed`（:42）+ OnboardingFeature 的 `.customAccountSheet(.presented(.delegate(.dismissed)))` handler + 測試 `cancelTapped emits delegate.dismissed`（CustomAccountFormFeatureTests :87-93）與 `sheet delegate.dismissed clears the sheet`（OnboardingFeatureTests :93-102）。**`Delegate.saved`（或同名活 delegate）絕不可動**；Onboarding 的 `ifLet` 自動 nil 機制確認保留

歸零驗證：`aiInputTextChanged`、`seedRandomDataDismissed`、`widgetCarrierId`（Features+Tests 範圍；**UserSettingsAdapter 的同名 SettingsKey 屬 Application 層，絕不可動**）、CustomAccountForm 範圍的 `dismissed` 歸零；`widgetCarrierName`、`submitTapped` 反向還在。
Suite：`AccessoryBarFeatureTests` + `SettingsFeatureTests` + `CustomAccountFormFeatureTests` + `OnboardingFeatureTests`。
Commit：`refactor(misc): remove dead AI text action, seed dismiss, widgetCarrierId shadow and cancel chain [ci skip]`

---

### Task 4: 驗證 + 交叉 review + PR + merge

- ast-grep 四條閘門 + 完整 test scheme
- 派獨立 subagent 交叉 review 整個 PR diff — 重點：①unarchive contextMenu 活路徑完好 ②`State.budgetMetrics` vs `AnalysisData.budgetMetrics` 刪對邊 ③binding 機制移除後 AnalysisView/TopBar 編譯與互動（picker 等顯式 action）不受影響 ④CustomAccountForm 連鎖刪除後 onboarding sheet 下滑回收仍閉環 ⑤widgetCarrierId 與 UserSettingsAdapter SettingsKey 的同名區隔
- 開 PR（base = `integration/presentation-audit`）→ merge 進整合分支（使用者已授權）

---

## Self-Review 紀錄

- 審查 confirmed 非 test-gap 項對應：AccessoryBar F1+補漏 font、AccountMgmt F1（accountMoved）+ 補漏（archived 死分支）、CategoryMgmt F1、BudgetMgmt F1+F2（BudgetRow）、CustomAccountForm F1、Settings F1（seedRandomDataDismissed）+F2（widgetCarrierId）、Analysis F1（dismissInsight）+F2（budgetMetrics）+ 補漏（MonthlyTrendCard、binding）、AIAssistant F1（cancelInFlight）✅
- AccountMgmt F2（deleteRequested 無錯誤處理）屬「補錯誤處理」非死碼 → 留待 B 波或 follow-up，不在 A4 ✅
- unarchive 活路徑（contextMenu）已實查確認並置入保留邊界 ✅
