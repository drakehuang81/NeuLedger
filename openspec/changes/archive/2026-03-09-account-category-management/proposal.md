## Why

Currently, the app lacks complete UI flows and functionalities for users to fully manage their core data: accounts, categories, and tags. To make the app's basic operations complete, we need to provide dedicated management screens accessible from the Settings page, allowing users to add, edit, reorder, and archive these essential entities. This is a critical prerequisite for a fully functioning and personalizable bookkeeping application.

## What Changes

- Refactor `SettingsFeature` to use TCA stack-based navigation (`StackState`/`StackAction`), replacing the current delegate-based pattern. Clean up dead delegate handling in `MainTabFeature`.
- Create an **Account Management** screen to list active/archived accounts with computed balances, add new accounts, edit properties, and archive/delete accounts following business rules (using `TransactionClient` to check for associated transactions before deletion).
- Create a **Category Management** screen to list existing categories (split by income/expense via segmented control), allow drag-and-drop reordering, editing (name/icon/color), and adding user-defined custom categories with proper default category protection.
- Create a **Tag Management** screen to list all existing tags, add new tags, edit names/colors, and safely delete tags with disassociation warning.
- Implement corresponding TCA Reducers, SwiftUI Views, and test suites for these management flows.

## Capabilities

### New Capabilities

- `screen-account-management`: UI specifications for the Account Management screen (listing, adding, editing, and archiving accounts).
- `screen-category-management`: UI specifications for the Category Management screen (listing, reordering, and editing categories).
- `screen-tag-management`: UI specifications for the Tag Management screen (listing, editing names/colors, adding, and deleting tags).

### Modified Capabilities

- `screen-settings`: Convert `SettingsFeature` to stack-based navigation and add navigation entries to access the new management sub-pages.

## Impact

- **UI/Navigation**: `SettingsView` will be wrapped in `NavigationStack(path:)`. `SettingsFeature` will own `StackState<Path.State>` / `StackAction<Path.Action>` for push navigation. Existing delegate-based navigation actions will be replaced by direct path mutations. Unused delegate handling in `MainTabFeature` will be cleaned up.
- **Architecture**: Introduction of new `AccountManagementFeature`, `CategoryManagementFeature`, and `TagManagementFeature` TCA reducers, states, and actions.
- **Dependencies**: Uses existing domain clients — `AccountClient`, `CategoryClient`, `TagClient`, and `TransactionClient` (for account deletion checks).
