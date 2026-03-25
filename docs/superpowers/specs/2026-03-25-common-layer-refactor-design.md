# Common Layer Refactor Design

**Date:** 2026-03-25
**Status:** Approved

## Background

The `Common` module serves as the design system layer — pure SwiftUI components, extensions, and design tokens. It must have **zero dependencies** (no Domain, no Core). During a codebase audit, two categories of issues were found:

1. Minor Domain knowledge leaking into a Common component
2. Repeated UI patterns in the Features layer that should be abstracted into Common, along with duplicated extension code

---

## Goals

- Common components accept only primitive Swift types (`String`, `Color`, `Bool`, `Decimal`, `CGFloat`). No Domain entity types, no wrapper structs.
- Features layer is responsible for mapping Domain entities into primitives before passing to Common.
- Repeated UI patterns (color swatch picker, icon picker, icon badge) extracted as generic Common components.
- Duplicate `private extension` definitions on Domain enums consolidated — display string and SF Symbol name properties moved to Domain; color properties consolidated into a single Features-layer file.

---

## Changes

### 1. Common/Components — Fix `TransactionRow` API

**Problem:** `TransactionRow` internally derives `isExpense: Bool { amount < 0 }` to decide text color. This embeds a Domain convention ("negative amount = expense") into a Common component.

**Fix:** Replace `amount: Decimal` with explicit primitives.

```swift
// Before
TransactionRow(amount: -120, ...)

// After
TransactionRow(amountText: "NT$120", amountColor: Color.Design.expenseRed, ...)
```

- Remove `isExpense` logic and `amount.twdFormatted` call from `TransactionRow`
- All call sites in Features pass pre-formatted `amountText` and pre-computed `amountColor`
- **Test impact:** Update any snapshot/unit tests for `TransactionRow` if they exist

---

### 2. Common/Components — Add 3 New Generic Components

#### `IconBadge`
Colored circle with an SF Symbol inside. Used in Account/Category previews and list rows.

```swift
IconBadge(systemImage: "creditcard", color: .blue, size: 44)
```

#### `IconPickerRow`
Horizontal scrolling row of SF Symbol icon buttons with selection state.

The two existing icon pickers use different selected-state styles:
- `AddEditAccountView`: selected = `color.opacity(0.2)` fill + color stroke + colored icon (circle size 48)
- `AddEditCategoryView`: selected = fully opaque color fill + `textInverse` icon (circle size 44)

**Canonical style chosen:** `AddEditCategoryView` style (opaque fill, `textInverse` icon, size 44). The Account form will adopt this style — this is an intentional visual change.

```swift
IconPickerRow(
    icons: DesignConstants.accountIconOptions,
    selectedIcon: store.icon,
    accentColor: Color(hex: store.colorHex)
) { iconName in
    store.send(.iconChanged(iconName))
}
```

#### `ColorSwatchPicker`
Grid or horizontal scroll of colored hex circles with checkmark on selection.

The two existing color pickers use slightly different selected-state decoration:
- `AddEditAccountView`: single `textPrimary` stroke ring
- `AddEditCategoryView`: `textInverse` stroke + outer color stroke overlay

**Canonical style chosen:** `AddEditCategoryView` double-ring style. The Account form will adopt this — intentional visual change.

```swift
ColorSwatchPicker(
    colors: DesignConstants.accountColorOptions,  // or categoryColorOptions / tagColorOptions
    selectedHex: store.colorHex
) { hex in
    store.send(.colorHexChanged(hex))
}
```

Layout (scroll vs grid) is controlled by an optional `layout` parameter:
```swift
enum ColorSwatchLayout { case horizontalScroll, grid(columns: Int) }
ColorSwatchPicker(colors:, selectedHex:, layout: .grid(columns: 6), onSelect:)
```

All three components accept only `String`, `Color`, `[String]`, and closures — no Domain types.

---

### 3. Common/DesignSystem — Add Design Constants

New file `DesignConstants.swift` in `Common/DesignSystem/`:

```swift
public enum DesignConstants {
    public static let accountIconOptions: [String] = [
        "creditcard", "banknote", "wallet.bifold", "building.columns",
        "dollarsign.circle", "star.circle", "cart.circle", "briefcase.circle"
    ]

    public static let categoryIconOptions: [String] = [
        "fork.knife", "car.fill", "gamecontroller.fill", "bag.fill", "house.fill",
        "bolt.fill", "cross.case.fill", "book.fill", "person.2.fill", "briefcase.fill",
        "star.fill", "laptopcomputer", "chart.line.uptrend.xyaxis", "gift.fill",
        "ellipsis.circle.fill", "tag.fill", "cart.fill", "airplane", "heart.fill", "music.note"
    ]

    /// Shared palette for category and tag color selection.
    public static let categoryColorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#32ADE6", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55"
    ]

    /// Account color palette — includes brand blue and warm yellow in place of grey.
    public static let accountColorOptions: [String] = [
        "#3478F6", "#34C759", "#FF9500", "#FF3B30", "#5856D6",
        "#FF2D55", "#AF52DE", "#00C7BE", "#32ADE6", "#FF9F0A"
    ]

    /// Tag color palette — superset including neutral grey.
    public static let tagColorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#3478F6", "#8E8E93"
    ]
}
```

**Note:** Three separate palettes are preserved intentionally. The existing color lists per form differ in both composition and count; silently merging them into one would produce silent visual regressions.

---

### 4. Domain — Add Display Properties to `TransactionType`

`TransactionType.displayName` is currently defined as a `private extension` in **five** Features files:
- `TransactionsView.swift`
- `FilterView.swift`
- `TransactionDetailView.swift`
- `DashboardScreen.swift` (inline `switch` without using the property name)
- `AddTransactionView.swift` (inline `Text(String(localized: "common_expense")).tag(...)` per case)

