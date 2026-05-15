# Domain Category Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make NeuLedger's 14 default seed categories display as "餐飲 / 交通 / …" under zh-Hant instead of the raw English seed names. User-created and user-renamed defaults still fall back to the stored `name`.

**Architecture:** Add a `localizedName: String` computed property on `Domain.Category`, guarded by `isDefault` plus a static `[seedName → i18nKey]` map. Mirror the new 14 i18n keys into both `NeuLedger/Resources/Localizable.xcstrings` (Bundle.main) and `Features/Sources/Domain/Resources/Localizable.xcstrings` (Bundle.module, so DomainTests resolve). Sweep all View call sites that render `category.name` to use `category.localizedName`. No SwiftData schema change.

**Tech Stack:** Swift Foundation, SwiftUI (call-site reads only), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-05-15-category-localization-design.md`

---

## File Structure

**Create:**

| Path | Purpose |
|---|---|
| `Features/Sources/Domain/Entities/Category+Localized.swift` | `public extension Category { var localizedName: String }` + sync warning comment + private seed map |
| `Features/Tests/DomainTests/Entities/CategoryLocalizedNameTests.swift` | 4 cases (default match / default rename / user-created / all 14 seeds non-empty) |

**Modify:**

| Path | Change |
|---|---|
| `NeuLedger/Resources/Localizable.xcstrings` | 14 new `category_seed_*` keys |
| `Features/Sources/Domain/Resources/Localizable.xcstrings` | Mirror 14 keys |
| `Features/Sources/Common/Components/BudgetCategoryListPicker.swift` | `Text(cat.name)` → `Text(cat.localizedName)` |
| `Features/Sources/Features/CategoryManagement/CategoryManagementView.swift` | List row `Text(category.name)` → `Text(category.localizedName)` |
| `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift` | Delete-confirm alert uses `localizedName` (display); edit-prefill `AddEditCategoryFeature.State` still passes raw `name` |
| `Features/Sources/Features/Dashboard/AddTransactionView.swift` | `CategoryChip(title: category.name, ...)` → `CategoryChip(title: category.localizedName, ...)` |
| `Features/Sources/Features/Transactions/FilterView.swift` | `Label(category.name, ...)` → `Label(category.localizedName, ...)` |
| `Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift` | `category?.name` references → `category?.localizedName` (2 occurrences in row title + subtitle) |
| `Features/Sources/Features/Transactions/TransactionDetailFeature.swift` | `.task` extraction line 105: `c.first { $0.id == id }?.name` → `c.first { $0.id == id }?.localizedName` |

**NOT touched (intentional):**

| Path | Reason |
|---|---|
| `Features/Sources/Features/CategoryManagement/AddEditCategoryFeature.swift:39` | TextField prefill uses raw `name` — user must see the actual stored value when editing. |
| `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:428` | Internal name lookup against AI-suggested raw name — keep as-is. |
| `Features/Sources/Features/Analysis/AnalysisFeature.swift` + `AnalysisView.swift` | `metric.categoryName` is used as identity (id derived from it). Localization here would break group-by stability across locales. Tracked as a follow-up — not in this plan. |
| `Features/Sources/Core/Persistence/DatabaseClient.swift` seeds | Seed names stay English; the resolver translates at read time. |

---

## Conventions

- Work on `developer` branch.
- Build: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Domain tests: `xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/<SuiteName>`
- Features tests: `xcodebuild test -project NeuLedger.xcodeproj -scheme FeaturesTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Co-author trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
- LSP "No such module" / "Type 'Color' has no member 'Design'" warnings are pre-existing SourceKit artifacts; `xcodebuild` is the source of truth.

---

## Task 0: Domain `Category.localizedName` + i18n keys + tests

**Files:**
- Create: `Features/Sources/Domain/Entities/Category+Localized.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`
- Modify: `Features/Sources/Domain/Resources/Localizable.xcstrings`
- Create: `Features/Tests/DomainTests/Entities/CategoryLocalizedNameTests.swift`

### Step 1: Add 14 keys to both xcstrings catalogs

Open `NeuLedger/Resources/Localizable.xcstrings` (app bundle) and `Features/Sources/Domain/Resources/Localizable.xcstrings` (Domain SPM bundle). Add the following 14 keys to **each** catalog, in the `"strings"` dictionary, using the same JSON shape as neighboring entries (`extractionState: "manual"` + `localizations.en.stringUnit.value` + `localizations.zh-Hant.stringUnit.value`):

