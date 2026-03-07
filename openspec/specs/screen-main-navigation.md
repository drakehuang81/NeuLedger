# Spec: Screen - Main Navigation
**Purpose**: Define how the application routes between major flows like Onboarding and the Main Tab experience, and the floating TabBar behaviors.

## Requirements

### Requirement: Transition to Main Routing
The `AppView` must present the `MainTabView` when the application finishes onboarding or immediately launches into the `.main` state.

#### Scenario: App launches with `.main` state
- **WHEN** the `AppFeature`'s destination transitions to or starts with `.main` (after completing onboarding).
- **THEN** the `AppView` presents the `MainTabView` corresponding to the `MainTabFeature` scope.
- **AND** the transition matches the existing styling (e.g. opacity-based transition).

### Requirement: Display Custom Floating TabBar
The main routing view must present a custom floating split `TabBar` composed of `navCapsule` (primary navigation) and `contextCapsule` (global contextual action) over the main content without obscuring it permanently.

#### Scenario: Viewing the main screen
- **WHEN** the `MainTabView` is presented.
- **THEN** the custom floating `TabBar` is visible overlaying the content.
- **AND** safe-area insets are appropriately handled so inner scrollable content can be scrolled fully past the floating bar.

### Requirement: Tab Navigation State Management
The application must maintain the currently selected tab using TCA state management, allowing deterministic tab switching.

#### Scenario: User navigates using the TabBar
- **WHEN** the user taps an inactive tab button in the `navCapsule`.
- **THEN** the `MainTabFeature` triggers an action to update its selected tab state.
- **AND** the visible main subview immediately switches to the corresponding view.

#### Scenario: Tab 命名與順序
- **WHEN** `MainTabFeature.Tab` enum 被定義
- **THEN** 有效的 tab 值 SHALL 為：`.dashboard`、`.transactions`、`.analysis`、`.settings`
- **AND** `Tab.search` SHALL 不再存在（**BREAKING**，已由 `.transactions` 取代）
- **AND** `MainTabFeature.State` SHALL 包含 `transactions: TransactionsFeature.State` scope

### Requirement: Global Context Action Support
The `contextCapsule` portion of the `GlobalTabBar` must support global actions decoupled from the currently selected tab.

#### Scenario: Transactions tab 的 contextCapsule 動作
- **WHEN** 使用者切換至 Transactions tab 且點擊 `contextCapsule` 按鈕
- **THEN** 顯示圖示為 `plus`（加號）
- **AND** 點擊後觸發 `MainTabFeature.Action.contextActionTapped`
- **AND** `MainTabFeature` SHALL 將此動作轉發至 `TransactionsFeature`，開啟預設類型（`.expense`）的 `AddTransactionFeature` sheet

#### Scenario: Dashboard tab 的 contextCapsule 動作（維持不變）
- **WHEN** 使用者切換至 Dashboard tab 且點擊 `contextCapsule` 按鈕
- **THEN** 行為維持與現有實作一致（開啟 Dashboard 的新增交易 Sheet）
