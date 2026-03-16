
# Onboarding Persistence, Analysis Real Data & Budget Gauge Colors Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three spec gaps: (1) Onboarding persists the created account and supports skip, (2) Analysis loads real transaction data instead of mock, (3) BudgetGauge uses spec-defined color rules.

**Architecture:** OnboardingFeature gains an `accountClient` dependency to persist accounts on finish/skip. AnalysisFeature replaces mock data generation with real `transactionClient.fetch` aggregation and `aiServiceClient.generateInsight` calls. BudgetGauge derives its bar color from the spent/limit ratio using the spec's three-tier rule.

**Tech Stack:** Swift, TCA (v1.23.1), SwiftUI, Swift Testing

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `Features/Sources/Features/Onboarding/OnboardingFeature.swift` | Add `accountClient` dep, `skipButtonTapped` action, account persistence |
| Modify | `Features/Sources/Features/Onboarding/OnboardingView.swift` | Add skip button to each step |
| Modify | `Features/Tests/FeaturesTests/OnboardingFeatureTests.swift` | Tests for skip and account persistence |
| Modify | `Features/Sources/Features/Analysis/AnalysisFeature.swift` | Replace mock with real data aggregation |
| Modify | `Features/Sources/Features/Analysis/AnalysisView.swift` | Remove `hasData` init dependency, derive from state |
| Modify | `Features/Sources/Common/Components/BudgetGauge.swift` | Color logic based on progress percentage |

---

## Chunk 1: Onboarding Account Persistence & Skip

### Task 1: OnboardingFeature — Add account persistence and skip action

**Files:**
- Modify: `Features/Sources/Features/Onboarding/OnboardingFeature.swift`
- Test: `Features/Tests/FeaturesTests/OnboardingFeatureTests.swift`

- [ ] **Step 1: Write failing test — finishButtonTapped creates account**

In `OnboardingFeatureTests.swift`, add:

```swift
@Test("finishButtonTapped creates account with user input and sends delegate")
func testFinishCreatesAccount() async throws {
    let addedAccount = LockIsolated<Account?>(nil)

    let store = await TestStore(
        initialState: OnboardingFeature.State(
            currentStep: .ready,
            accountName: "我的銀行",
            accountType: .bank
        )
    ) {
        OnboardingFeature()
    } withDependencies: {
        $0.userSettingsClient.setBool = { _, _ in }
        $0.accountClient.add = { account in
            addedAccount.setValue(account)
        }
    }

    await store.send(.finishButtonTapped)
    await store.receive(\.accountCreated) {
        $0.isCreatingAccount = true
    }
    await store.receive(\.delegate.onboardingCompleted)

    let account = addedAccount.value
    #expect(account?.name == "我的銀行")
    #expect(account?.type == .bank)
    #expect(account?.icon == "building.columns")
    #expect(account?.isArchived == false)
}
```

- [ ] **Step 2: Write failing test — skipButtonTapped creates default account**

```swift
@Test("skipButtonTapped creates default cash account and completes")
func testSkipCreatesDefaultAccount() async throws {
    let addedAccount = LockIsolated<Account?>(nil)

    let store = await TestStore(
        initialState: OnboardingFeature.State(currentStep: .welcome)
    ) {
        OnboardingFeature()
    } withDependencies: {
        $0.userSettingsClient.setBool = { _, _ in }
        $0.accountClient.add = { account in
            addedAccount.setValue(account)
        }
    }

    await store.send(.skipButtonTapped)
    await store.receive(\.accountCreated) {
        $0.isCreatingAccount = true
    }
    await store.receive(\.delegate.onboardingCompleted)

    let account = addedAccount.value
    #expect(account?.name == "現金")
    #expect(account?.type == .cash)
    #expect(account?.icon == "banknote")
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FeaturesTests/OnboardingFeatureTests 2>&1 | tail -20`
Expected: Compilation errors — `skipButtonTapped`, `isCreatingAccount`, `accountCreated` don't exist yet.

- [ ] **Step 4: Implement OnboardingFeature changes**

Replace `OnboardingFeature.swift` with the following changes:

1. Add `isCreatingAccount` to State:
```swift
@ObservableState
struct State: Equatable {
    var currentStep: Step = .welcome
    var accountName: String = String(localized: "onboarding_setup_name_placeholder")
    var accountType: AccountType = .cash
    var isCreatingAccount: Bool = false
}
```

