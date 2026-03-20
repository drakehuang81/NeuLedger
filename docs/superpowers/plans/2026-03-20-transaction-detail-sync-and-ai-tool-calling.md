# Transaction Detail Sync + AI Tool Calling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the transaction detail edit-sync bug (stale data after editing) and implement AI Tool Calling for financial Q&A with an Input Bar mode toggle.

**Architecture:** Three independent fix/feature areas — (1) delegate payload propagation through `AddTransactionFeature → TransactionDetailFeature → TransactionsFeature`, (2) a new `QueryTransactionsTool` in Core + `answerFinancialQuestion` on `AIServiceClient`, (3) `InputPurpose` mode toggle on `MainTabFeature` with new reducer cases and UI.

**Tech Stack:** Swift 6, TCA v1.23.1, Foundation Models (`FoundationModels`), SwiftUI, Swift Testing (`@Suite`, `@Test`, `TestStore`).

**Spec:** `docs/superpowers/specs/2026-03-20-transaction-detail-sync-and-ai-tool-calling-design.md`

**Run tests with:**
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | grep -E "(✔|✘|passed|failed|error:)"
```

---

## File Map

| Status | File | Change |
|--------|------|--------|
| Modify | `Features/Sources/Features/Dashboard/AddTransactionFeature.swift` | Add `savedWithTransaction(Transaction)` delegate case; emit in edit mode |
| Modify | `Features/Sources/Features/Dashboard/DashboardFeature.swift` | Handle `.saved` + `.savedWithTransaction(_)` to reload recent transactions |
| Modify | `Features/Sources/Features/Transactions/TransactionDetailFeature.swift` | Handle `.savedWithTransaction`, update `state.transaction`, emit `.delegate(.updated(t))` |
| Modify | `Features/Sources/Features/Transactions/TransactionsFeature.swift` | Bind `t` in `.delegate(.updated(t))`; switch to in-place update |
| Modify | `Features/Sources/Domain/Clients/AIServiceClient.swift` | Add `answerFinancialQuestion` property |
| Modify | `Features/Sources/Core/Clients/AIServiceClient+Live.swift` | Add private `QueryTransactionsTool`; implement `answerFinancialQuestion` liveValue |
| Modify | `NeuLedger/Resources/Localizable.xcstrings` | Add `ai_ask_error` key |
| Modify | `Features/Sources/Features/MainTab/MainTabFeature.swift` | Add `InputPurpose`, `aiAnswer`, `CancelID.aiAnswer`, new actions + reducer |
| Modify | `Features/Sources/Features/MainTab/MainTabView.swift` | Add SF Symbol toggle + inline answer display |
| Create | `Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift` | New — 3 tests |
| Modify | `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift` | Add 1 edit-mode delegate test |
| Modify | `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` | Add 3 ask-mode tests |

---

## Task 1: Add `savedWithTransaction(Transaction)` to `AddTransactionFeature.Delegate`

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`
- Modify: `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift`

- [ ] **Step 1: Write a failing test for edit-mode delegate payload**

Add to `AddTransactionFeatureTests` (at the end of the struct, before the closing `}`):

```swift
@Test("saveTapped in .edit mode sends savedWithTransaction carrying updated values")
func testEditModeSavedDelegateCarriesTransaction() async {
    let existing = Transaction(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
        amount: 100,
        date: Date(timeIntervalSince1970: 0),
        note: "old note",
        categoryId: nil,
        accountId: Self.account1.id,
        toAccountId: nil,
        type: .expense
    )
    var state = AddTransactionFeature.State(mode: .edit(existing))
    state.amountText = "250"
    state.accountId = Self.account1.id

    let store = await TestStore(initialState: state) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [Self.account1] }
        $0.categoryClient.fetchAll = { [] }
        $0.userSettingsClient.string = { _ in "" }
        $0.aiServiceClient.isAvailable = { false }
        $0.transactionClient.update = { _ in }
    }

    await store.send(.saveTapped)
    await store.receive(\.savedSuccessfully)
    // Expect savedWithTransaction, NOT saved:
    await store.receive(\.delegate.savedWithTransaction) { state in
        #expect(state.transaction?.amount == 250)
        #expect(state.transaction?.id == existing.id)
    }
}
```

> Note: `state.transaction` inside `receive(\.delegate.savedWithTransaction)` — you are asserting the *associated value* of the action. In TCA `TestStore`, use `await store.receive(\.delegate.savedWithTransaction)` and inspect the received action or use a `LockIsolated` to capture it:

