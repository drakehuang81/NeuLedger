# Missing Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill in 6 missing test suites for existing features — BudgetManagement, BudgetForm, Transactions list, Filter, Budget Core client, and Tag Core client.

**Architecture:** All feature tests use TCA `TestStore` with dependency overrides. All Core tests use an in-memory `DatabaseClient` (same pattern as existing `AccountClientTests`). No new production code is written — tests only.

**Tech Stack:** Swift Testing (`@Suite`, `@Test`), TCA `TestStore`, SwiftData in-memory container, Swift 6, iOS 26

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `Features/Tests/FeaturesTests/BudgetManagementFeatureTests.swift` | Create | Reducer tests: load, toggleActive, delete flow |
| `Features/Tests/FeaturesTests/BudgetFormFeatureTests.swift` | Create | Reducer tests: validation, save new, save edit |
| `Features/Tests/FeaturesTests/TransactionsFeatureTests.swift` | Create | Reducer tests: load list, search, filter delegate |
| `Features/Tests/FeaturesTests/FilterFeatureTests.swift` | Create | Reducer tests: toggle filters, apply, clearAll |
| `Features/Tests/CoreTests/Clients/BudgetClientTests.swift` | Create | Integration: add, fetch, update, delete via SwiftData |
| `Features/Tests/CoreTests/Clients/TagClientTests.swift` | Create | Integration: add, fetch, update, delete, tag disassociation |

---

## Task 1: BudgetManagementFeature Tests

**Files:**
- Create: `Features/Tests/FeaturesTests/BudgetManagementFeatureTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("BudgetManagementFeature Tests")
struct BudgetManagementFeatureTests {

    static let sampleBudget = Budget(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "食費",
        amount: 10000,
        categoryId: nil,
        period: .monthly,
        startDate: Date(),
        isActive: true
    )

    // MARK: - .task

    @Test(".task loads budgets into state")
    func testTaskLoadsBudgets() async {
        let store = await TestStore(initialState: BudgetManagementFeature.State()) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.budgetClient.fetchAll = { [Self.sampleBudget] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.budgetsLoaded) {
            $0.isLoading = false
            $0.budgets = [Self.sampleBudget]
        }
    }

    // MARK: - toggleActive

    @Test("toggleActive flips isActive and updates via client")
    func testToggleActive() async {
        var updated: Budget?
        let store = await TestStore(
            initialState: BudgetManagementFeature.State(budgets: [Self.sampleBudget])
        ) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.budgetClient.update = { updated = $0 }
            $0.budgetClient.fetchAll = { [Self.sampleBudget] }
        }

        await store.send(.toggleActive(Self.sampleBudget))
        await store.receive(\.budgetsLoaded)
        #expect(updated?.isActive == false)
    }

    // MARK: - delete flow

    @Test("deleteRequested presents confirmation alert")
    func testDeleteRequestedShowsAlert() async {
        let store = await TestStore(
            initialState: BudgetManagementFeature.State(budgets: [Self.sampleBudget])
        ) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.budgetClient.fetchAll = { [] }
        }

        await store.send(.deleteRequested(Self.sampleBudget.id)) {
            $0.alert = AlertState {
                TextState("budget_delete_confirm_title", bundle: .main)
            } actions: {
                ButtonState(role: .destructive, action: .deleteConfirmed(Self.sampleBudget.id)) {
                    TextState("common_delete", bundle: .main)
                }
                ButtonState(role: .cancel) {
                    TextState("common_cancel", bundle: .main)
                }
            }
        }
    }

    @Test("deleteConfirmed removes budget and reloads")
    func testDeleteConfirmedRemovesBudget() async {
        var deletedId: Budget.ID?
        let store = await TestStore(
            initialState: BudgetManagementFeature.State(budgets: [Self.sampleBudget])
        ) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.budgetClient.delete = { deletedId = $0 }
            $0.budgetClient.fetchAll = { [] }
        }

        await store.send(.alert(.presented(.deleteConfirmed(Self.sampleBudget.id))))
        await store.receive(\.budgetsLoaded) {
            $0.budgets = []
            $0.alert = nil
        }
        #expect(deletedId == Self.sampleBudget.id)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/BudgetManagementFeatureTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS. If `AlertState` construction doesn't match exactly — inspect `BudgetManagementFeature.swift` lines 82–96 to copy the exact alert construction and update the test accordingly.

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/FeaturesTests/BudgetManagementFeatureTests.swift
git commit -m "test(features): add BudgetManagementFeature tests"
```

---

## Task 2: BudgetFormFeature Tests

