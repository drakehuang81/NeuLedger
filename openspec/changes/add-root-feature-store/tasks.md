## 1. AppFeature Reducer 建立

- [ ] 1.1 建立 `Features/Sources/Features/AppFeature.swift`，定義 `@Reducer struct AppFeature`
- [ ] 1.2 定義 `enum Destination: Equatable`，包含 `.onboarding(OnboardingFeature.State)` 和 `.main` 兩個 case
- [ ] 1.3 定義 `@ObservableState struct State: Equatable`，包含 `var destination: Destination`
- [ ] 1.4 定義 `enum Action`，包含 `.onboarding(OnboardingFeature.Action)` case
- [ ] 1.5 實作 `body` Reducer，使用 `.ifCaseLet(\.destination.onboarding, action: \.onboarding)` 組合 `OnboardingFeature`

## 2. Delegate Action 處理

- [ ] 2.1 在 `AppFeature.body` 的 `Reduce` 中攔截 `.onboarding(.delegate(.onboardingCompleted))`，將 `state.destination` 設為 `.main`
- [ ] 2.2 確保其他 `.onboarding` action 回傳 `.none`（由 child reducer 處理）

## 3. RootView → AppView 重構

- [ ] 3.1 將 `RootView.swift` 重新命名為 `AppView.swift`（`git mv`）
- [ ] 3.2 將 `struct RootView` 重新命名為 `struct AppView`
- [ ] 3.3 移除 `AppView` 中的 `@Dependency` 屬性（`userSettingsClient`、`accountClient`、`categoryClient`）
- [ ] 3.4 移除 `@State private var hasCompletedOnboarding` 及相關 `.onAppear` 邏輯
- [ ] 3.5 新增 `@Bindable var store: StoreOf<AppFeature>` 屬性
- [ ] 3.6 實作 `body`：根據 `store.destination` 使用 `switch` 渲染
- [ ] 3.7 `.onboarding` case 使用 `store.scope(state:action:)` 衍生子 Store 傳給 `OnboardingView`
- [ ] 3.8 `.main` case 暫時顯示 placeholder 內容
- [ ] 3.9 加入轉場動畫（`.animation` + `.transition`）讓 destination 切換有視覺過渡效果

## 4. NeuLedgerApp 入口更新

- [ ] 4.1 在 `NeuLedgerApp` 中移除直接的 `@Dependency(\.databaseClient)` 用法（或保留僅供 `.modelContainer` 使用）
- [ ] 4.2 建立頂層 `Store(initialState:reducer:)`，根據 `userSettingsClient.bool(.hasCompletedOnboarding)` 決定初始 `Destination`
- [ ] 4.3 將 `Store` 注入 `AppView(store:)`
- [ ] 4.4 確認 `.modelContainer` 仍正確設定

## 5. 驗證與測試

- [ ] 5.1 確認專案可編譯成功（`swift build` 或 Xcode Build）
- [ ] 5.2 首次啟動（未完成 Onboarding）：確認顯示 Onboarding 流程
- [ ] 5.3 完成 Onboarding：確認畫面自動切換至主畫面
- [ ] 5.4 非首次啟動：確認直接進入主畫面
- [ ] 5.5 （可選）新增 `AppFeatureTests`，使用 `TestStore` 驗證 delegate action 處理與路由切換
