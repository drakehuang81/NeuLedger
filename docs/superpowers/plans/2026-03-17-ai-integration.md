# AI Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real Apple Foundation Models inference into all four `AIServiceClient` methods, and surface AI capabilities in the TabBar input bar, AddTransaction form, and Analysis screen.

**Architecture:** Domain entities gain `@Generable` conformance; Core gets a real `AIServiceClient+Live.swift` with per-call `LanguageModelSession` and an actor-based insight cache; Features gain an AI input bar in `MainTabView`, background note parsing and a category suggestion button in `AddTransactionView`.

**Tech Stack:** Apple Foundation Models (`LanguageModelSession`, `@Generable`, `@Guide`), TCA v1.23.1, Swift Testing (`@Suite`, `@Test`), Swift Concurrency (`actor`, `async/await`)

**Spec:** `docs/superpowers/specs/2026-03-17-ai-integration-design.md`

**Build command:**
```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

**Test command:**
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(PASS|FAIL|error:|Build)"
```

---

## Chunk 1: Domain Layer — @Generable Conformance

### Task 1: ExtractedTransaction — add @Generable

> **TDD note:** This task adds `@Generable` annotations to an existing struct — there is no behavioral change to test in isolation. Correctness is verified by build success (compiler macro expansion) and by the existing `DomainTests/AIServiceClientTests` which confirm the `testValue` still compiles. No separate unit test is added.

> **`@Generable` init conflict note:** The `@Generable` macro may synthesize its own initializer. If the build fails with a "redeclaration" error on the custom `init`, remove the explicit `init` block — `@Generable` provides a synthesized version. Verify against the shipping iOS 26 SDK.

**Files:**
- Modify: `Features/Sources/Domain/Entities/ExtractedTransaction.swift`

- [ ] **Step 1: Update `ExtractedTransaction.swift`**

Replace the entire file with:

```swift
import Foundation
import FoundationModels

/// A data structure holding transaction fragments parsed from natural language.
///
/// `@Generable` lets Foundation Models produce this struct directly from a prompt.
/// All fields are Optional so the model can express uncertainty — callers check nil before using.
@Generable
public struct ExtractedTransaction: Equatable, Sendable {
    /// The parsed monetary value of the transaction, if successfully determined.
    @Guide(description: "Transaction amount in TWD, always positive. Nil if unclear.")
    public var amount: Double?

    /// A potential category name interpreted from the context of the user's description.
    @Guide(description: "Best-guess category name from user's input. Nil if not determinable.")
    public var suggestedCategory: String?

    /// A cleaned and formatted version of the transaction's description or note.
    @Guide(description: "Short note in Traditional Chinese if possible. Nil if not provided.")
    public var description: String?

    /// The interpreted textual nature of the transaction.
    @Guide(description: "Type: 'expense', 'income', or 'transfer'. Nil if unclear.")
    public var type: String?

    // Keep the custom init for callers (testValue, test fixtures, etc.).
    // If @Generable synthesizes a conflicting init, remove this block.
    public init(
        amount: Double? = nil,
        suggestedCategory: String? = nil,
        description: String? = nil,
        type: String? = nil
    ) {
        self.amount = amount
        self.suggestedCategory = suggestedCategory
        self.description = description
        self.type = type
    }
}
```

- [ ] **Step 2: Run existing DomainTests to verify no regressions**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:DomainTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: all existing DomainTests pass

- [ ] **Step 3: Build to verify `@Generable` compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Domain/Entities/ExtractedTransaction.swift
git commit -m "feat(domain): add @Generable conformance to ExtractedTransaction"
```

---

### Task 2: CategorySuggestions — add @Generable

> **TDD note:** Same as Task 1 — annotation-only change. DomainTests verify no regressions. Same `@Generable` init conflict caveat applies: remove the explicit `init` if the SDK synthesizes a conflicting one.

**Files:**
- Modify: `Features/Sources/Domain/Entities/CategorySuggestions.swift`

- [ ] **Step 1: Update `CategorySuggestions.swift`**

Replace the entire file with:

```swift
import Foundation
import FoundationModels

/// A structured response containing category recommendations provided by an AI service.
///
/// `@Generable` lets Foundation Models produce this struct from a prompt.
@Generable
public struct CategorySuggestions: Equatable, Sendable {
    /// Up to 3 category names from the provided list, ranked by relevance. Must be exact matches.
    @Guide(description: "Up to 3 category names from the provided list, ranked by relevance. Must be exact matches from the list.")
    public var suggestions: [String]

    /// The AI's reported confidence level (e.g., "high", "medium", "low").
    @Guide(description: "Confidence level: 'high', 'medium', or 'low'.")
    public var confidence: String

    public init(
        suggestions: [String] = [],
        confidence: String
    ) {
        self.suggestions = suggestions
        self.confidence = confidence
    }
}
```

- [ ] **Step 2: Build to verify no regressions**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Domain/Entities/CategorySuggestions.swift
git commit -m "feat(domain): add @Generable conformance to CategorySuggestions"
```

