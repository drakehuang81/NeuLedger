## Why

As the user enters the `.main` state after completing the onboarding process in `AppView`, the app requires a primary navigation system. Incorporating the `GlobalTabBar` (a floating tab bar with a split design: `navCapsule` and `contextCapsule`) from the `neuledger-design-system` will provide a scalable and modern way for users to switch between the main functional areas of the app and perform global actions (e.g., Search).

## What Changes

- Introduce a new main navigation feature (`MainTabFeature`) managed by The Composable Architecture (TCA).
- Create a `MainTabView` that acts as the root view for the `.main` destination.
- Implement the split Floating TabBar UI containing `navCapsule` (for primary navigation tabs) and `contextCapsule` (for contextual global actions like search/add).
- Integrate `MainTabFeature` into the `AppFeature`'s `.main` destination.
- Set up initial placeholder pages for the integrated tabs to establish the routing mechanism.

## Capabilities

### New Capabilities
- `main-navigation`: The core routing and tab switching logic for the main app experience, including the UI implementation of the floating split tab bar.

### Modified Capabilities
- `app-routing`: Update the main app routing in `AppFeature` to correctly present the `MainTabView` when the application state transitions to `.main`.

## Impact

- **Features/AppView.swift**: Replaces the `Text("app_greeting")` placeholder with the newly created `MainTabView`.
- **Features/AppFeature.swift**: Update the state and action enums to handle the new tab-based navigation state.
- **New Feature Modules**: Introduction of `MainTabFeature` and `MainTabView` (or structurally similar ones based on the overall architecture).
- **UI Components**: Implementation of the custom floating tab bar component based on `neuledger-design-system.pen`.
