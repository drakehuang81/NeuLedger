# Budget Form Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repaint `BudgetFormView` to match `design/source/budget-form.jsx` — mono UPPERCASE section headers + Glass section cards, 32pt mono amount field with per-period breakdown helper text, radio-style category picker. Reducer is untouched.

**Architecture:** Pure visual upgrade. The 5 existing form sections (Name / Amount / Period / StartDate / Category) survive; their containers move from system `Form/Section` to a custom `FormSection` Glass card pattern. A new `Decimal.perPeriodBreakdown(_:)` helper in Domain renders the live "≈ NT$ X / 天" hint under the amount field. Category picker becomes a radio list with a leading "全部支出 ∗" sentinel row (replaces the existing `Picker(.menu)`).

**Tech Stack:** SwiftUI (iOS 26 Liquid Glass), TCA v1.23.1 (unchanged), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-05-15-budget-form-redesign-design.md`

---

## File Structure

**Create:**

| Path | Purpose |
|---|---|
| `Features/Sources/Domain/Extensions/Decimal+Budget.swift` | `perPeriodBreakdown(_ period: BudgetPeriod) -> String?` localized helper |
| `Features/Sources/Common/Components/FormSection.swift` | Wrapper: mono UPPERCASE header + Glass card + optional footer text |
| `Features/Sources/Common/Components/ErrorText.swift` | Red inline error row with alert icon |
| `Features/Sources/Common/Components/BudgetCategoryListPicker.swift` | Radio-style category list with leading "All expenses ∗" entry |
| `Features/Tests/DomainTests/Enums/BudgetPeriodSuffixTests.swift` | Suffix output per case |
| `Features/Tests/DomainTests/Extensions/DecimalPerPeriodBreakdownTests.swift` | Boundary + rounding tests for breakdown |

**Modify:**

| Path | Change |
|---|---|
| `Features/Sources/Domain/Enums/BudgetPeriod.swift` | Add `localizedSuffix: String` |
| `Features/Sources/Features/BudgetManagement/BudgetFormView.swift` | Rewrite body: drop `Form/Section`, use new primitives |
| `NeuLedger/Resources/Localizable.xcstrings` | 6 new keys (breakdown × 3, suffix × 3) |

---

## Conventions

- All work happens on `developer` branch.
- Build (any task): `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Run Domain tests: `xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/<SuiteName>`
- Run Features tests: `xcodebuild test -project NeuLedger.xcodeproj -scheme FeaturesTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Co-author trailer on each commit: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
- LSP "No such module" / "Type 'Color' has no member 'Design'" warnings in SourceKit are pre-existing project artifacts; `xcodebuild` is the source of truth.

---

## Task 0: i18n keys + Domain helpers (`BudgetPeriod.localizedSuffix` + `Decimal.perPeriodBreakdown`)

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`
- Modify: `Features/Sources/Domain/Enums/BudgetPeriod.swift`
- Create: `Features/Sources/Domain/Extensions/Decimal+Budget.swift`
- Create: `Features/Tests/DomainTests/Enums/BudgetPeriodSuffixTests.swift`
- Create: `Features/Tests/DomainTests/Extensions/DecimalPerPeriodBreakdownTests.swift`

### Step 1: Add localization keys

Open `NeuLedger/Resources/Localizable.xcstrings` and add these entries under the `"strings"` dictionary (use the same JSON shape as neighboring entries — `extractionState: "manual"` plus `localizations.en.stringUnit.value` / `localizations.zh-Hant.stringUnit.value`):

| Key | en | zh-Hant |
|---|---|---|
| `budget_period_suffix_weekly` | `week` | `週` |
| `budget_period_suffix_monthly` | `month` | `月` |
| `budget_period_suffix_yearly` | `year` | `年` |
| `budget_form_breakdown_weekly` | `≈ NT$%@ / day` | `≈ NT$%@ / 天` |
| `budget_form_breakdown_monthly` | `≈ NT$%@ / day · about NT$%@ / week` | `≈ NT$%@ / 天 · 約 NT$%@ / 週` |
| `budget_form_breakdown_yearly` | `≈ NT$%@ / month` | `≈ NT$%@ / 月` |

- [ ] **Step 2: Write failing tests for `BudgetPeriod.localizedSuffix`**

Create `Features/Tests/DomainTests/Enums/BudgetPeriodSuffixTests.swift`:

