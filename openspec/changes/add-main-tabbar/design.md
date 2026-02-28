## Context

The `AppView` currently handles navigation between `.onboarding` and `.main`, but the `.main` state is just a placeholder (`Text("app_greeting")`). Based on the `neuledger-design-system.pen`, we need a floating tab bar (`GlobalTabBar`) containing two distinct parts: a `navCapsule` for primary navigation tabs, and a `contextCapsule` for contextual global actions (like search or add). The application uses The Composable Architecture (TCA) and SwiftUI.

## Goals / Non-Goals

**Goals:**
- Implement `MainTabFeature` using TCA to manage the state of the selected tab.
- Implement the split Floating TabBar UI (`navCapsule` and `contextCapsule`) matching the design system specifications (glassmorphism/background blur, specific padding and corner radii).
- Integrate `MainTabView` into `AppView` for the `.main` destination.
- Create placeholder views for the tabs (e.g., Home, Ledger, Settings) so they can be switched using the new tab bar.

**Non-Goals:**
- Implementing the actual content of the inner tabs (e.g., creating the full ledger or charts UI). Only placeholders are required to prove routing.
- Implementing the detailed functionality of the action in `contextCapsule` (e.g., actual search logic or transaction adding logic). We only need the UI button firing a dummy action.

## Decisions

**Decision 1: TCA State Management for Tabs**
- **Decision:** Create a new `MainTabFeature` with an `enum Tab` representing the available tabs. The state will hold the `selectedTab`.
- **Rationale:** Keeps the tab selection explicitly modeled in TCA, allowing other features to programmatically change tabs or read the current tab if necessary. It ensures the single source of truth principle.
- **Alternatives:** Using `@State` directly in the View. Rejected because it breaks TCA's pattern and makes programmatic navigation out of scope.

**Decision 2: Custom Floating TabBar Implementation**
- **Decision:** Build a custom `TabBarView` overlayed at the bottom of the screen using `ZStack`, and switch the main content based on `store.selectedTab` instead of relying on the native `TabView` UI.
- **Rationale:** The design system dictates a very specific "split" floating layout (`navCapsule` + `contextCapsule`) with glassmorphic effects and gap spacing that cannot be achieved with native `UITabBarController` / `TabView` styling modifiers.
- **Alternatives:** Using native `TabView` and hiding the bar to provide our own overlay. Switching custom views directly allows for clearer control over the transition animations and is often more straightforward in a fully custom architecture.

**Decision 3: Glassmorphic Materials**
- **Decision:** Use native SwiftUI `.ultraThinMaterial` or `.regularMaterial` tailored to match `background_blur` effect from the design.
- **Rationale:** Native materials are performant and handle dark/light mode contextually.

## Risks / Trade-offs

- **Risk:** Safe Area handling with a custom floating Tab Bar. If not handled correctly, content at the bottom of scroll views might be obscured by the floating bar.
    - **Mitigation:** Ensure the inner content views receive appropriate bottom padding (injected via an environment value or safe area insets) to account for the overlapping custom floating tab bar.
- **Risk:** Performance cost of multiple blurs.
    - **Mitigation:** Rely on Apple's optimized Material types instead of custom heavy blur implementations.
