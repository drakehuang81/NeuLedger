## ADDED Requirements

### Requirement: SettingsKey 型別安全 key 定義
系統 SHALL 提供泛型 `SettingsKey<Value>` 結構，用於定義 UserDefaults 的 key。每個 `SettingsKey` MUST 包含 `rawValue: String`（對應 UserDefaults key）與 `defaultValue: Value`（當 key 不存在時的預設值）。`SettingsKey` MUST 遵循 `Sendable` 協議。

#### Scenario: 定義 Bool 型別的 key
- **WHEN** 透過 constrained extension 定義 `SettingsKey<Bool>` 的靜態屬性（如 `.hasCompletedOnboarding`）
- **THEN** 該屬性 MUST 可被 `UserSettingsClient` 的 Bool 相關方法接受，且帶有明確的 `rawValue` 與 `defaultValue`

#### Scenario: 未來擴充其他型別
- **WHEN** 需要儲存 `String`、`Int` 或 `Data` 等型別的設定值
- **THEN** 只需新增對應的 `SettingsKey` constrained extension 與 `UserSettingsClient` 方法即可，無需修改既有程式碼

### Requirement: UserSettingsClient 泛型讀寫介面
系統 SHALL 提供 `UserSettingsClient` 作為 `@DependencyClient`，定義型別安全的 key-value 讀寫介面。初始版本 MUST 支援 Bool 型別的讀取與寫入操作。

#### Scenario: 讀取 Bool 值 — key 存在
- **WHEN** 呼叫 `userSettingsClient.bool(.hasCompletedOnboarding)` 且該 key 已被寫入 `true`
- **THEN** MUST 回傳 `true`

#### Scenario: 讀取 Bool 值 — key 不存在
- **WHEN** 呼叫 `userSettingsClient.bool(.hasCompletedOnboarding)` 且該 key 從未被寫入
- **THEN** MUST 回傳 `SettingsKey.hasCompletedOnboarding.defaultValue`（即 `false`）

#### Scenario: 寫入 Bool 值
- **WHEN** 呼叫 `userSettingsClient.setBool(true, .hasCompletedOnboarding)`
- **THEN** 後續呼叫 `userSettingsClient.bool(.hasCompletedOnboarding)` MUST 回傳 `true`

### Requirement: UserSettingsClient TCA Dependency 註冊
`UserSettingsClient` MUST 透過 `DependencyValues` extension 註冊為 `\.userSettingsClient`，並提供 `TestDependencyKey` 的 `testValue`，使測試環境可自動取得未實作的預設值。

#### Scenario: 在 TCA Reducer 中注入
- **WHEN** 在 Reducer 中宣告 `@Dependency(\.userSettingsClient) var userSettingsClient`
- **THEN** 正式環境 MUST 使用 Live 實作（UserDefaults），測試環境 MUST 使用 test value

#### Scenario: 測試環境中 override
- **WHEN** 在 `TestStore` 中透過 `withDependencies` override `userSettingsClient`
- **THEN** Reducer 中使用的 MUST 是被 override 的實作

### Requirement: UserSettingsClient Live 實作
Core 層 MUST 提供 `UserSettingsClient` 的 `DependencyKey.liveValue`，底層委派給 `UserDefaults.standard`。

#### Scenario: Live 環境下讀取 Bool
- **WHEN** 呼叫 `bool(.hasCompletedOnboarding)` 且 `UserDefaults.standard` 中 `"hasCompletedOnboarding"` 為 `true`
- **THEN** MUST 回傳 `true`

#### Scenario: Live 環境下寫入 Bool
- **WHEN** 呼叫 `setBool(true, .hasCompletedOnboarding)`
- **THEN** `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")` MUST 為 `true`

### Requirement: RootView 透過 UserSettingsClient 讀取 onboarding 狀態
`RootView` MUST 移除 `@AppStorage("hasCompletedOnboarding")`，改為透過 `@Dependency(\.userSettingsClient)` 讀取 onboarding 完成狀態。

#### Scenario: 首次啟動 — 尚未完成 onboarding
- **WHEN** `userSettingsClient.bool(.hasCompletedOnboarding)` 回傳 `false`
- **THEN** `RootView` MUST 顯示 `OnboardingView`

#### Scenario: 已完成 onboarding
- **WHEN** `userSettingsClient.bool(.hasCompletedOnboarding)` 回傳 `true`
- **THEN** `RootView` MUST 顯示主畫面內容

### Requirement: OnboardingFeature 透過 UserSettingsClient 寫入完成狀態
`OnboardingFeature` Reducer MUST 移除直接的 `UserDefaults.standard.set` 呼叫，改為透過注入的 `UserSettingsClient` 寫入 onboarding 完成狀態。

#### Scenario: 使用者完成 onboarding 流程
- **WHEN** 使用者觸發 `finishButtonTapped` action
- **THEN** Reducer MUST 呼叫 `userSettingsClient.setBool(true, .hasCompletedOnboarding)` 並發送 `.delegate(.onboardingCompleted)` action

### Requirement: OnboardingFeature 步驟流程
`OnboardingFeature` Reducer MUST 管理三個步驟的線性流程：`welcome` → `accountSetup` → `ready`。

#### Scenario: 開始按鈕 — 從 welcome 到 accountSetup
- **WHEN** 狀態為 `.welcome` 且收到 `startButtonTapped` action
- **THEN** 狀態 MUST 變更為 `.accountSetup`

#### Scenario: 下一步按鈕 — 從 accountSetup 到 ready
- **WHEN** 狀態為 `.accountSetup` 且收到 `nextButtonTapped` action
- **THEN** 狀態 MUST 變更為 `.ready`

#### Scenario: Binding 不影響步驟
- **WHEN** 收到 `binding` action（如修改 `accountName`）
- **THEN** `currentStep` MUST 不變，且不產生任何 Effect

### Requirement: OnboardingFeature 單元測試
MUST 為 `OnboardingFeature` Reducer 提供完整的單元測試覆蓋，使用 TCA 的 `TestStore` 搭配 mock 的 `UserSettingsClient`。

#### Scenario: 測試完整 onboarding 流程
- **WHEN** 依序發送 `startButtonTapped` → `nextButtonTapped` → `finishButtonTapped`
- **THEN** 狀態 MUST 依序變更為 `.accountSetup` → `.ready`，且 `finishButtonTapped` MUST 觸發 `userSettingsClient.setBool(true, .hasCompletedOnboarding)` 並收到 `.delegate(.onboardingCompleted)`

#### Scenario: 測試 binding 行為
- **WHEN** 透過 binding 修改 `accountName` 為 "銀行帳戶"
- **THEN** `state.accountName` MUST 更新為 "銀行帳戶"，且無額外 Effect

#### Scenario: 測試 UserSettingsClient 被正確呼叫
- **WHEN** `finishButtonTapped` 被觸發
- **THEN** 測試 MUST 驗證 `setBool` 被呼叫，參數為 `(true, .hasCompletedOnboarding)`
