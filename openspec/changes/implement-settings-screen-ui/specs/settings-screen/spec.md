## ADDED Requirements

### Requirement: 設定畫面整體佈局

`SettingsView` SHALL 以 `ScrollView` + `VStack(spacing: 24)` 為骨架，整體 padding 為 `top: 60, horizontal: 20, bottom: 40`（bottom 需額外加上 TabBar 安全距離）。頂部顯示大標題「設定」（`.custom("BricolageGrotesque-Bold", size: 34)` 或 `Font.Design.largeTitle`，`text-primary`）。其下排列四個分區（管理、偏好設定、資料、關於），每個分區為一個 `VStack(spacing: 6)`，內含：

1. Section 標題（`.custom("DMSans-SemiBold", size: 13)` 或 `.caption.weight(.semibold)`，`Color.Design.textSecondary`）
2. Glass 卡片容器：`VStack(spacing: 0)` 套用 `.glassEffect()` + `RoundedRectangle(cornerRadius: 16)`，**不使用** `GlassCard` 元件（因其固定 padding 20 與設計稿的 row 自帶 padding 衝突）

各列之間無分隔線，統一透過 Glass 背景區隔。

#### Scenario: 畫面初始渲染

- **WHEN** 使用者切換至設定 Tab
- **THEN** 畫面顯示「設定」大標題
- **AND** 依序顯示四個分區：管理、偏好設定、資料、關於
- **AND** 每個分區的卡片呈現 Liquid Glass 效果（cornerRadius 16）
- **AND** 各分區間距 24pt，section 標題與卡片間距 6pt

---

### Requirement: 管理分區 UI

管理分區 SHALL 包含四個導航列。每列結構為 `HStack`（`justifyContent: spaceBetween`），padding 垂直 14pt、水平 16pt：

- **左側** `HStack(spacing: 12)`：SF Symbol 圖示（22×22, `.symbolRenderingMode(.hierarchical)`）+ 標籤文字（`.body` 17pt, `Color.Design.textPrimary`）
- **右側**：`chevron.right` SF Symbol（20×20, `Color.Design.textTertiary`）

圖示顏色依設計稿指定：

| 列 | SF Symbol | 圖示顏色 |
|----|-----------|---------|
| 帳戶管理 | `wallet.bifold` | `Color.Design.brandPrimary` |
| 分類管理 | `square.grid.2x2` | `Color.Design.brandSecondary` |
| 預算設定 | `banknote` | `Color.Design.incomeGreen` |
| 標籤管理 | `tag` | `Color.Design.brandAccent` |

#### Scenario: 點擊管理列

- **WHEN** 使用者點擊管理分區的任一列（帳戶管理 / 分類管理 / 預算設定 / 標籤管理）
- **THEN** 觸發對應的 `delegate` Action（`.navigateToAccounts` / `.navigateToCategories` / `.navigateToBudgets` / `.navigateToTags`）
- **AND** 子頁面導航由 `MainTabFeature` 負責處理（本 change 暫時 `.none`）

---

### Requirement: 偏好設定分區 UI

偏好設定分區 SHALL 包含三列，每列 padding 垂直 14pt、水平 16pt，左側 `HStack(spacing: 12)` 含 SF Symbol（22×22）+ 標籤（`.body` 17pt, `Color.Design.textPrimary`）：

1. **預設帳戶**：`creditcard` 圖示（`Color.Design.textSecondary`）+ 標籤，右側顯示當前帳戶名稱（`.body` 17pt, `Color.Design.textSecondary`），初始值由 `accountClient.fetchActive()` 第一筆提供
2. **語言**：`globe` 圖示（`Color.Design.textSecondary`）+ 標籤，右側顯示「繁體中文」靜態文字（`.body` 17pt, `Color.Design.textSecondary`）
3. **AI 智慧功能**：`sparkles` 圖示（`Color.Design.brandPrimary`）+ 標籤，右側為 `Toggle`，`.tint(Color.Design.incomeGreen)`

#### Scenario: 畫面載入時讀取 AI Toggle 狀態

- **WHEN** `SettingsFeature` 執行 `.task` Effect
- **THEN** 從 `userSettingsClient.bool(.aiEnabled)` 讀取當前值
- **AND** 更新 `State.isAIEnabled`，`ToggleView` 反映該狀態

