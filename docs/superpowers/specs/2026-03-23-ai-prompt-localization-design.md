# Design: AIServiceClient Prompt Localization

**Date:** 2026-03-23
**Status:** Approved
**Scope:** Core layer (`AIServiceClient+Live.swift`), Domain layer (`ExtractedTransaction.swift`), app resources (`Localizable.xcstrings`)

---

## Problem

`AIServiceClient+Live.swift` contains hardcoded Traditional Chinese prompt strings. When the user switches the app language to English (via iOS Settings), the AI prompts remain in Chinese, causing:

1. AI outputs (insights, extracted notes) to be in Chinese regardless of app language
2. Inconsistent experience for English-speaking users

---

## Goal

- AI prompt language follows `Locale.current` (the app's active language)
- AI outputs (generated text, extracted note fields) are in the same language as the app
- The AI can still understand user input regardless of its language
- `QueryTransactionsTool` intermediate strings are also localized for consistency

---

## Non-Goals

- In-app language picker (language switching remains via iOS Settings → app restart)
- Adding languages beyond English (`en`) and Traditional Chinese (`zh-Hant`)
- Changing the `AIServiceClient` public interface
- Modifying `InsightCache` behavior

---

## Solution: `String(localized:bundle:)` + `Localizable.xcstrings`

Use the project's existing `Localizable.xcstrings` (located at `NeuLedger/Resources/Localizable.xcstrings`) to store prompt strings with `en` and `zh-Hant` variants. At call time, `String(localized:bundle:)` automatically resolves to the correct language via `Locale.current` — no manual locale detection needed.

### Why this approach

- Idiomatic iOS localization — consistent with existing `ai_*` key naming convention already in the file
- `Bundle.main` at runtime points to the app bundle, accessible from the `Core` SPM target
- `Locale.current` reflects the iOS language setting automatically; no additional logic required
- Language switching requires an app restart (iOS system behavior), so `InsightCache` cache invalidation is handled naturally

### Localization pattern across all SPM targets

All strings in this project (including those called from `Core`, `Features`, or any other SPM target) live in `NeuLedger/Resources/Localizable.xcstrings` — the app bundle. At runtime, `String(localized:)` defaults to `Bundle.main`, which is always the app bundle regardless of which SPM target makes the call. This is confirmed by the existing `Features` target code, which calls `String(localized: "common_cancel")` etc. without specifying `bundle:` and resolves correctly.

The new prompt keys follow the same pattern. Specifying `bundle: .main` explicitly is optional but makes the intent clear in `AIServiceClient+Live.swift` where the bundle dependency is less obvious.

**Critical constraint: string literal keys only.** The `bundle:` parameter on `String(localized:bundle:)` only takes effect when the key is a string literal. If the key is a variable, the compiler resolves the bundle differently and may silently fall back to `Bundle.module` (the SPM target's own bundle, which has no strings). Always inline the key:

```swift
// CORRECT
String(localized: "ai_prompt_extract_transaction", bundle: .main)

// WRONG — bundle parameter may be silently ignored when key is a variable
let key = "ai_prompt_extract_transaction"
String(localized: key, bundle: .main)
```

---

## Files Changed

| File | Change |
|------|--------|
| `NeuLedger/Resources/Localizable.xcstrings` | Add 7 new keys with `en` + `zh-Hant` variants |
| `Features/Sources/Core/Clients/AIServiceClient+Live.swift` | Replace hardcoded prompts with `String(localized:bundle:)` + `String(format:)` |
| `Features/Sources/Domain/Entities/ExtractedTransaction.swift` | Update `@Guide` on `description` field to language-neutral instruction |

---

## xcstrings Changes

Seven new keys to add to `Localizable.xcstrings`:

### `ai_prompt_extract_transaction`

Template receives one `%@` argument: the raw user input.

- **en:** `"Parse a transaction from the input below. Amount is in TWD. Use the same language as the input for all text fields.\nInput: %@"`
- **zh-Hant:** `"從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。所有文字欄位請使用繁體中文。\n輸入：%@"`

### `ai_prompt_suggest_categories`

Template receives two `%@` arguments: transaction description, category list.

- **en:** `"Based on the transaction description below, select the most appropriate categories from the list (up to 3, ordered by relevance). Only choose from the list provided.\nTransaction: %@\nAvailable categories: %@"`
- **zh-Hant:** `"根據以下交易描述，從分類清單中選出最合適的分類（最多3個，依相關性排序）。請只從清單中選擇，不要建議清單以外的分類。\n交易描述：%@\n可用分類：%@"`

### `ai_prompt_generate_insight`

Template receives three `%@` arguments: period description, total income, total expense. Category breakdown is appended conditionally (see `generateInsight` code change below) — omitted entirely when empty rather than leaving a dangling label.

- **en:** `"Write a brief spending insight in 2-3 sentences.\nPeriod: %@\nTotal income: NT$%@\nTotal expense: NT$%@"`
- **zh-Hant:** `"請用繁體中文撰寫一段簡短的消費分析洞察（2-3句話）。\n時間範圍：%@\n總收入：NT$%@\n總支出：NT$%@"`

### `ai_tool_no_transactions`

Returned by `QueryTransactionsTool` when the query yields no results.

- **en:** `"No transactions found."`
- **zh-Hant:** `"查無交易紀錄。"`

### `ai_tool_no_note`

Placeholder shown in transaction list when `note` is `nil`.

- **en:** `"(no note)"`
- **zh-Hant:** `"（無備註）"`

### `ai_prompt_category_breakdown`

Optional category line appended to `ai_prompt_generate_insight` when `categoryBreakdown` is non-empty. Template receives one `%@` argument: the formatted category list. Kept as a separate key so the base template stays at three `%@` arguments (avoiding a dangling label when breakdown is empty).

- **en:** `"Category breakdown: %@"`
- **zh-Hant:** `"各分類支出：%@"`

### `dashboard_period_recent`

Used in `DashboardFeature` as `periodDescription` when building `SpendingSummary` for the dashboard insight. Currently hardcoded as `"Recent"` in English only — must be localized because it is interpolated directly into `ai_prompt_generate_insight`.

- **en:** `"Recent"`
- **zh-Hant:** `"近期"`

---

## Code Changes

### Pattern

```swift
let template = String(localized: "some_key", bundle: .main)  // key MUST be a literal
let prompt = String(format: template, arg1, arg2)
```

### Locale-aware list separator helper

Two prompts need locale-sensitive list separators. Declare as a `private static func` on the `extension AIServiceClient` block (it is called from `static let liveValue` closures, so an instance method would not compile):

```swift
private static func listSeparator() -> String {
    Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true ? "、" : ", "
}
```

The `hasPrefix("zh")` check covers `zh` (generic Chinese), `zh-Hant`, and `zh-Hans`. This is intentionally broad — if Simplified Chinese is added in future, separator behaviour is already correct. The optional chain `?.identifier` defaults to `", "` (English form) if `languageCode` is `nil`, which is the safe fallback.

### `extractTransaction`

```swift
extractTransaction: { input in
    let session = LanguageModelSession()
    let template = String(localized: "ai_prompt_extract_transaction", bundle: .main)
    let prompt = String(format: template, input)
    return try await session.respond(to: prompt, generating: ExtractedTransaction.self).content
},
```

### `suggestCategories`

```swift
suggestCategories: { description, existingCategories in
    let session = LanguageModelSession()
    let categoryList = existingCategories.joined(separator: AIServiceClient.listSeparator())
    let template = String(localized: "ai_prompt_suggest_categories", bundle: .main)
    let prompt = String(format: template, description, categoryList)
    return try await session.respond(to: prompt, generating: CategorySuggestions.self).content
},
```

### `generateInsight`

Category breakdown is appended as a separate line only when non-empty. `DashboardFeature` passes an empty `categoryBreakdown` (it builds a lightweight summary from recent totals only); `AnalysisFeature` passes the full breakdown. Both call sites are handled correctly by the conditional append.

```swift
generateInsight: { summary in
    if let cached = await AIServiceClient.insightCache.get(for: summary) { return cached }
    let session = LanguageModelSession()
    let template = String(localized: "ai_prompt_generate_insight", bundle: .main)
    var prompt = String(format: template,
        summary.periodDescription,
        "\(summary.totalIncome)",
        "\(summary.totalExpense)")
    if !summary.categoryBreakdown.isEmpty {
        let categoryText = summary.categoryBreakdown
            .map { "\($0.key): NT$\($0.value)" }
            .joined(separator: AIServiceClient.listSeparator())
        let categoryLine = String(
            format: String(localized: "ai_prompt_category_breakdown", bundle: .main),
            categoryText)
        prompt += "\n" + categoryLine
    }
    let result = try await session.respond(to: prompt).content
    await AIServiceClient.insightCache.set(result, for: summary)
    return result
},
```

### `answerFinancialQuestion`

No changes needed. The user's question is passed directly to the model; the model naturally responds in the language of the question.

### `QueryTransactionsTool.call(arguments:)`

```swift
if transactions.isEmpty {
    return String(localized: "ai_tool_no_transactions", bundle: .main)
}
let noNote = String(localized: "ai_tool_no_note", bundle: .main)
let lines = transactions.map { t in
    "\(formatter.string(from: t.date)) \(t.note ?? noNote) NT$\(t.amount)"
}
return lines.joined(separator: "\n")
```

`QueryTransactionsTool`'s `description` and `@Guide` annotations remain in English — these are schema strings consumed by the Foundation Models runtime to understand the tool interface, not user-facing output.

### `ExtractedTransaction.description` — `@Guide` update

The current `@Guide` hardcodes Traditional Chinese:

```swift
// BEFORE
@Guide(description: "Short note in Traditional Chinese if possible. Nil if not provided.")
public var description: String?
```

This annotation is passed to Foundation Models alongside the prompt and overrides the prompt's language instruction. Change to language-neutral:

```swift
// AFTER
@Guide(description: "Short note summarising the transaction. Use the same language as the prompt. Nil if not provided.")
public var description: String?
```

This is different from `QueryTransactionsTool`'s `@Guide` annotations (which describe query parameters and should stay in English): those are tool-discovery schema strings, while `ExtractedTransaction.description` produces user-facing content.

### `DashboardFeature` — localize `periodDescription`

`DashboardFeature.swift:231` hardcodes `periodDescription: "Recent"`, which is interpolated into the insight prompt. Change to:

```swift
periodDescription: String(localized: "dashboard_period_recent", bundle: .main)
```

---

## InsightCache: No Changes Required

`InsightCache` is a `static let` and lives for one app session. iOS requires a full app restart to apply language changes, so the cache is always fresh when the language changes.

Additionally, `SpendingSummary.periodDescription` is itself a locale-resolved string (e.g., `"近期"` for `zh-Hant`, `"Recent"` for `en`). This means cache keys are naturally language-scoped — a `zh-Hant` entry and an `en` entry for the same period produce different keys, making cross-language cache collisions impossible.

---

## Testing

Existing unit tests are unaffected — `testValue` uses unimplemented stubs that never call `String(localized:)`. Manual verification is the primary strategy:

1. Run the app with the simulator language set to English → confirm AI outputs (insight text, extracted note) are in English
2. Switch simulator language to Traditional Chinese → confirm AI outputs are in Traditional Chinese
3. Enter an English transaction description in `zh-Hant` mode → confirm the model still parses it correctly

Automated bundle-resolution testing (verifying `String(localized:bundle:)` resolves from `Bundle.main` in the Core SPM target) requires an integration test that imports the app bundle — this is out of scope and accepted as a manual-only concern.
