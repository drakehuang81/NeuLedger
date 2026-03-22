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

### Critical constraint: string literals only

`String(localized:bundle:)` requires the key to be a **string literal** at the call site. If the key is stored in a variable, the `bundle:` parameter is silently ignored and the lookup falls back to `Bundle.module` (the Core SPM bundle, which has no strings), causing the key itself to be returned at runtime with no error. Always write the key inline:

```swift
// CORRECT
String(localized: "ai_prompt_extract_transaction", bundle: .main)

// WRONG — bundle parameter silently ignored
let key = "ai_prompt_extract_transaction"
String(localized: key, bundle: .main)  // falls back to Bundle.module
```

---

## Files Changed

| File | Change |
|------|--------|
| `NeuLedger/Resources/Localizable.xcstrings` | Add 6 new keys with `en` + `zh-Hant` variants |
| `Features/Sources/Core/Clients/AIServiceClient+Live.swift` | Replace hardcoded prompts with `String(localized:bundle:)` + `String(format:)` |
| `Features/Sources/Domain/Entities/ExtractedTransaction.swift` | Update `@Guide` on `description` field to language-neutral instruction |

---

## xcstrings Changes

Six new keys to add to `Localizable.xcstrings`:

### `ai_prompt_extract_transaction`

Template receives one `%@` argument: the raw user input.

- **en:** `"Parse a transaction from the input below. Amount is in TWD. Use the same language as the input for all text fields.\nInput: %@"`
- **zh-Hant:** `"從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。所有文字欄位請使用繁體中文。\n輸入：%@"`

### `ai_prompt_suggest_categories`

Template receives two `%@` arguments: transaction description, category list.

- **en:** `"Based on the transaction description below, select the most appropriate categories from the list (up to 3, ordered by relevance). Only choose from the list provided.\nTransaction: %@\nAvailable categories: %@"`
- **zh-Hant:** `"根據以下交易描述，從分類清單中選出最合適的分類（最多3個，依相關性排序）。請只從清單中選擇，不要建議清單以外的分類。\n交易描述：%@\n可用分類：%@"`

### `ai_prompt_generate_insight`

Template receives four `%@` arguments: period description, total income, total expense, category breakdown.

- **en:** `"Write a brief spending insight in 2-3 sentences.\nPeriod: %@\nTotal income: NT$%@\nTotal expense: NT$%@\nCategory breakdown: %@"`
- **zh-Hant:** `"請用繁體中文撰寫一段簡短的消費分析洞察（2-3句話）。\n時間範圍：%@\n總收入：NT$%@\n總支出：NT$%@\n各分類支出：%@"`

### `ai_tool_no_transactions`

Returned by `QueryTransactionsTool` when the query yields no results.

- **en:** `"No transactions found."`
- **zh-Hant:** `"查無交易紀錄。"`

### `ai_tool_no_note`

Placeholder shown in transaction list when `note` is `nil`.

- **en:** `"(no note)"`
- **zh-Hant:** `"（無備註）"`

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

Two prompts need locale-sensitive list separators. Use a helper to avoid duplication:

```swift
private func listSeparator() -> String {
    Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true ? "、" : ", "
}
```

The `hasPrefix("zh")` check covers `zh` (generic Chinese), `zh-Hant`, and `zh-Hans`. This is intentionally broad — if Simplified Chinese is added in future, separator behaviour is already correct.

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
    let categoryList = existingCategories.joined(separator: listSeparator())
    let template = String(localized: "ai_prompt_suggest_categories", bundle: .main)
    let prompt = String(format: template, description, categoryList)
    return try await session.respond(to: prompt, generating: CategorySuggestions.self).content
},
```

### `generateInsight`

```swift
generateInsight: { summary in
    if let cached = await AIServiceClient.insightCache.get(for: summary) { return cached }
    let session = LanguageModelSession()
    let categoryText = summary.categoryBreakdown
        .map { "\($0.key): NT$\($0.value)" }
        .joined(separator: listSeparator())
    let template = String(localized: "ai_prompt_generate_insight", bundle: .main)
    let prompt = String(format: template,
        summary.periodDescription,
        "\(summary.totalIncome)",
        "\(summary.totalExpense)",
        categoryText)
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