2. Add new actions:
```swift
enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case startButtonTapped
    case nextButtonTapped
    case finishButtonTapped
    case skipButtonTapped
    case accountCreated
    case delegate(Delegate)

    @CasePathable
    enum Delegate: Equatable {
        case onboardingCompleted
    }
}
```

3. Add `accountClient` dependency:
```swift
@Dependency(\.userSettingsClient) var userSettingsClient
@Dependency(\.accountClient) var accountClient
```

4. Update the reducer body — replace `finishButtonTapped` case and add new cases:
```swift
case .finishButtonTapped:
    let name = state.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
    let accountName = name.isEmpty ? String(localized: "onboarding_setup_name_placeholder") : name
    let accountType = state.accountType
    return .run { [userSettingsClient, accountClient] send in
        let account = Account(
            name: accountName,
            type: accountType,
            icon: accountType.defaultIcon,
            color: accountType.defaultColor
        )
        try await accountClient.add(account)
        userSettingsClient.setBool(true, .hasCompletedOnboarding)
        await send(.accountCreated)
    }

case .skipButtonTapped:
    return .run { [userSettingsClient, accountClient] send in
        let defaultAccount = Account(
            name: String(localized: "onboarding_setup_name_placeholder"),
            type: .cash,
            icon: "banknote",
            color: "#2ECC71"
        )
        try await accountClient.add(defaultAccount)
        userSettingsClient.setBool(true, .hasCompletedOnboarding)
        await send(.accountCreated)
    }

case .accountCreated:
    state.isCreatingAccount = true
    return .send(.delegate(.onboardingCompleted))
```

5. Add `AccountType` helper extension (at the bottom of the file or as a private extension):
```swift
private extension AccountType {
    var defaultIcon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .eWallet: "wallet.bifold"
        }
    }

    var defaultColor: String {
        switch self {
        case .cash: "#2ECC71"
        case .bank: "#3498DB"
        case .creditCard: "#E74C3C"
        case .eWallet: "#9B59B6"
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FeaturesTests/OnboardingFeatureTests 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 6: Fix existing `testFinishButtonTapped` test**

The existing test must be updated because `finishButtonTapped` is now async. Update it to also provide `accountClient.add`:

```swift
@Test("finishButtonTapped calls setBool and sends delegate")
func testFinishButtonTapped() async throws {
    let capturedSetBool = LockIsolated(
        (called: false, value: Bool?.none, keyRawValue: String?.none)
    )

    let store = await TestStore(
        initialState: OnboardingFeature.State(currentStep: .ready)
    ) {
        OnboardingFeature()
    } withDependencies: {
        $0.userSettingsClient.setBool = { value, key in
            capturedSetBool.withValue {
                $0.called = true
                $0.value = value
                $0.keyRawValue = key.rawValue
            }
        }
        $0.accountClient.add = { _ in }
    }

    await store.send(.finishButtonTapped)
    await store.receive(\.accountCreated) {
        $0.isCreatingAccount = true
    }
    await store.receive(\.delegate.onboardingCompleted)

    let recorded = capturedSetBool.value
    #expect(recorded.called == true)
    #expect(recorded.value == true)
    #expect(recorded.keyRawValue == SettingsKey.hasCompletedOnboarding.rawValue)
}
```

- [ ] **Step 7: Run all onboarding tests**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FeaturesTests/OnboardingFeatureTests 2>&1 | tail -20`
Expected: All PASS.

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/Onboarding/OnboardingFeature.swift Features/Tests/FeaturesTests/OnboardingFeatureTests.swift
git commit -m "feat(onboarding): persist account on finish/skip with accountClient"
```

### Task 2: OnboardingView — Add skip button UI

**Files:**
- Modify: `Features/Sources/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add skip button to each step**

Add a `.toolbar` modifier or overlay to each step. Per spec, every step should have a "跳過" button. The simplest approach: add a toolbar item to the ZStack wrapping all steps.

Replace the body of `OnboardingView` to wrap content in a `VStack` with a top-aligned skip button:

In `welcomeStep`, `accountSetupStep`, and `readyStep`, add a skip button at the top-right. The cleanest approach is to overlay the ZStack:

