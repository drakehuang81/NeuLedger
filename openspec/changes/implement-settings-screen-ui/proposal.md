## Why

Settings Screen 是 NeuLedger 四個主要 Tab 之一，目前尚未實作。需根據已完成的設計稿，建立對應的 TCA Reducer 與 SwiftUI View，完成基本 UI 呈現與導航佔位。

## What Changes

- 新增 `SettingsFeature` TCA Reducer（State / Action / body）
- 新增 `SettingsView` SwiftUI View，實作設計稿中的四個分區：管理、偏好設定、資料、關於
- 將 `SettingsFeature` 接入 `MainTabFeature`（目前 Settings tab 為空佔位）
- 管理分區的四個列（帳戶管理、分類管理、預算設定、標籤管理）以 NavigationLink 佔位，尚未實作子頁面
- 偏好設定：預設帳戶與語言顯示靜態值，AI 智慧功能 Toggle 讀寫 `userSettingsClient`
- 資料分區：匯出 CSV / JSON 按鈕以 Action 佔位（實際匯出邏輯不在本 change 範圍內）
- 關於分區：版本號靜態顯示，隱私權政策以 NavigationLink 佔位

## Capabilities

### New Capabilities

- `settings-screen`: Settings Screen 的完整 UI 呈現，涵蓋四個 section 的 List Row 樣式、Liquid Glass 卡片、Toggle、靜態值顯示

### Modified Capabilities

- `screen-settings`: 現有 screen spec 已有業務邏輯需求；本 change 僅實作 UI 結構，不新增 spec 需求，故標記此 spec 為參考依據，不產生 delta spec

## Impact

- `Features/Sources/Features/Settings/` — 新增目錄與兩個檔案（Feature + View）
- `Features/Sources/Features/MainTab/MainTabFeature.swift` — 加入 `SettingsFeature` 子 store
- `Features/Sources/Features/MainTab/MainTabView.swift` — 替換 Settings tab 佔位為 `SettingsView`
- 依賴：`userSettingsClient`（已存在）、`accountClient.fetchActive`（取預設帳戶名稱）
