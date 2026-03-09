## Context

NeuLedger requires robust management functionalities for core domain entities like Accounts, Categories, and Tags. Currently, the domain models and client interfaces (`AccountClient`, `CategoryClient`, `TagClient`) are defined in feature specs, but there is no User Interface to actively manage these entities. To provide a complete bookkeeping experience, users must be able to view, create, edit, reorder, archive, and delete them. These management screens will be nested within the main `Settings` screen as sub-pages.

The current `SettingsView` is a plain `ScrollView` with no `NavigationStack`. Navigation actions are forwarded via TCA delegate actions to `MainTabFeature`, which currently handles them as no-ops. This change must introduce proper stack-based navigation within `SettingsFeature`.

## Goals / Non-Goals

**Goals:**
- Provide clear and intuitive list views for Accounts, Categories, and Tags.
- Allow users to create, read, update, and delete/archive (CRUD) these entities using existing domain clients (`AccountClient`, `CategoryClient`, `TagClient`).
- Implement specialized flows for Account archiving (protecting accounts with linked transactions via `TransactionClient` to check for associated transactions).
- Organize Category views by Income/Expense and support custom ordering.
- Set up stack-based navigation in `SettingsFeature` using TCA's `StackState`/`StackAction` pattern.
- Build the flows using The Composable Architecture (TCA) following the project's Clean Architecture layer separation.

**Non-Goals:**
- Implementing the core persistence logic (since `AccountClient`, `CategoryClient`, `TagClient` already define those mechanisms).
- Building the actual main transaction entry flows (which only consume these items, though they rely on their updated state).
- Budget management UI (separate change).

## Decisions

1. **Architecture & State Management (TCA)**:
   Each management flow will be isolated into its own TCA feature (`AccountManagementFeature`, `CategoryManagementFeature`, `TagManagementFeature`). These features will communicate with the environment via their respective clients:
   - `AccountManagementFeature` → `AccountClient` + `TransactionClient` (for deletion checks)
   - `CategoryManagementFeature` → `CategoryClient`
   - `TagManagementFeature` → `TagClient`

2. **Navigation Flow (Stack-Based)**:
   `SettingsFeature` will own a `StackState<Path.State>` / `StackAction<Path.Action>` for push navigation. A nested `Path` reducer will compose the three management features. `SettingsView` will be wrapped in a `NavigationStack(path:)` bound to this state. The existing delegate actions (`navigateToAccounts`, etc.) will be replaced by direct `path.append` mutations. The unused delegate handling in `MainTabFeature` will be removed.

3. **In-place Editing vs Dedicated Detail Views**:
   - Creating/Editing will be handled via presented sheets (`@Presents` + `PresentationAction`) within each management feature to maintain context while filling out forms (like names, selecting SF Symbols, and picking colors).
   - This keeps the main list clean and allows for dedicated validation logic (like detecting duplicate account names) within the Add/Edit sub-features.

4. **Archiving vs Deletion Strategy**:
   - Deleting an account with associated transactions breaks database integrity. Per specs, accounts can only be "archived" (hidden from pickers) if they have transactions. `AccountManagementFeature` will use `transactionClient.fetch(TransactionFilter(accountIds: [id]))` to check for associated transactions before allowing permanent deletion. If transactions exist, prompt for archiving instead.

5. **Sorting & Sections**:
   - Accounts will be split into Active and Archived sections in the UI. Each account row displays the computed balance via `accountClient.computeBalance`, loaded in parallel with `TaskGroup`.
   - Categories will use a segmented control for "Expense" and "Income". Support for drag-and-drop reordering is required. Sort order updates will call `categoryClient.update` for each reordered category sequentially (the list is small enough that this is acceptable).

## Risks / Trade-offs

- **Risk**: Handling the reordering logic correctly for Categories can be tricky with SwiftData, especially ensuring the `sortOrder` updates correctly across the list. Mitigation: reassign `sortOrder` as sequential integers (0, 1, 2, ...) after each reorder, then persist each category.
- **Risk**: Multiple `computeBalance` calls for the account list. Mitigation: use `TaskGroup` for parallel fetching; show a loading indicator per row if needed.
- **Trade-off**: Putting all management deep inside `Settings` might make them less discoverable for frequent adjustments, but it clears clutter from the dashboard/transaction views. We will stick to Settings for now to match common app patterns.