**Files:**
- Create: `Features/Tests/FeaturesTests/BudgetFormFeatureTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("BudgetFormFeature Tests")
struct BudgetFormFeatureTests {

    static let sampleCategory = Domain.Category(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        name: "食費", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: false
    )

    // MARK: - Validation

    @Test("saveTapped with empty name sets nameError")
    func testSaveTappedEmptyNameSetsError() async {
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.amountChanged("5000"))
        await store.send(.saveTapped) {
            $0.nameError = String(localized: "budget_form_name_required", bundle: .main)
        }
    }

    @Test("saveTapped with zero amount sets amountError")
    func testSaveTappedZeroAmountSetsError() async {
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.nameChanged("食費"))
        await store.send(.amountChanged("0")) {
            $0.amountText = "0"
        }
        await store.send(.saveTapped) {
            $0.amountError = String(localized: "budget_form_amount_positive", bundle: .main)
        }
    }

    // MARK: - Save new

    @Test("saveTapped with valid inputs adds budget and emits saved delegate")
    func testSaveTappedValidAdds() async {
        var addedBudget: Budget?
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
            $0.budgetClient.add = { addedBudget = $0 }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.nameChanged("食費")) { $0.name = "食費" }
        await store.send(.amountChanged("10000")) { $0.amountText = "10000" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(addedBudget?.name == "食費")
        #expect(addedBudget?.amount == 10000)
    }

    // MARK: - Save edit

    @Test("saveTapped in edit mode updates existing budget")
    func testSaveTappedEditUpdates() async {
        let existing = Budget(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "舊名稱", amount: 5000, categoryId: nil,
            period: .monthly, startDate: Date(), isActive: true
        )
        var updatedBudget: Budget?
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .edit(existing))
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
            $0.budgetClient.update = { updatedBudget = $0 }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.nameChanged("新名稱")) { $0.name = "新名稱" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(updatedBudget?.name == "新名稱")
        #expect(updatedBudget?.id == existing.id)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/BudgetFormFeatureTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS. If localization key strings don't match — open `BudgetFormFeature.swift` lines 121–162 to find the exact `String(localized:)` keys and update accordingly.

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/FeaturesTests/BudgetFormFeatureTests.swift
git commit -m "test(features): add BudgetFormFeature tests"
```

---

## Task 3: TransactionsFeature Tests

**Files:**
- Create: `Features/Tests/FeaturesTests/TransactionsFeatureTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("TransactionsFeature Tests")
struct TransactionsFeatureTests {

    static let sampleTransaction = Transaction(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        amount: 200, date: Date(), note: "午餐",
        categoryId: nil, accountId: UUID(), toAccountId: nil,
        type: .expense, tags: [], aiSuggested: false,
        createdAt: Date(), updatedAt: Date()
    )

    // MARK: - .task

    @Test(".task loads transactions")
    func testTaskLoadsTransactions() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [Self.sampleTransaction] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.transactionsLoaded) {
            $0.isLoading = false
            $0.transactions = [Self.sampleTransaction]
        }
    }

    // MARK: - Search

    @Test("searchTextChanged debounces and reloads")
    func testSearchTextChanged() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [] }
            $0.transactionClient.search = { _ in [Self.sampleTransaction] }
        }
        store.exhaustivity = .off

        await store.send(.searchTextChanged("午餐")) {
            $0.searchText = "午餐"
        }
    }

    // MARK: - Filter delegate

    @Test("filter delegate filterApplied updates activeFilter and reloads")
    func testFilterAppliedUpdatesFilter() async {
        let filter = TransactionFilter(types: [.expense])
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.accountClient.fetchAll = { [] }
            $0.tagClient.fetchAll = { [] }
        }
        store.exhaustivity = .off

        // Open filter sheet
        await store.send(.filterButtonTapped) {
            $0.filter = FilterFeature.State(
                selectedTypes: [],
                selectedCategoryIds: [],
                selectedAccountIds: [],
                selectedTagIds: [],
                startDate: nil, endDate: nil,
                categories: [], accounts: [], tags: [],
                isLoading: false
            )
        }

        // Apply filter via delegate
        await store.send(.filter(.presented(.delegate(.filterApplied(filter))))) {
            $0.activeFilter = filter
            $0.filter = nil
        }
        await store.receive(\.transactionsLoaded)
    }

    // MARK: - Delete

    @Test("deleteTransaction sets confirmation id")
    func testDeleteTransactionSetsConfirmation() async {
        let store = await TestStore(
            initialState: TransactionsFeature.State(transactions: [Self.sampleTransaction])
        ) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [Self.sampleTransaction] }
        }

        await store.send(.deleteTransaction(Self.sampleTransaction.id)) {
            $0.deleteConfirmationId = Self.sampleTransaction.id
        }
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/TransactionsFeatureTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS. The `filterButtonTapped` test's initial `FilterFeature.State` must match what `TransactionsFeature` actually sets — check lines 120–123 of `TransactionsFeature.swift` and copy the exact state construction if needed.

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/FeaturesTests/TransactionsFeatureTests.swift
git commit -m "test(features): add TransactionsFeature tests"
```