| Key | en | zh-Hant |
|---|---|---|
| `category_seed_food` | `Food` | `餐飲` |
| `category_seed_transport` | `Transport` | `交通` |
| `category_seed_entertainment` | `Entertainment` | `娛樂` |
| `category_seed_shopping` | `Shopping` | `購物` |
| `category_seed_housing` | `Housing` | `居家` |
| `category_seed_utilities` | `Utilities` | `水電費` |
| `category_seed_health` | `Health` | `健康醫療` |
| `category_seed_education` | `Education` | `教育` |
| `category_seed_other_expense` | `Other Expense` | `其他支出` |
| `category_seed_salary` | `Salary` | `薪資` |
| `category_seed_freelance` | `Freelance` | `接案` |
| `category_seed_investment` | `Investment` | `投資` |
| `category_seed_gift` | `Gift` | `禮金` |
| `category_seed_other_income` | `Other Income` | `其他收入` |

### Step 2: Write failing tests

Create `Features/Tests/DomainTests/Entities/CategoryLocalizedNameTests.swift`:

```swift
import Foundation
import Testing
@testable import Domain

@Suite("Category.localizedName Tests")
struct CategoryLocalizedNameTests {

    private static func make(name: String, isDefault: Bool) -> Category {
        Category(
            name: name,
            icon: "tag",
            color: "#000000",
            type: .expense,
            isDefault: isDefault
        )
    }

    @Test("Default seed with English seed name resolves to localized string")
    func testDefaultSeedResolves() {
        let cat = Self.make(name: "Food", isDefault: true)
        let result = cat.localizedName
        // zh-Hant simulator → "餐飲"; en simulator → "Food"
        #expect(result == "餐飲" || result == "Food")
        // The localized lookup must not echo the i18n key back.
        #expect(result != "category_seed_food")
    }

    @Test("Default category renamed by user falls back to raw name")
    func testDefaultRenamedFallback() {
        let cat = Self.make(name: "My Food", isDefault: true)
        #expect(cat.localizedName == "My Food")
    }

    @Test("Non-default user-created category falls back to raw name")
    func testUserCreatedFallback() {
        let cat = Self.make(name: "Coffee", isDefault: false)
        #expect(cat.localizedName == "Coffee")
    }

    @Test("All 14 seed names resolve to a non-empty, non-key value")
    func testAllSeedsResolve() {
        let seedNames = [
            "Food", "Transport", "Entertainment", "Shopping",
            "Housing", "Utilities", "Health", "Education", "Other Expense",
            "Salary", "Freelance", "Investment", "Gift", "Other Income",
        ]
        for name in seedNames {
            let cat = Self.make(name: name, isDefault: true)
            let result = cat.localizedName
            #expect(!result.isEmpty, "\(name) localizedName was empty")
            #expect(!result.hasPrefix("category_seed_"), "\(name) returned i18n key instead of translation")
        }
    }
}
```

### Step 3: Run — verify compile failure (`localizedName` undefined)

```
xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/CategoryLocalizedNameTests
```

Expected: compile failure on `cat.localizedName`.

### Step 4: Implement the extension

Create `Features/Sources/Domain/Entities/Category+Localized.swift`:

```swift
import Foundation

// NOTE: The seed-name keys consumed below
// (`category_seed_food` / `_transport` / `_entertainment` / `_shopping` /
// `_housing` / `_utilities` / `_health` / `_education` / `_other_expense` /
// `_salary` / `_freelance` / `_investment` / `_gift` / `_other_income`)
// live in TWO xcstrings catalogs and must be kept in sync:
//
//   - Features/Sources/Domain/Resources/Localizable.xcstrings  (Bundle.module)
//   - NeuLedger/Resources/Localizable.xcstrings                (Bundle.main)
//
// The English keys also act as the lookup keys in `seedLocalizationMap`
// below. If you rename a seed in Core/Persistence/DatabaseClient.swift,
// update both the catalogs AND the map entry here so the resolver still
// matches.

public extension Category {

    /// Returns a localized display name for default seed categories.
    /// User-created or user-renamed default categories fall back to the
    /// raw stored `name`.
    var localizedName: String {
        guard isDefault, let key = Self.seedLocalizationMap[name] else {
            return name
        }
        return String(localized: String.LocalizationValue(key), bundle: .module)
    }

    /// English seed name → i18n key. Mirrors the SeedCategory entries
    /// in `Features/Sources/Core/Persistence/DatabaseClient.swift`.
    /// Keep in sync if seeds change.
    private static let seedLocalizationMap: [String: String] = [
        "Food":            "category_seed_food",
        "Transport":       "category_seed_transport",
        "Entertainment":   "category_seed_entertainment",
        "Shopping":        "category_seed_shopping",
        "Housing":         "category_seed_housing",
        "Utilities":       "category_seed_utilities",
        "Health":          "category_seed_health",
        "Education":       "category_seed_education",
        "Other Expense":   "category_seed_other_expense",
        "Salary":          "category_seed_salary",
        "Freelance":       "category_seed_freelance",
        "Investment":      "category_seed_investment",
        "Gift":            "category_seed_gift",
        "Other Income":    "category_seed_other_income",
    ]
}
```

