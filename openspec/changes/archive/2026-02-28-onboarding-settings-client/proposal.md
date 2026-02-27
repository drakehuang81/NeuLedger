## Why

`RootView` 目前直接使用 `@AppStorage("hasCompletedOnboarding")` 讀取 UserDefaults，而 `OnboardingFeature` 的 `finishButtonTapped` 也直接呼叫 `UserDefaults.standard.set(true, forKey:)`。這種做法有兩個問題：

1. **違反 Clean Architecture 慣例**：專案既有模式以「Domain 定義介面 → Core 提供實作」（如 `AccountClient` / `AccountClient+Live`），但 UserDefaults 的存取未遵循此慣例。
2. **無法測試及隔離**：直接耦合 UserDefaults 導致 `OnboardingFeature` 無法被單元測試，且未來其他功能若也使用 UserDefaults（如使用者偏好、主題設定等），將面臨同樣的耦合問題。

解決方式是建立一個**泛型的 `UserSettingsClient`**，搭配型別安全的 `SettingsKey<Value>` Model 來定義 keys。不需為每個功能建立獨立的 wrapper client，所有功能統一透過 `UserSettingsClient` + 對應的 `SettingsKey` 來操作 UserDefaults。

## What Changes

- **新增** `SettingsKey<Value>` Model（Domain 層）：泛型 key 定義，帶有 `rawValue: String` 與 `defaultValue: Value`，透過 constrained extension 集中定義各 key（如 `.hasCompletedOnboarding`）。
- **新增** `UserSettingsClient`（Domain 層）：泛型的 key-value 讀寫介面，提供 `bool(SettingsKey<Bool>) -> Bool` / `setBool(Bool, SettingsKey<Bool>) -> Void` 等型別安全方法，作為 `@DependencyClient`。未來可擴充 `string`、`int`、`data` 等型別。
- **新增** `UserSettingsClient+Live`（Core 層）：Live 實作，底層委派給 `UserDefaults.standard`。
- **重構** `RootView`：移除 `@AppStorage`，改用 `@Dependency(\.userSettingsClient)` 搭配 `.hasCompletedOnboarding` key 讀取 onboarding 狀態。
- **重構** `OnboardingFeature`：移除直接 `UserDefaults.standard` 呼叫，改透過 `userSettingsClient.setBool(true, .hasCompletedOnboarding)` 寫入完成狀態。
- **新增** `OnboardingFeatureTests`：針對 `OnboardingFeature` Reducer 的所有 Action（`startButtonTapped`、`nextButtonTapped`、`finishButtonTapped`）及 Delegate 行為撰寫單元測試，透過 mock `UserSettingsClient` 驗證寫入行為。
- **新增** `UserSettingsClientTests`：驗證 `SettingsKey` 定義與 Client 的 test value 行為。

## Capabilities

### New Capabilities

- `user-settings`: 通用的泛型 UserDefaults 存取抽象。涵蓋 `SettingsKey<Value>` 型別安全 key Model、`UserSettingsClient` Domain 介面定義、Core live 實作、test value 預設、以及 `RootView` 和 `OnboardingFeature` 對此 Client 的整合與單元測試。

### Modified Capabilities

（無現有 spec 需修改）

## Impact

- **Domain 層** (`Features/Sources/Domain/`)：
  - 新增 `Clients/UserSettingsClient.swift`（含 `SettingsKey<Value>` 定義）
- **Core 層** (`Features/Sources/Core/Clients/`)：
  - 新增 `UserSettingsClient+Live.swift`
- **Features 層** (`Features/Sources/Features/`)：
  - `RootView.swift`：移除 `@AppStorage`，改用 `UserSettingsClient`
  - `Onboarding/OnboardingFeature.swift`：移除直接 UserDefaults 呼叫，改用 `UserSettingsClient`
- **Tests** (`Features/Tests/FeaturesTests/`)：
  - 新增 `FeaturesTests/OnboardingFeatureTests.swift`
  - 新增 `DomainTests/UserSettingsClientTests.swift`（或 `CoreTests/`）
- **無 Breaking Change**：不影響既有 API 或模組公開介面