```swift
var body: some View {
    ZStack {
        Color.Design.background
            .ignoresSafeArea()

        Group {
            switch store.currentStep {
            case .welcome:
                welcomeStep
                    .transition(stepTransition)
            case .accountSetup:
                accountSetupStep
                    .transition(stepTransition)
            case .ready:
                readyStep
                    .transition(stepTransition)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.currentStep)
    }
    .overlay(alignment: .topTrailing) {
        if store.currentStep != .ready {
            Button {
                store.send(.skipButtonTapped)
            } label: {
                Text("跳過")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.Design.textSecondary)
            }
            .padding(.trailing, 24)
            .padding(.top, 16)
        }
    }
}
```

Note: The `.ready` step already has "前往主畫面" as its CTA, so skip is not needed there.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): add skip button to welcome and account setup steps"
```

---

## Chunk 2: Analysis Real Data

### Task 3: AnalysisFeature — Replace mock data with real transaction aggregation

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisFeature.swift`
- Modify: `Features/Sources/Features/Analysis/AnalysisView.swift`

- [ ] **Step 1: Rewrite AnalysisFeature.loadData to fetch real transactions**

Key changes to `AnalysisFeature.swift`:

1. Remove `hasData` from State (replace with computed property):
```swift
@ObservableState
public struct State: Equatable {
    // ...existing fields...
    public var isLoading: Bool = false

    public var hasData: Bool {
        summary != nil
    }

    public init(selectedPeriod: Period = .month) {
        self.selectedPeriod = selectedPeriod
    }
}
```

2. Add `isLoading` related action and `aiServiceClient` dependency:
```swift
@Dependency(\.aiServiceClient) var aiServiceClient
```

3. Replace `loadData` case in reducer. Remove mock data path entirely:
```swift
case .loadData:
    state.isLoading = true
    let period = state.selectedPeriod
    return .merge(
        .run { [transactionClient, categoryClient, aiServiceClient] send in
            let dateRange = Self.dateRange(for: period)
            let filter = TransactionFilter(dateRange: dateRange)
            let transactions = try await transactionClient.fetch(filter)

            guard !transactions.isEmpty else {
                await send(.loadedData(.success(nil)))
                return
            }

            // Compute summary (exclude transfers)
            let totalIncome = transactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let totalExpense = transactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let summary = FinancialSummary(
                totalIncome: totalIncome,
                totalExpense: totalExpense
            )

            // Compute category proportions (expenses only)
            let categories = try await categoryClient.fetchAll()
            let categoryMap = Dictionary(
                uniqueKeysWithValues: categories.map { ($0.id, $0.name) }
            )
            var categoryTotals: [String: Decimal] = [:]
            for txn in transactions where txn.type == .expense {
                let name = categoryMap[txn.categoryId] ?? "其他"
                categoryTotals[name, default: .zero] += txn.amount
            }
            let proportions = categoryTotals
                .sorted { $0.value > $1.value }
                .map { CategoryProportion(name: $0.key, amount: $0.value) }

            // Compute daily trends (expenses only)
            let cal = Calendar.current
            var dailyTotals: [Date: Decimal] = [:]
            for txn in transactions where txn.type == .expense {
                let day = cal.startOfDay(for: txn.date)
                dailyTotals[day, default: .zero] += txn.amount
            }
            let trends = dailyTotals
                .sorted { $0.key < $1.key }
                .map { DailyTrend(date: $0.key, amount: $0.value) }

            // AI insight
            var insight: InsightDetail? = nil
            if aiServiceClient.isAvailable() {
                let spendingSummary = SpendingSummary(
                    totalIncome: totalIncome,
                    totalExpense: totalExpense,
                    categoryBreakdown: categoryTotals,
                    periodDescription: period.rawValue
                )
                if let text = try? await aiServiceClient.generateInsight(spendingSummary) {
                    insight = InsightDetail(
                        title: "AI 洞察",
                        description: text
                    )
                }
            }

            let data = AnalysisData(
                summary: summary,
                categoryProportions: proportions,
                dailyTrends: trends,
                budgetMetrics: [],
                insight: insight
            )
            await send(.loadedData(.success(data)))
        },
        .run { [budgetClient, transactionClient, categoryClient] send in
            let metrics = await Self.computeBudgetMetrics(
                budgetClient: budgetClient,
                transactionClient: transactionClient,
                categoryClient: categoryClient
            )
            await send(.budgetMetricsLoaded(metrics))
        }
        .cancellable(id: CancelID.budgets, cancelInFlight: true)
    )
```

