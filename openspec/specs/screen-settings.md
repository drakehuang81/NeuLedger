# Spec: Screen - Settings
**Purpose**: Define the Settings view structure, user preferences logic, client implementations, and data export.

## Requirements

### Requirement: 設定偏好（Preferences UI）

#### Scenario: 可設定項目
- **WHEN** 使用者前往設定
- **THEN** 提供以下偏好設定：
    - **預設帳戶**：新增交易時的預設帳戶（Picker）
    - **語言**：zh-Hant / en（Picker — 影響 AI 輸出語言）
    - **AI 自動分類**：開/關（Toggle）
    - **AI 支出洞察**：開/關（Toggle）

#### Scenario: 偏好儲存機制
- **WHEN** 使用者更改偏好
- **THEN** 立即持久化（透過 `UserSettingsClient`）
- **AND** 下次 App 啟動時保持不變

### Requirement: 資料匯出（Data Export）

#### Scenario: 匯出為 CSV
- **WHEN** 使用者在設定 → 資料 → 匯出 CSV
- **THEN** 匯出所有交易為 CSV 檔案
- **AND** 欄位順序：日期, 類型, 分類, 備註, 金額, 帳戶, 標籤
- **AND** 日期格式：`yyyy/MM/dd`
- **AND** 金額：支出為負數、收入為正數
- **AND** 標籤以逗號分隔
- **AND** 使用系統 Share Sheet 分享檔案

#### Scenario: 匯出為 JSON
- **WHEN** 使用者在設定 → 資料 → 匯出 JSON
- **THEN** 匯出所有交易為 JSON 檔案
- **AND** 包含完整資料結構（ID、所有欄位、關聯 ID）
- **AND** 使用系統 Share Sheet 分享檔案

### Requirement: SettingsKey 型別安全 key 定義
系統 SHALL 提供泛型 `SettingsKey<Value>` 結構，用於定義 UserDefaults 的 key。每個 `SettingsKey` MUST 包含 `rawValue: String`（對應 UserDefaults key）與 `defaultValue: Value`（當 key 不存在時的預設值）。`SettingsKey` MUST 遵循 `Sendable` 協議。

#### Scenario: 定義 Bool 型別的 key
- **WHEN** 透過 constrained extension 定義 `SettingsKey<Bool>` 的靜態屬性（如 `.hasCompletedOnboarding`）
- **THEN** 該屬性 MUST 可被 `UserSettingsClient` 的 Bool 相關方法接受，且帶有明確的 `rawValue` 與 `defaultValue`

### Requirement: UserSettingsClient 泛型讀寫介面
系統 SHALL 提供 `UserSettingsClient` 作為 `@DependencyClient`，定義型別安全的 key-value 讀寫介面。初始版本 MUST 支援 Bool 型別的讀取與寫入操作。

#### Scenario: Live 環境下讀取與寫入
- **WHEN** 呼叫 `bool` 且 `UserDefaults` 中有資料
- **THEN** MUST 回傳該資料；若無，回傳 `SettingsKey.defaultValue`
- **WHEN** 呼叫 `setBool`
- **THEN** 寫入 `UserDefaults`

### Requirement: UserSettingsClient TCA Dependency 註冊
`UserSettingsClient` MUST 透過 `DependencyValues` extension 註冊為 `\.userSettingsClient`，並提供 `TestDependencyKey` 的 `testValue`，使測試環境可自動取得未實作的預設值。
