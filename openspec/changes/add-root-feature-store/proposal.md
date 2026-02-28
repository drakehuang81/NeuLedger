## Why

目前 `RootView` 直接使用 `@Dependency` 和 `@State` 來管理應用程式的路由邏輯（Onboarding vs 主畫面），完全繞過了 TCA 狀態管理。這違反了專案「所有 Feature 皆使用 `@Reducer` 管理狀態」的架構原則。隨著後續需求增加（NavigationStack/Path 管理、Deep Link 處理、應用層級狀態協調），缺少統一的 App Store 將導致邏輯碎片化且難以測試。

## What Changes

- 新增 `AppFeature` Reducer，作為應用程式最頂層的 TCA 狀態管理中心
- `AppFeature` 使用 TCA 的 child feature composition 持有 `OnboardingFeature` 子狀態
- 將路由判斷邏輯（`hasCompletedOnboarding` 讀取與切換）從 View 層移至 `AppFeature` Reducer
- `RootView` 重新命名為 `AppView`，改為接收 `StoreOf<AppFeature>` 並透過 Store 驅動畫面切換
- `NeuLedgerApp`（`@main`）負責建立頂層 `Store(initialState:reducer:)` 並注入 `AppView`
- 處理 `OnboardingFeature.Delegate.onboardingCompleted` action，在 App 層級完成路由切換
- 為未來 NavigationStack/Path、Deep Link、TabView 整合預留擴展點

## Capabilities

### New Capabilities
- `app-feature-store`: 應用程式根層級的 TCA Reducer（`AppFeature`），負責管理 App 啟動後的路由決策（Onboarding / Main）、子 Feature 組合、以及未來的導航狀態管理

### Modified Capabilities
- `onboarding-flow`: RootView 條件顯示的需求將改由 `AppFeature` 驅動，Onboarding 的 delegate action 處理邏輯移至 `AppFeature`

## Impact

- **`RootView.swift`**: 重新命名為 `AppView.swift`，重構為純粹的 TCA Store-driven View，移除直接的 `@Dependency` 和 `@State` 用法
- **`OnboardingFeature.swift`**: 無程式碼變動，但其 delegate action 的消費者將從 View 改為 `AppFeature`
- **新增檔案**: `AppFeature.swift`（放置於 `Features/Sources/Features/`，與 `AppView.swift` 同層）
- **測試**: 可新增 `AppFeatureTests` 驗證路由判斷邏輯與 delegate action 處理
- **無破壞性改動**: 對外行為不變，純為內部架構重構