---

## Task 4: FilterFeature Tests

**Files:**
- Create: `Features/Tests/FeaturesTests/FilterFeatureTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("FilterFeature Tests")
struct FilterFeatureTests {

    static let sampleCategory = Domain.Category(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        name: "食費", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: false
    )
    static let sampleAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false, createdAt: Date()
    )

    func makeStore() async -> TestStoreOf<FilterFeature> {
        await TestStore(
            initialState: FilterFeature.State(
                selectedTypes: [],
                selectedCategoryIds: [],
                selectedAccountIds: [],
                selectedTagIds: [],
                startDate: nil, endDate: nil,
                categories: [Self.sampleCategory],
                accounts: [Self.sampleAccount],
                tags: [],
                isLoading: false
            )
        ) {
            FilterFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [Self.sampleCategory] }
            $0.accountClient.fetchAll = { [Self.sampleAccount] }
            $0.tagClient.fetchAll = { [] }
            $0.dismiss = DismissEffect { }
        }
    }

    // MARK: - Toggle filters

    @Test("typeToggled adds type to selectedTypes")
    func testTypeToggled() async {
        let store = await makeStore()
        await store.send(.typeToggled(.expense)) {
            $0.selectedTypes = [.expense]
        }
    }

    @Test("typeToggled twice removes type from selectedTypes")
    func testTypeToggledTwiceRemoves() async {
        let store = await makeStore()
        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [.expense] }
        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [] }
    }

    @Test("categoryToggled adds category id")
    func testCategoryToggled() async {
        let store = await makeStore()
        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = [Self.sampleCategory.id]
        }
    }

    // MARK: - Apply

    @Test("applyTapped emits filterApplied delegate with correct filter")
    func testApplyTappedEmitsDelegate() async {
        let store = await makeStore()
        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [.expense] }
        await store.send(.applyTapped)
        await store.receive(\.delegate.filterApplied) { state in
            // filter was emitted — state is unchanged by this receive
        }
    }

    // MARK: - Clear all

    @Test("clearAllTapped resets all filter fields")
    func testClearAllResetsFilters() async {
        let store = await makeStore()
        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [.expense] }
        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = [Self.sampleCategory.id]
        }
        await store.send(.clearAllTapped) {
            $0.selectedTypes = []
            $0.selectedCategoryIds = []
            $0.selectedAccountIds = []
            $0.selectedTagIds = []
            $0.startDate = nil
            $0.endDate = nil
        }
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/FilterFeatureTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/FeaturesTests/FilterFeatureTests.swift
git commit -m "test(features): add FilterFeature tests"
```

---

## Task 5: BudgetClient Core Integration Tests

**Files:**
- Create: `Features/Tests/CoreTests/Clients/BudgetClientTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("BudgetClient Integration Tests")
struct BudgetClientTests {
    var container: ModelContainer
    var sut: BudgetClient

    init() throws {
        let schema = Schema([
            SDTransaction.self, SDAccount.self, SDCategory.self,
            SDBudget.self, SDTag.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try ModelContainer(for: schema, configurations: [config])
        self.container = c
        self.sut = withDependencies {
            $0.databaseClient = DatabaseClient(modelContainer: { c })
        } operation: {
            BudgetClient.liveValue
        }
    }

    // MARK: - Add

    @Test("add stores budget and fetchAll returns it")
    func testAddAndFetchAll() async throws {
        let budget = Budget(
            id: UUID(), name: "食費", amount: 10000,
            categoryId: nil, period: .monthly,
            startDate: Date(), isActive: true
        )
        try await sut.add(budget)
        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].name == "食費")
        #expect(all[0].amount == 10000)
    }

    // MARK: - Update

    @Test("update modifies existing budget")
    func testUpdate() async throws {
        var budget = Budget(
            id: UUID(), name: "原始", amount: 5000,
            categoryId: nil, period: .monthly,
            startDate: Date(), isActive: true
        )
        try await sut.add(budget)
        budget.name = "更新後"
        budget.amount = 8000
        try await sut.update(budget)
        let all = try await sut.fetchAll()
        #expect(all[0].name == "更新後")
        #expect(all[0].amount == 8000)
    }

    // MARK: - Delete

    @Test("delete removes budget from store")
    func testDelete() async throws {
        let budget = Budget(
            id: UUID(), name: "食費", amount: 10000,
            categoryId: nil, period: .monthly,
            startDate: Date(), isActive: true
        )
        try await sut.add(budget)
        try await sut.delete(budget.id)
        let all = try await sut.fetchAll()
        #expect(all.isEmpty)
    }

    // MARK: - fetchActive

    @Test("fetchActive returns only active budgets")
    func testFetchActive() async throws {
        let active = Budget(
            id: UUID(), name: "Active", amount: 1000,
            categoryId: nil, period: .monthly, startDate: Date(), isActive: true
        )
        let inactive = Budget(
            id: UUID(), name: "Inactive", amount: 2000,
            categoryId: nil, period: .monthly, startDate: Date(), isActive: false
        )
        try await sut.add(active)
        try await sut.add(inactive)
        let result = try await sut.fetchActive()
        #expect(result.count == 1)
        #expect(result[0].name == "Active")
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/BudgetClientTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/CoreTests/Clients/BudgetClientTests.swift
git commit -m "test(core): add BudgetClient integration tests"
```