```swift
import Foundation
import Testing
@testable import Domain

@Suite("BudgetPeriod.localizedSuffix Tests")
struct BudgetPeriodSuffixTests {

    @Test("weekly returns localized week suffix (zh-Hant)")
    func testWeeklySuffix() {
        // Default test locale resolves zh-Hant from xcstrings.
        // Acceptable values are either "週" (zh-Hant) or "week" (en) — depends on simulator language.
        let s = BudgetPeriod.weekly.localizedSuffix
        #expect(s == "週" || s == "week")
        #expect(!s.isEmpty)
    }

    @Test("monthly returns localized month suffix")
    func testMonthlySuffix() {
        let s = BudgetPeriod.monthly.localizedSuffix
        #expect(s == "月" || s == "month")
        #expect(!s.isEmpty)
    }

    @Test("yearly returns localized year suffix")
    func testYearlySuffix() {
        let s = BudgetPeriod.yearly.localizedSuffix
        #expect(s == "年" || s == "year")
        #expect(!s.isEmpty)
    }

    @Test("all cases produce non-empty suffix")
    func testAllCasesNonEmpty() {
        for p in BudgetPeriod.allCases {
            #expect(!p.localizedSuffix.isEmpty)
        }
    }
}
```

- [ ] **Step 3: Run — verify compile failure (`localizedSuffix` undefined)**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/BudgetPeriodSuffixTests
```

Expected: compile failure.

- [ ] **Step 4: Add `localizedSuffix` to `BudgetPeriod`**

In `Features/Sources/Domain/Enums/BudgetPeriod.swift`, append inside the enum:

```swift
    /// Short localized suffix used in UI labels such as "NT$ 8,000 / 月".
    public var localizedSuffix: String {
        switch self {
        case .weekly:  return String(localized: "budget_period_suffix_weekly")
        case .monthly: return String(localized: "budget_period_suffix_monthly")
        case .yearly:  return String(localized: "budget_period_suffix_yearly")
        }
    }
```

- [ ] **Step 5: Run — verify tests pass**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/BudgetPeriodSuffixTests
```

Expected: 4 tests pass.

- [ ] **Step 6: Write failing tests for `Decimal.perPeriodBreakdown`**

Create `Features/Tests/DomainTests/Extensions/DecimalPerPeriodBreakdownTests.swift`:

```swift
import Foundation
import Testing
@testable import Domain

@Suite("Decimal.perPeriodBreakdown Tests")
struct DecimalPerPeriodBreakdownTests {

    @Test("Zero returns nil")
    func testZeroReturnsNil() {
        #expect(Decimal(0).perPeriodBreakdown(.monthly) == nil)
    }

    @Test("Negative returns nil")
    func testNegativeReturnsNil() {
        #expect(Decimal(-100).perPeriodBreakdown(.monthly) == nil)
    }

    @Test("Monthly NT$8000 yields per-day and per-week breakdown")
    func testMonthlyBreakdown() throws {
        let s = try #require(Decimal(8000).perPeriodBreakdown(.monthly))
        // 8000 / 30 ≈ 267; 8000 / 4.33 ≈ 1848
        #expect(s.contains("267"))
        #expect(s.contains("1,848") || s.contains("1848"))
    }

    @Test("Weekly NT$2100 yields per-day breakdown")
    func testWeeklyBreakdown() throws {
        let s = try #require(Decimal(2100).perPeriodBreakdown(.weekly))
        // 2100 / 7 = 300
        #expect(s.contains("300"))
    }

    @Test("Yearly NT$120000 yields per-month breakdown")
    func testYearlyBreakdown() throws {
        let s = try #require(Decimal(120_000).perPeriodBreakdown(.yearly))
        // 120000 / 12 = 10000
        #expect(s.contains("10,000") || s.contains("10000"))
    }

    @Test("Large monthly value rounds cleanly without crash")
    func testLargeMonthly() throws {
        let s = try #require(Decimal(999_999).perPeriodBreakdown(.monthly))
        #expect(!s.isEmpty)
    }
}
```

- [ ] **Step 7: Run — verify compile failure (`perPeriodBreakdown` undefined)**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/DecimalPerPeriodBreakdownTests
```

Expected: compile failure.

- [ ] **Step 8: Implement `Decimal.perPeriodBreakdown`**

Create `Features/Sources/Domain/Extensions/Decimal+Budget.swift` (you may need to `mkdir` the `Extensions` folder first):

```swift
import Foundation

