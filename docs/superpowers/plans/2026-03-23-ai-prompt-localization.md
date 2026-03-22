# AI Prompt Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded Traditional Chinese AI prompt strings with `String(localized:bundle:)` lookups so AI outputs follow the app's active language (`Locale.current`).

**Architecture:** All localized strings live in the app bundle's `Localizable.xcstrings`. SPM targets (`Core`, `Features`) call `String(localized: "literal_key", bundle: .main)` at call time — `Bundle.main` always resolves to the app bundle at runtime regardless of which SPM target the call is made from. Category breakdown is conditionally appended to the insight prompt to handle the Dashboard's empty-breakdown case cleanly.

**Tech Stack:** Swift 5.9, Foundation Models (`LanguageModelSession`), `Localizable.xcstrings` (JSON-based Xcode string catalog)

---

## File Map

| File | Change |
|------|--------|
| `NeuLedger/Resources/Localizable.xcstrings` | Add 7 new keys |
| `Features/Sources/Domain/Entities/ExtractedTransaction.swift` | Update `@Guide` on line 19 |
| `Features/Sources/Core/Clients/AIServiceClient+Live.swift` | Add `listSeparator()`, rewrite 4 prompt sites |
| `Features/Sources/Features/Dashboard/DashboardFeature.swift` | Localize `periodDescription` on line 231 |

---

## Task 1: Add xcstrings keys

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

The file is JSON. All new keys go inside the `"strings"` object. Insert them in alphabetical order near the existing `ai_*` entries. Each key uses `extractionState: "manual"` — the same pattern as the existing `ai_*` keys.

- [ ] **Step 1: Open `NeuLedger/Resources/Localizable.xcstrings` and insert the following 7 blocks inside `"strings": { ... }`, after the last `ai_*` entry and before whatever comes next alphabetically.**

`ai_prompt_category_breakdown` — one `%@` arg: formatted category list:

```json
"ai_prompt_category_breakdown": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "Category breakdown: %@"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "各分類支出：%@"
      }
    }
  }
},
```

`ai_prompt_extract_transaction` — one `%@` arg: raw user input:

```json
"ai_prompt_extract_transaction": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "Parse a transaction from the input below. Amount is in TWD. Use the same language as the input for all text fields.\nInput: %@"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。所有文字欄位請使用繁體中文。\n輸入：%@"
      }
    }
  }
},
```

`ai_prompt_generate_insight` — three `%@` args: period description, total income, total expense (category breakdown line is appended separately):

```json
"ai_prompt_generate_insight": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "Write a brief spending insight in 2-3 sentences.\nPeriod: %@\nTotal income: NT$%@\nTotal expense: NT$%@"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "請用繁體中文撰寫一段簡短的消費分析洞察（2-3句話）。\n時間範圍：%@\n總收入：NT$%@\n總支出：NT$%@"
      }
    }
  }
},
```

`ai_prompt_suggest_categories` — two `%@` args: transaction description, category list:

```json
"ai_prompt_suggest_categories": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "Based on the transaction description below, select the most appropriate categories from the list (up to 3, ordered by relevance). Only choose from the list provided.\nTransaction: %@\nAvailable categories: %@"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "根據以下交易描述，從分類清單中選出最合適的分類（最多3個，依相關性排序）。請只從清單中選擇，不要建議清單以外的分類。\n交易描述：%@\n可用分類：%@"
      }
    }
  }
},
```

`ai_tool_no_note` — no args:

```json
"ai_tool_no_note": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "(no note)"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "（無備註）"
      }
    }
  }
},
```

`ai_tool_no_transactions` — no args:

```json
"ai_tool_no_transactions": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "No transactions found."
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "查無交易紀錄。"
      }
    }
  }
},
```

`dashboard_period_recent` — insert near other `dashboard_*` keys or at the end of `"strings"`. No args:

```json
"dashboard_period_recent": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "Recent"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "近期"
      }
    }
  }
},
```

- [ ] **Step 2: Verify the file is valid JSON**

```bash
python3 -m json.tool NeuLedger/Resources/Localizable.xcstrings > /dev/null && echo "Valid JSON"
```

Expected: `Valid JSON` with no errors. If you see an error, find the malformed JSON (usually a missing comma between entries or a trailing comma inside an object).

- [ ] **Step 3: Build to confirm xcstrings are accepted by Xcode**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|warning:|BUILD"
```

Expected: `BUILD SUCCEEDED`. No errors related to `Localizable.xcstrings`.

- [ ] **Step 4: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(i18n): add AI prompt xcstrings keys (en + zh-Hant)"
```

---

## Task 2: Update `ExtractedTransaction` `@Guide`

**Files:**
- Modify: `Features/Sources/Domain/Entities/ExtractedTransaction.swift:19`

The `@Guide(description:)` annotation on `description` instructs Foundation Models on how to fill that field. It currently hardcodes "Traditional Chinese", which overrides the prompt's language instruction. Change it to language-neutral wording.

- [ ] **Step 1: Open `Features/Sources/Domain/Entities/ExtractedTransaction.swift` and replace line 19**

Before:
```swift
@Guide(description: "Short note in Traditional Chinese if possible. Nil if not provided.")
```