### Step 5: Run — verify tests pass

```
xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/CategoryLocalizedNameTests
```

Expected: 4/4 pass.

### Step 6: Build full project

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

### Step 7: Commit

```bash
git add NeuLedger/Resources/Localizable.xcstrings \
        Features/Sources/Domain/Resources/Localizable.xcstrings \
        Features/Sources/Domain/Entities/Category+Localized.swift \
        Features/Tests/DomainTests/Entities/CategoryLocalizedNameTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add Category.localizedName resolver for seed categories

Default categories whose stored English name matches a known seed
(Food / Transport / Salary / …) now resolve to their zh-Hant
translation at read time. User-created and user-renamed defaults
fall back to the raw stored `name`. No SwiftData schema change.

14 new i18n keys mirrored into both the app bundle (Bundle.main)
and the Domain SPM bundle (Bundle.module) — the latter is what
DomainTests reads from. The Category+Localized.swift file carries
a sync-warning header listing both catalogs.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 1: View call-site sweep

Migrate every direct `category.name` display in the Features layer to `category.localizedName`. Reducer internals that use `name` as identity / lookup stay untouched.

**Files:**
- Modify: `Features/Sources/Common/Components/BudgetCategoryListPicker.swift`
- Modify: `Features/Sources/Features/CategoryManagement/CategoryManagementView.swift`
- Modify: `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift`
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift`
- Modify: `Features/Sources/Features/Transactions/FilterView.swift`
- Modify: `Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift`

### Step 1: `BudgetCategoryListPicker.swift`

Locate the row construction for each category — the loop currently passes `Text(cat.name)`:

Find:
```swift
                row(
                    emoji: cat.icon,
                    color: Color(hex: cat.color),
                    title: Text(cat.name),
```

Replace with:
```swift
                row(
                    emoji: cat.icon,
                    color: Color(hex: cat.color),
                    title: Text(cat.localizedName),
```

### Step 2: `CategoryManagementView.swift`

In `categoryRow(_:)` — line 109:

Find:
```swift
                    Text(category.name)
                        .font(Font.Design.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Design.textPrimary)
```

Replace with:
```swift
                    Text(category.localizedName)
                        .font(Font.Design.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Design.textPrimary)
```

### Step 3: `CategoryManagementFeature.swift` — delete-confirm alert

Find the AlertState message construction around line 142:

```swift
                    TextState(String(format: String(localized: "alert_delete_category_message_name %@"), category.name))
```

Replace `category.name` with `category.localizedName`:

```swift
                    TextState(String(format: String(localized: "alert_delete_category_message_name %@"), category.localizedName))
```

**Do NOT change line 103** — that's the prefill of the edit form, which keeps `name: category.name` so the TextField shows the raw stored value the user is actually editing.

### Step 4: `AddTransactionView.swift`

In `categorySection` — around line 139:

Find:
```swift
                                CategoryChip(
                                    title: category.name,
                                    systemImage: category.icon,
                                    color: Color(hex: category.color),
                                    isSelected: store.categoryId == category.id,
                                    isSuggested: store.suggestedCategoryNames.contains(category.name)
                                )
```

Change ONLY the `title:` parameter; keep the `isSuggested:` comparison on raw `name` (AI suggestions return raw stored names):

```swift
                                CategoryChip(
                                    title: category.localizedName,
                                    systemImage: category.icon,
                                    color: Color(hex: category.color),
                                    isSelected: store.categoryId == category.id,
                                    isSuggested: store.suggestedCategoryNames.contains(category.name)
                                )
```

### Step 5: `FilterView.swift`

Line 43:

Find:
```swift
                                    Label(category.name, systemImage: category.icon)
```

Replace:
```swift
                                    Label(category.localizedName, systemImage: category.icon)
```

### Step 6: `TransactionsSection.swift`

This file has two `?.name` references inside the `TransactionRow` construction. Find:

```swift
                    TransactionRow(
                        title: tx.note?.isEmpty == false
                            ? (tx.note ?? "")
                            : (category?.name ?? "—"),
                        subtitle: category?.name ?? tx.type.displayName,
```