---

## Chunk 2: Core Layer — InsightCache + Live Implementation

### Task 3: InsightCache actor

**Files:**
- Create: `Features/Sources/Core/Clients/InsightCache.swift`
- Create: `Features/Tests/CoreTests/InsightCacheTests.swift`

- [ ] **Step 1: Write the failing tests first**

Create `Features/Tests/CoreTests/InsightCacheTests.swift`:

```swift
import Testing
import Domain
@testable import Core

@Suite("InsightCache")
struct InsightCacheTests {

    @Test("cache miss returns nil")
    func cacheMissReturnsNil() async {
        let cache = InsightCache()
        let summary = SpendingSummary(
            totalIncome: 1000,
            totalExpense: 500,
            categoryBreakdown: ["食物": 300, "交通": 200],
            periodDescription: "2026年3月"
        )
        let result = await cache.get(for: summary)
        #expect(result == nil)
    }

    @Test("cache hit returns stored value")
    func cacheHitReturnsStoredValue() async {
        let cache = InsightCache()
        let summary = SpendingSummary(
            totalIncome: 1000,
            totalExpense: 500,
            categoryBreakdown: ["食物": 500],
            periodDescription: "本週"
        )
        await cache.set("你本週消費偏高", for: summary)
        let result = await cache.get(for: summary)
        #expect(result == "你本週消費偏高")
    }

    @Test("different summaries produce different keys")
    func differentSummariesDontCollide() async {
        let cache = InsightCache()
        let summary1 = SpendingSummary(
            totalIncome: 1000, totalExpense: 500,
            categoryBreakdown: [:], periodDescription: "本月"
        )
        let summary2 = SpendingSummary(
            totalIncome: 2000, totalExpense: 1000,
            categoryBreakdown: [:], periodDescription: "本月"
        )
        await cache.set("洞察一", for: summary1)
        let result1 = await cache.get(for: summary1)
        let result2 = await cache.get(for: summary2)
        #expect(result1 == "洞察一")
        #expect(result2 == nil)
    }

    @Test("same data with different category order hits cache")
    func categoryOrderDoesNotAffectCacheKey() async {
        let cache = InsightCache()
        let summary1 = SpendingSummary(
            totalIncome: 1000, totalExpense: 500,
            categoryBreakdown: ["食物": 300, "交通": 200],
            periodDescription: "本月"
        )
        let summary2 = SpendingSummary(
            totalIncome: 1000, totalExpense: 500,
            categoryBreakdown: ["交通": 200, "食物": 300],
            periodDescription: "本月"
        )
        await cache.set("洞察", for: summary1)
        let result = await cache.get(for: summary2)
        // Keys are sorted alphabetically, so order doesn't matter
        #expect(result == "洞察")
    }
}
```

- [ ] **Step 2: Run tests — expect build failure (InsightCache not yet created)**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CoreTests/InsightCacheTests 2>&1 | tail -10
```

Expected: compile error — `InsightCache` not found

- [ ] **Step 3: Create `InsightCache.swift`**

Create `Features/Sources/Core/Clients/InsightCache.swift`:

```swift
import Domain