public extension Decimal {

    /// Returns a localized human-readable per-period breakdown of this amount.
    ///
    /// - For `.monthly`, produces "≈ NT$X / 天 · 約 NT$Y / 週" (zh-Hant).
    /// - For `.weekly`, produces "≈ NT$X / 天".
    /// - For `.yearly`, produces "≈ NT$X / 月".
    /// - Returns `nil` when the amount is zero or negative.
    ///
    /// Rounding uses banker's mode to the nearest integer.
    func perPeriodBreakdown(_ period: BudgetPeriod) -> String? {
        guard self > 0 else { return nil }
        switch period {
        case .weekly:
            let perDay = Self.rounded(self / 7)
            return String(
                format: String(localized: "budget_form_breakdown_weekly"),
                Self.formatted(perDay)
            )
        case .monthly:
            let perDay  = Self.rounded(self / 30)
            let perWeek = Self.rounded(self / Decimal(string: "4.33")!)
            return String(
                format: String(localized: "budget_form_breakdown_monthly"),
                Self.formatted(perDay),
                Self.formatted(perWeek)
            )
        case .yearly:
            let perMonth = Self.rounded(self / 12)
            return String(
                format: String(localized: "budget_form_breakdown_yearly"),
                Self.formatted(perMonth)
            )
        }
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .plain)
        return output
    }

    private static func formatted(_ value: Decimal) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        return fmt.string(from: value as NSDecimalNumber) ?? "0"
    }
}
```

- [ ] **Step 9: Run breakdown tests — verify pass**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme DomainTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DomainTests/DecimalPerPeriodBreakdownTests
```

Expected: 6 tests pass.

- [ ] **Step 10: Build full project**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 11: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings \
        Features/Sources/Domain/Enums/BudgetPeriod.swift \
        Features/Sources/Domain/Extensions/Decimal+Budget.swift \
        Features/Tests/DomainTests/Enums/BudgetPeriodSuffixTests.swift \
        Features/Tests/DomainTests/Extensions/DecimalPerPeriodBreakdownTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add BudgetPeriod.localizedSuffix and Decimal.perPeriodBreakdown

localizedSuffix returns the short "週 / 月 / 年" label used after an
amount in the Budget Form (e.g. "NT$8,000 / 月"). perPeriodBreakdown
renders the live "≈ NT$ X / 天" helper line under the amount field,
adapting to the selected period. Both are en/zh-Hant localized.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 1: Common primitives (`FormSection`, `ErrorText`, `BudgetCategoryListPicker`)

**Files:**
- Create: `Features/Sources/Common/Components/FormSection.swift`
- Create: `Features/Sources/Common/Components/ErrorText.swift`
- Create: `Features/Sources/Common/Components/BudgetCategoryListPicker.swift`

These primitives are pure SwiftUI; they have no unit tests (visual only). Build green is the gate.

- [ ] **Step 1: Create `FormSection.swift`**

```swift
import SwiftUI

/// A budget/settings-style form section with a mono UPPERCASE header,
/// a Glass-tinted rounded card around the content, and an optional
/// footer hint paragraph.
public struct FormSection<Content: View>: View {
    private let headerKey: LocalizedStringKey
    private let footerKey: LocalizedStringKey?
    private let content: () -> Content

    public init(
        _ headerKey: LocalizedStringKey,
        footerKey: LocalizedStringKey? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headerKey = headerKey
        self.footerKey = footerKey
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerKey)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)
                .padding(.leading, 6)
                .padding(.bottom, 8)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(
                    Glass.clear.tint(Color.Design.surface),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            if let footerKey {
                Text(footerKey)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Design.textSecondary)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 22)
    }
}
```

- [ ] **Step 2: Create `ErrorText.swift`**

```swift
import SwiftUI

/// Inline form error: red alert icon + 12.5pt expenseRed message.
///
/// Use directly under an input field's container.
public struct ErrorText: View {
    private let messageKey: LocalizedStringKey

    public init(_ messageKey: LocalizedStringKey) {
        self.messageKey = messageKey
    }

    /// String-payload initializer for messages produced at runtime
    /// (e.g. localized errors that are already `String`).
    public init(_ message: String) {
        self.messageKey = LocalizedStringKey(message)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.Design.expenseRed)
            Text(messageKey)
                .font(.system(size: 12.5))
                .lineSpacing(1.4)
                .foregroundStyle(Color.Design.expenseRed)
        }
        .padding(.top, 6)
    }
}
```

