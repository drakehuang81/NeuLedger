## ADDED Requirements

### Requirement: AppFeature Reducer 狀態定義
系統 SHALL 定義 `AppFeature` 作為應用程式根層級的 TCA `@Reducer`，使用 `enum Destination` 管理路由目的地。

#### Scenario: Destination 列舉定義
- **WHEN** `AppFeature` 被定義
- **THEN** SHALL 包含 `enum Destination: Equatable` 列舉，具有以下 case：
  - `.onboarding(OnboardingFeature.State)` — 代表 Onboarding 流程
  - `.main` — 代表主畫面（未來將替換為 TabFeature.State）

#### Scenario: State 結構定義
- **WHEN** `AppFeature.State` 被初始化
- **THEN** SHALL 包含 `var destination: Destination` 屬性
- **AND** State SHALL 標註 `@ObservableState` 並遵循 `Equatable`

---

### Requirement: AppFeature 初始路由判斷
`NeuLedgerApp`（`@main`）SHALL 在建立 `Store` 時根據 `userSettingsClient` 決定初始路由。

#### Scenario: 首次啟動進入 Onboarding
- **WHEN** `userSettingsClient.bool(.hasCompletedOnboarding)` 回傳 `false`
- **THEN** `AppFeature.State` 的 `destination` SHALL 被初始化為 `.onboarding(OnboardingFeature.State())`

#### Scenario: 非首次啟動直接進入主畫面
- **WHEN** `userSettingsClient.bool(.hasCompletedOnboarding)` 回傳 `true`
- **THEN** `AppFeature.State` 的 `destination` SHALL 被初始化為 `.main`

---

### Requirement: OnboardingFeature 子 Feature 組合
`AppFeature` SHALL 使用 TCA 的 `ifCaseLet` 將 `OnboardingFeature` 作為 child feature 組合。

#### Scenario: Onboarding 狀態為當前 destination 時
- **WHEN** `destination` 為 `.onboarding`
- **THEN** `OnboardingFeature` reducer SHALL 被執行
- **AND** `OnboardingFeature` 的所有 action 都 SHALL 正確派送

#### Scenario: 離開 Onboarding 後 child reducer 不再執行
- **WHEN** `destination` 切換為 `.main`
- **THEN** `OnboardingFeature` reducer SHALL 不再接收 action
- **AND** Onboarding 狀態 SHALL 被丟棄

---

### Requirement: Onboarding 完成委派處理
`AppFeature` SHALL 攔截 `OnboardingFeature.Delegate.onboardingCompleted` action 並完成路由切換。

#### Scenario: Onboarding 完成後切換至主畫面
- **WHEN** `AppFeature` 收到 `.onboarding(.delegate(.onboardingCompleted))` action
- **THEN** `destination` SHALL 變為 `.main`

---

### Requirement: AppFeature Action 定義
`AppFeature` SHALL 定義清晰的 Action enum 以處理子 Feature 委派。

#### Scenario: Action 列舉結構
- **WHEN** `AppFeature.Action` 被定義
- **THEN** SHALL 至少包含以下 case：
  - `.onboarding(OnboardingFeature.Action)` — 轉發 OnboardingFeature action

---

### Requirement: AppView Store-Driven 渲染
`AppView` SHALL 接收 `StoreOf<AppFeature>` 並根據 `destination` 狀態渲染對應畫面。

#### Scenario: 渲染 Onboarding 畫面
- **WHEN** `store.destination` 為 `.onboarding`
- **THEN** AppView SHALL 透過 `store.scope(state:action:)` 衍生子 Store
- **AND** SHALL 將子 Store 傳遞給 `OnboardingView`

#### Scenario: 渲染主畫面
- **WHEN** `store.destination` 為 `.main`
- **THEN** AppView SHALL 顯示主畫面內容（暫為 placeholder）

#### Scenario: 轉場動畫
- **WHEN** `destination` 從 `.onboarding` 變為 `.main`
- **THEN** 畫面切換 SHALL 包含轉場動畫效果

---

### Requirement: NeuLedgerApp 頂層 Store 建立
`NeuLedgerApp`（`@main`）SHALL 建立 `Store<AppFeature>` 作為唯一的頂層 Store。

#### Scenario: Store 建立與注入
- **WHEN** App 啟動
- **THEN** `NeuLedgerApp` SHALL 建立 `Store(initialState:reducer:)` 並注入 `AppView`
- **AND** SHALL 不再在 View 層直接持有 `@Dependency`（`userSettingsClient`、`accountClient`、`categoryClient`）

---

### Requirement: 檔案結構
`AppFeature` 和 `AppView` 的檔案 SHALL 遵循 `architecture-blueprint` 規範的擺放位置。

#### Scenario: 檔案路徑定義
- **WHEN** 專案結構被檢視
- **THEN** 以下檔案 SHALL 存在：
  - `Features/Sources/Features/AppFeature.swift` — AppFeature Reducer 定義
  - `Features/Sources/Features/AppView.swift` — AppView（原 RootView.swift 重新命名）