/// Thread-safe in-memory cache for AI-generated spending insights.
///
/// Uses a `String` cache key (derived from `SpendingSummary` fields) rather than `Hashable`
/// synthesis to avoid any Swift version compatibility questions around `Decimal.Hashable`.
/// Not persisted to disk — insights reflect fresh transaction data each app launch.
actor InsightCache {
    private var storage: [String: String] = [:]

    func get(for summary: SpendingSummary) -> String? {
        storage[cacheKey(for: summary)]
    }

    func set(_ insight: String, for summary: SpendingSummary) {
        storage[cacheKey(for: summary)] = insight
    }

    /// Produces a stable, deterministic key from all summary fields.
    /// Category breakdown is sorted alphabetically so insertion order doesn't affect the key.
    /// Format: "period|income|expense|cat1:amount1,cat2:amount2"
    ///
    /// `Decimal.description` (used via Swift string interpolation) is locale-independent on Apple
    /// platforms — it uses a fixed "." decimal separator regardless of device locale. This is safe.
    /// Ref: NSDecimalNumber docs: "description" always uses period as separator.
    private func cacheKey(for summary: SpendingSummary) -> String {
        let cats = summary.categoryBreakdown
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        return "\(summary.periodDescription)|\(summary.totalIncome)|\(summary.totalExpense)|\(cats)"
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CoreTests/InsightCacheTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Clients/InsightCache.swift \
        Features/Tests/CoreTests/InsightCacheTests.swift
git commit -m "feat(core): add InsightCache actor with key-based caching"
```

---

### Task 4: AIServiceClient+Live — real Foundation Models implementation

**Files:**
- Modify: `Features/Sources/Core/Clients/AIServiceClient+Live.swift`

> **Note:** This task replaces the stub with real Foundation Models calls. Unit tests for the inference itself are impractical (require on-device model); correctness is validated manually on device. The cache logic is already tested in Task 3.

> **API verification:** Before implementing, check `LanguageModelSession.respond(to:generating:)` return type in the shipping iOS 26 SDK. If it returns a wrapper type (not `T` directly), add `.content` (or equivalent) at all three inference call sites.

- [ ] **Step 1: Replace `AIServiceClient+Live.swift`**

```swift
import Foundation
import FoundationModels
import Domain
import Dependencies

extension AIServiceClient: DependencyKey {
    // InsightCache is a static let so it is created once for the app session and shared
    // by all generateInsight calls — not reset each time liveValue is accessed.
    private static let insightCache = InsightCache()

    public static let liveValue = AIServiceClient(

        // MARK: - extractTransaction
        // A fresh LanguageModelSession per call — no shared context needed for single-shot extraction.
        // Throws on failure so the caller (Feature layer) decides: show error or silently ignore.
        extractTransaction: { input in
            let session = LanguageModelSession()
            let prompt = """
            從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。
            所有文字欄位請使用繁體中文。
            輸入：\(input)
            """
            // respond(to:generating:) returns ExtractedTransaction directly (iOS 26 SDK).
            // If the SDK wraps the result, use: try await session.respond(...).content
            return try await session.respond(to: prompt, generating: ExtractedTransaction.self)
        },

        // MARK: - suggestCategories
        // Passing the full existing category list constrains the model to known names,
        // preventing hallucinated categories that don't exist in the user's data.
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
        // Same SpendingSummary within a session hits the cache — no repeated inference for
        // the Analysis screen's period switcher (week/month/year all stay cached after first load).
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
        // Synchronous — safe to call on any thread without await.
        // Returns false if the device doesn't support Foundation Models or the model isn't downloaded.
        isAvailable: {
            SystemLanguageModel.default.isAvailable
        }
    )
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Clients/AIServiceClient+Live.swift
git commit -m "feat(core): implement real Foundation Models integration in AIServiceClient"
```

---

## Chunk 3: AddTransactionFeature — Foundation Changes

### Task 5: AddTransactionFeature — Mode, State, CancelID, new fields/actions

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`
- Test: `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift`

- [ ] **Step 1: Write failing tests for `.addPrefilled` mode State.init mapping**

Add these tests to the existing `AddTransactionFeatureTests` file now (they will fail until Step 2 implements the mode):

```swift
@Test(".addPrefilled mode pre-fills form fields from ExtractedTransaction")
func addPrefilledModePreFillsFields() async {
    let extracted = ExtractedTransaction(
        amount: 150,
        suggestedCategory: "食物",
        description: "午餐便當",
        type: "expense"
    )
    let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    #expect(state.amountText == "150")
    #expect(state.note == "午餐便當")
    #expect(state.type == .expense)
    #expect(state.categoryId == nil)
}

@Test(".addPrefilled with all-nil fields uses sensible defaults")
func addPrefilledNilFieldsDefaults() async {
    let extracted = ExtractedTransaction()
    let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    #expect(state.amountText == "")
    #expect(state.note == "")
    #expect(state.type == .expense)
}
```

- [ ] **Step 2: Run tests — expect build failure (`.addPrefilled` not yet defined)**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests 2>&1 | tail -5
```

Expected: compile error — `addPrefilled` not found

- [ ] **Step 3: Add `.addPrefilled` Mode case**

In `AddTransactionFeature.Mode`, add the new case after `.edit`:

```swift
public enum Mode: Equatable, Sendable {
    case add(TransactionType)
    case edit(Transaction)
    case addPrefilled(ExtractedTransaction)   // opened from TabBar AI input with pre-parsed data
}
```

- [ ] **Step 2: Handle `.addPrefilled` in `State.init`**

In `State.init`, add the new switch arm after `case let .edit(transaction):`:

```swift
case let .addPrefilled(extracted):
    // Map optional AI-parsed fields to form state; use sensible defaults for nil values.
    self.type = TransactionType(rawValue: extracted.type ?? "") ?? .expense
    self.amountText = extracted.amount.map { String(Int($0)) } ?? ""
    self.note = extracted.description ?? ""
    self.accountId = nil     // user must always select their own account
    self.toAccountId = nil
    self.categoryId = nil    // category matching handled separately via suggestCategoryTapped
    self.date = date
```

- [ ] **Step 3: Handle `.addPrefilled` in `saveTapped`**

In the `saveTapped` handler's inner `.run` block, the `switch mode` currently has `.add` and `.edit`. Add `.addPrefilled` treated identically to `.add`:

```swift
case .addPrefilled:
    // Pre-filled values were used for initial state only — saving works exactly like .add.
    let transaction = Transaction(
        amount: amountValue,
        date: date,
        note: note,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        type: type_
    )
    try await transactionClient.add(transaction)
```

- [ ] **Step 4: Extend `CancelID` enum**

Replace `private enum CancelID { case task }` with:

```swift
private enum CancelID { case task; case noteDebounce; case categorySuggest }
```

- [ ] **Step 5: Add new state fields**

Inside `State`, after the existing `isLoading: Bool` field, add:

```swift
// AI assistance state
public var isBackgroundParsingNote: Bool = false
public var isSuggestingCategory: Bool = false
public var suggestedCategoryNames: [String] = []
public var categorySuggestionError: String? = nil
```

- [ ] **Step 6: Add new actions and dependency**

In `Action` enum, after `case delegate(Delegate)`:

```swift
// AI assistance actions
case backgroundExtractionCompleted(ExtractedTransaction?)
case suggestCategoryTapped
case categorySuggestionsReceived(TaskResult<CategorySuggestions>)
```

After the existing `@Dependency(\.dismiss) var dismiss` line:

```swift
@Dependency(\.aiServiceClient) var aiServiceClient
```

- [ ] **Step 7: Add stub handlers for new actions (required for exhaustive switch)**

Swift requires all enum cases to be handled in a `switch`. Add placeholder `return .none` stubs for the three new actions in `AddTransactionFeature.body` before the build step. These will be replaced with real logic in Tasks 7 and 8:

```swift
case .backgroundExtractionCompleted:
    return .none   // implemented in Task 7

case .suggestCategoryTapped:
    return .none   // implemented in Task 8

case .categorySuggestionsReceived:
    return .none   // implemented in Task 8
```

- [ ] **Step 8: Build — verify compilation**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 10: Run failing tests — verify they now pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: `addPrefilledModePreFillsFields` and `addPrefilledNilFieldsDefaults` pass

- [ ] **Step 11: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
        Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift
git commit -m "feat(add-transaction): add .addPrefilled mode, AI state fields, and stub handlers"
```

---

### Task 6: DashboardFeature + TransactionsFeature — addTransactionWithPrefilledData

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift`
- Test: `Features/Tests/FeaturesTests/DashboardFeatureTests.swift`

- [ ] **Step 1: Write failing test for DashboardFeature routing**

Add to `DashboardFeatureTests`:

```swift
@Test("addTransactionWithPrefilledData presents AddTransaction in .addPrefilled mode")
func addTransactionWithPrefilledDataPresents() async {
    let extracted = ExtractedTransaction(
        amount: 200, suggestedCategory: "交通",
        description: "搭捷運", type: "expense"
    )
    let store = await TestStore(initialState: DashboardFeature.State()) {
        DashboardFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.accountClient.fetchAll = { [] }
        $0.transactionClient.fetchRecent = { [] }
        $0.aiServiceClient.isAvailable = { false }
        $0.aiServiceClient.generateInsight = { _ in "" }
    }
    await store.send(.addTransactionWithPrefilledData(extracted)) {
        $0.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    }
}
```

- [ ] **Step 2: Run test — expect build failure (action not yet defined)**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/DashboardFeatureTests 2>&1 | tail -5
```

Expected: compile error

- [ ] **Step 3: Add action to `DashboardFeature`**

In `DashboardFeature.Action`, after `case addTransactionButtonTapped`:

```swift
// Received from MainTabFeature when the TabBar AI input successfully extracts a transaction.
case addTransactionWithPrefilledData(ExtractedTransaction)
```

In `DashboardFeature.body`, add a handler (before the `case .addTransaction:` catch-all):

```swift
case let .addTransactionWithPrefilledData(extracted):
    state.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    return .none
```

- [ ] **Step 2: Add action to `TransactionsFeature`**

In `TransactionsFeature.Action`, after `case contextActionTapped`:

```swift
// Received from MainTabFeature when the TabBar AI input successfully extracts a transaction.
case addTransactionWithPrefilledData(ExtractedTransaction)
```

In `TransactionsFeature.body`, add a handler (before the `case .addTransaction:` catch-all):

```swift
case let .addTransactionWithPrefilledData(extracted):
    state.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    return .none
```

- [ ] **Step 4 (was Step 3): Build to verify no regressions**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run DashboardFeatureTests — verify failing test now passes**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/DashboardFeatureTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: `addTransactionWithPrefilledDataPresents` passes; all existing DashboardFeatureTests still pass

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Sources/Features/Transactions/TransactionsFeature.swift \
        Features/Tests/FeaturesTests/DashboardFeatureTests.swift
git commit -m "feat: add addTransactionWithPrefilledData action to Dashboard and Transactions features"
```

---

## Chunk 4: AddTransactionFeature — AI Logic + View

> **Prerequisite:** Chunks 1–3 must be fully applied and `xcodebuild build` must succeed before starting this chunk. This chunk depends on `.addPrefilled` Mode case, `backgroundExtractionCompleted(ExtractedTransaction?)` action, `suggestCategoryTapped`, `categorySuggestionsReceived`, and `aiServiceClient` dependency — all added in Chunk 3, Task 5.

### Task 7: noteChanged debounce + backgroundExtractionCompleted

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`

- [ ] **Step 1: Extend `noteChanged` handler**

Find the existing handler:
```swift
case let .noteChanged(note):
    state.note = note
    return .none
```

Replace with:

```swift
case let .noteChanged(note):
    state.note = note
    state.isBackgroundParsingNote = !note.isEmpty
    guard !note.isEmpty else {
        // Cancel any pending debounce when field is cleared
        return .cancel(id: CancelID.noteDebounce)
    }
    // Debounce 500ms — consistent with RunLoop.main pattern used in TransactionsFeature.
    // isAvailable() is checked inline (not via stored flag) because AddTransactionFeature
    // has no .task lifecycle, and adding one just for this check would be over-engineering.
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

- [ ] **Step 2: Add `backgroundExtractionCompleted` handler**

Add to the switch in `body`:

```swift
case let .backgroundExtractionCompleted(extracted):
    // Always clear the loading indicator first.
    state.isBackgroundParsingNote = false
    guard let extracted else { return .none }

    // Apply AI-parsed values only to EMPTY form fields — never overwrite user input.
    // Note: state.note is intentionally NOT filled here. The debounce was triggered by
    // the user typing in the note field, so state.note is already set by noteChanged.
    // Filling it again from AI would produce a loop or conflict.
    if state.amountText.isEmpty, let amount = extracted.amount {
        state.amountText = String(Int(amount))
    }
    if state.categoryId == nil, let suggestedName = extracted.suggestedCategory {
        // Match against the currently filtered categories list
        state.categoryId = state.filteredCategories.first { $0.name == suggestedName }?.id
    }
    // Only update type for .add mode and only if the user hasn't manually changed it.
    // Skip for .addPrefilled (type was already set from AI in State.init).
    // Skip for .edit (preserve original transaction type).
    if case let .add(initialType) = state.mode,
       state.type == initialType,
       let typeString = extracted.type,
       let parsedType = TransactionType(rawValue: typeString) {
        state.type = parsedType
        // Clear category if type changed (category list is filtered by type)
        if parsedType != initialType { state.categoryId = nil }
    }
    return .none
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift
git commit -m "feat(add-transaction): add background note AI parsing with debounce"
```

---

### Task 8: suggestCategoryTapped + categorySuggestionsReceived + View

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift`

- [ ] **Step 1: Add `suggestCategoryTapped` handler**

```swift
case .suggestCategoryTapped:
    // Guard in reducer — the View disables the button, but this prevents subtle bugs
    // if isAvailable state drifts between the .task check and the tap.
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

- [ ] **Step 2: Add `categorySuggestionsReceived` handler**

```swift
case let .categorySuggestionsReceived(.success(suggestions)):
    state.isSuggestingCategory = false
    // Filter to only names that exist in the current filtered category list
    state.suggestedCategoryNames = suggestions.suggestions.filter { name in
        state.filteredCategories.contains { $0.name == name }
    }
    return .none

case .categorySuggestionsReceived(.failure):
    state.isSuggestingCategory = false
    state.categorySuggestionError = "無法取得建議，請手動選擇"
    return .none
```

- [ ] **Step 3: Update `AddTransactionView` — category section**

In the category `Section` of `AddTransactionView`, after the existing `Picker`, add the AI suggest button and suggestion highlights. Replace the category section body:

```swift
// MARK: 分類（非轉帳）
if store.type != .transfer {
    Section {
        if store.filteredCategories.isEmpty {
            Text("add_transaction_no_categories")
                .foregroundStyle(Color.Design.textTertiary)
        } else {
            Picker(String(localized: "add_transaction_category"), selection: Binding(
                get: { store.categoryId },
                set: { store.send(.categorySelected($0)) }
            )) {
                Text("common_please_select").tag(Optional<Domain.Category.ID>.none)
                ForEach(store.filteredCategories) { category in
                    HStack {
                        Label(category.name, systemImage: category.icon)
                        Spacer()
                        // Highlight AI-suggested categories with a sparkle badge
                        if store.suggestedCategoryNames.contains(category.name) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.accentColor)
                                .font(.caption)
                        }
                    }
                    .tag(Optional<Domain.Category.ID>(category.id))
                }
            }
        }

        // AI suggest button row
        HStack {
            if store.isSuggestingCategory {
                ProgressView()
                    .controlSize(.small)
                Text("add_transaction_ai_suggesting")
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            } else {
                Button {
                    store.send(.suggestCategoryTapped)
                } label: {
                    Label("add_transaction_ai_suggest_category", systemImage: "wand.and.sparkles")
                        .font(Font.Design.caption)
                }
                .disabled(store.note.isEmpty)
            }
        }

        if let error = store.categoryError {
            Text(error)
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.expenseRed)
        }
        if let error = store.categorySuggestionError {
            Text(error)
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.expenseRed)
        }
    } header: {
        Text("add_transaction_category")
    }
}
```

- [ ] **Step 4: Update `AddTransactionView` — note section (background parse indicator)**

Replace the note `Section` with:

```swift
// MARK: 備註
Section {
    HStack {
        TextField(String(localized: "add_transaction_note_placeholder"), text: Binding(
            get: { store.note },
            set: { store.send(.noteChanged($0)) }
        ))
        if store.isBackgroundParsingNote {
            ProgressView()
                .controlSize(.small)
        }
    }
} header: {
    Text("add_transaction_note")
}
```

- [ ] **Step 5: Add localisation keys**

Add the following keys to `Localizable.xcstrings` (or the appropriate `.strings` file):

```
"add_transaction_ai_suggest_category" = "AI 建議分類";
"add_transaction_ai_suggesting" = "AI 分析中…";
```

> Check the project's existing localisation mechanism first: if it uses `Localizable.xcstrings`, add the entries there; if `.strings` files per language, add to each language file.

- [ ] **Step 6: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
        Features/Sources/Features/Dashboard/AddTransactionView.swift
git commit -m "feat(add-transaction): add AI category suggestion and background note parsing UI"
```