#### Scenario: 切換 AI 智慧功能 Toggle

- **WHEN** 使用者切換 AI 智慧功能 Toggle
- **THEN** 立即呼叫 `userSettingsClient.setBool(newValue, .aiEnabled)` 持久化
- **AND** UI Toggle 狀態即時更新（無需 reload）

#### Scenario: 畫面載入時顯示預設帳戶名稱

- **WHEN** `SettingsFeature` 執行 `.task` Effect
- **THEN** 呼叫 `accountClient.fetchActive()` 取第一筆帳戶名稱
- **AND** 若有帳戶則顯示帳戶名稱，若無則顯示「無」

---

### Requirement: 資料分區 UI

資料分區 SHALL 包含兩個動作列，每列 padding 垂直 14pt、水平 16pt，左側 `HStack(spacing: 12)` 含 SF Symbol（22×22）+ 標籤（`.body` 17pt），右側為 `chevron.right`（20×20, `Color.Design.textTertiary`）。

| 列 | SF Symbol | 圖示顏色 |
|----|-----------|---------|
| 匯出 CSV | `square.and.arrow.down` | `Color.Design.textSecondary` |
| 匯出 JSON | `tablecells` | `Color.Design.textSecondary` |

#### Scenario: 點擊匯出列

- **WHEN** 使用者點擊「匯出 CSV」或「匯出 JSON」
- **THEN** 觸發對應 Action（`.exportCSVTapped` / `.exportJSONTapped`）
- **AND** 本 change 中該 Action 僅 log，不執行實際匯出邏輯

---

### Requirement: 關於分區 UI

關於分區 SHALL 包含兩列，每列 padding 垂直 14pt、水平 16pt，左側 `HStack(spacing: 12)` 含 SF Symbol（22×22）+ 標籤（`.body` 17pt, `Color.Design.textPrimary`）：

1. **版本**：`info.circle` 圖示（`Color.Design.textSecondary`）+ 「版本」標籤，右側顯示從 `Bundle.main.infoDictionary["CFBundleShortVersionString"]` 讀取的版本號（`.body` 17pt, `Color.Design.textTertiary`），若讀取失敗則顯示「—」
2. **隱私權政策**：`doc.text` 圖示（`Color.Design.textSecondary`）+ 標籤，右側為 `chevron.right`（20×20, `Color.Design.textTertiary`）

#### Scenario: 版本號顯示

- **WHEN** 使用者進入設定畫面
- **THEN** 版本號顯示 `CFBundleShortVersionString` 的值（如「1.0.0」）
- **AND** 若無法讀取則顯示「—」

#### Scenario: 點擊隱私權政策

- **WHEN** 使用者點擊「隱私權政策」列
- **THEN** 觸發 `.privacyPolicyTapped` Action（本 change 暫時 `.none`）

---

### Requirement: SettingsFeature TCA 整合

`SettingsFeature` SHALL 作為 `MainTabFeature` 的子 Reducer，透過 `Scope` 組合。`MainTabFeature.State` MUST 新增 `settings: SettingsFeature.State`，`MainTabFeature.Action` MUST 新增 `settings(SettingsFeature.Action)` case。`MainTabView` Settings Tab MUST 改用 `SettingsView(store:)` 取代現有 `PlaceholderView`。

#### Scenario: SettingsFeature 正確接入

- **WHEN** 使用者切換至設定 Tab
- **THEN** `SettingsView` 正常渲染（不 crash）
- **AND** `SettingsFeature` 的 `.task` Effect 正確執行（載入帳戶名稱、AI Toggle 狀態）

#### Scenario: SettingsKey.aiEnabled 定義

- **WHEN** 程式碼在 `Domain/Clients/UserSettingsClient.swift` 的 `Bool` extension 加入 `.aiEnabled`
- **THEN** `SettingsKey<Bool>.aiEnabled` 的 `rawValue` 為 `"aiEnabled"`，`defaultValue` 為 `true`
- **AND** 可被 `userSettingsClient.bool(_:)` 與 `userSettingsClient.setBool(_:_:)` 接受
