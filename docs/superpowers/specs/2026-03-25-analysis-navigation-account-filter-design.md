# Analysis Navigation & Account Filter Design

## Goal

Move AnalysisView out of the main tab bar. It becomes a full-screen navigation push accessible only from the Dashboard account cards. Add an account filter (Menu picker) to AnalysisView so users can scope analysis data to a specific account or view all accounts.

## Architecture

AnalysisFeature moves from `MainTabFeature` into `DashboardFeature` as a tree-based navigation destination (`@Presents`). When a user taps an account card on the Dashboard, DashboardFeature initialises `AnalysisFeature.State(selectedAccountId: id)` and DashboardScreen pushes AnalysisView via `.navigationDestination(item:)`.

The `delegate(.accountTapped)` case is removed from `DashboardFeature.Delegate` — it is no longer needed because DashboardFeature handles the navigation directly.

## File Structure

### Modified

| File | Change |
|------|--------|
| `Features/Sources/Features/Dashboard/DashboardFeature.swift` | Add `@Presents var analysis: AnalysisFeature.State?`; change `.accountTapped` to open analysis directly; remove `.delegate(.accountTapped)` |
| `Features/Sources/Features/Dashboard/DashboardScreen.swift` | Add `.navigationDestination(item:)` for AnalysisView |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | Remove `analysis` state, action, scope, and `.dashboard(.delegate(.accountTapped))` handler |
| `Features/Sources/Features/MainTab/MainTabView.swift` | Remove `Tab("Analysis", ...)` |
| `Features/Sources/Features/Analysis/AnalysisFeature.swift` | Add account filter state/actions; filter `loadData` and `computeBudgetMetrics` by accountId; add `@Dependency(\.accountClient)` |
| `Features/Sources/Features/Analysis/AnalysisView.swift` | Add account Menu picker in toolbar; send `.task` on appear |
| `Features/Tests/FeaturesTests/DashboardFeatureTests.swift` | Update `testAccountTappedDelegate` — now expects `state.analysis != nil` instead of delegate action |
| `Features/Tests/FeaturesTests/AnalysisFeatureTests.swift` | Add `task`/`accountsLoaded` test; `accountSelected` reload test; account filter propagation test |

## AnalysisFeature Changes

### State additions

```swift
public var selectedAccountId: Account.ID? = nil   // nil = all accounts
public var accounts: [Account] = []               // populated on .task
```

### init update

```swift
public init(selectedPeriod: Period = .month, selectedAccountId: Account.ID? = nil) {
    self.selectedPeriod = selectedPeriod
    self.selectedAccountId = selectedAccountId
}
```

### Action additions

```swift
case task
case accountsLoaded([Account])
case accountSelected(Account.ID?)
```

### Reducer logic

- `.task` — fetch all active accounts via `accountClient.fetchActive()`, send `.accountsLoaded`; also send `.loadData` (accounts load concurrently with data load — ordering doesn't matter since `.loadData` only reads `selectedAccountId`, not `accounts`)
- `.accountSelected(id)` — set `selectedAccountId`, send `.loadData`
- `.loadData` — include `accountIds: selectedAccountId.map { Set([$0]) }` in `TransactionFilter`
- `computeBudgetMetrics(accountId:)` — when `accountId != nil`, first fetch transactions for that account, collect the distinct `categoryId` set, then filter budgets to only those whose `categoryId` is in that set (or `categoryId == nil`). Skip budgets for unrelated categories.

### New dependency

```swift
@Dependency(\.accountClient) var accountClient
```

## DashboardFeature Changes

### State

```swift
@Presents var analysis: AnalysisFeature.State?
```

### Action

```swift
case analysis(PresentationAction<AnalysisFeature.Action>)
```

### Reducer

```swift
// Replace:
case let .accountTapped(id):
    return .send(.delegate(.accountTapped(id)))

// With:
case let .accountTapped(id):
    state.analysis = AnalysisFeature.State(selectedAccountId: id)
    return .none

// Add ifLet scope in body:
.ifLet(\.$analysis, action: \.analysis) {
    AnalysisFeature()
}
```

### Delegate enum

Remove `case accountTapped(Account.ID)` — no longer needed.

## DashboardScreen Changes

```swift
.navigationDestination(
    item: $store.scope(state: \.analysis, action: \.analysis)
) { analysisStore in
    AnalysisView(store: analysisStore)
}
```

## MainTabFeature Changes

- Remove `var analysis = AnalysisFeature.State()` from `State`
- Remove `case analysis(AnalysisFeature.Action)` from `Action`
- Remove `Scope(state: \.analysis, action: \.analysis) { AnalysisFeature() }` from body
- Remove `case .dashboard(.delegate(.accountTapped)):` handler

## MainTabView Changes

Remove:

```swift
Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis) {
    AnalysisView(store: store.scope(state: \.analysis, action: \.analysis))
}
```

Also remove `case analysis` from `MainTabFeature.Tab` enum.

## AnalysisView Changes

Add account Menu picker in the navigation toolbar (trailing, next to the period picker or as a second toolbar item):

```swift
Menu {
    Button("全部帳戶") { store.send(.accountSelected(nil)) }
    ForEach(store.accounts) { account in
        Button(account.name) { store.send(.accountSelected(account.id)) }
    }
} label: {
    Label(
        store.selectedAccountId.flatMap { id in store.accounts.first { $0.id == id }?.name } ?? String(localized: "analysis_all_accounts"),
        systemImage: "chevron.up.chevron.down"
    )
}
```

Send `.task` on appear:

```swift
.task { await store.send(.task).finish() }
```

(Currently AnalysisView only sends `.loadData` on appear. Change to `.task` which will load accounts first then trigger `.loadData`.)

## Localisation Keys Required

- `analysis_all_accounts` — "全部帳戶"

## Testing

### DashboardFeatureTests — update existing test

```swift
@Test("accountTapped opens analysis with selectedAccountId set")
func testAccountTappedOpensAnalysis() async throws {
    let accountId = UUID()
    let store = await TestStore(initialState: DashboardFeature.State()) {
        DashboardFeature()
    }
    await store.send(.accountTapped(accountId)) {
        $0.analysis = AnalysisFeature.State(selectedAccountId: accountId)
    }
}
```

### AnalysisFeatureTests — new tests

1. `task loads accounts from accountClient`
2. `accountSelected updates selectedAccountId and triggers loadData`
3. `loadData passes accountIds filter when selectedAccountId is set`
4. `computeBudgetMetrics filters to account-relevant categories when accountId provided`

## Key Constraints

- `MainTabFeature.Tab.analysis` case is removed — no other code references it
- AnalysisFeature is only alive while the navigation destination is presented; state is reset on each entry
- `TransactionFilter.accountIds` already exists in Domain — no Domain layer changes needed
- All user-facing strings use `String(localized:)` — add `analysis_all_accounts` key to all Localizable.xcstrings files
