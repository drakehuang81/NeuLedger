# Design: AIServiceClient Prompt Localization

**Date:** 2026-03-23
**Status:** Approved
**Scope:** Core layer only — no changes to Domain or Feature layers

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

---

## xcstrings Changes

Five new keys to add to `Localizable.xcstrings`:

### `ai_prompt_extract_transaction`

Template receives one `%@` argument: the raw user input.

- **en:** `"Parse a transaction from the input below. Amount is in TWD. Use English for all text fields.\nInput: %@"`
- **zh-Hant:** `"從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。所有文字欄位請使用繁體中文。\n輸入：%@"`

### `ai_prompt_suggest_categories`

Template receives two `%@` arguments: transaction description, comma-separated category list.

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

---

## Code Changes in `AIServiceClient+Live.swift`

### Pattern

```swift
let template = String(localized: "some_key", bundle: .main)
let prompt = String(format: template, arg1, arg2)
```

### extractTransaction

```swift
extractTransaction: { input in
    let session = LanguageModelSession()
    let template = String(localized: "ai_prompt_extract_transaction", bundle: .main)
    let prompt = String(format: template, input)
    return try await session.respond(to: prompt, generating: ExtractedTransaction.self).content
},
```

### suggestCategories

```swift
suggestCategories: { description, existingCategories in
    let session = LanguageModelSession()
    let separator = Locale.current.language.languageCode?.identifier == "zh" ? "、" : ", "
    let categoryList = existingCategories.joined(separator: separator)
    let template = String(localized: "ai_prompt_suggest_categories", bundle: .main)
    let prompt = String(format: template, description, categoryList)
    return try await session.respond(to: prompt, generating: CategorySuggestions.self).content
},
```

> Note: The Chinese separator `、` is used for `zh-Hant` locale; English uses `, `.

### generateInsight

```swift
generateInsight: { summary in
    if let cached = await AIServiceClient.insightCache.get(for: summary) { return cached }
    let session = LanguageModelSession()
    let categoryText = summary.categoryBreakdown
        .map { "\($0.key): NT$\($0.value)" }
        .joined(separator: ", ")
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

### QueryTransactionsTool.call(arguments:)

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

### answerFinancialQuestion

No changes needed. The user's question is passed directly to the model; the model naturally responds in the language of the question. `QueryTransactionsTool`'s `description` and `@Guide` annotations remain in English as they describe the tool schema to the model, not user-facing text.

---

## InsightCache: No Changes Required

`InsightCache` is a `static let` and lives for the app session. Because iOS requires an app restart to apply language changes, the cache is always in a fresh state when the language changes. No invalidation logic is needed.

---

## Files Changed

| File | Change |
|------|--------|
| `NeuLedger/Resources/Localizable.xcstrings` | Add 5 new `ai_prompt_*` / `ai_tool_*` keys with `en` + `zh-Hant` variants |
| `Features/Sources/Core/Clients/AIServiceClient+Live.swift` | Replace hardcoded prompt strings with `String(localized:bundle:)` + `String(format:)` |

---

## Testing

- Existing tests are unaffected — `testValue` uses unimplemented stubs and never executes live prompts
- Manual verification: run the app with `en` scheme language and confirm AI outputs are in English; switch to `zh-Hant` and confirm outputs are in Traditional Chinese
