# Design: Transaction Detail Edit Sync + AI Tool Calling

**Date:** 2026-03-20
**Status:** Approved
**Scope:** Bug fix (detail edit sync) + Feature (AI Tool Calling + Input Bar mode toggle)

---

## 1. Transaction Detail Edit Sync Fix

### Problem (accurate diagnosis)

`TransactionDetailFeature.Delegate` already has `case updated(Transaction)` — the payload exists. The real bug is two-fold:

1. `AddTransactionFeature.Delegate.saved` carries no payload, so `TransactionDetailFeature` cannot obtain the updated `Transaction` after the child edit completes.
2. `TransactionDetailFeature` never emits `.delegate(.updated(_))` — it only closes the sheet:

```swift
case let .editTransaction(.presented(.delegate(.saved))):
    state.editTransaction = nil  // closes sheet
    return .none                 // ← delegate never forwarded
```

### Fix

**Step 1 — Split `AddTransactionFeature.Delegate.saved`:**

```swift
public enum Delegate: Sendable, Equatable {
    case saved                              // add / addPrefilled mode
    case savedWithTransaction(Transaction)  // edit mode — carries updated transaction
    case dismissed
}
```

In the `.edit` branch of `saveTapped`, emit `.delegate(.savedWithTransaction(transaction))` instead of `.delegate(.saved)`.

**Step 2 — `TransactionDetailFeature` handles the new delegate case:**

```swift
case let .editTransaction(.presented(.delegate(.savedWithTransaction(t)))):
    state.transaction = t
    state.editTransaction = nil          // dismiss the edit sheet
    return .send(.delegate(.updated(t)))
```

**Step 3 — `TransactionsFeature` in-place update:**

The current handler at line 178 already matches `.delegate(.updated)` but discards the payload and does a full reload:

```swift
// Current (discard payload, full reload):
case .detail(.presented(.delegate(.updated))):
    state.detail = nil
    return .run { send in ... fetchAll ... }

// Replace with (use payload, in-place update):
case let .detail(.presented(.delegate(.updated(t)))):
    if let idx = state.transactions.firstIndex(where: { $0.id == t.id }) {
        state.transactions[idx] = t
    }
    state.detail = nil
    return .none
```

**Step 4 — `DashboardFeature` refresh after add/edit:**

`DashboardFeature.addTransaction` is currently a no-op (`return .none`) for all child actions. Add explicit handling to reload recent transactions after a save:

```swift
case .addTransaction(.presented(.delegate(.saved))),
     .addTransaction(.presented(.delegate(.savedWithTransaction(_)))):
    return .run { send in
        let transactions = try await transactionClient.fetchRecent()
        await send(.transactionsUpdated(transactions))
    }
```

Note: `savedWithTransaction(_)` must use the wildcard `_` since the associated value is not needed here.

**Other callers:** `TransactionsFeature` own edit flow (from list, not detail) still receives `.saved` — its existing handler is unchanged.

---

## 2. AI Tool Calling

### `QueryTransactionsTool` (private, inside `AIServiceClient+Live.swift`)

No new file needed — defined as a `private struct` inside `AIServiceClient+Live.swift`. Dependencies are resolved with `@Dependency` inside the async `answerFinancialQuestion` closure (valid inside `async` contexts):

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
}
```

**Tool definition:**

```swift
private struct QueryTransactionsTool: Tool {
    let description = "Query the user's transaction history by category and/or date range"

    @Generable
    struct Arguments {
        var category: String?   // category name; nil = all categories
        var startDate: String?  // ISO 8601
        var endDate: String?    // ISO 8601
    }

    let transactionClient: TransactionClient
    let categoryClient: CategoryClient

    func call(arguments: Arguments) async throws -> ToolOutput {
        // 1. Fetch all categories; find ID for arguments.category if provided
        // 2. Build TransactionFilter with dateRange + optional categoryIds
        // 3. Fetch via transactionClient.fetch(_:)
        // 4. Format as plain-text: "YYYY-MM-DD <note> NT$<amount>" per line
        // 5. Return ToolOutput(formatted string)
    }
}
```

### `AIServiceClient` — new method

Added to `Domain/Clients/AIServiceClient.swift`:

```swift
public var answerFinancialQuestion: @Sendable (String) async throws -> String
```

**testValue note:** `@DependencyClient` generates unimplemented stubs — calling `answerFinancialQuestion` in tests without an explicit override will fail. Always override in tests:

```swift
$0.aiServiceClient.answerFinancialQuestion = { _ in "上個月餐費 NT$8,500" }
```

**Privacy:** Entirely on-device via `LanguageModelSession`. No network requests.

---

## 3. AI Input Bar Mode Toggle (MainTab)

### State additions to `MainTabFeature.State`

```swift
enum InputPurpose: Equatable, Sendable {
    case record  // existing behaviour
    case ask     // new — financial Q&A
}

