# Analysis Navigation & Account Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move AnalysisView out of the tab bar into a navigation push from Dashboard account cards, and add an account Menu picker to filter analysis data by account.

**Architecture:** AnalysisFeature moves from `MainTabFeature` scope into `DashboardFeature` as a `@Presents` tree-based navigation destination. `DashboardFeature.accountTapped` opens `AnalysisFeature.State(selectedAccountId:)` directly instead of bubbling a delegate action. `AnalysisFeature` gains `selectedAccountId`, `accounts` state and filters all data queries accordingly.

**Tech Stack:** TCA v1.23.1 (`@Presents`, `ifLet`, `PresentationAction`), Swift Testing (`@Suite`, `@Test`, `#expect`), `TransactionFilter.accountIds` (already exists in Domain)

---

## File Map

| File | Action |
|------|--------|
| `Features/Sources/Features/Analysis/AnalysisFeature.swift` | Add account filter state/actions, filter loadData + budgets |
| `Features/Tests/FeaturesTests/AnalysisFeatureTests.swift` | Add task/accountSelected/filter tests |
| `Features/Sources/Features/Analysis/AnalysisView.swift` | Add account Menu picker, change `.loadData` to `.task` |
| `Features/Sources/Features/Dashboard/DashboardFeature.swift` | Add `@Presents analysis`, change `accountTapped`, remove delegate case |
| `Features/Tests/FeaturesTests/DashboardFeatureTests.swift` | Update `testAccountTappedDelegate` test |
| `Features/Sources/Features/Dashboard/DashboardScreen.swift` | Add `.navigationDestination(item:)` for AnalysisView |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | Remove analysis state/action/scope/delegate handler, remove `Tab.analysis` |
| `Features/Sources/Features/MainTab/MainTabView.swift` | Remove Analysis Tab |
| `NeuLedger/Resources/Localizable.xcstrings` | Add `analysis_all_accounts` key |

---

### Task 1: AnalysisFeature — account filter state, actions, and filtered data loading

**Spec:** `docs/superpowers/specs/2026-03-25-analysis-navigation-account-filter-design.md` — "AnalysisFeature Changes" section

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisFeature.swift`
- Test: `Features/Tests/FeaturesTests/AnalysisFeatureTests.swift`

**Context:**
- `AnalysisFeature.State` currently has `selectedPeriod`, `isLoading`, `summary`, `categoryProportions`, `dailyTrends`, `budgetMetrics`, `insight`, `categoryDrilldown`
- `loadData` builds a `TransactionFilter(dateRange:)` — we need to also pass `accountIds`
- `computeBudgetMetrics` is a `static func` — needs `accountId: Account.ID?` parameter
- Existing dependency: `@Dependency(\.accountClient)` does NOT yet exist in AnalysisFeature — must be added
- `accountClient.fetchActive()` returns `[Account]` (active non-archived accounts)

- [ ] **Step 1: Write the failing tests**

Add to `Features/Tests/FeaturesTests/AnalysisFeatureTests.swift` after the existing tests:

```swift
// MARK: - Account Filter

