# AI Integration Design
**Date:** 2026-03-17
**Status:** Approved
**Scope:** Implement real Foundation Models integration for all four `AIServiceClient` methods

---

## Background

`AIServiceClient.liveValue` (in `Core/Clients/AIServiceClient+Live.swift`) currently returns stub placeholder results for all four methods. The wiring is already partially in place:
- `AnalysisFeature` calls `aiServiceClient.isAvailable()` and `generateInsight` — currently always skipped because `isAvailable` returns `false`
- `DashboardFeature` already injects `aiServiceClient` via `@Dependency(\.aiServiceClient)`

This change replaces the stub `liveValue` with real Foundation Models inference. `AddTransactionFeature` does **not** currently inject `aiServiceClient` — adding it is a net-new dependency as part of this change.

---

## Goals

1. Implement all four `AIServiceClient` methods with real Foundation Models calls
2. Add natural language transaction input via the TabBar bottom accessory
3. Add background AI assistance in the AddTransaction note field
4. Add a manual AI category suggestion button in the category picker
5. Graceful degradation when Foundation Models is unavailable

---

## Non-Goals

- Multi-language AI prompts (繁體中文 only, per CLAUDE.md)
- Server-side AI (all inference is on-device)
- Persistent AI session history across app launches
- Streaming responses

---

## Architecture

### Dependency Direction
No changes to dependency direction. `Features → Core → Domain` remains intact.
`FoundationModels` is imported in Domain (for `@Generable`) and Core (for session management).

### FoundationModels in Domain
`@Generable` must be applied to the structs that Foundation Models generates into — `ExtractedTransaction` and `CategorySuggestions`, which live in Domain. `FoundationModels` is an Apple **system framework** (like `Foundation`) — not a package dependency. No `Package.swift` change is required; `import FoundationModels` works in any SPM target targeting iOS 26. This does not violate the "zero persistence deps" rule.

### Thread Safety for AIServiceClient
Foundation Models `LanguageModelSession` is `Sendable` and designed for `async/await`. Each method creates a fresh session inside its `async` closure.

The `generateInsight` memory cache requires thread-safe shared mutable state. A dedicated `InsightCache` actor holds the cache, stored as a `static let` on `AIServiceClient` (not inside `liveValue`) so it is truly shared across all closure invocations.

### Foundation Models API Return Types

`LanguageModelSession` methods used in this spec:
- `session.respond(to: prompt, generating: MyType.self)` → returns `MyType` directly for `@Generable` types
- `session.respond(to: prompt)` → returns `String` directly

Both are `async throws`.

> **Implementation note:** Verify against the shipping iOS 26 Foundation Models SDK. If the SDK wraps results in a container type (e.g. `.content`), add the unwrap at all three inference call sites. The rest of the spec is unaffected by this API detail.

---

## Domain Layer Changes

### ExtractedTransaction
Add `@Generable` conformance and `import FoundationModels`. **Field names, types, and optionality are kept exactly as-is** — the only structural changes are `@Generable` and `@Guide` annotations. No call sites are broken.

```swift
import Foundation
import FoundationModels

// @Generable tells Foundation Models how to produce this struct from natural language.
// All fields are Optional so the model can express uncertainty — callers check nil before using.
@Generable
public struct ExtractedTransaction: Equatable, Sendable {
    @Guide(description: "Transaction amount in TWD, always positive. Nil if unclear.")
    public var amount: Double?

    @Guide(description: "Best-guess category name from user's input. Nil if not determinable.")
    public var suggestedCategory: String?

    @Guide(description: "Short note in Traditional Chinese if possible. Nil if not provided.")
    public var description: String?

    @Guide(description: "Type: 'expense', 'income', or 'transfer'. Nil if unclear.")
    public var type: String?
}
```

### CategorySuggestions
Add `@Generable` conformance and `import FoundationModels`. The `confidence` field is retained.