- [ ] **Step 3: Create `BudgetCategoryListPicker.swift`**

```swift
import Domain
import SwiftUI

/// A radio-style picker for choosing a Budget category (or "All expenses").
///
/// Layout: each row has a 32pt color-tinted emoji circle, the category
/// name, and a trailing checkmark when selected. The first row is a
/// sentinel "All expenses ∗" with `id == nil`.
public struct BudgetCategoryListPicker: View {
    private let categories: [Domain.Category]
    private let selectedId: Domain.Category.ID?
    private let onSelect: (Domain.Category.ID?) -> Void

    public init(
        categories: [Domain.Category],
        selectedId: Domain.Category.ID?,
        onSelect: @escaping (Domain.Category.ID?) -> Void
    ) {
        self.categories = categories
        self.selectedId = selectedId
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            row(
                emoji: "∗",
                color: Color.Design.accentOrange,
                title: Text("budget_form_all_expenses"),
                isAll: true,
                isSelected: selectedId == nil,
                action: { onSelect(nil) }
            )

            ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                Divider()
                    .padding(.leading, 60)

                row(
                    emoji: cat.icon,
                    color: Color(hex: cat.color),
                    title: Text(cat.name),
                    isAll: false,
                    isSelected: selectedId == cat.id,
                    action: { onSelect(cat.id) }
                )
            }
        }
    }

    private func row(
        emoji: String,
        color: Color,
        title: Text,
        isAll: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                    Text(emoji)
                        .font(.system(
                            size: isAll ? 18 : 16,
                            weight: isAll ? .bold : .regular
                        ))
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)

                title
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.Design.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Design.accentOrange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

> **Note:** `cat.icon` in `Domain.Category` is a `String` — designs show emoji or SF Symbol. The existing iOS seeds use SF Symbol names like `"fork.knife"`. We render the field as-is via `Text(emoji)`; if the value happens to be an SF Symbol name, it will appear as text. This is acceptable for V1 — the design preview uses emojis. A follow-up can switch the row's leading visual to `Image(systemName:)` when icons are SF Symbols.

- [ ] **Step 4: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Common/Components/FormSection.swift \
        Features/Sources/Common/Components/ErrorText.swift \
        Features/Sources/Common/Components/BudgetCategoryListPicker.swift
git commit -m "$(cat <<'EOF'
feat(common): add FormSection, ErrorText, BudgetCategoryListPicker

FormSection wraps content in a mono UPPERCASE header + Glass card +
optional footer. ErrorText renders a red alert icon + message used by
form fields. BudgetCategoryListPicker is a radio-style list with an
"All expenses ∗" sentinel row, replacing the Picker(.menu) we have in
the Budget Form today.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Rewrite `BudgetFormView`

**Files:**
- Modify: `Features/Sources/Features/BudgetManagement/BudgetFormView.swift`

This task replaces the entire `body` content. Reducer is untouched. After this commit, the screen matches the spec visually.

- [ ] **Step 1: Replace `BudgetFormView.swift` with the new implementation**

Write the file:

```swift
import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct BudgetFormView: View {
    @Bindable var store: StoreOf<BudgetFormFeature>

    public init(store: StoreOf<BudgetFormFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    nameSection
                    amountSection
                    periodSection
                    startDateSection
                    if !store.availableCategories.isEmpty {
                        categorySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .background(Color.Design.background)
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isSaveEnabled)
                }
            }
            .task { await store.send(.task).finish() }
        }
    }

    // MARK: - Save gating

    private var isSaveEnabled: Bool {
        guard !store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let amount = Decimal(string: store.amountText), amount > 0 else {
            return false
        }
        return true
    }

    // MARK: - Sections

    private var nameSection: some View {
        FormSection("common_name") {
            VStack(alignment: .leading, spacing: 0) {
                TextField(
                    String(localized: "budget_form_name_placeholder"),
                    text: Binding(
                        get: { store.name },
                        set: { store.send(.nameChanged($0)) }
                    )
                )
                .font(.system(size: 17))
                .foregroundStyle(Color.Design.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let error = store.nameError {
                    ErrorText(error)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    private var amountSection: some View {
        FormSection("budget_form_amount") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(verbatim: "NT$")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Color.Design.textSecondary)

                    TextField(
                        "0",
                        text: Binding(
                            get: { store.amountText },
                            set: { store.send(.amountChanged($0)) }
                        )
                    )
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color.Design.textPrimary)
                    .keyboardType(.numberPad)

                    Text("/ \(store.period.localizedSuffix)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if let error = store.amountError {
                    ErrorText(error)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                } else if let breakdown = breakdownText {
                    Text(breakdown)
                        .font(.system(size: 12, design: .monospaced))
                        .tracking(-0.1)
                        .foregroundStyle(Color.Design.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    private var breakdownText: String? {
        guard let amount = Decimal(string: store.amountText), amount > 0 else { return nil }
        return amount.perPeriodBreakdown(store.period)
    }

    private var periodSection: some View {
        FormSection("budget_form_period") {
            Picker(
                String(localized: "budget_form_period"),
                selection: Binding(
                    get: { store.period },
                    set: { store.send(.periodChanged($0)) }
                )
            ) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    Text(period.localizedName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var startDateSection: some View {
        FormSection("budget_form_start_date") {
            HStack(spacing: 12) {
                Text("budget_form_start_date")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.Design.textPrimary)
                Spacer(minLength: 0)
                DatePicker(
                    "",
                    selection: Binding(
                        get: { store.startDate },
                        set: { store.send(.startDateChanged($0)) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var categorySection: some View {
        FormSection(
            "budget_form_apply_category",
            footerKey: "budget_form_all_expenses_hint"
        ) {
            BudgetCategoryListPicker(
                categories: store.availableCategories,
                selectedId: store.categoryId,
                onSelect: { newId in
                    store.send(.categoryChanged(newId))
                }
            )
        }
    }
}
```

- [ ] **Step 2: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run all Features tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme FeaturesTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all tests pass. The existing `BudgetFormFeatureTests` should be unaffected because the reducer is unchanged.

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/BudgetManagement/BudgetFormView.swift
git commit -m "$(cat <<'EOF'
feat(budget-form): rewrite view with FormSection cards and breakdown helper

Drops the system Form/Section scaffolding in favor of the design-spec
layout: mono UPPERCASE section headers, Glass-tinted section cards,
a 32pt mono amount field with "/ 月" suffix and live "≈ NT$ X / 天"
breakdown, and a radio-style BudgetCategoryListPicker (replacing the
Picker(.menu)). Reducer state and actions are unchanged.

Save button is gated on non-empty trimmed name AND parseable positive
amount, mirroring the reducer's existing validation rules.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Polish — accessibility identifiers

**Files:**
- Modify: `Features/Sources/Features/BudgetManagement/BudgetFormView.swift`
- Modify: `Features/Sources/Common/Components/BudgetCategoryListPicker.swift`

- [ ] **Step 1: Add accessibility identifiers to the toolbar buttons in `BudgetFormView.swift`**

In `BudgetFormView.body`'s `.toolbar { ... }` block, add identifiers:

Replace the existing:

```swift
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isSaveEnabled)
                }
```

with:

```swift
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                    .accessibilityIdentifier("budget_form_cancel_button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isSaveEnabled)
                    .accessibilityIdentifier("budget_form_save_button")
                }
```

- [ ] **Step 2: Add accessibility identifiers to each picker row in `BudgetCategoryListPicker.swift`**

In `BudgetCategoryListPicker.row(...)`, add `.accessibilityIdentifier` to the `Button`:

Replace the `Button(action: action) { ... } .buttonStyle(.plain)` block with:

```swift
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                    Text(emoji)
                        .font(.system(
                            size: isAll ? 18 : 16,
                            weight: isAll ? .bold : .regular
                        ))
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)

                title
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.Design.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Design.accentOrange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isAll ? "budget_form_category_all" : "budget_form_category_row")
```

- [ ] **Step 3: Verify no hardcoded hex colors leaked into new files**

```bash
grep -rn "#FFFFFF\|#000000" \
    Features/Sources/Features/BudgetManagement/BudgetFormView.swift \
    Features/Sources/Common/Components/FormSection.swift \
    Features/Sources/Common/Components/ErrorText.swift \
    Features/Sources/Common/Components/BudgetCategoryListPicker.swift \
    Features/Sources/Domain/Extensions/Decimal+Budget.swift
```

Expected: empty output. If any match, replace with `Color.Design.*` semantic tokens.

- [ ] **Step 4: Build + run all Features tests**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project NeuLedger.xcodeproj -scheme FeaturesTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED + all tests pass.

- [ ] **Step 5: Manual smoke (record findings — no automated assertion)**

Launch on iPhone 17 Pro simulator:

1. From `BudgetManagementView`, tap `+` → New Budget Form opens.
2. The 5 sections render top-to-bottom: 名稱 / 預算金額 / 週期 / 起始日 / 套用分類.
3. Each section has a mono UPPERCASE header above a Glass card.
4. Amount section: type `8000`, period stays `monthly` → breakdown line shows `≈ NT$ 267 / 天 · 約 NT$ 1,848 / 週`.
5. Switch period to weekly → breakdown updates to per-day only.
6. Category list: first row "全部支出 ∗" is selected by default (checkmark present); tap another row → checkmark moves.
7. Cancel button dismisses; Save button stays disabled until both name and positive amount are filled.
8. Open an existing budget (via row tap in `BudgetManagementView`) → all fields prefilled; title reads "編輯預算"; Save is enabled.

If any step fails visually, fix and re-run.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/BudgetManagement/BudgetFormView.swift \
        Features/Sources/Common/Components/BudgetCategoryListPicker.swift
git commit -m "$(cat <<'EOF'
chore(budget-form): add accessibility identifiers and final color audit

Adds identifiers to toolbar Cancel/Save and to each category picker
row. Confirms no hardcoded hex colors in the new BudgetForm files —
all surfaces go through Color.Design.*. Manual smoke verified the
5 sections + breakdown helper + radio list flow.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**

- Section structure (Name / Amount / Period / StartDate / Category) → Task 2 (entire view) ✅
- FormSection primitive (mono UPPERCASE header + Glass card + footer) → Task 1 ✅
- AmountField with NT$ prefix, 32pt mono, ` / <suffix>` and per-period breakdown → Task 2 (`amountSection`) + Task 0 (`Decimal.perPeriodBreakdown`) ✅
- ErrorText primitive → Task 1 ✅
- BudgetCategoryListPicker with leading "全部支出 ∗" sentinel → Task 1 ✅
- `BudgetPeriod.localizedSuffix` → Task 0 ✅
- 6 new i18n keys → Task 0 Step 1 ✅
- Domain tests for suffix + breakdown → Task 0 ✅
- Accessibility identifiers → Task 3 ✅
- Hardcoded color audit → Task 3 Step 3 ✅
- Manual smoke for both `.add` and `.edit` modes → Task 3 Step 5 ✅
- Reducer unchanged → Tasks 0-3 leave it alone ✅

**Placeholder scan:** No "TBD" / "implement later" / vague-handler patterns. Every step has runnable code or commands.

**Type consistency:**
- `BudgetPeriod.localizedSuffix` (String) used in Task 2 `amountSection` → matches Task 0's definition. ✅
- `Decimal.perPeriodBreakdown(_:)` returns `String?` — Task 2's `breakdownText` computed property uses `if let amount = Decimal(string:), amount > 0 ... amount.perPeriodBreakdown(store.period)`. Signature matches. ✅
- `FormSection.init(_:footerKey:content:)` — Task 1 defines, Task 2 calls `FormSection("common_name") { ... }` and `FormSection("budget_form_apply_category", footerKey: "budget_form_all_expenses_hint") { ... }`. Matches. ✅
- `BudgetCategoryListPicker.init(categories:selectedId:onSelect:)` — Task 1 defines, Task 2 calls with those exact label names. ✅
- `ErrorText.init(_:)` accepts both `LocalizedStringKey` and `String` — Task 2 passes `store.nameError` / `store.amountError` (both `String?`, unwrapped first), routed through the `String` overload. ✅
- `Color.Design.textPrimary` / `.textSecondary` / `.surface` / `.expenseRed` / `.accentOrange` / `.background` — all used in earlier completed tasks (Detail view, AccountChip), confirmed to exist in this codebase. ✅
- `glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(...))` — matches Dashboard / Detail pattern. ✅

No issues found in self-review.

---

## Execution

Plan complete and saved to `docs/superpowers/plans/2026-05-15-budget-form-redesign.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task with two-stage review.
2. **Inline Execution** — Execute tasks in this session with checkpoints.

Which approach?
