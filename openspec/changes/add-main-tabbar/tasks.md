## 1. TCA Feature Setup

- [ ] 1.1 Create `MainTabFeature.swift` and define `MainTabFeature` reducer.
- [ ] 1.2 Define `MainTabFeature.State` containing the currently `selectedTab`.
- [ ] 1.3 Define `MainTabFeature.Action` with tab selection and global context actions (e.g., search/add tapped).
- [ ] 1.4 Implement the empty placeholder reducers for the inner tab items.

## 2. Floating TabBar UI Implementation

- [ ] 2.1 Create custom `GlobalTabBarView.swift`.
- [ ] 2.2 Implement `navCapsule` inside the TabBar (glassmorphic styling, pill shape, dynamic selection status).
- [ ] 2.3 Implement `contextCapsule` inside the TabBar (glassmorphic styling, circular background for global actions like search or add).
- [ ] 2.4 Arrange `navCapsule` and `contextCapsule` matching the split design spacing.

## 3. MainTabView Composition

- [ ] 3.1 Create `MainTabView.swift` as the host for the tab content and the floating tab bar overlay.
- [ ] 3.2 Add a ZStack base layout combining placeholder tab contents and the bottom-anchored `GlobalTabBarView`.
- [ ] 3.3 Ensure Safe Area insets apply appropriate padding to bottom content so the floating tab does not obscure list content permanently.

## 4. App-Level Integration

- [ ] 4.1 Update `AppFeature.swift` to add `MainTabFeature` into its destination states.
- [ ] 4.2 Update `AppFeature` actions to handle `MainTabFeature` delegation or routing.
- [ ] 4.3 Modify `AppView.swift` to present `MainTabView` (scoping to `MainTabFeature`) when the `store.destination` acts on `.main`.
- [ ] 4.4 Make sure the transition animations (.asymmetric opacity moves) are correctly bound to the `.main` state replacing the text placeholder.