```swift
import Foundation
import FoundationModels

// @Generable for structured category recommendation output.
@Generable
public struct CategorySuggestions: Equatable, Sendable {
    @Guide(description: "Up to 3 category names from the provided list, ranked by relevance. Must be exact matches.")
    public var suggestions: [String]

    @Guide(description: "Confidence level: 'high', 'medium', or 'low'.")
    public var confidence: String
}
```

---

## Core Layer Changes

### New file: `Core/Clients/InsightCache.swift`

`InsightCache` uses a `String` cache key derived from the summary's content. This avoids any `Hashable` synthesis questions (e.g., whether `Decimal` is `Hashable` in the target Swift version) and makes the cache key deterministic and collision-free for practical inputs.

```swift
import Domain

// InsightCache is an actor so concurrent generateInsight calls never race on the dictionary.
// The cache key is a stable string representation of the summary — no Hashable synthesis needed.
// Not persisted to disk: insights reflect fresh transaction data each app launch.
actor InsightCache {
    private var storage: [String: String] = [:]

    func get(for summary: SpendingSummary) -> String? {
        storage[cacheKey(for: summary)]
    }

    func set(_ insight: String, for summary: SpendingSummary) {
        storage[cacheKey(for: summary)] = insight
    }

    // Key encodes all fields that affect the insight output.
    // Format: "period|income|expense|cat1:amount1,cat2:amount2"
    private func cacheKey(for summary: SpendingSummary) -> String {
        let cats = summary.categoryBreakdown
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        return "\(summary.periodDescription)|\(summary.totalIncome)|\(summary.totalExpense)|\(cats)"
    }
}
```

### AIServiceClient+Live.swift (full replacement)

`InsightCache` is stored as a `static let` so it is created once and shared across all `liveValue` closure invocations — not re-created each time `liveValue` is accessed.

```swift
import Foundation
import FoundationModels
import Domain
import Dependencies

extension AIServiceClient: DependencyKey {
    // InsightCache lives here as a static let so the cache persists for the app session
    // and is shared by all calls to generateInsight — not reset each time liveValue is read.
    private static let insightCache = InsightCache()

    public static let liveValue = AIServiceClient(

        // MARK: - extractTransaction
        // Parses natural language into a structured ExtractedTransaction.
        // A fresh session per call — no shared context needed for single-shot extraction.
        // Throws on failure; caller decides whether to show an error or silently ignore.
        extractTransaction: { input in
            let session = LanguageModelSession()
            let prompt = """
            從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。
            所有文字欄位請使用繁體中文。
            輸入：\(input)
            """
            return try await session.respond(to: prompt, generating: ExtractedTransaction.self)
        },

        // MARK: - suggestCategories
        // Returns up to 3 ranked category suggestions from the user's existing list.
        // Constraining the model to known names prevents hallucinated categories.
        suggestCategories: { description, existingCategories in
            let session = LanguageModelSession()
            let categoryList = existingCategories.joined(separator: "、")
            let prompt = """
            根據以下交易描述，從分類清單中選出最合適的分類（最多3個，依相關性排序）。
            請只從清單中選擇，不要建議清單以外的分類。
            交易描述：\(description)
            可用分類：\(categoryList)
            """
            return try await session.respond(to: prompt, generating: CategorySuggestions.self)
        },

        // MARK: - generateInsight
        // Generates a Traditional Chinese spending insight paragraph.
        // Same summary within a session returns a cached result — no repeated inference.
        generateInsight: { [insightCache] summary in
            if let cached = await insightCache.get(for: summary) { return cached }
            let session = LanguageModelSession()
            let prompt = """
            請用繁體中文撰寫一段簡短的消費分析洞察（2-3句話）。
            時間範圍：\(summary.periodDescription)
            總收入：NT$\(summary.totalIncome)
            總支出：NT$\(summary.totalExpense)
            各分類支出：\(summary.categoryBreakdown.map { "\($0.key): NT$\($0.value)" }.joined(separator: "、"))
            """
            let result = try await session.respond(to: prompt)
            await insightCache.set(result, for: summary)
            return result
        },

        // MARK: - isAvailable
        // Synchronous — safe to call on any thread.
        // Returns false if the model is unsupported or not yet downloaded.
        isAvailable: {
            SystemLanguageModel.default.isAvailable
        }
    )
}
```

