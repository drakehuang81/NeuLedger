## Context

Settings Screen 是 MainTab 的第三個 Tab，目前以 `PlaceholderView` 佔位。設計稿（neuledger-design-system.pen）已完成，包含四個分區的完整視覺規格：管理、偏好設定、資料、關於。

現有基礎：
- `MainTabFeature` 已有 `Tab.settings` case，但 State / Action / Scope 均未加入 SettingsFeature
- `MainTabView` 的 Settings Tab 仍用 `PlaceholderView`
- `UserSettingsClient` 已存在（用於 AI 功能 Toggle 的持久化）
- `accountClient` 已存在（用於讀取預設帳戶名稱）

## Goals / Non-Goals

**Goals:**
- 實作 `SettingsFeature` TCA Reducer（State / Action / body）
- 實作 `SettingsView`，完整呈現設計稿四個分區
- 將 SettingsFeature 接入 MainTabFeature / MainTabView
- AI 智慧功能 Toggle 讀寫 `userSettingsClient`（`.aiEnabled` key）
- 預設帳戶列顯示當前預設帳戶名稱（從 `accountClient` 讀取）

**Non-Goals:**
- 管理列的子頁面（帳戶管理、分類管理、預算設定、標籤管理）— 留待各自 change 實作
- 匯出 CSV / JSON 的實際邏輯 — 僅觸發 Action，不做資料處理
- 語言切換的實際邏輯 — 靜態顯示
- 隱私權政策頁面

## Decisions

### 1. SettingsFeature 使用標準 TCA @Reducer

與 `DashboardFeature`、`AnalysisFeature` 一致：`@ObservableState` State + `@Dependency` 注入。

**替代方案考慮：** 直接在 View 層使用 `@AppStorage`（無 TCA）。
**拒絕原因：** 與現有架構不符，且 Toggle 狀態需在 `.task` 中初始化，有非同步流程。

### 2. AI 功能 Toggle 使用現有 `userSettingsClient`

設計稿中只有一個「AI 智慧功能」Toggle（而非 spec 定義的兩個獨立 Toggle）。本 change 依照設計稿，新增單一 `SettingsKey<Bool>.aiEnabled`（預設 `true`），透過 `userSettingsClient.bool` 讀取、`userSettingsClient.setBool` 寫入。若日後需拆分為自動分類 / 支出洞察兩個獨立 Toggle，再另行擴充。

**替代方案考慮：** 新增獨立的 `aiSettingsClient`。
**拒絕原因：** 過度設計，`UserSettingsClient` 已具備泛型鍵值能力。

### 3. 預設帳戶名稱在 `.task` 載入

`SettingsFeature.State` 儲存 `defaultAccountName: String`，在 `.task` Effect 中呼叫 `accountClient.fetchActive()` 取第一個帳戶名稱（或顯示「無」）。這是臨時做法——真正的「預設帳戶」功能需要新增 `SettingsKey<String>.defaultAccountId` 讓使用者選定，留待後續 change 實作。

**替代方案考慮：** 直接儲存帳戶 ID，View 層解析。
**拒絕原因：** View 不應直接依賴 accountClient。

### 4. 管理列的導航以 delegate Action 佔位

設計稿的管理列（帳戶管理等）產生 `delegate(.navigateTo(.accounts))` 等 delegate Action，由 MainTabFeature 處理（目前 `.none`）。此方式與現有 Dashboard delegate pattern 一致。

### 5. UI 元件：ScrollView + VStack + 直接 `.glassEffect()`

Settings Screen **不使用** 原生 `List`，也**不使用** `GlassCard` 元件（其固定 `.padding(20)` 與設計稿的 row 自帶 `padding(14, 16)` 衝突）。改以 `ScrollView` + `VStack(spacing: 24)` 為骨架，每個 section 卡片為 `VStack(spacing: 0)` 直接套用 `.glassEffect()` + `RoundedRectangle(cornerRadius: 16)`。

**替代方案考慮 1：** 使用 `List` + `.listStyle(.insetGrouped)` 原生分組樣式。
**拒絕原因：** 原生 List section 無法呈現設計稿的 Liquid Glass 圓角卡片效果，且 List 的 row 間距、padding 不易精確控制。

**替代方案考慮 2：** 使用現有 `GlassCard` 元件。
**拒絕原因：** `GlassCard` 有固定 `.padding(20)` 和 `spacing: 16`，設計稿要求卡片無整體 padding，各 row 各自 padding `[14, 16]`。若修改 `GlassCard` 會影響現有使用處。

## Risks / Trade-offs

- **`SettingsKey<Bool>.aiEnabled` 尚未定義** → 需在 Domain 層新增此 key；若其他 feature 尚未使用此 key，不存在衝突風險。
- **預設帳戶邏輯簡化** → 目前取 `fetchActive()` 第一筆，未來若需真正的「預設帳戶」概念，需擴充 Domain 層；本 change 接受此簡化。
- **匯出按鈕無功能** → 點擊後僅 log，使用者可能困惑；透過 UI 視覺（chevron 圖示）明示這是導航入口，待後續 change 補齊。
- **版本號讀取** → 從 `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` 取得，若為 nil 則 fallback 顯示 "—"。

## Migration Plan

1. 在 `Domain/Clients/UserSettingsClient.swift` 新增 `SettingsKey<Bool>.aiEnabled`
2. 新增 `Features/Sources/Features/Settings/SettingsFeature.swift`
3. 新增 `Features/Sources/Features/Settings/SettingsView.swift`
4. 更新 `MainTabFeature.swift`：加入 `settings: SettingsFeature.State`、SettingsFeature.Action、Scope
5. 更新 `MainTabView.swift`：Settings Tab 改用 `SettingsView`
6. Build & 手動驗證四個分區渲染正確

無資料遷移，無 rollback 風險（純 UI 新增）。

## Open Questions

- 語言切換是否需要在本 change 中接入 `Locale`？→ 暫定不做，靜態顯示「繁體中文」。
- `SettingsKey<Bool>.aiEnabled` 需要同時影響 Dashboard 的 AI 功能嗎？→ 本 change 只做 Settings 端的讀寫，Dashboard 側留待日後整合。
- 設計稿 AI Toggle 為單一個，spec 定義為兩個（自動分類 + 支出洞察）→ 本 change 依設計稿用單一 Toggle，後續視需求拆分。