```swift
// Alternative (simpler) assertion pattern using LockIsolated:
@Test("saveTapped in .edit mode sends savedWithTransaction carrying updated values")
func testEditModeSavedDelegateCarriesTransaction() async {
    let existing = Transaction(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
        amount: 100,
        date: Date(timeIntervalSince1970: 0),
        note: "old note",
        categoryId: nil,
        accountId: Self.account1.id,
        toAccountId: nil,
        type: .expense
    )
    var state = AddTransactionFeature.State(mode: .edit(existing))
    state.amountText = "250"
    state.accountId = Self.account1.id

    let updatedCapture: LockIsolated<Transaction?> = LockIsolated(nil)

    let store = await TestStore(initialState: state) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [Self.account1] }
        $0.categoryClient.fetchAll = { [] }
        $0.userSettingsClient.string = { _ in "" }
        $0.aiServiceClient.isAvailable = { false }
        $0.transactionClient.update = { updatedCapture.setValue($0) }
    }

    await store.send(.saveTapped)
    await store.receive(\.savedSuccessfully)
    await store.receive(\.delegate.savedWithTransaction)

    #expect(updatedCapture.value?.amount == 250)
    #expect(updatedCapture.value?.id == existing.id)
}
```

- [ ] **Step 2: Run the test — expect COMPILE ERROR** (`.savedWithTransaction` doesn't exist yet)

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests \
  2>&1 | grep -E "(error:|✘)"
```

Expected: compile error about `savedWithTransaction`.

- [ ] **Step 3: Add the new delegate case to `AddTransactionFeature`**

In `AddTransactionFeature.swift`, find the `Delegate` enum (around line 112) and add the new case:

```swift
@CasePathable
public enum Delegate: Sendable, Equatable {
    case saved                              // add / addPrefilled mode
    case savedWithTransaction(Transaction)  // edit mode
    case dismissed
}
```

- [ ] **Step 4: Update the edit-mode save path to emit `savedWithTransaction`**

The `savedSuccessfully` case cannot receive the transaction — it has no payload. Use a new internal action to carry the transaction from `saveTapped` to the delegate.

**4a — Add `savedSuccessfullyWithTransaction` to the `Action` enum.**

Find the `Action` enum (around line 93). It currently reads:

```swift
case saveTapped
case dismiss
case savedSuccessfully

case delegate(Delegate)
```

Change to:

```swift
case saveTapped
case dismiss
case savedSuccessfully
case savedSuccessfullyWithTransaction(Transaction)   // ← add this line

case delegate(Delegate)
```

**4b — Update the `.edit` branch in `saveTapped` to send the new action.**

Update the `.edit` branch in `saveTapped` to send `.savedSuccessfullyWithTransaction(transaction)` instead of `.savedSuccessfully`:

```swift
case let .edit(existing):
    let transaction = Transaction(
        id: existing.id,
        amount: amountValue,
        date: date,
        note: note,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        type: type_,
        tags: existing.tags,
        aiSuggested: existing.aiSuggested,
        createdAt: existing.createdAt,
        updatedAt: Date()
    )
    try await transactionClient.update(transaction)
    await send(.savedSuccessfullyWithTransaction(transaction))  // ← changed
```

Add handler for the new action:

```swift
case let .savedSuccessfullyWithTransaction(transaction):
    return .run { send in
        await send(.delegate(.savedWithTransaction(transaction)))
        await dismiss()
    }
```

The existing `.savedSuccessfully` handler for `.add`/`.addPrefilled` stays unchanged:

```swift
case .savedSuccessfully:
    return .run { send in
        await send(.delegate(.saved))
        await dismiss()
    }
```

- [ ] **Step 5: Run targeted test — expect PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests \
  2>&1 | grep -E "(✔|✘|passed|failed)"
```

Expected: all `AddTransactionFeatureTests` pass (including the new test).

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
        Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift
git commit -m "feat(add-transaction): add savedWithTransaction delegate case for edit mode"
```

---

## Task 2: Fix `TransactionDetailFeature` — handle `savedWithTransaction` and emit delegate

**Files:**
- Create: `Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift`

- [ ] **Step 1: Create the test file**

Create `Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift`:

```swift
import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("TransactionDetailFeature Tests")
struct TransactionDetailFeatureTests {

    private static let account = Account(
        id: UUID(uuidString: "11000000-0000-0000-0000-000000000001")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )

    private static let sampleTransaction = Transaction(
        id: UUID(uuidString: "22000000-0000-0000-0000-000000000001")!,
        amount: 150,
        date: Date(timeIntervalSince1970: 0),
        note: "午餐",
        categoryId: nil,
        accountId: account.id,
        toAccountId: nil,
        type: .expense
    )

    // MARK: - Edit Flow

    @Test("editTapped presents edit form with .edit mode")
    func testEditTappedPresentsEditForm() async {
        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        ) {
            TransactionDetailFeature()
        }

        await store.send(.editTapped) {
            $0.editTransaction = AddTransactionFeature.State(mode: .edit(Self.sampleTransaction))
        }
    }

    @Test("savedWithTransaction updates state.transaction, dismisses sheet, sends delegate")
    func testEditSavedWithTransactionUpdatesStateAndSendsDelegate() async {
        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.editTransaction = AddTransactionFeature.State(mode: .edit(Self.sampleTransaction))

        let updatedTransaction = Transaction(
            id: Self.sampleTransaction.id,
            amount: 300,
            date: Self.sampleTransaction.date,
            note: "晚餐",
            categoryId: nil,
            accountId: Self.account.id,
            toAccountId: nil,
            type: .expense
        )

        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        }

        await store.send(.editTransaction(.presented(.delegate(.savedWithTransaction(updatedTransaction))))) {
            $0.transaction = updatedTransaction
            $0.editTransaction = nil
        }
        await store.receive(\.delegate.updated)
    }

    // MARK: - Delete Flow

    @Test("deleteConfirmed calls transactionClient.delete and sends delegate")
    func testDeleteConfirmedCallsDeleteAndDismisses() async {
        let deletedId: LockIsolated<Transaction.ID?> = LockIsolated(nil)
        let id = Self.sampleTransaction.id

        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        ) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.transactionClient.delete = { deletedId.setValue($0) }
            $0.dismiss = DismissEffect { }   // ← required: TestStore cannot call live dismiss
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
        }
        await store.receive(\.delegate.deleted)

        #expect(deletedId.value == id)
    }
}
```

- [ ] **Step 2: Run tests — expect COMPILE ERROR** (`savedWithTransaction` not yet handled in `TransactionDetailFeature`)

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing:FeaturesTests/TransactionDetailFeatureTests \
  2>&1 | grep -E "(error:|✘|passed|failed)"
```