---

## Features Layer Changes

### MainTabFeature

**New state fields (additions):**
```swift
var isAIInputExpanded: Bool = false
var aiInputText: String = ""
var isAIInputLoading: Bool = false
var aiInputError: String? = nil      // shown below input field on extraction failure
var aiUnavailable: Bool = false      // set once on .task; drives all AI UI in MainTabView
```

**New actions (additions):**
```swift
case task                                              // net-new lifecycle action
case aiAvailabilityLoaded(Bool)
case aiInputButtonTapped
case aiInputTextChanged(String)
case aiInputSubmitted
case aiInputDismissed
case aiExtractionCompleted(TaskResult<ExtractedTransaction>)
```

**New dependency:**
```swift
@Dependency(\.aiServiceClient) var aiServiceClient
```

**New `CancelID`:**
```swift
private enum CancelID { case aiExtraction }
```

**`task` handler:**
```swift
case .task:
    return .run { send in
        await send(.aiAvailabilityLoaded(aiServiceClient.isAvailable()))
    }
```

**`aiInputSubmitted` handler:**
```swift
case .aiInputSubmitted:
    guard !state.aiInputText.isEmpty else { return .none }
    state.isAIInputLoading = true
    state.aiInputError = nil
    let text = state.aiInputText
    return .run { send in
        await send(.aiExtractionCompleted(
            TaskResult { try await aiServiceClient.extractTransaction(text) }
        ))
    }
    .cancellable(id: CancelID.aiExtraction, cancelInFlight: true)
```

**`aiExtractionCompleted` handler:**

On `.success(extracted)`:
- Reset input bar: `isAIInputExpanded = false`, `aiInputText = ""`, `isAIInputLoading = false`
- Route to the correct child feature based on `selectedTab`:
  - `.transactions` → `return .send(.transactions(.addTransactionWithPrefilledData(extracted)))`
  - all others → `return .send(.dashboard(.addTransactionWithPrefilledData(extracted)))`

> **TCA routing note:** In TCA, `Scope` reducers run **before** the parent `Reduce`. The `.transactions(...)` and `.dashboard(...)` child actions are processed by their respective `Scope` first, then the parent's `case .dashboard: return .none` / `case .transactions: return .none` catch-all arms run (returning `.none` as expected). No new cases are needed in `MainTabFeature.body` for this routing. However, `addTransactionWithPrefilledData` **must** be added to `DashboardFeature.Action` and `TransactionsFeature.Action` (these are net-new actions in their respective features, not existing ones).

On `.failure`:
- `isAIInputLoading = false`
- `aiInputError = "無法解析，請再試一次或手動輸入"`

**`aiInputDismissed` handler:**
```swift
case .aiInputDismissed:
    state.isAIInputExpanded = false
    state.aiInputText = ""
    state.isAIInputLoading = false
    state.aiInputError = nil
    return .none
```

### DashboardFeature — net-new action
```swift
// Received from MainTabFeature when AI extracts a transaction via the TabBar input bar.
case addTransactionWithPrefilledData(ExtractedTransaction)
```
Handler: presents `addTransaction` in `.addPrefilled(extracted)` mode (reusing `@Presents var addTransaction`).

### TransactionsFeature — net-new action
Same pattern. `TransactionsFeature` already has `@Presents var addTransaction` and `case addTransaction(PresentationAction<AddTransactionFeature.Action>)`.
```swift
case addTransactionWithPrefilledData(ExtractedTransaction)
```
Handler: presents `addTransaction` in `.addPrefilled(extracted)` mode.

### AddTransactionFeature — Mode extension
Add a new mode case for the TabBar AI flow:
```swift
public enum Mode: Equatable, Sendable {
    case add(TransactionType)
    case edit(Transaction)
    case addPrefilled(ExtractedTransaction)   // net-new: opened with AI-parsed data pre-loaded
}
```

