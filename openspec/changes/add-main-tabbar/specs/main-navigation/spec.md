## ADDED Requirements

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
- **AND** the visible main subview immediately switches to the corresponding placeholder view.

### Requirement: Global Context Action Support
The `contextCapsule` portion of the `GlobalTabBar` must support global actions (like opening a search view or adding a record) that are decoupled from the currently selected tab.

#### Scenario: Activating a global context action
- **WHEN** the user taps the button (e.g. search icon) inside the `contextCapsule`.
- **THEN** the `MainTabFeature` receives a global action trigger.
- **AND** for this phase, the system confirms routing to a dummy action (e.g., printing a debug log).
