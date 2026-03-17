# AI Integration Design
**Date:** 2026-03-17
**Status:** Approved
**Scope:** Implement real Foundation Models integration for all four `AIServiceClient` methods

---

## Background

`AIServiceClient.liveValue` currently returns empty placeholder results for all methods. The architecture (client interface, `@Dependency` injection, call sites in `AnalysisFeature` and `AddTransactionFeature`) is already in place. This change wires in real on-device Apple Foundation Models inference.

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

### Why Domain imports FoundationModels
`@Generable` must be applied to the structs that Foundation Models generates into — `ExtractedTransaction` and `CategorySuggestions`, which live in Domain. `FoundationModels` is a pure Apple framework (not a persistence dependency), consistent with the project's iOS 26-only constraint. This does not violate the "zero persistence deps" rule.

---

## Domain Layer Changes

### ExtractedTransaction
```swift
import FoundationModels

// @Generable tells Foundation Models how to produce this struct from natural language.
// Each property maps to a field the model should attempt to populate.
@Generable
public struct ExtractedTransaction: Equatable, Sendable {
    @Guide(description: "Transaction amount in TWD, always positive")
    public var amount: Decimal

    @Guide(description: "Type of transaction: expense, income, or transfer")
    public var type: String  // raw value of TransactionType

    @Guide(description: "Short note or description, in Traditional Chinese if possible")
    public var note: String

    @Guide(description: "Best-guess category name from user's input, may be empty")
    public var suggestedCategoryName: String
}
```

### CategorySuggestions
```swift
import FoundationModels

// @Generable for structured category recommendation output.
@Generable
public struct CategorySuggestions: Equatable, Sendable {
    @Guide(description: "Up to 3 category names from the provided list, ranked by relevance")
    public var suggestions: [String]
}
```

---

## Core Layer Changes

### AIServiceClient+Live.swift

All four methods are implemented on a `@ModelActor`-isolated actor to ensure thread safety. Each method creates its own `LanguageModelSession` — sessions are lightweight and scoped per-call. `generateInsight` uses a memory cache keyed by `SpendingSummary` hash to avoid redundant inference for the same data.

#### isAvailable()
```swift
// Checks whether the on-device Foundation Model is ready to use.
// Returns false on unsupported devices or when the model hasn't finished downloading.
func isAvailable() -> Bool {
    SystemLanguageModel.default.isAvailable
}
```

#### extractTransaction(_ input: String) throws -> ExtractedTransaction
```swift
// Parses natural language input (e.g. "午餐花了150") into a structured transaction.
// Creates a fresh session per call — no shared context needed here.
// Throws on model unavailability or inference failure; caller decides how to handle.
let session = LanguageModelSession()
let prompt = """
從以下輸入解析出一筆交易紀錄，金額單位為新台幣。
輸入：\(input)
"""
return try await session.respond(to: prompt, generating: ExtractedTransaction.self)
```

#### suggestCategories(_ description: String, _ existingCategories: [String]) throws -> CategorySuggestions
```swift
// Given a transaction description and the user's existing category list,
// returns up to 3 ranked category suggestions.
// Passing the full category list constrains the model to known options.
let session = LanguageModelSession()
let categoryList = existingCategories.joined(separator: "、")
let prompt = """
根據以下交易描述，從分類清單中選出最合適的分類（最多3個，依相關性排序）。
交易描述：\(description)
可用分類：\(categoryList)
"""
return try await session.respond(to: prompt, generating: CategorySuggestions.self)
```

#### generateInsight(_ summary: SpendingSummary) throws -> String
```swift
// Generates a Traditional Chinese spending insight paragraph.
// Results are cached in-memory by SpendingSummary hash — the same summary
// within an app session won't trigger a second inference call.
// Cache is intentionally not persisted to disk (insights should refresh each launch).
```

**Cache implementation:**
```swift
private var insightCache: [Int: String] = [:]

// In generateInsight:
let cacheKey = summary.hashValue
if let cached = insightCache[cacheKey] { return cached }
// ... run inference ...
insightCache[cacheKey] = result
return result
```

---

## Features Layer Changes

