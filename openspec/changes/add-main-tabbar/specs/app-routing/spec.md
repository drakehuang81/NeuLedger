## MODIFIED Requirements

### Requirement: Transition to Main Routing
The `AppView` must present the `MainTabView` when the application finishes onboarding or immediately launches into the `.main` state. (Replacing the current placeholder `Text("app_greeting")`).

#### Scenario: App launches with `.main` state
- **WHEN** the `AppFeature`'s destination transitions to or starts with `.main` (after completing onboarding).
- **THEN** the `AppView` presents the `MainTabView` corresponding to the `MainTabFeature` scope.
- **AND** the transition matches the existing styling (e.g. opacity-based transition).