---

## Chunk 5: MainTabFeature + MainTabView — AI Input Bar

> **Prerequisite:** Chunks 1–3 must be fully applied and build-verified. Chunk 5 depends on `DashboardFeature.Action.addTransactionWithPrefilledData` and `TransactionsFeature.Action.addTransactionWithPrefilledData` (added in Chunk 3, Task 6), and on `AddTransactionFeature.Mode.addPrefilled` (added in Chunk 3, Task 5).

### Task 9: MainTabFeature — AI state machine

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`

- [ ] **Step 1: Add AI state fields to `State`**

Inside `State`, after `var settings = SettingsFeature.State()`:

```swift
// AI input bar state
var isAIInputExpanded: Bool = false
var aiInputText: String = ""
var isAIInputLoading: Bool = false
var aiInputError: String? = nil      // shown inline below the text field
var aiUnavailable: Bool = false      // set once on .task; drives all AI UI
```

- [ ] **Step 2: Add AI actions to `Action`**

In `Action` enum, after `case contextActionTapped`:

```swift
// Lifecycle
case task

// AI input bar
case aiAvailabilityLoaded(isAvailable: Bool)   // Bool = true means AI IS available
case aiInputButtonTapped
case aiInputTextChanged(String)
case aiInputSubmitted
case aiInputDismissed
case aiExtractionCompleted(TaskResult<ExtractedTransaction>)
```

- [ ] **Step 3: Add dependency and CancelID**

After the `Scope` blocks in `body`, add before `Reduce`:

```swift
@Dependency(\.aiServiceClient) var aiServiceClient
private enum CancelID { case aiExtraction }
```

- [ ] **Step 4: Add AI action handlers to `body`**

In the `Reduce` block, add new cases. Add before `case .dashboard:`:

```swift
case .task:
    return .run { send in
        // Check AI availability once at launch — stored in state so all AI UI reads a single flag.
        await send(.aiAvailabilityLoaded(isAvailable: aiServiceClient.isAvailable()))
    }