### MainTabFeature

New state and actions for the AI input bar:

```swift
// State additions
var isAIInputExpanded: Bool = false
var aiInputText: String = ""
var isAIInputLoading: Bool = false

// Action additions
case aiInputButtonTapped
case aiInputTextChanged(String)
case aiInputSubmitted
case aiInputDismissed
case aiExtractionCompleted(TaskResult<ExtractedTransaction>)
```

**Flow:**
1. User taps AI wand button → `isAIInputExpanded = true`
2. User types → `aiInputText` updated
3. User taps send → calls `aiServiceClient.extractTransaction(aiInputText)`
4. On success → closes input bar, sends `dashboard(.addTransactionWithPrefilledData(extracted))` or `transactions(.addTransactionWithPrefilledData(extracted))` depending on selected tab
5. On failure → shows inline error, input bar stays open

### MainTabView — tabViewBottomAccessory

Two states rendered with animation:

**Compact (default):**
```
[  AI wand button  ]  [  + button  ]
```

**Expanded:**
```
[ text field: "交易描述..." ]  [ send button ]  [ × dismiss ]
```

- AI button disabled + grayed when `!aiServiceClient.isAvailable()`
- Tapping disabled AI button shows brief tooltip: "此裝置不支援 AI 功能"
- Expansion animates using `.spring()` transition

### AddTransactionFeature

**Background note parsing (debounce):**
```swift
// State additions
var isBackgroundParsingNote: Bool = false

// Action additions
case noteChanged(String)             // triggers debounce
case backgroundExtractionCompleted(TaskResult<ExtractedTransaction>)
```

On `noteChanged`: cancel previous debounce, schedule new `.run` after 500ms calling `extractTransaction`. On success: fill only **empty** fields (never overwrite user input). `isBackgroundParsingNote` drives a small loading indicator on the note field.

**Category AI suggestion button:**
```swift
// State additions
var isSuggestingCategory: Bool = false
var suggestedCategoryIds: [Category.ID] = []  // up to 3

// Action additions
case suggestCategoryTapped
case categorySuggestionsReceived(TaskResult<CategorySuggestions>)
```

Button states:
- Normal: wand icon, tappable
- Loading: `ProgressView` spinner
- Unavailable: grayed wand, disabled, `.help("此裝置不支援 AI 功能")`

On success: highlight up to 3 categories in the picker with an accent ring. User still makes the final selection.

---

## Graceful Degradation

| AI Feature | Available | Unavailable |
|-----------|-----------|-------------|
| TabBar AI wand | Tappable | Grayed + disabled, tooltip on tap |
| Note field background parsing | Runs silently | Skipped entirely |
| Category AI suggest button | Tappable | Grayed + disabled |
| Analysis insight card | Shows AI text | Shows gray placeholder "AI 洞察需要裝置支援" |

`isAvailable()` is checked once on `MainTabFeature.task` and stored in state — not re-checked on every interaction.

---

## Error Handling

- `extractTransaction` failure in TabBar input: show inline error text below the input field, keep input open
- `extractTransaction` failure in note debounce: silently ignore (user is mid-typing anyway)
- `suggestCategories` failure: show brief inline message "無法取得建議，請手動選擇"
- `generateInsight` failure: Analysis insight card shows gray placeholder (same as unavailable state)

---

## Code Comment Convention

Each non-trivial method in `AIServiceClient+Live.swift` gets:
1. A `// MARK: - MethodName` section header
2. A short comment explaining **why** the approach was chosen (not just what it does)
3. Inline comments on any non-obvious prompt engineering decisions

---

## Testing

| Test | Approach |
|------|---------|
| `AIServiceClientTests` (Domain) | Verify `testValue` stubs are accessible via `DependencyValues` |
| `AIServiceClientLiveTests` (Core) | Skip inference; test cache logic and error propagation with mock session |
| `MainTabFeatureTests` | Test AI input state machine: expand → type → submit → result routing |
| `AddTransactionFeatureTests` | Test debounce cancellation, partial-fill logic (no overwrite), suggest button states |

---

## Open Questions

None — all decisions made during design session.