Expected: compile error or test failures.

- [ ] **Step 3: Update `TransactionDetailFeature` to handle `savedWithTransaction`**

In `TransactionDetailFeature.swift`, **replace both** the `.saved` handler (lines 105-107) and the `.dismissed` handler (lines 109-111) together. The current code reads:

```swift
case let .editTransaction(.presented(.delegate(.saved))):   // line 105
    state.editTransaction = nil
    return .none

case .editTransaction(.presented(.delegate(.dismissed))):   // line 109
    state.editTransaction = nil
    return .none
```

Replace those two cases (lines 105-111) with three cases:

```swift
case let .editTransaction(.presented(.delegate(.savedWithTransaction(t)))):
    state.transaction = t
    state.editTransaction = nil
    return .send(.delegate(.updated(t)))

case .editTransaction(.presented(.delegate(.saved))):
    // add/addPrefilled mode — close sheet only (detail only uses edit mode, but keep for exhaustiveness)
    state.editTransaction = nil
    return .none

case .editTransaction(.presented(.delegate(.dismissed))):
    state.editTransaction = nil
    return .none
```

The existing `case .editTransaction:` catch-all on line 113 stays unchanged.

- [ ] **Step 4: Run targeted tests — expect all 3 PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing:FeaturesTests/TransactionDetailFeatureTests \
  2>&1 | grep -E "(✔|✘|passed|failed)"
```

Expected: `✔ Test run with 3 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Transactions/TransactionDetailFeature.swift \
        Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift
git commit -m "fix(transaction-detail): sync state and send delegate after edit save"
```

---

## Task 3: Fix `TransactionsFeature` + `DashboardFeature` — propagate the updated transaction

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift`
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`

> These are compile-fix and correctness changes — existing test coverage (via the full suite) validates them.

- [ ] **Step 1: Fix `TransactionsFeature` — in-place update instead of full reload**

Find the handler around line 178 in `TransactionsFeature.swift`:

```swift
// BEFORE:
case .detail(.presented(.delegate(.updated))):
    state.detail = nil
    return .run { send in
        let transactions = try await transactionClient.fetchAll()
        await send(.transactionsLoaded(transactions))
    }