`State.init` handles `.addPrefilled` in its switch:
```swift
case let .addPrefilled(extracted):
    self.type = TransactionType(rawValue: extracted.type ?? "") ?? .expense
    self.amountText = extracted.amount.map { String(Int($0)) } ?? ""
    self.note = extracted.description ?? ""
    self.accountId = nil    // user must select account
    self.toAccountId = nil
    self.categoryId = nil   // AI category matching via suggestCategoryTapped separately
    self.date = date
```

### AddTransactionFeature — saveTapped update
The existing `saveTapped` handler switches on `mode` with `.add` and `.edit` arms. Add `.addPrefilled` as a third arm, treated identically to `.add` (creates a new transaction — the mode's pre-filled data was only used for initial state):

```swift
case let .addPrefilled:
    // Treat exactly like .add — the pre-filled values are already in the form fields.
    let transaction = Transaction(
        amount: amountValue, date: date, note: note,
        categoryId: categoryId, accountId: accountId,
        toAccountId: toAccountId, type: type_
    )
    try await transactionClient.add(transaction)
```

### AddTransactionFeature — noteChanged (extend existing handler)
`case noteChanged(String)` **already exists** at line 85. The handler body is extended — add the debounce effect after `state.note = note`:

```swift
case let .noteChanged(note):
    state.note = note
    state.isBackgroundParsingNote = !note.isEmpty
    guard !note.isEmpty else {
        return .cancel(id: CancelID.noteDebounce)
    }
    // Use RunLoop.main scheduler — consistent with the debounce pattern in TransactionsFeature.
    // isAvailable() is checked inline rather than via a stored flag because AddTransactionFeature
    // has no .task lifecycle, and adding one solely for this check would be over-engineering.
    return .run { [note] send in
        guard aiServiceClient.isAvailable() else {
            await send(.backgroundExtractionCompleted(nil))
            return
        }
        let result = try? await aiServiceClient.extractTransaction(note)
        await send(.backgroundExtractionCompleted(result))
    }
    .debounce(id: CancelID.noteDebounce, for: .milliseconds(500), scheduler: RunLoop.main)
```

### AddTransactionFeature — extend existing CancelID enum
The **existing** enum is `private enum CancelID { case task }`. Extend it:
```swift
private enum CancelID { case task; case noteDebounce; case categorySuggest }
```

### AddTransactionFeature — new state, actions, dependency

**New state fields:**
```swift
var isBackgroundParsingNote: Bool = false
var isSuggestingCategory: Bool = false
var suggestedCategoryNames: [String] = []
var categorySuggestionError: String? = nil
```

**New actions:**
```swift
case backgroundExtractionCompleted(ExtractedTransaction?)
case suggestCategoryTapped
case categorySuggestionsReceived(TaskResult<CategorySuggestions>)
```

**New dependency:**
```swift
@Dependency(\.aiServiceClient) var aiServiceClient
```

**`backgroundExtractionCompleted` handler:**
Always sets `isBackgroundParsingNote = false` first, then applies values only to **empty** form fields:
- `amountText.isEmpty` → set from `extracted.amount`
- `note.isEmpty` → set from `extracted.description`
- `categoryId == nil` → attempt to match `extracted.suggestedCategory` against `state.filteredCategories`
- `type`: only update if mode is `.add(...)` and user has not manually changed the type. Skip for `.addPrefilled` (already set in `State.init`). Never update for `.edit`.

**`suggestCategoryTapped` handler:**
```swift
case .suggestCategoryTapped:
    // Guard in the reducer — the View disables the button, but this prevents subtle bugs
    // if availability state drifts after initial load.
    guard aiServiceClient.isAvailable() else {
        state.categorySuggestionError = "此裝置不支援 AI 功能"
        return .none
    }
    state.isSuggestingCategory = true
    state.categorySuggestionError = nil
    let description = state.note
    let categoryNames = state.filteredCategories.map(\.name)
    return .run { send in
        await send(.categorySuggestionsReceived(
            TaskResult { try await aiServiceClient.suggestCategories(description, categoryNames) }
        ))
    }
    .cancellable(id: CancelID.categorySuggest, cancelInFlight: true)
```

**`categorySuggestionsReceived` handler:**
- `.success`: `isSuggestingCategory = false`; filter results to names in `state.filteredCategories`; store in `suggestedCategoryNames`
- `.failure`: `isSuggestingCategory = false`; `categorySuggestionError = "無法取得建議，請手動選擇"`

---

## MainTabView — tabViewBottomAccessory

The existing `+` button (bound to `.contextActionTapped`) is **unchanged** in behaviour. The AI wand button is added to its left.

**Compact layout (default):**
```
[ AI wand button ]  [ + button ]
```

**Expanded layout** (when `store.isAIInputExpanded`):
```
[ text field: "描述這筆交易…" ]  [ send ]  [ × ]
```
- Error label shown below the text field when `store.aiInputError != nil`
- Transitions use `.spring()` animation

**AI wand button:** `.disabled(store.aiUnavailable)` + `.help("此裝置不支援 AI 功能")`. Use conditional `onTapGesture` when disabled to show a brief tooltip (plain `Button.disabled` silently eats taps).

---

## Graceful Degradation

`isAvailable()` is checked once on `MainTabFeature.task` and stored in `aiUnavailable`. `AddTransactionFeature` checks inline (intentional — no `.task` lifecycle).

| AI Feature | Available | Unavailable |
|-----------|-----------|-------------|
| TabBar AI wand | Tappable | Grayed, `.disabled`, `.help` tooltip |
| Note field background parsing | Runs after 500ms debounce | Skipped (`guard isAvailable()`) |
| Category AI suggest button | Tappable | Grayed, `.disabled`, reducer sets `categorySuggestionError` |
| Analysis insight card | Shows AI text | Shows gray placeholder "需要裝置支援 AI 功能" |

---

## Error Handling

| Error Site | Behaviour |
|-----------|-----------|
| `extractTransaction` failure in TabBar | `isAIInputLoading = false`; `aiInputError` set; inline error below field; input stays open |
| `extractTransaction` failure in note debounce | `try?` silent ignore; `isBackgroundParsingNote = false` |
| `suggestCategories` failure | `isSuggestingCategory = false`; `categorySuggestionError` set |
| `generateInsight` failure | Analysis insight card shows gray placeholder |

`LanguageModelError` propagates as `Error`. Feature layer catches generically.

---

## Code Comment Convention

Each method in `AIServiceClient+Live.swift` gets:
1. A `// MARK: - MethodName` section header
2. A comment explaining **why** the approach was chosen
3. Inline comments on non-obvious prompt engineering decisions

---

## Testing

| Test | Notes |
|------|-------|
| `AIServiceClientTests` (Domain) | Verify `testValue` stubs accessible via `DependencyValues` — no change needed |
| `InsightCacheTests` (Core, new) | Hit returns stored value; miss calls inference; different summaries produce different keys |
| `MainTabFeatureTests` | `task` → availability stored; expand → type → submit → `aiExtractionCompleted(.success)` → input dismissed + correct child action per `selectedTab`; failure sets `aiInputError` |
| `DashboardFeatureTests` (existing — unaffected) | Existing tests don't call `addTransactionWithPrefilledData`. New test: `addTransactionWithPrefilledData` presents `addTransaction` in `.addPrefilled` mode |
| `AddTransactionFeatureTests` (existing — unaffected) | The three existing tests don't call `noteChanged` — no stub changes needed |
| `AddTransactionFeatureTests` (new) | Any test calling `.send(.noteChanged(...))` must inject `$0.aiServiceClient.isAvailable = { false }`. Tests: debounce cancellation; partial-fill only-empty-fields; `suggestCategoryTapped` unavailable guard + loading + success + failure; `.addPrefilled` mode `State.init` mapping; `saveTapped` in `.addPrefilled` mode creates transaction |

---

## Open Questions

None — all decisions made during design session.