Replace both occurrences:

```swift
                    TransactionRow(
                        title: tx.note?.isEmpty == false
                            ? (tx.note ?? "")
                            : (category?.localizedName ?? "—"),
                        subtitle: category?.localizedName ?? tx.type.displayName,
```

### Step 7: `TransactionDetailFeature.swift`

In the `.task` handler around line 105, find the categoryName extraction:

```swift
                        let categoryName = txn.categoryId.flatMap { id in c.first { $0.id == id }?.name }
```

Replace:

```swift
                        let categoryName = txn.categoryId.flatMap { id in c.first { $0.id == id }?.localizedName }
```

### Step 8: Build

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

### Step 9: Run all Features tests

```
xcodebuild test -project NeuLedger.xcodeproj -scheme FeaturesTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 270/270 pass (1 pre-existing known issue). Any failure is likely a test that asserted on the raw English seed name — investigate and adapt only if the assertion is meant to be locale-stable.

### Step 10: Sanity-check no remaining display-side `.name` from `Domain.Category` instances

Run:

```bash
grep -rn "category\.name\|categories\.first.*\.name\|categoryMap\[.*\]\?\.name" Features/Sources/Features --include="*.swift" | grep -v "TestStore\|test\|Tests"
```

Expected matches you can safely ignore (NOT bugs):
- `AddEditCategoryFeature.swift:39` — TextField prefill (must stay raw)
- `AddTransactionFeature.swift:428` — internal lookup by raw name (must stay raw)
- `AnalysisFeature.swift` lines (tracked as follow-up — out of scope for this plan)
- `CategoryManagementFeature.swift:103` — edit form prefill (must stay raw)
- `Features/Sources/Common/Components/...` references using `.name` from non-Category types

If you see ANY display-side rendering of a `Domain.Category`'s `.name` other than those four exception classes, fix it in this commit.

### Step 11: Commit

```bash
git add Features/Sources/Common/Components/BudgetCategoryListPicker.swift \
        Features/Sources/Features/CategoryManagement/CategoryManagementView.swift \
        Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift \
        Features/Sources/Features/Dashboard/AddTransactionView.swift \
        Features/Sources/Features/Transactions/FilterView.swift \
        Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift \
        Features/Sources/Features/Transactions/TransactionDetailFeature.swift
git commit -m "$(cat <<'EOF'
refactor(features): display seed categories via Category.localizedName

Sweeps every direct render of `category.name` to `category.localizedName`
across the Budget Form picker, Category Management list, AddTransaction
chips, Filter labels, Dashboard transactions section, the
TransactionDetail header pipeline, and the delete-confirmation alert.

AnalysisFeature is intentionally untouched — its `categoryName` doubles
as a stable group-by identity and localizing it would break charts
across locales. Tracked as a follow-up.

Edit-form prefills (CategoryManagement edit, AddTransaction AI
matching) keep using the raw `name` so users see the actual stored
value being edited.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**

- Spec §3 `Category.localizedName` extension + guard + map → Task 0 Step 4 ✅
- Spec §4 view-render call sites → Task 1 Steps 1–7 (7 files) ✅
- Spec §4.1 Analysis follow-up note → Task 1 introduction + Step 10 exception list ✅
- Spec §5 4 test cases → Task 0 Step 2 ✅
- Spec §6 14 i18n keys (dual-bundle) → Task 0 Step 1 ✅
- Spec §7 risk mitigations (sync warning comment) → Task 0 Step 4 (file header comment) ✅
- Spec §8 2-slice plan → matches this plan's Task 0 + Task 1 ✅
- Spec §9 DoD: every checklist item maps to a step ✅

**Placeholder scan:** no TBD / vague handlers / "similar to task N". Every code snippet is paste-ready.

**Type consistency:**

- `Category.localizedName` (String, no parameters) — defined Task 0 Step 4, used Task 1 Steps 1–7. Same signature throughout. ✅
- `seedLocalizationMap` private static — Task 0 only; not referenced from elsewhere. ✅
- `Bundle.module` — Task 0 Step 4 — relies on `Package.swift` already declaring `resources: [.process("Resources")]` on the Domain target (added during Budget Form Task 0, commit `55723d4`). ✅
- `category.localizedName` calls in Task 1 Steps 1–7 all use the same property access pattern. ✅

No issues. No re-review needed.

---

## Execution

Plan complete and saved to `docs/superpowers/plans/2026-05-15-category-localization.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task with two-stage review.
2. **Inline Execution** — Execute tasks in this session with checkpoints.

Which approach?