// AFTER — bind `t` and update in place:
case let .detail(.presented(.delegate(.updated(t)))):
    if let idx = state.transactions.firstIndex(where: { $0.id == t.id }) {
        state.transactions[idx] = t
    }
    state.detail = nil
    return .none
```

- [ ] **Step 2: Fix `DashboardFeature` — reload after save**

Find the `addTransaction` no-op handler in `DashboardFeature.swift` (around line 240):

```swift
// BEFORE:
case .addTransaction:
    return .none

// AFTER — reload recent transactions after a successful save:
case .addTransaction(.presented(.delegate(.saved))),
     .addTransaction(.presented(.delegate(.savedWithTransaction(_)))):
    return .run { send in
        let transactions = try await transactionClient.fetchRecent()
        await send(.transactionsUpdated(transactions))
    }

case .addTransaction:
    return .none
```

- [ ] **Step 3: Run the full Features test suite — expect all pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | grep -E "(✔|✘|passed|failed|TEST SUCCEEDED|TEST FAILED)"
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Transactions/TransactionsFeature.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift
git commit -m "fix: propagate updated transaction to list and dashboard after edit"
```

---

## Task 4: Add `answerFinancialQuestion` to `AIServiceClient` + implement `QueryTransactionsTool`

**Files:**
- Modify: `Features/Sources/Domain/Clients/AIServiceClient.swift`
- Modify: `Features/Sources/Core/Clients/AIServiceClient+Live.swift`

> `QueryTransactionsTool` uses Foundation Models — it cannot be unit-tested in simulator. No new tests for the liveValue; the interface is covered by the domain-level `testValue` unimplemented stub.

- [ ] **Step 1: Add `answerFinancialQuestion` to `AIServiceClient.swift`**

After the `generateInsight` property, add:

```swift
/// Answers a natural language financial question by querying transaction history via Tool Calling.
///
/// - Parameter question: The user's question in natural language (e.g., "上個月餐費花了多少？").
/// - Returns: A natural language answer generated on-device.
public var answerFinancialQuestion: @Sendable (String) async throws -> String
```

- [ ] **Step 2: Build to confirm no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Implement `QueryTransactionsTool` and `answerFinancialQuestion` liveValue**

In `AIServiceClient+Live.swift`, add before the `extension AIServiceClient: DependencyKey` block:

```swift
// MARK: - QueryTransactionsTool

private struct QueryTransactionsTool: Tool {
    let description = "Query the user's transaction history by category name and/or date range"

    @Generable
    struct Arguments {
        @Guide(description: "Category name to filter by. Omit to include all categories.")
        var category: String?
        @Guide(description: "Start date in ISO 8601 format (YYYY-MM-DD). Omit for no lower bound.")
        var startDate: String?
        @Guide(description: "End date in ISO 8601 format (YYYY-MM-DD). Omit for no upper bound.")
        var endDate: String?
    }

    let transactionClient: TransactionClient
    let categoryClient: CategoryClient

    func call(arguments: Arguments) async throws -> ToolOutput {
        let allCategories = try await categoryClient.fetchAll()

        // Resolve category name to ID (case-insensitive match)
        var categoryIds: [Domain.Category.ID]? = nil
        if let name = arguments.category {
            let matched = allCategories.filter {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            if !matched.isEmpty {
                categoryIds = matched.map(\.id)
            }
        }

        // Parse date range
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let start = arguments.startDate.flatMap { iso.date(from: $0) }
        let end = arguments.endDate.flatMap { iso.date(from: $0) }
        let dateRange: ClosedRange<Date>? = (start != nil || end != nil)
            ? (start ?? .distantPast)...(end ?? .distantFuture)
            : nil

        let filter = TransactionFilter(
            categoryIds: categoryIds.map(Set.init),
            dateRange: dateRange
        )
        let transactions = try await transactionClient.fetch(filter)

        if transactions.isEmpty {
            return ToolOutput("查無交易紀錄。")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let lines = transactions.map { t in
            "\(formatter.string(from: t.date)) \(t.note ?? "（無備註）") NT$\(t.amount)"
        }
        return ToolOutput(lines.joined(separator: "\n"))
    }
}
```

Then add `answerFinancialQuestion` to the `liveValue` (inside `AIServiceClient.liveValue`, after `generateInsight`):

