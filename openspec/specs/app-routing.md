# Spec: App Routing

## Purpose
Define how the application routes between major flows like Onboarding and the Main Tab experience.

## Requirements

### Requirement: Transition to Main Routing
The `AppView` must present the `MainTabView` when the application finishes onboarding or immediately launches into the `.main` state. (Replacing the current placeholder `Text("app_greeting")`).

#### Scenario: App launches with `.main` state
- **WHEN** the `AppFeature`'s destination transitions to or starts with `.main` (after completing onboarding).
- **THEN** the `AppView` presents the `MainTabView` corresponding to the `MainTabFeature` scope.
- **AND** the transition matches the existing styling (e.g. opacity-based transition).

### Requirement: Splash Routing Initialization
The application MUST initialize its starting state asynchronously in the `.splash` state.

#### Scenario: App Initialization
- **WHEN** the `AppView` appears
- **THEN** it sends a `.onAppear` action to `AppFeature`
- **AND** the `AppFeature` determines whether to route to `.main` or `.onboarding` based on `hasCompletedOnboarding`
- **AND** for testability, this logic MUST be contained within the Reducer's action handler, not the state initializer.
