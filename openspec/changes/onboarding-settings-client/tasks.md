## 1. Domain 層 — SettingsKey 與 UserSettingsClient 介面

- [x] 1.1 在 `Features/Sources/Domain/Clients/` 建立 `UserSettingsClient.swift`，定義 `SettingsKey<Value>` 泛型 struct（含 `rawValue: String`、`defaultValue: Value`，遵循 `Sendable`）
- [x] 1.2 在同一檔案中新增 `SettingsKey<Bool>` constrained extension，定義 `static let hasCompletedOnboarding`（rawValue: `"hasCompletedOnboarding"`，defaultValue: `false`）
- [x] 1.3 在同一檔案中定義 `@DependencyClient public struct UserSettingsClient: Sendable`，包含 `bool: (SettingsKey<Bool>) -> Bool`（預設回傳 `defaultValue`）與 `setBool: (Bool, SettingsKey<Bool>) -> Void`
- [x] 1.4 在同一檔案中新增 `TestDependencyKey` conformance（`testValue`）與 `DependencyValues` extension（`\.userSettingsClient`）

## 2. Core 層 — UserSettingsClient Live 實作

- [x] 2.1 在 `Features/Sources/Core/Clients/` 建立 `UserSettingsClient+Live.swift`，提供 `DependencyKey.liveValue`，`bool` 委派至 `UserDefaults.standard.object(forKey:)` 搭配 defaultValue fallback、`setBool` 委派至 `UserDefaults.standard.set(_:forKey:)`

## 3. Features 層 — 重構 OnboardingFeature

- [x] 3.1 在 `OnboardingFeature` 中新增 `@Dependency(\.userSettingsClient) var userSettingsClient`
- [x] 3.2 將 `finishButtonTapped` 的 `.run { ... UserDefaults.standard.set ... }` 改為同步呼叫 `userSettingsClient.setBool(true, .hasCompletedOnboarding)` 後 `return .send(.delegate(.onboardingCompleted))`

## 4. Features 層 — 重構 RootView

- [x] 4.1 在 `RootView` 中移除 `@AppStorage("hasCompletedOnboarding")`，改為 `@Dependency(\.userSettingsClient) var userSettingsClient` + `@State private var hasCompletedOnboarding = false`
- [x] 4.2 新增 `.onAppear { hasCompletedOnboarding = userSettingsClient.bool(.hasCompletedOnboarding) }`，確保首次載入時從 Client 讀取狀態

## 5. 單元測試 — OnboardingFeature

- [x] 5.1 在 `Features/Tests/FeaturesTests/` 建立 `OnboardingFeatureTests.swift`，import `ComposableArchitecture` 與 `Testing`
- [x] 5.2 撰寫測試：`startButtonTapped` 將 `currentStep` 從 `.welcome` 變更為 `.accountSetup`
- [x] 5.3 撰寫測試：`nextButtonTapped` 將 `currentStep` 從 `.accountSetup` 變更為 `.ready`
- [x] 5.4 撰寫測試：`finishButtonTapped` 呼叫 `setBool(true, .hasCompletedOnboarding)` 並收到 `.delegate(.onboardingCompleted)`
- [x] 5.5 撰寫測試：binding 修改 `accountName` 正確更新狀態且無額外 Effect

## 6. 單元測試 — UserSettingsClient

- [x] 6.1 在 `Features/Tests/FeaturesTests/DomainTests/` 建立 `UserSettingsClientTests.swift`
- [x] 6.2 撰寫測試：驗證 `SettingsKey.hasCompletedOnboarding` 的 `rawValue` 與 `defaultValue` 正確
- [x] 6.3 撰寫測試：驗證 `UserSettingsClient.testValue` 的 `bool` 方法回傳 defaultValue

## 7. 驗證與清理

- [x] 7.1 執行完整 build 確認無編譯錯誤
- [x] 7.2 執行所有單元測試確認通過
- [x] 7.3 在模擬器上手動驗證 onboarding 流程（首次啟動顯示 onboarding → 完成後顯示主畫面 → 重啟仍為主畫面）
