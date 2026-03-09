## MODIFIED Requirements

### Requirement: Stack-Based Navigation in Settings
`SettingsFeature` SHALL adopt TCA's stack-based navigation pattern to support push navigation to management sub-screens.

#### Scenario: Navigation architecture
- **WHEN** implementing navigation from Settings to sub-screens
- **THEN** `SettingsFeature.State` SHALL include `path: StackState<Path.State>` where `Path` is a nested `@Reducer` composing `AccountManagementFeature`, `CategoryManagementFeature`, and `TagManagementFeature`
- **AND** `SettingsFeature.Action` SHALL include `path(StackActionOf<Path>)` in place of the current delegate-based navigation actions
- **AND** `SettingsView` SHALL be wrapped in `NavigationStack(path: $store.scope(state: \.path, action: \.path))`
- **AND** the existing delegate actions (`navigateToAccounts`, `navigateToCategories`, `navigateToBudgets`, `navigateToTags`) and their `Delegate` enum SHALL be replaced by direct `state.path.append` mutations
- **AND** the corresponding dead delegate handling in `MainTabFeature` SHALL be removed

## ADDED Requirements

### Requirement: Data Management Navigation Section
Provide navigation access to core data settings for configuring Accounts, Categories, and Tags independently.

#### Scenario: Accessing Management Views
- **WHEN** the user views the main Settings screen
- **THEN** the existing "管理" section SHALL contain tappable rows that push the management screens onto the navigation stack via `store.send(.path(.push(...)))`
- **AND** the rows for Account, Category, and Tag management SHALL push their respective management screens
- **AND** the "預算設定" row SHALL remain as-is (placeholder for future budget management change)