case let .aiAvailabilityLoaded(isAvailable):
    // isAvailable=true  → AI works → aiUnavailable=false
    // isAvailable=false → AI broken → aiUnavailable=true
    state.aiUnavailable = !isAvailable
    return .none

case .aiInputButtonTapped:
    state.isAIInputExpanded = true
    state.aiInputError = nil
    return .none

case let .aiInputTextChanged(text):
    state.aiInputText = text
    return .none

case .aiInputDismissed:
    state.isAIInputExpanded = false
    state.aiInputText = ""
    state.isAIInputLoading = false
    state.aiInputError = nil
    return .none

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

case let .aiExtractionCompleted(.success(extracted)):
    // Reset input bar
    state.isAIInputExpanded = false
    state.aiInputText = ""
    state.isAIInputLoading = false
    // Route to the correct child feature — Scope reducers run before this parent Reduce,
    // so the child action will be processed by DashboardFeature/TransactionsFeature first.
    switch state.selectedTab {
    case .transactions:
        return .send(.transactions(.addTransactionWithPrefilledData(extracted)))
    default:
        return .send(.dashboard(.addTransactionWithPrefilledData(extracted)))
    }

case .aiExtractionCompleted(.failure):
    state.isAIInputLoading = false
    state.aiInputError = "無法解析，請再試一次或手動輸入"
    return .none