var inputPurpose: InputPurpose = .record
var aiAnswer: String? = nil
```

Reuse existing fields:
- `isAIInputLoading` — loading indicator for both modes
- `aiInputError` — inline error for both modes

### `CancelID` extension

Add `case aiAnswer` to the existing `private enum CancelID`:

```swift
private enum CancelID { case aiExtraction; case aiAnswer }
```

### New actions

```swift
case inputPurposeSwitched(InputPurpose)
case askSubmitted
case answerReceived(String)
case answerFailed
```

### Reducer logic

```swift
case let .inputPurposeSwitched(purpose):
    state.inputPurpose = purpose
    state.aiInputText = ""
    state.aiAnswer = nil
    state.aiInputError = nil
    // Cancel any in-flight ask effect when switching modes
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
    // Guard: ignore if user switched away from ask mode mid-flight
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

### `aiInputDismissed` — add `aiAnswer` reset

Update the existing `aiInputDismissed` handler to also clear `aiAnswer`:

```swift
case .aiInputDismissed:
    state.isAIInputExpanded = false
    state.aiInputText = ""
    state.isAIInputLoading = false
    state.aiInputError = nil
    state.aiAnswer = nil          // ← add this
    return .none
```

### Localization

Add to `Localizable.xcstrings`:
- Key: `ai_ask_error`
- zh-Hant: `"無法取得回答，請再試一次"`
- en: `"Could not get an answer, please try again"`

### UI changes

- **Mode toggle** (left of text field): SF Symbols segmented capsule — `pencil` + "記帳" / `bubble.left` + "問 AI". No emojis.
- `ask` mode submit → `.askSubmitted`
- `aiAnswer` displayed inline above Input Bar with glass card styling; hidden when `nil`
- `isAIInputLoading` drives spinner (shared)
- `aiInputError` drives inline error (shared)
- `record` mode behaviour completely unchanged

---

## 4. Unit Tests

### New file: `TransactionDetailFeatureTests.swift`

| Test | Asserts |
|------|---------|
| `testEditTappedPresentsEditForm` | `.editTapped` → `state.editTransaction` is non-nil with `.edit(transaction)` mode |
| `testEditSavedWithTransactionUpdatesStateAndSendsDelegate` | `.savedWithTransaction(t)` → `state.transaction == t`, `state.editTransaction == nil`, `receive(\.delegate.updated)` with payload `t` |
| `testDeleteConfirmedCallsDeleteAndDismisses` | `.deleteConfirmed` → `transactionClient.delete` called with correct id + `receive(\.delegate.deleted)` |

### Additions to `AddTransactionFeatureTests.swift`

| Test | Asserts |
|------|---------|
| `testEditModeSavedDelegateCarriesTransaction` | Edit mode save → `receive(\.delegate.savedWithTransaction)` carrying Transaction with updated field values |

### Additions to `MainTabFeatureTests.swift`

| Test | Asserts |
|------|---------|
| `testInputPurposeSwitchedToAsk` | `.inputPurposeSwitched(.ask)` → `state.inputPurpose == .ask`, `aiAnswer == nil`, `aiInputText == ""` |
| `testAskSubmittedReceivesAnswer` | `.askSubmitted` → `isAIInputLoading = true` → `receive(.answerReceived)` → `aiAnswer` set, `isAIInputLoading = false`, `aiInputText == ""` |
| `testAskSubmittedHandlesFailure` | `.askSubmitted` (stub throws) → `receive(.answerFailed)` → `aiInputError` set, `isAIInputLoading = false` |

All tests use `TestStore` with explicit `aiServiceClient.answerFinancialQuestion` overrides.

---

## Files Modified

| File | Change |
|------|--------|
| `Dashboard/AddTransactionFeature.swift` | Add `savedWithTransaction(Transaction)` case; emit in edit mode |
| `Dashboard/DashboardFeature.swift` | Handle `.saved` + `.savedWithTransaction(_)` to reload recent transactions |
| `Transactions/TransactionDetailFeature.swift` | Handle `.savedWithTransaction`, update state, emit `.delegate(.updated(t))` |
| `Transactions/TransactionsFeature.swift` | Bind `t` in `.delegate(.updated(t))` match; switch to in-place update |
| `Domain/Clients/AIServiceClient.swift` | Add `answerFinancialQuestion` method |
| `Core/Clients/AIServiceClient+Live.swift` | Add private `QueryTransactionsTool`; implement `answerFinancialQuestion` |
| `NeuLedger/Resources/Localizable.xcstrings` | Add `ai_ask_error` key |
| `Features/MainTab/MainTabFeature.swift` | Add `InputPurpose`, `aiAnswer`, `CancelID.aiAnswer`, new actions + reducer cases; update `aiInputDismissed` |
| `Features/MainTab/MainTabView.swift` | Add SF Symbol toggle + inline answer display |
| `Tests/FeaturesTests/TransactionDetailFeatureTests.swift` | New test file — 3 tests |
| `Tests/FeaturesTests/AddTransactionFeatureTests.swift` | Add 1 edit-mode delegate test |
| `Tests/FeaturesTests/MainTabFeatureTests.swift` | Add 3 ask-mode tests |