```swift
answerFinancialQuestion: { question in
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    let tool = QueryTransactionsTool(
        transactionClient: transactionClient,
        categoryClient: categoryClient
    )
    let session = LanguageModelSession(tools: [tool])
    return try await session.respond(to: question).content
},
```

- [ ] **Step 4: Build to confirm no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Clients/AIServiceClient.swift \
        Features/Sources/Core/Clients/AIServiceClient+Live.swift
git commit -m "feat(ai): add answerFinancialQuestion with QueryTransactionsTool"
```

---

## Task 5: Add `InputPurpose`, `aiAnswer`, and ask-mode reducer to `MainTabFeature`

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add `ai_ask_error` localization key**

In `NeuLedger/Resources/Localizable.xcstrings`, find the `ai_`-prefixed keys section and add:

```json
"ai_ask_error": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Could not get an answer, please try again" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "無法取得回答，請再試一次" } }
  }
},
```

- [ ] **Step 2: Write failing tests for ask mode**

Add to `MainTabFeatureTests.swift` (in a new `@Suite` block or appended to existing):

```swift
@Suite("MainTabFeature — ask mode")
struct MainTabAskModeTests {

    @Test("inputPurposeSwitched clears text and answer")
    func testInputPurposeSwitchedToAsk() async {
        var initial = MainTabFeature.State()
        initial.aiInputText = "some text"
        initial.aiAnswer = "some answer"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }

        await store.send(.inputPurposeSwitched(.ask)) {
            $0.inputPurpose = .ask
            $0.aiInputText = ""
            $0.aiAnswer = nil
            $0.aiInputError = nil
        }
    }

    @Test("askSubmitted receives answer and resets loading")
    func testAskSubmittedReceivesAnswer() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.inputPurpose = .ask
        initial.aiInputText = "上個月餐費多少？"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.answerFinancialQuestion = { _ in "上個月餐費 NT$8,500" }
        }

        await store.send(.askSubmitted) {
            $0.isAIInputLoading = true
            $0.aiInputError = nil
            $0.aiAnswer = nil
        }
        await store.receive(\.answerReceived) {
            $0.aiAnswer = "上個月餐費 NT$8,500"
            $0.isAIInputLoading = false
            $0.aiInputText = ""
        }
    }

    @Test("askSubmitted on failure sets aiInputError")
    func testAskSubmittedHandlesFailure() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.inputPurpose = .ask
        initial.aiInputText = "上個月餐費多少？"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.answerFinancialQuestion = { _ in
                struct FakeError: Error {}
                throw FakeError()
            }
        }

        await store.send(.askSubmitted) {
            $0.isAIInputLoading = true
            $0.aiInputError = nil
            $0.aiAnswer = nil
        }
        await store.receive(\.answerFailed) {
            $0.isAIInputLoading = false
            $0.aiInputError = String(localized: "ai_ask_error")
        }
    }
}
```

- [ ] **Step 3: Run tests — expect COMPILE ERROR**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing:FeaturesTests/MainTabFeatureTests \
  2>&1 | grep -E "(error:|✘|passed|failed)"
```