```

- [ ] **Step 5: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift
git commit -m "feat(main-tab): add AI input bar state machine"
```

---

### Task 10: MainTabView — AI input bar UI

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`

- [ ] **Step 1: Add `.task` modifier and update `tabViewBottomAccessory`**

Replace the entire `tabViewBottomAccessory` block and add `.task`:

```swift
.task {
    await store.send(.task).finish()
}
.tabViewBottomAccessory {
    if store.isAIInputExpanded {
        // Expanded: natural language input bar
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                TextField("描述這筆交易…", text: Binding(
                    get: { store.aiInputText },
                    set: { store.send(.aiInputTextChanged($0)) }
                ))
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit { store.send(.aiInputSubmitted) }

                if store.isAIInputLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                } else {
                    Button {
                        store.send(.aiInputSubmitted)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(store.aiInputText.isEmpty)

                    Button {
                        store.send(.aiInputDismissed)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())

            if let error = store.aiInputError {
                Text(error)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.expenseRed)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    } else {
        // Compact: AI wand + original + button
        HStack {
            Spacer()
            // AI wand button — disabled when Foundation Models is unavailable
            Group {
                if store.aiUnavailable {
                    Button {} label: {
                        Image(systemName: "wand.and.sparkles")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.textTertiary)
                    }
                    .disabled(true)
                    .help("此裝置不支援 AI 功能")
                    // onTapGesture still fires even when Button is .disabled
                    .onTapGesture {
                        // Brief tooltip — disabled button swallows the tap, this won't fire.
                        // The .help() modifier handles accessibility.
                    }
                } else {
                    Button {
                        withAnimation(.spring()) {
                            store.send(.aiInputButtonTapped)
                        }
                    } label: {
                        Image(systemName: "wand.and.sparkles")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .padding(.trailing, 8)

            // Original + button — behaviour unchanged
            Button {
                store.send(.contextActionTapped)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

Wrap the `tabViewBottomAccessory` contents with `withAnimation(.spring())` on state transitions by adding `.animation(.spring(), value: store.isAIInputExpanded)` to the `TabView`.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabView.swift
git commit -m "feat(main-tab): add AI natural language input bar to tab bottom accessory"
```

---

## Chunk 6: Tests

> **Prerequisite:** All previous chunks must be applied and build-verified before writing tests.

### Task 11: MainTabFeatureTests — new test file

**Files:**
- Create: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: Write tests**

Create `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`:

```swift
import ComposableArchitecture
import Domain
import Testing
@testable import Features

@Suite("MainTabFeature — AI input")
struct MainTabFeatureTests {

    @Test("task stores AI availability")
    func taskStoresAvailability() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true)) {
            $0.aiUnavailable = false
        }
    }

    @Test("task marks AI unavailable when not available")
    func taskMarksUnavailable() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: false)) {
            $0.aiUnavailable = true
        }
    }

    @Test("AI input button expands the input bar")
    func aiInputButtonExpands() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.aiInputButtonTapped) {
            $0.isAIInputExpanded = true
        }
    }

    @Test("dismiss resets all AI input state")
    func dismissResetsState() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.aiInputError = "some error"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
        }
    }

    @Test("successful extraction on dashboard tab opens AddTransaction")
    func successfulExtractionRoutesDashboard() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.extractTransaction = { _ in extracted }
            // Stub child dependencies
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsClient.string = { _ in "" }
        }
        await store.send(.aiExtractionCompleted(.success(extracted))) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
        }
        await store.receive(.dashboard(.addTransactionWithPrefilledData(extracted))) {
            $0.dashboard.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted))
        }
    }

    @Test("failed extraction shows error and keeps input open")
    func failedExtractionShowsError() async {
        struct FakeError: Error {}
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.aiExtractionCompleted(.failure(FakeError()))) {
            $0.isAIInputLoading = false
            $0.aiInputError = "無法解析，請再試一次或手動輸入"
        }
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/MainTabFeatureTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: all tests pass

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "test(main-tab): add AI input bar state machine tests"
```

---

### Task 12: DashboardFeatureTests — addTransactionWithPrefilledData

**Files:**
- Modify: `Features/Tests/FeaturesTests/DashboardFeatureTests.swift`

- [ ] **Step 1: Add test for new action**

Add to the existing `DashboardFeatureTests` suite:

```swift
@Test("addTransactionWithPrefilledData presents AddTransaction in .addPrefilled mode")
func addTransactionWithPrefilledDataPresents() async {
    let extracted = ExtractedTransaction(
        amount: 200,
        suggestedCategory: "交通",
        description: "搭捷運",
        type: "expense"
    )
    let store = await TestStore(initialState: DashboardFeature.State()) {
        DashboardFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.accountClient.fetchAll = { [] }
        $0.transactionClient.fetchRecent = { [] }
        $0.aiServiceClient.isAvailable = { false }
        $0.aiServiceClient.generateInsight = { _ in "" }
    }
    await store.send(.addTransactionWithPrefilledData(extracted)) {
        $0.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/DashboardFeatureTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: all tests pass (including existing ones)

- [ ] **Step 3: Commit**

```bash
git add Features/Tests/FeaturesTests/DashboardFeatureTests.swift
git commit -m "test(dashboard): add test for addTransactionWithPrefilledData action"
```

---

### Task 13: AddTransactionFeatureTests — new AI tests

**Files:**
- Modify: `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift`

- [ ] **Step 1: Add new tests**

Add to the existing `AddTransactionFeatureTests` suite:

```swift
// Helper to create a store with AI disabled (prevents unimplemented stub calls)
private func makeStore(
    mode: AddTransactionFeature.Mode = .add(.expense),
    aiAvailable: Bool = false
) async -> TestStoreOf<AddTransactionFeature> {
    await TestStore(
        initialState: AddTransactionFeature.State(mode: mode)
    ) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
        $0.userSettingsClient.string = { _ in "" }
        $0.aiServiceClient.isAvailable = { aiAvailable }
        if aiAvailable {
            $0.aiServiceClient.extractTransaction = { _ in ExtractedTransaction() }
            $0.aiServiceClient.suggestCategories = { _, _ in
                CategorySuggestions(suggestions: [], confidence: "low")
            }
        }
    }
}

@Test(".addPrefilled mode pre-fills form fields from ExtractedTransaction")
func addPrefilledModePreFillsFields() async {
    let extracted = ExtractedTransaction(
        amount: 150,
        suggestedCategory: "食物",
        description: "午餐便當",
        type: "expense"
    )
    let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    #expect(state.amountText == "150")
    #expect(state.note == "午餐便當")
    #expect(state.type == .expense)
    #expect(state.categoryId == nil)    // category set separately
}

@Test(".addPrefilled with nil fields uses sensible defaults")
func addPrefilledNilFieldsDefaults() async {
    let extracted = ExtractedTransaction()   // all nil
    let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
    #expect(state.amountText == "")
    #expect(state.note == "")
    #expect(state.type == .expense)     // default
}

@Test("saveTapped in .addPrefilled mode creates new transaction")
func saveTappedPrefilledCreatesTransaction() async {
    var savedTransaction: Transaction?
    let store = await TestStore(
        initialState: AddTransactionFeature.State(mode: .addPrefilled(ExtractedTransaction()))
    ) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [Account(name: "現金", type: .cash, icon: "banknote", color: "#00FF00", sortOrder: 0)] }
        $0.categoryClient.fetchAll = { [] }
        $0.userSettingsClient.string = { _ in "" }
        $0.aiServiceClient.isAvailable = { false }
        $0.transactionClient.add = { savedTransaction = $0 }
        $0.dismiss = DismissEffect { }
    }
    await store.send(.task)
    await store.receive(\.optionsLoaded) { _ in }

    await store.send(.amountTextChanged("200"))
    // accountId auto-set to first account; select it explicitly if needed
    await store.send(.saveTapped)
    await store.receive(\.savedSuccessfully)
    await store.receive(\.delegate.saved)
    #expect(savedTransaction != nil)
    #expect(savedTransaction?.amount == 200)
}

@Test("suggestCategoryTapped is no-op when AI unavailable")
func suggestCategoryTappedUnavailable() async {
    let store = await makeStore(aiAvailable: false)
    await store.send(.suggestCategoryTapped) {
        $0.categorySuggestionError = "此裝置不支援 AI 功能"
    }
}

@Test("backgroundExtractionCompleted fills only empty fields")
func backgroundExtractionFillsOnlyEmptyFields() async {
    let store = await makeStore(aiAvailable: false)
    // Pre-set amountText so it should NOT be overwritten
    await store.send(.amountTextChanged("999"))
    let extracted = ExtractedTransaction(amount: 150, suggestedCategory: nil, description: "午餐", type: "income")
    await store.send(.backgroundExtractionCompleted(extracted)) {
        $0.isBackgroundParsingNote = false
        // amount NOT overwritten (was "999", not empty)
        // note NOT filled by background extraction (note triggered the debounce; filling it here
        //   would conflict with what the user is currently typing — see backgroundExtractionCompleted handler)
        // type updated (.add(.expense) initial, user hasn't changed it, extracted says income)
        $0.type = .income
    }
    // Verify amount was NOT changed
    #expect(store.state.amountText == "999")
}

@Test("backgroundExtractionCompleted nil is a no-op except clearing loading flag")
func backgroundExtractionNilClearsLoading() async {
    var initial = AddTransactionFeature.State(mode: .add(.expense))
    initial.isBackgroundParsingNote = true
    let store = await TestStore(initialState: initial) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
        $0.userSettingsClient.string = { _ in "" }
        $0.aiServiceClient.isAvailable = { false }
    }
    await store.send(.backgroundExtractionCompleted(nil)) {
        $0.isBackgroundParsingNote = false
    }
}
```

- [ ] **Step 2: Run all AddTransactionFeatureTests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: all tests pass (existing + new)

- [ ] **Step 3: Run full test suite to check for regressions**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(PASS|FAIL|error:|BUILD)"
```

Expected: all tests pass, `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift
git commit -m "test(add-transaction): add AI mode, partial-fill, and category suggest tests"
```

---

## Final Check

- [ ] **Full build + test run**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Final commit summary**

Verify all 8 commits are in order:
```bash
git log --oneline -10
```
