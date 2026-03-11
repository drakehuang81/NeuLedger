## Context

目前 `BudgetClient` 與 `Budget` 的 Domain 模型已經在 Core 層實作完畢，但 UI 層（Settings 裡的預算選項、Analysis 裡的預算儀表板）都還是假資料或單純的佔位符。
因為 App 使用 TCA (The Composable Architecture) 架構，我們需要設計一個新的 Feature (`BudgetManagementFeature`) 來管理預算的 CRUD 狀態，並將其整合進現有的 `SettingsFeature` 的 Navigation Stack 中。同時，也需要更新 `AnalysisFeature` 來訂閱/讀取真實的預算資料以供顯示。

## Goals / Non-Goals

**Goals:**
- 提供使用者一個完整的預算管理介面 (Budget Management Screen)，能新增、編輯、啟用、停用預算。
- 將 `BudgetManagementFeature` 完美整合進 `SettingsFeature` 的 Navigation Stack。
- 讓 `AnalysisFeature` 能夠存取真實的預算進度 (Budget vs. Expenses) 並正確顯示。
- 遵循現有 App 的設計系統 (`neuledger-design-system.pen`) 與 TCA 的標準實作方式。

**Non-Goals:**
- **不包含**超出 `BudgetClient` 現有能力的複雜預算分析（如：跨月度的複雜預算預測）。
- **不包含** Core 層的 `BudgetClient` 重構或資料庫 Schema 變更（依賴現有實作）。
- **不涉及**自動從其他帳戶匯入預算的進階功能。

## Decisions

1. **獨立的 `BudgetManagementFeature`**:
   - **Rationale**: 為了保持模組化，我們建立一個專屬的 TCA Reducer (`BudgetManagementFeature.swift`) 來處理預算列表與表單。
   - **Approach**: 包含一個主要的 List 狀態，以及可能透過 sheet 呈現的 `BudgetFormFeature` 狀態。因為預算表單邏輯單純，初期可以選擇直接將新增/編輯的狀態 (如 `sheet: PresentationState<BudgetFormFeature.State>`) 放進 `BudgetManagementFeature` 內進行管理。
   
2. **在 `SettingsView` 使用現有 `SettingsRoute` 導覽模式整合**:
   - **Rationale**: 現有的 Settings 導覽採用 View 層的 `SettingsRoute` enum + SwiftUI `NavigationLink(value:)` + `navigationDestination(for:)`，與帳戶、分類、標籤管理畫面一致。
   - **Approach**: 在 `SettingsRoute` 增加 `.budgetManagement` case，在 `navigationDestination(for:)` 中建立 `BudgetManagementView(store:)`，並將佔位符替換為 `NavigationLink(value: .budgetManagement)`。

3. **`AnalysisFeature` 整合 `BudgetClient`**:
   - **Rationale**: `AnalysisFeature` 負責顯示收支與預算。它需要觀測當前啟用的預算 (`isActive == true`) 以及該週期的總支出。
   - **Approach**: 在 `AnalysisFeature.State` 加入預算的屬性。在 `.onTask` (或 `fetchData` action) 內呼叫 `budgetClient.fetchActive()`，然後結合已有的支出資料，計算出供 UI 使用的 `BudgetGaugeMetrics`。

4. **表單狀態驗證與保存**:
   - **Rationale**: 建立或更新預算時不應包含空名稱或不合理的金額。
   - **Approach**: 表單送出時，透過 `BudgetManagementFeature` (或 `BudgetFormFeature`) 攔截 `.saveTapped` 進行驗證。驗證成功後透過呼叫 `budgetClient.add(budget)` 或 `budgetClient.update(budget)`，然後刷新列表。

## Risks / Trade-offs

- **Risk: TCA Navigation 層級過深**: 在 TCA 中處理 Stack Navigation 加上 Sheet Presentation 可能會造成 Reducer 較複雜。 
  - **Mitigation**: 將「表單 (Form)」邏輯抽取為一個獨立的 `BudgetFormFeature`，透過 TCA 原生 `@PresentationState` 讓 `BudgetManagementFeature` 維持清爽，不要把所有的表單綁定都塞在母層 Reducer 內。
- **Risk: `AnalysisFeature` 資料同步延遲**: 使用者在 Settings 改了預算，退回/切換到 Analysis 時可能沒更新。
  - **Mitigation**: 確保在 `AnalysisFeature` view 出現時（或依賴有通知機制的 Client stream，若 Client 有實作 stream 的話）觸發重新載入邏輯。因為是在 TCA 架構下，最簡單的做法是在 `AnalysisFeature` 的 `.view(.task)` หรือ `.onAppear` action 中固定去 fetch 最新的 Active Budget。