@Test("task loads active accounts into state")
func testTaskLoadsAccounts() async {
    let accounts = [
        Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759", sortOrder: 0),
        Account(name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6", sortOrder: 1),
    ]
    let store = await TestStore(initialState: AnalysisFeature.State()) {
        AnalysisFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { accounts }
        $0.transactionClient.fetch = { _ in [] }
        $0.budgetClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
        $0.aiServiceClient.isAvailable = { false }
    }
    store.exhaustivity = .off

    await store.send(.task)
    await store.receive(\.accountsLoaded) { $0.accounts = accounts }
}

@Test("accountSelected updates selectedAccountId and triggers loadData")
func testAccountSelected() async {
    let accountId = UUID()
    let store = await TestStore(initialState: AnalysisFeature.State()) {
        AnalysisFeature()
    } withDependencies: {
        $0.transactionClient.fetch = { _ in [] }
        $0.budgetClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
        $0.aiServiceClient.isAvailable = { false }
    }
    store.exhaustivity = .off

    await store.send(.accountSelected(accountId)) {
        $0.selectedAccountId = accountId
    }
    // loadData is triggered — exhaustivity.off skips downstream
}

@Test("loadData passes accountIds filter when selectedAccountId is set")
func testLoadDataPassesAccountFilter() async {
    let accountId = UUID()
    var initial = AnalysisFeature.State()
    initial.selectedAccountId = accountId

    let capturedFilter = LockIsolated<TransactionFilter?>(nil)
    let store = await TestStore(initialState: initial) {
        AnalysisFeature()
    } withDependencies: {
        $0.transactionClient.fetch = { filter in
            capturedFilter.setValue(filter)
            return []
        }
        $0.budgetClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
        $0.aiServiceClient.isAvailable = { false }
    }
    store.exhaustivity = .off

    await store.send(.loadData)
    await store.receive(\.loadedData)

    #expect(capturedFilter.value?.accountIds == Set([accountId]))
}

@Test("computeBudgetMetrics filters budgets to account-relevant categories")
func testBudgetMetricsAccountFilter() async {
    let accountId = UUID()
    let relevantCategoryId = UUID()
    let irrelevantCategoryId = UUID()

    let relevantBudget = Budget(
        name: "飲食預算", amount: 1000,
        categoryId: relevantCategoryId, period: .monthly, startDate: Date()
    )
    let irrelevantBudget = Budget(
        name: "交通預算", amount: 500,
        categoryId: irrelevantCategoryId, period: .monthly, startDate: Date()
    )
    // Only a transaction with relevantCategoryId in this account
    let accountTxn = Transaction(
        amount: 200, date: Date(),
        categoryId: relevantCategoryId, accountId: accountId, type: .expense
    )

    var initial = AnalysisFeature.State()
    initial.selectedAccountId = accountId

    let store = await TestStore(initialState: initial) {
        AnalysisFeature()
    } withDependencies: {
        $0.transactionClient.fetch = { _ in [accountTxn] }
        $0.budgetClient.fetchActive = { [relevantBudget, irrelevantBudget] }
        $0.categoryClient.fetchAll = { [] }
        $0.aiServiceClient.isAvailable = { false }
    }
    store.exhaustivity = .off

    await store.send(.loadData)
    await store.receive(\.budgetMetricsLoaded) {
        // Only relevantBudget should appear; irrelevantBudget is filtered out
        #expect($0.budgetMetrics.count == 1)
        #expect($0.budgetMetrics.first?.id == relevantBudget.id.uuidString)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AnalysisFeatureTests 2>&1 | grep -E "(✘|error:|passed|failed)"
```

Expected: FAIL — `task`, `accountSelected`, `loadData` filter, budget filter tests fail because these actions/state don't exist yet.

- [ ] **Step 3: Implement changes to AnalysisFeature**

In `Features/Sources/Features/Analysis/AnalysisFeature.swift`:

**3a. Add to State:**
```swift
public var selectedAccountId: Account.ID? = nil
public var accounts: [Account] = []
```

**3b. Update `init`:**
```swift
public init(selectedPeriod: Period = .month, selectedAccountId: Account.ID? = nil) {
    self.selectedPeriod = selectedPeriod
    self.selectedAccountId = selectedAccountId
}
```

**3c. Add to Action enum:**
```swift
case task
case accountsLoaded([Account])
case accountSelected(Account.ID?)
```

**3d. Add dependency (after existing ones):**
```swift
@Dependency(\.accountClient) var accountClient
```

**3e. Add new action cases to reducer (inside `Reduce { state, action in switch action {`):**
```swift
case .task:
    return .merge(
        .run { [accountClient] send in
            let accounts = (try? await accountClient.fetchActive()) ?? []
            await send(.accountsLoaded(accounts))
        },
        .send(.loadData)
    )

case let .accountsLoaded(accounts):
    state.accounts = accounts
    return .none

case let .accountSelected(id):
    state.selectedAccountId = id
    return .send(.loadData)
```

**3f. Update `loadData` to include `accountIds` in the filter:**
```swift
// Replace:
let filter = TransactionFilter(dateRange: dateRange)
// With:
let filter = TransactionFilter(
    accountIds: state.selectedAccountId.map { Set([$0]) },
    dateRange: dateRange
)
```

Note: `state` must be captured in the `.run` closure — add `[state]` to the capture list:
```swift
return .merge(
    .run { [transactionClient, categoryClient, aiServiceClient, state] send in
```

**3g. Update `computeBudgetMetrics` signature and add account filtering:**

Change signature:
```swift
static func computeBudgetMetrics(
    budgetClient: BudgetClient,
    transactionClient: TransactionClient,
    categoryClient: CategoryClient,
    accountId: Account.ID? = nil
) async -> [BudgetGaugeMetrics]
```

Add account filtering logic at the start of the function, after fetching `activeBudgets`:
```swift
var filteredBudgets = activeBudgets
if let accountId {
    let accountFilter = TransactionFilter(
        accountIds: Set([accountId]),
        types: [.expense]
    )
    let accountTransactions = (try? await transactionClient.fetch(accountFilter)) ?? []
    let relevantCategoryIds = Set(accountTransactions.compactMap(\.categoryId))
    filteredBudgets = activeBudgets.filter { budget in
        guard let catId = budget.categoryId else { return true }
        return relevantCategoryIds.contains(catId)
    }
}
// Replace all uses of `activeBudgets` below with `filteredBudgets`
```

**3h. Pass `accountId` when calling `computeBudgetMetrics` in `loadData`:**
```swift
// In the .run for budget metrics, capture state:
.run { [budgetClient, transactionClient, categoryClient, state] send in
    let metrics = await Self.computeBudgetMetrics(
        budgetClient: budgetClient,
        transactionClient: transactionClient,
        categoryClient: categoryClient,
        accountId: state.selectedAccountId
    )
    await send(.budgetMetricsLoaded(metrics))
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AnalysisFeatureTests 2>&1 | grep -E "(✘|✔|passed|failed)"
```

Expected: All AnalysisFeatureTests pass.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Analysis/AnalysisFeature.swift \
        Features/Tests/FeaturesTests/AnalysisFeatureTests.swift
git commit -m "feat(analysis): add account filter state, actions, and filtered data loading"
```

---

### Task 2: AnalysisView — account Menu picker

**Spec:** `docs/superpowers/specs/2026-03-25-analysis-navigation-account-filter-design.md` — "AnalysisView Changes" section

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisView.swift`

**Context:**
- Currently `AnalysisView.body` sends `.loadData` in `.task`
- The navigation title is "Analysis" (`String(localized: "analysis_title")`)
- `store.accounts` is now available (populated by `.task`)
- `store.selectedAccountId` is the current selection (nil = all)

- [ ] **Step 1: Remove the NavigationStack wrapper from AnalysisView**

`AnalysisView` is now always pushed inside `DashboardScreen`'s `NavigationStack`. SwiftUI does not support nested `NavigationStack`s — doing so breaks the navigation bar. Remove the outer `NavigationStack` and apply modifiers directly on `scrollView`.

Replace the entire `body`:
```swift
public var body: some View {
    scrollView
        .background(Color.Design.background.ignoresSafeArea())
        .navigationTitle(String(localized: "analysis_title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await store.send(.task).finish()
        }
        .sheet(
            item: Binding(
                get: { store.categoryDrilldown },
                set: { if $0 == nil { store.send(.categoryDrilldownDismissed) } }
            )
        ) { drilldown in
            CategoryTransactionsView(
                categoryName: drilldown.categoryName,
                transactions: drilldown.transactions
            )
        }
}
```

Also update the `#Preview` blocks at the bottom of `AnalysisView.swift` to wrap with `NavigationStack` (so previews still have a navigation bar):
```swift
#Preview("Data") {
    NavigationStack {
        AnalysisView(store: Store(initialState: AnalysisFeature.State()) { AnalysisFeature() })
    }
}

#Preview("Empty State") {
    NavigationStack {
        AnalysisView(store: Store(initialState: AnalysisFeature.State()) { AnalysisFeature() })
    }
}
```

- [ ] **Step 2: Add account Menu picker to the navigation toolbar**

Add a toolbar item to `NavigationStack` in `AnalysisView.body`:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        if !store.accounts.isEmpty {
            Menu {
                Button(String(localized: "analysis_all_accounts")) {
                    store.send(.accountSelected(nil))
                }
                ForEach(store.accounts) { account in
                    Button(account.name) {
                        store.send(.accountSelected(account.id))
                    }
                }
            } label: {
                let selectedName = store.selectedAccountId
                    .flatMap { id in store.accounts.first { $0.id == id }?.name }
                Label(
                    selectedName ?? String(localized: "analysis_all_accounts"),
                    systemImage: "chevron.up.chevron.down"
                )
                .font(Font.Design.callout)
            }
        }
    }
}
```

- [ ] **Step 3: Build verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Analysis/AnalysisView.swift
git commit -m "feat(analysis): add account Menu picker and switch to .task on appear"
```

---

### Task 3: DashboardFeature — @Presents analysis, direct navigation, remove delegate

**Spec:** `docs/superpowers/specs/2026-03-25-analysis-navigation-account-filter-design.md` — "DashboardFeature Changes" section

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`
- Test: `Features/Tests/FeaturesTests/DashboardFeatureTests.swift`

**Context:**
- Currently `DashboardFeature.State` has `@Presents var addTransaction: AddTransactionFeature.State?`
- Currently `.accountTapped(id)` sends `.delegate(.accountTapped(id))`
- `Delegate` enum has `case accountTapped(Account.ID)` — this must be removed
- Need to add `import` for AnalysisFeature (same module, no import needed)
- The `ifLet` scope goes at the bottom of `body`, after the existing `ifLet(\.$addTransaction, ...)`

- [ ] **Step 1: Update the existing test to expect the new behaviour**

In `Features/Tests/FeaturesTests/DashboardFeatureTests.swift`, find and replace the test at line ~316:

```swift
// Replace:
@Test("accountTapped publishes delegate action with account ID")
func testAccountTappedDelegate() async throws {
    let accountId = UUID()
    let store = await TestStore(
        initialState: DashboardFeature.State()
    ) {
        DashboardFeature()
    }

    await store.send(.accountTapped(accountId))
    await store.receive(\.delegate.accountTapped)
}

// With:
@Test("accountTapped opens analysis with selectedAccountId set")
func testAccountTappedOpensAnalysis() async throws {
    let accountId = UUID()
    let store = await TestStore(
        initialState: DashboardFeature.State()
    ) {
        DashboardFeature()
    }

    await store.send(.accountTapped(accountId)) {
        $0.analysis = AnalysisFeature.State(selectedAccountId: accountId)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/DashboardFeatureTests 2>&1 | grep -E "(✘|error:|passed|failed)"
```

Expected: FAIL — `state.analysis` property doesn't exist yet.

- [ ] **Step 3: Update DashboardFeature**

**3a. Add `@Presents var analysis: AnalysisFeature.State?` to State** (after `@Presents var addTransaction`):
```swift
@Presents var analysis: AnalysisFeature.State?
```

**3b. Add `case analysis(PresentationAction<AnalysisFeature.Action>)` to Action** (after `case addTransaction`):
```swift
case analysis(PresentationAction<AnalysisFeature.Action>)
```

**3c. Remove `case accountTapped(Account.ID)` from Delegate enum.**

**3d. Change `.accountTapped` handler:**
```swift
// Replace:
case let .accountTapped(id):
    return .send(.delegate(.accountTapped(id)))

// With:
case let .accountTapped(id):
    state.analysis = AnalysisFeature.State(selectedAccountId: id)
    return .none
```

**3e. Add default case for `.analysis` actions** (add before `case .delegate:`):
```swift
case .analysis:
    return .none
```

**3f. Remove the now-dead `MainTabFeature` delegate handler** — removing `case accountTapped` from `Delegate` makes `MainTabFeature`'s `case .dashboard(.delegate(.accountTapped)):` a compile error. Remove it now in `Features/Sources/Features/MainTab/MainTabFeature.swift`:
```swift
// Remove this case entirely:
case .dashboard(.delegate(.accountTapped)):
    state.selectedTab = .analysis
    return .none
```

**3g. Add `ifLet` scope** at the bottom of `body`, after the existing `ifLet(\.$addTransaction, ...)`:
```swift
.ifLet(\.$analysis, action: \.analysis) {
    AnalysisFeature()
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/DashboardFeatureTests 2>&1 | grep -E "(✘|✔|passed|failed)"
```

Expected: All DashboardFeatureTests pass.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Tests/FeaturesTests/DashboardFeatureTests.swift \
        Features/Sources/Features/MainTab/MainTabFeature.swift
git commit -m "feat(dashboard): open AnalysisView directly on accountTapped, remove delegate"
```

---

### Task 4: DashboardScreen — add navigationDestination for AnalysisView

**Spec:** `docs/superpowers/specs/2026-03-25-analysis-navigation-account-filter-design.md` — "DashboardScreen Changes" section

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift`

**Context:**
- `DashboardScreen` has a top-level `NavigationStack` wrapping `ScrollView`
- It already uses `.sheet(item: $store.scope(state: \.addTransaction, action: \.addTransaction))` — follow the same pattern for navigation destination
- `$store.scope(state: \.analysis, action: \.analysis)` provides the scoped store binding

- [ ] **Step 1: Add navigationDestination**

In `DashboardScreen.body`, inside `NavigationStack`, add after the existing `.sheet(item: $store.scope(state: \.addTransaction, ...))`:

```swift
.navigationDestination(
    item: $store.scope(state: \.analysis, action: \.analysis)
) { analysisStore in
    AnalysisView(store: analysisStore)
}
```

- [ ] **Step 2: Build verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Dashboard/DashboardScreen.swift
git commit -m "feat(dashboard): push AnalysisView via navigationDestination on account tap"
```

---

### Task 5: Remove Analysis from MainTabFeature and MainTabView

**Spec:** `docs/superpowers/specs/2026-03-25-analysis-navigation-account-filter-design.md` — "MainTabFeature Changes" and "MainTabView Changes" sections

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`

**Context:**
- `MainTabFeature.Tab` enum has cases: `dashboard`, `analysis`, `settings`, `transactions`
- `MainTabFeature.State` has `var analysis = AnalysisFeature.State()`
- `MainTabFeature.Action` has `case analysis(AnalysisFeature.Action)`
- `MainTabFeature.body` has `Scope(state: \.analysis, action: \.analysis) { AnalysisFeature() }`
- `MainTabFeature.body` handles `case .dashboard(.delegate(.accountTapped)):` → remove this case
- `MainTabView` has `Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis)` → remove
- No test in `MainTabFeatureTests` directly references `.dashboard(.delegate(.accountTapped))` — no test update needed here
- After removing `Tab.analysis`, check if `Tab.analysis` is referenced anywhere else:

```bash
grep -r "\.analysis" Features/Sources/Features/MainTab/
```

- [ ] **Step 1: Update MainTabFeature**

**1a. Remove `case analysis` from `Tab` enum:**
```swift
// Remove: case analysis
```

**1b. Remove from State:**
```swift
// Remove: var analysis = AnalysisFeature.State()
```

**1c. Remove from Action:**
```swift
// Remove: case analysis(AnalysisFeature.Action)
```

**1d. Remove from `body`:**
```swift
// Remove the entire Scope block:
Scope(state: \.analysis, action: \.analysis) {
    AnalysisFeature()
}
```

**1e. ~~Remove the delegate handler~~** — already done in Task 3, Step 3f.

- [ ] **Step 2: Update MainTabView**

Remove the Analysis Tab block:
```swift
// Remove:
Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis) {
    AnalysisView(store: store.scope(state: \.analysis, action: \.analysis))
}
```

- [ ] **Step 3: Build verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `** BUILD SUCCEEDED **` — if there are errors about `\.analysis` references, remove them.

- [ ] **Step 4: Run full test suite to verify no regressions**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(✘|Test run|passed|failed)" | tail -10
```

Expected: Test run passes (the pre-existing `suggestCategoryTapped` failure is unrelated to this change — it was present before).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabView.swift
git commit -m "refactor(main-tab): remove Analysis tab — accessible only via Dashboard account tap"
```

---

### Task 6: Add localisation key and final test run

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

**Context:**
- The file uses JSON format with `"key": { "extractionState": "manual", "localizations": { "en": ..., "zh-Hant": ... } }` structure
- Insert the new key near the other `analysis_` keys (around line 3464, after `analysis_other_category`)
- There is only one `Localizable.xcstrings` file in the project

- [ ] **Step 1: Add `analysis_all_accounts` key**

In `NeuLedger/Resources/Localizable.xcstrings`, after the `"analysis_other_category"` entry, add:

```json
    "analysis_all_accounts": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "All Accounts" } },
        "zh-Hant": { "stringUnit": { "state": "translated", "value": "全部帳戶" } }
      }
    },
```

- [ ] **Step 2: Build verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Full test run**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(✘|Test run|passed|failed)" | tail -10
```

Expected: All tests pass except the pre-existing `suggestCategoryTapped is no-op when AI unavailable` failure.

- [ ] **Step 4: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(analysis): add analysis_all_accounts localisation key"
```