The SF Symbol name (`icon` in `TransactionsView`) is also duplicated.

Add to `Domain/Enums/TransactionType.swift` (or a `TransactionType+Display.swift`):

```swift
public extension TransactionType {
    var displayName: String {
        switch self {
        case .expense:  String(localized: "common_expense")
        case .income:   String(localized: "common_income")
        case .transfer: String(localized: "common_transfer")
        }
    }

    /// SF Symbol system image name for this transaction type.
    /// Named `systemImageName` (not `icon`) to be consistent with SwiftUI/SF Symbols naming conventions.
    var systemImageName: String {
        switch self {
        case .expense:  "arrow.up.circle.fill"
        case .income:   "arrow.down.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }
}
```

- **All five files** must remove their local definitions and adopt `transaction.type.displayName` / `transaction.type.systemImageName`
- The property was previously named `icon` in `TransactionsView` — all call sites must be updated to `systemImageName`
- **Test impact:** Add Domain unit test assertions for both new properties across all three cases

> **Architectural note:** `String(localized:)` in Domain resolves against the main app bundle at runtime (same pattern as `BudgetPeriod.localizedName`). This works as long as the SPM package is consumed by a single app target. If a second target or an isolated test target is added in future, `String(localized: bundle: .module)` will be required alongside a resource bundle declaration in `Package.swift`.

---

### 5. Features/Shared — Consolidate `TransactionType` Color

`TransactionType.color` / `badgeColor` / `amountColor` are defined inconsistently across two files:
- `TransactionsView.swift`: `transfer` → `Color.Design.textSecondary`
- `TransactionDetailView.swift`: `transfer` badge → `Color.Design.brandPrimary`; `transfer` amount → `Color.Design.textPrimary`

**Canonical color for `.transfer`: `Color.Design.textSecondary`.** The `TransactionDetailView` badge will change from `brandPrimary` to `textSecondary` — this is an intentional visual change to achieve consistency.

Create a new directory `Features/Sources/Features/Shared/` and add `TransactionType+UIColor.swift`:

```swift
import SwiftUI
import Common
import Domain

public extension TransactionType {
    var uiColor: Color {
        switch self {
        case .expense:  Color.Design.expenseRed
        case .income:   Color.Design.incomeGreen
        case .transfer: Color.Design.textSecondary
        }
    }
}
```

- All Features files use `.uiColor` instead of local private variants
- **Test impact:** Remove old private extensions; verify any tests that assert specific colors for `.transfer`

---

### 6. Features — Remove Duplicate Code

| Location | Problem | Fix |
|---|---|---|
| `AddEditTagView.swift` | Local `hexColor(_ hex:)` function | Delete; use `Color(hex:)` from Common |
| `TransactionDetailView.swift` | `private extension Decimal { var formattedTWD }` produces `"NT$ 46,200"` (space after symbol), while Common's `twdFormatted` produces `"NT$46,200"` (no space). Delete the local extension and use `.twdFormatted`; the display format in the detail view will change to no-space — this is an intentional visual alignment with the rest of the app. |
| `TransactionDetailView.swift` | `private struct FlowLayout: Layout` — duplicates `Common/Components/FlowLayout.swift` | Delete the private struct; use `FlowLayout` from Common |
| `AddEditAccountView.swift` | Inline icon/color picker code + hardcoded lists | Replace with `IconPickerRow` + `ColorSwatchPicker` + `DesignConstants.accountIconOptions` + `DesignConstants.accountColorOptions` |
| `AddEditCategoryView.swift` | Same inline icon/color picker | Replace with `IconPickerRow` + `ColorSwatchPicker` + `DesignConstants.categoryIconOptions` + `DesignConstants.categoryColorOptions` |
| `AddEditTagView.swift` | Inline color picker + hardcoded list | Replace with `ColorSwatchPicker` + `DesignConstants.tagColorOptions` |

---

### 7. Follow-up (Out of Scope for This Change)

`AccountType.displayLabel` in `Domain/Enums/AccountType.swift` has hardcoded English strings (`"Cash"`, `"Bank"`, `"Credit Card"`, `"E-Wallet"`). This violates the `String(localized:)` constraint in CLAUDE.md. It is not addressed here to keep scope focused, but should be fixed in a follow-up.

---

## What Does NOT Change

- Analysis chart components (`CategoryPieChartView`, `TrendBarChartView`, `SummaryCardView`) stay in `Features/Analysis/Components/` — they reference Domain types and are feature-specific.
- `BudgetRow` stays in `Features/BudgetManagement/Components/` — it depends on `Domain.Budget`.
- `AccessoryShimmerPill` stays private in `MainTabView.swift` — it is MainTab-specific.
- Common/Extensions currently has only `Decimal+Currency.swift`. No new extensions are added to Common (Domain-type extensions cannot go in Common without adding a Domain dependency, which violates the zero-dependency rule).

---

## Test Checklist

- [ ] `TransactionRow` — update all call sites to `amountText`/`amountColor`; verify no test uses old `amount: Decimal` signature
- [ ] `TransactionType.displayName` / `systemImageName` — add Domain unit test assertions for all three cases
- [ ] `TransactionType.uiColor` — add or update any tests asserting colors; verify `.transfer` color change is acceptable
- [ ] `DashboardScreen` + `AddTransactionView` — confirm inline switch statements replaced with `transaction.type.displayName`
- [ ] `AddEditAccountView` / `AddEditCategoryView` / `AddEditTagView` — run existing form tests after picker extraction
- [ ] Full `Features` scheme test run passes after all changes
