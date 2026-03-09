## 1. Settings Navigation Refactor

- [x] 1.1 Add `Path` reducer to `SettingsFeature`: Define `@Reducer(state: .equatable) enum Path { case accountManagement(AccountManagementFeature) / case categoryManagement(CategoryManagementFeature) / case tagManagement(TagManagementFeature) }`. Add `path: StackState<Path.State>` to State and `path(StackActionOf<Path>)` to Action.
- [x] 1.2 Remove delegate-based navigation: Remove `Delegate` enum, `delegate(Delegate)` action case, and `navigateToAccounts/Categories/Budgets/Tags` action cases from `SettingsFeature`. Replace with direct `state.path.append(.accountManagement(...))` mutations on button taps.
- [x] 1.3 Update `SettingsView`: Wrap content in `NavigationStack(path: $store.scope(state: \.path, action: \.path))`. Add `.navigationDestination(store:)` for each `Path` case.
- [x] 1.4 Clean up `MainTabFeature`: Remove the dead `.settings(.delegate(...))` case handlers.

## 2. Scaffold TCA Features

- [x] 2.1 Create `AccountManagementFeature.swift`: State (accounts list, balances dict, loading flag, `@Presents addEditAccount`), Action (task, accountsLoaded, balancesLoaded, delete/archive tapped, addEdit presentation), Body with `@Dependency(\.accountClient)` and `@Dependency(\.transactionClient)`.
- [x] 2.2 Create `CategoryManagementFeature.swift`: State (categories list, selected segment expense/income, `@Presents addEditCategory`), Action (task, segmentChanged, reorder, addEdit presentation), Body with `@Dependency(\.categoryClient)`.
- [x] 2.3 Create `TagManagementFeature.swift`: State (tags list, `@Presents addEditTag`), Action (task, addEdit presentation, delete confirmation), Body with `@Dependency(\.tagClient)`.

## 3. Implement Account Management UI

- [x] 3.1 Create `AccountManagementView.swift`: Grouped list with "啟用中" and "已封存" sections. Each row shows icon, name, type label, and balance. Use `TaskGroup` to load balances in parallel.
- [x] 3.2 Create `AddEditAccountView.swift`: Sheet form with Name (TextField), Type (Picker), Icon (SF Symbol grid), Color (ColorPicker). Inline validation for empty/duplicate names.
- [x] 3.3 Implement archive/delete logic in reducer: On delete action, call `transactionClient.fetch(TransactionFilter(accountIds: [id]))` to check for associated transactions. If non-empty, show archive confirmation alert. If empty, show delete confirmation alert.
- [x] 3.4 Implement unarchive: Tapping an archived account shows option to restore via `accountClient.update` with `isArchived = false`.

## 4. Implement Category Management UI

- [x] 4.1 Create `CategoryManagementView.swift`: Segmented control ("支出" / "收入") at top, list below filtered by selected type. Each row shows colored icon + name.
- [x] 4.2 Implement reorder: `onMove` modifier on the list. After move, reassign `sortOrder` as 0, 1, 2, ... and call `categoryClient.update` for each changed category.
- [x] 4.3 Create `AddEditCategoryView.swift`: Sheet form with Name, Icon, Color, Type (defaults to current segment). For default categories (`isDefault == true`): disable delete button; disable Type picker. Inline validation for empty name.
- [x] 4.4 Implement category deletion: Only for `isDefault == false`. Show confirmation alert, then call `categoryClient.delete`.

## 5. Implement Tag Management UI

- [x] 5.1 Create `TagManagementView.swift`: List of all tags with color indicator and name. Empty state when no tags exist.
- [x] 5.2 Create `AddEditTagView.swift` (or inline alert): Sheet/alert for Name + Color input. Used for both adding and editing.
- [x] 5.3 Implement tag deletion: Swipe-to-delete with confirmation dialog warning about disassociation. Call `tagClient.delete`.

## 6. Tests

- [x] 6.1 Write `AccountManagementFeatureTests`: Test load accounts + balances, add account (validation: empty name, duplicate name), archive flow (with transactions → archive, without → delete), unarchive flow.
- [x] 6.2 Write `CategoryManagementFeatureTests`: Test load by type, segment switching, reorder sort order persistence, add/edit category, delete custom category, reject delete of default category.
- [x] 6.3 Write `TagManagementFeatureTests`: Test load tags, add tag, edit tag, delete tag with confirmation.
- [x] 6.4 Write `SettingsFeatureTests`: Test navigation path push/pop for each management screen.