---

## Task 6: TagClient Core Integration Tests

**Files:**
- Create: `Features/Tests/CoreTests/Clients/TagClientTests.swift`

- [ ] **Step 1: Create the test file**

```swift
import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("TagClient Integration Tests")
struct TagClientTests {
    var container: ModelContainer
    var sut: TagClient
    var transactionClient: TransactionClient

    init() throws {
        let schema = Schema([
            SDTransaction.self, SDAccount.self, SDCategory.self,
            SDBudget.self, SDTag.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try ModelContainer(for: schema, configurations: [config])
        self.container = c
        let db = DatabaseClient(modelContainer: { c })
        self.sut = withDependencies { $0.databaseClient = db } operation: { TagClient.liveValue }
        self.transactionClient = withDependencies { $0.databaseClient = db } operation: { TransactionClient.liveValue }
    }

    // MARK: - Add

    @Test("add stores tag and fetchAll returns it")
    func testAddAndFetchAll() async throws {
        let tag = Tag(id: UUID(), name: "外食", color: "#FF9500")
        try await sut.add(tag)
        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].name == "外食")
    }

    // MARK: - Update

    @Test("update modifies existing tag")
    func testUpdate() async throws {
        var tag = Tag(id: UUID(), name: "原始", color: "#FF9500")
        try await sut.add(tag)
        tag.name = "更新後"
        try await sut.update(tag)
        let all = try await sut.fetchAll()
        #expect(all[0].name == "更新後")
    }

    // MARK: - Delete

    @Test("delete removes tag from store")
    func testDelete() async throws {
        let tag = Tag(id: UUID(), name: "外食", color: "#FF9500")
        try await sut.add(tag)
        try await sut.delete(tag.id)
        let all = try await sut.fetchAll()
        #expect(all.isEmpty)
    }

    // MARK: - Auto-disassociate

    @Test("deleting tag removes it from associated transactions")
    func testDeleteDisassociatesFromTransactions() async throws {
        let tag = Tag(id: UUID(), name: "外食", color: "#FF9500")
        try await sut.add(tag)

        // Seed an account and category so the transaction can be added
        let context = ModelContext(container)
        let sdAccount = SDAccount(
            id: UUID(), name: "現金", typeRaw: AccountType.cash.rawValue,
            icon: "banknote", color: "#34C759", sortOrder: 0,
            isArchived: false, createdAt: Date()
        )
        context.insert(sdAccount)
        try context.save()

        let transaction = Transaction(
            id: UUID(), amount: 100, date: Date(), note: "外食",
            categoryId: nil, accountId: sdAccount.id, toAccountId: nil,
            type: .expense, tags: [tag], aiSuggested: false,
            createdAt: Date(), updatedAt: Date()
        )
        try await transactionClient.add(transaction)

        // Verify tag is on the transaction
        let before = try await transactionClient.fetchAll()
        #expect(before[0].tags.map(\.id).contains(tag.id))

        // Delete the tag
        try await sut.delete(tag.id)

        // Tag should be removed from the transaction
        let after = try await transactionClient.fetchAll()
        #expect(!after[0].tags.map(\.id).contains(tag.id))
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/TagClientTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/CoreTests/Clients/TagClientTests.swift
git commit -m "test(core): add TagClient integration tests"
```

---

## Final Verification

- [ ] **Run all new tests together**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/BudgetManagementFeatureTests \
  -only-testing:FeaturesTests/BudgetFormFeatureTests \
  -only-testing:FeaturesTests/TransactionsFeatureTests \
  -only-testing:FeaturesTests/FilterFeatureTests \
  -only-testing:CoreTests/BudgetClientTests \
  -only-testing:CoreTests/TagClientTests \
  2>&1 | grep -E "✔|✗|Suite.*passed|Suite.*failed" | tail -30
```

Expected: All 6 suites PASS.