After:
```swift
@Guide(description: "Short note summarising the transaction. Use the same language as the prompt. Nil if not provided.")
```

- [ ] **Step 2: Build the Domain scheme to confirm it compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Domain/Entities/ExtractedTransaction.swift
git commit -m "fix(ai): make ExtractedTransaction.description @Guide language-neutral"
```

---

## Task 3: Update `AIServiceClient+Live.swift`

**Files:**
- Modify: `Features/Sources/Core/Clients/AIServiceClient+Live.swift`

Four prompt sites need to be updated, plus a `private static func listSeparator()` helper added. All changes are inside `extension AIServiceClient`.

> **Important:** Keys passed to `String(localized:bundle:)` must always be string literals — never variables. The `bundle: .main` refers to the app's bundle (where `Localizable.xcstrings` lives), not the Core SPM module's bundle. See spec for details.

- [ ] **Step 1: Add `listSeparator()` helper**

Inside `extension AIServiceClient: DependencyKey` (at the top of the extension, before `liveValue`), add:

```swift
private static func listSeparator() -> String {
    Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true ? "、" : ", "
}
```

This must be `static` because it is called from the `static let liveValue` closures. It returns `"、"` (CJK enumeration comma) for all Chinese locales and `", "` otherwise. The optional chain defaults to `", "` when `languageCode` is `nil`.

- [ ] **Step 2: Replace `extractTransaction` closure body**

Find the `extractTransaction:` closure (currently around line 76–86). Replace the `let prompt = ...` and the three-line Chinese prompt string with:

```swift
extractTransaction: { input in
    let session = LanguageModelSession()
    let template = String(localized: "ai_prompt_extract_transaction", bundle: .main)
    let prompt = String(format: template, input)
    return try await session.respond(to: prompt, generating: ExtractedTransaction.self).content
},
```

- [ ] **Step 3: Replace `suggestCategories` closure body**

Find the `suggestCategories:` closure (currently around line 91–101). Replace with:

```swift
suggestCategories: { description, existingCategories in
    let session = LanguageModelSession()
    let categoryList = existingCategories.joined(separator: AIServiceClient.listSeparator())
    let template = String(localized: "ai_prompt_suggest_categories", bundle: .main)
    let prompt = String(format: template, description, categoryList)
    return try await session.respond(to: prompt, generating: CategorySuggestions.self).content
},
```

- [ ] **Step 4: Replace `generateInsight` closure body**

Find the `generateInsight:` closure (currently around line 106–119). Replace with:

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

Note: The category line is only appended when `categoryBreakdown` is non-empty. `DashboardFeature` passes an empty breakdown (totals only); `AnalysisFeature` passes the full breakdown. Both are handled correctly.

- [ ] **Step 5: Replace hardcoded strings in `QueryTransactionsTool.call(arguments:)`**

Find the `call(arguments:)` method and replace the bottom half (from `if transactions.isEmpty` to the `return lines.joined`) with:

```swift
if transactions.isEmpty {
    return String(localized: "ai_tool_no_transactions", bundle: .main)
}

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
let noNote = String(localized: "ai_tool_no_note", bundle: .main)
let lines = transactions.map { t in
    "\(formatter.string(from: t.date)) \(t.note ?? noNote) NT$\(t.amount)"
}
return lines.joined(separator: "\n")
```

`noNote` is declared outside the `.map` closure so the localized-string lookup runs once, not once per transaction.

- [ ] **Step 6: Build to confirm it compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`. Common errors:
- `static member 'listSeparator' cannot be used on instance of type` → ensure `listSeparator` is `private static func`, not a regular method
- `cannot convert value of type 'String' to type 'String.LocalizationValue'` → ensure keys are string literals, not variables

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Core/Clients/AIServiceClient+Live.swift
git commit -m "feat(ai): localize AI prompts via String(localized:bundle:)"
```

---

## Task 4: Localize `DashboardFeature.periodDescription`

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift:231`

`DashboardFeature` builds a `SpendingSummary` with a hardcoded English `periodDescription: "Recent"`. This string is interpolated into the insight prompt, so it must be localized.

- [ ] **Step 1: Open `DashboardFeature.swift` and find line 231**

Change:
```swift
periodDescription: "Recent"
```
to:
```swift
periodDescription: String(localized: "dashboard_period_recent", bundle: .main)
```

No import needed — `Foundation` is already imported. `bundle: .main` is specified explicitly for clarity (same reason as in `AIServiceClient+Live.swift`).

- [ ] **Step 2: Build**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Dashboard/DashboardFeature.swift
git commit -m "fix(i18n): localize DashboardFeature periodDescription"
```

---

## Verification

After all 4 tasks are complete, manually verify the end-to-end behaviour:

1. **English:** In Xcode, edit the scheme (`Product → Scheme → Edit Scheme → Run → Options → App Language → English`). Run on simulator. Trigger an AI insight from the Analysis screen — confirm the output is in English. Try recording a transaction — confirm the extracted note is in English.

2. **Traditional Chinese:** Change scheme app language to `Chinese, Traditional`. Repeat — confirm outputs are in Traditional Chinese.

3. **Cross-language input:** With `zh-Hant`, type an English transaction description (e.g., "lunch 150") in the AI record input — confirm it parses correctly despite the Chinese prompt.