Expected: compile error (`inputPurpose`, `aiAnswer`, `askSubmitted` etc. don't exist yet).

- [ ] **Step 4: Update `MainTabFeature.swift`**

**4a — Add `InputPurpose` enum** (before the `@Reducer` macro or as a top-level enum in the file):

```swift
public enum InputPurpose: Equatable, Sendable {
    case record
    case ask
}
```

**4b — Add to `State`:**

```swift
public var inputPurpose: InputPurpose = .record
public var aiAnswer: String? = nil
```

**4c — Add to `Action` enum:**

```swift
case inputPurposeSwitched(InputPurpose)
case askSubmitted
case answerReceived(String)
case answerFailed
```

**4d — Add `CancelID.aiAnswer`:**

```swift
private enum CancelID { case aiExtraction; case aiAnswer }
```

**4e — Update `aiInputDismissed` handler** — add `state.aiAnswer = nil`:

```swift
case .aiInputDismissed:
    state.isAIInputExpanded = false
    state.aiInputText = ""
    state.isAIInputLoading = false
    state.aiInputError = nil
    state.aiAnswer = nil        // ← add this line
    return .none
```

**4f — Add new action handlers** (inside the main `Reduce` switch, after `aiExtractionCompleted`):

```swift
case let .inputPurposeSwitched(purpose):
    state.inputPurpose = purpose
    state.aiInputText = ""
    state.aiAnswer = nil
    state.aiInputError = nil
    return .cancel(id: CancelID.aiAnswer)

case .askSubmitted:
    guard !state.aiInputText.isEmpty else { return .none }
    state.isAIInputLoading = true
    state.aiInputError = nil
    state.aiAnswer = nil
    let question = state.aiInputText
    return .run { send in
        do {
            let answer = try await aiServiceClient.answerFinancialQuestion(question)
            await send(.answerReceived(answer))
        } catch {
            await send(.answerFailed)
        }
    }
    .cancellable(id: CancelID.aiAnswer, cancelInFlight: true)

case let .answerReceived(text):
    guard state.inputPurpose == .ask else { return .none }
    state.aiAnswer = text
    state.isAIInputLoading = false
    state.aiInputText = ""
    return .none

case .answerFailed:
    state.isAIInputLoading = false
    state.aiInputError = String(localized: "ai_ask_error")
    return .none
```

- [ ] **Step 5: Run targeted tests — expect all 3 new tests PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -only-testing:FeaturesTests/MainTabFeatureTests \
  2>&1 | grep -E "(✔|✘|passed|failed)"
```

Expected: all `MainTabFeatureTests` pass (existing + 3 new).

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift \
        Features/Tests/FeaturesTests/MainTabFeatureTests.swift \
        NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(main-tab): add InputPurpose ask mode and answerFinancialQuestion reducer"
```

---

## Task 6: Update `MainTabView` — add mode toggle and inline answer display

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`

> UI changes — no unit tests. Verify visually on simulator.

- [ ] **Step 1: Find the AI Input Bar section in `MainTabView.swift`**

Search for `aiInputBar` or `isAIInputExpanded` in the file. The input bar is rendered conditionally. Identify:
- Where `aiInputText` is bound
- Where the submit button is
- Where `aiInputError` is displayed

- [ ] **Step 2: Add the mode toggle to the input bar**

In the AI input bar HStack (wherever the text field and submit button live), add a leading toggle before the text field:

```swift
// Mode toggle — record vs ask
if store.isAIInputExpanded {
    HStack(spacing: 4) {
        Button {
            store.send(.inputPurposeSwitched(.record))
        } label: {
            Label(String(localized: "ai_mode_record"), systemImage: "pencil")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(store.inputPurpose == .record
                    ? Color.accentColor
                    : Color.secondary.opacity(0.15))
                .foregroundStyle(store.inputPurpose == .record
                    ? Color.white
                    : Color.secondary)
                .clipShape(Capsule())
        }

        Button {
            store.send(.inputPurposeSwitched(.ask))
        } label: {
            Label(String(localized: "ai_mode_ask"), systemImage: "bubble.left")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(store.inputPurpose == .ask
                    ? Color.accentColor
                    : Color.secondary.opacity(0.15))
                .foregroundStyle(store.inputPurpose == .ask
                    ? Color.white
                    : Color.secondary)
                .clipShape(Capsule())
        }
    }
}
```

Add the 2 localization keys to `Localizable.xcstrings`:

```json
"ai_mode_record": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Record" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "記帳" } }
  }
},
"ai_mode_ask": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Ask AI" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "問 AI" } }
  }
},
```

- [ ] **Step 3: Update submit button to route by `inputPurpose`**

Find the submit button action and replace it:

```swift
// BEFORE (always aiInputSubmitted):
store.send(.aiInputSubmitted)

// AFTER (route by purpose):
if store.inputPurpose == .ask {
    store.send(.askSubmitted)
} else {
    store.send(.aiInputSubmitted)
}
```

- [ ] **Step 4: Add inline answer display**

Above (or below) the input bar text field area, add:

```swift
if let answer = store.aiAnswer {
    Text(answer)
        .font(Font.Design.body)
        .foregroundStyle(Color.Design.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

- [ ] **Step 5: Build and run on simulator**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Manually verify on simulator:
- Record mode: existing add-transaction flow unchanged
- Ask mode: typing a question + submit shows loading spinner, then inline answer
- Dismiss: clears answer

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabView.swift \
        NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(main-tab): add ask/record mode toggle and inline AI answer UI"
```

---

## Task 7: Full suite verification

- [ ] **Step 1: Run the complete test suite**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: If failures — check which tests fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  2>&1 | grep "✘"
```

Fix any failures before proceeding.

- [ ] **Step 3: If all pass — done** ✅
