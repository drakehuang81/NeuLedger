## MODIFIED Requirements

### Requirement: Tab Navigation State Management
The application must maintain the currently selected tab using TCA state management, allowing deterministic tab switching.

#### Scenario: User navigates using the TabBar
- **WHEN** the user taps an inactive tab button in the `navCapsule`.
- **THEN** the `MainTabFeature` triggers an action to update its selected tab state.
- **AND** the visible main subview immediately switches to the corresponding feature (e.g., Dashboard, Accounts, Analysis, Settings) instead of a simple placeholder.

### Requirement: Navigation Payload and Deep Linking
The `MainTabFeature` MUST intercept delegate actions from its sub-features (e.g., `DashboardFeature`) and route the user to the correct tab.

#### Scenario: Dashboard requests full transaction list
- **WHEN** the `DashboardFeature` sends a `.delegate(.seeAllTransactionsTapped)` action
- **THEN** the `MainTabFeature` intercepts this action
- **AND** updates its selected tab state to point to the Transactions/Accounts list tab.