4. Update `loadedData` to handle optional data:
Change `AnalysisData` field `insight` to optional: `let insight: InsightDetail?`
Change action: `case loadedData(TaskResult<AnalysisData?>)`

```swift
case let .loadedData(.success(data)):
    state.isLoading = false
    guard let data else {
        state.summary = nil
        state.categoryProportions = []
        state.dailyTrends = []
        state.insight = nil
        return .none
    }
    state.summary = data.summary
    state.categoryProportions = data.categoryProportions
    state.dailyTrends = data.dailyTrends
    state.insight = data.insight
    return .none

case .loadedData(.failure):
    state.isLoading = false
    return .none
```

5. Add `dateRange(for:)` static helper:
```swift
static func dateRange(for period: State.Period) -> ClosedRange<Date> {
    let cal = Calendar.current
    let now = Date()
    switch period {
    case .week:
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        return start...now
    case .month:
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return start...now
    case .year:
        let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        return start...now
    }
}
```

6. Delete `generateMockData` method entirely.

- [ ] **Step 2: Update AnalysisView for computed hasData**

In `AnalysisView.swift`, update the `#Preview("Data")` since `hasData` is no longer an init parameter:

```swift
#Preview("Data") {
    AnalysisView(
        store: Store(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        }
    )
}

#Preview("Empty State") {
    AnalysisView(
        store: Store(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        }
    )
}
```

The view body itself needs no changes — it already reads `store.hasData` which will now be a computed property.

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: Build succeeds.

- [ ] **Step 4: Run existing tests to check for regressions**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: All tests PASS (no AnalysisFeature tests exist yet, so no new failures).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Analysis/AnalysisFeature.swift Features/Sources/Features/Analysis/AnalysisView.swift
git commit -m "feat(analysis): replace mock data with real transaction aggregation and AI insights"
```

---

## Chunk 3: BudgetGauge Color Rules

### Task 4: BudgetGauge — Implement spec color logic

**Files:**
- Modify: `Features/Sources/Common/Components/BudgetGauge.swift`

- [ ] **Step 1: Replace hardcoded gradient with conditional color**

In `BudgetGauge.swift`, add a computed property for the bar color:

```swift
private var barColor: Color {
    switch progress {
    case ..<0.8:
        return Color.Design.incomeGreen
    case 0.8..<1.0:
        return Color.Design.warningAmber
    default:
        return Color.Design.expenseRed
    }
}
```

Then replace the `Capsule` fill from:
```swift
.fill(
    LinearGradient(
        colors: [.blue, .purple],
        startPoint: .leading,
        endPoint: .trailing
    )
)
```

To:
```swift
.fill(barColor)
```

Also update the `progress` property to allow values > 1.0 (remove `min` clamping for color purposes but keep it for width):

```swift
private var percentage: Double {
    guard total > 0 else { return 0 }
    return (used as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue
}

private var progress: Double {
    min(max(percentage, 0), 1)
}

private var barColor: Color {
    switch percentage {
    case ..<0.8:
        return Color.Design.incomeGreen
    case 0.8..<1.0:
        return Color.Design.warningAmber
    default:
        return Color.Design.expenseRed
    }
}
```

The bar width still uses `progress` (capped at 1.0), but the color uses `percentage` (can exceed 1.0).

Update the percentage text display to use `percentage`:
```swift
Text("\(Int(percentage * 100))%")
```

- [ ] **Step 2: Update preview to show all three states**

```swift
#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        VStack(spacing: 16) {
            BudgetGauge(total: 5000, used: 2000, label: "飲食")  // < 80% green
            BudgetGauge(total: 5000, used: 4200, label: "交通")  // 80-100% amber
            BudgetGauge(total: 5000, used: 6000, label: "娛樂")  // > 100% red
        }
        .padding()
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Common/Components/BudgetGauge.swift
git commit -m "feat(budget): implement spec color rules for BudgetGauge progress bar"
```

---

## Final Verification

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: All tests PASS.

- [ ] **Step 2: Build entire app**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: Build succeeds.
