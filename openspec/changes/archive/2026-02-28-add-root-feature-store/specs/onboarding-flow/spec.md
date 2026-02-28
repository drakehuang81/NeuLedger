## MODIFIED Requirements

### Requirement: RootView 條件顯示
`AppView`（原 `RootView`）SHALL 根據 `AppFeature.State.destination` 決定顯示 Onboarding 或主畫面，不再直接讀取 `userSettingsClient`。

#### Scenario: 首次啟動顯示 Onboarding
- **WHEN** App 啟動且 `AppFeature.State.destination` 為 `.onboarding`
- **THEN** `AppView` SHALL 顯示 `OnboardingView`
- **AND** SHALL 透過 `store.scope` 衍生子 Store 傳給 `OnboardingView`
- **AND** SHALL 不顯示主畫面內容

#### Scenario: Onboarding 完成後顯示主畫面
- **WHEN** `AppFeature` 收到 `.onboarding(.delegate(.onboardingCompleted))` action
- **THEN** `destination` SHALL 變為 `.main`
- **AND** `AppView` SHALL 自動切換至主畫面

#### Scenario: 非首次啟動直接進入主畫面
- **WHEN** App 啟動且 `AppFeature.State.destination` 為 `.main`
- **THEN** `AppView` SHALL 直接顯示主畫面
- **AND** SHALL 不顯示 `OnboardingView`
