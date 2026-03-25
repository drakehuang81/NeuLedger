# Common Layer Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple Common from Domain knowledge, extract repeated UI patterns (IconBadge, IconPickerRow, ColorSwatchPicker) into Common, and consolidate TransactionType display properties.

**Architecture:** Domain gets pure-string display properties (no SwiftUI). Common gets three new generic picker components and a DesignConstants file (no Domain import — Common has zero dependencies). Features/Shared holds the single `TransactionType+UIColor.swift` that maps Domain types to SwiftUI Colors.

**Tech Stack:** Swift Testing (`@Suite`, `@Test`, `#expect`), TCA v1.23.1, SwiftUI, xcodebuild

---

## File Map

**Create:**
- `Features/Sources/Domain/Enums/TransactionType+Display.swift`
- `Features/Sources/Common/DesignSystem/DesignConstants.swift`
- `Features/Sources/Common/Components/IconBadge.swift`
- `Features/Sources/Common/Components/IconPickerRow.swift`
- `Features/Sources/Common/Components/ColorSwatchPicker.swift`
- `Features/Sources/Features/Shared/TransactionType+UIColor.swift`

**Modify:**
- `Features/Tests/DomainTests/Enums/TransactionTypeTests.swift` — add display property tests
- `Features/Tests/CommonTests/CommonTests.swift` — add DesignConstants tests
- `Features/Sources/Common/Components/TransactionRow.swift` — replace `amount: Decimal` with `amountText: String` + `amountColor: Color`
- `Features/Sources/Features/Transactions/TransactionsView.swift` — remove private extension; update TransactionRow call site
- `Features/Sources/Features/Transactions/FilterView.swift` — remove private extension
- `Features/Sources/Features/Transactions/TransactionDetailView.swift` — remove private extensions + formattedTWD + private FlowLayout; update call sites
- `Features/Sources/Features/Dashboard/DashboardScreen.swift` — replace inline switch; update TransactionRow call site
- `Features/Sources/Features/Dashboard/AddTransactionView.swift` — replace inline Text per case with displayName
- `Features/Sources/Features/AccountManagement/AddEditAccountView.swift` — use IconPickerRow + ColorSwatchPicker + DesignConstants
- `Features/Sources/Features/CategoryManagement/AddEditCategoryView.swift` — same
- `Features/Sources/Features/TagManagement/AddEditTagView.swift` — remove hexColor; use ColorSwatchPicker + DesignConstants

---

## Task 1: Add Display Properties to Domain (TDD)

**Files:**
- Create: `Features/Sources/Domain/Enums/TransactionType+Display.swift`
- Modify: `Features/Tests/DomainTests/Enums/TransactionTypeTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `TransactionTypeTests.swift`:

```swift
@Test("TransactionType.displayName returns localized key string")
func testDisplayName() {
    // In test context String(localized:) returns the key — verify non-empty
    #expect(!TransactionType.expense.displayName.isEmpty)
    #expect(!TransactionType.income.displayName.isEmpty)
    #expect(!TransactionType.transfer.displayName.isEmpty)
    // Verify all three are distinct
    let names = TransactionType.allCases.map(\.displayName)
    #expect(Set(names).count == 3)
}

@Test("TransactionType.systemImageName returns SF Symbol names")
func testSystemImageName() {
    #expect(TransactionType.expense.systemImageName == "arrow.up.circle.fill")
    #expect(TransactionType.income.systemImageName == "arrow.down.circle.fill")
    #expect(TransactionType.transfer.systemImageName == "arrow.left.arrow.right.circle.fill")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Domain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/TransactionTypeTests 2>&1 | tail -20
```

Expected: compile error — `displayName` / `systemImageName` not found.

- [ ] **Step 3: Create the implementation**

Create `Features/Sources/Domain/Enums/TransactionType+Display.swift`:

```swift
import Foundation

public extension TransactionType {
    /// Localized display name for UI labels.
    var displayName: String {
        switch self {
        case .expense:  String(localized: "common_expense")
        case .income:   String(localized: "common_income")
        case .transfer: String(localized: "common_transfer")
        }
    }

    /// SF Symbol system image name for this transaction type.
    var systemImageName: String {
        switch self {
        case .expense:  "arrow.up.circle.fill"
        case .income:   "arrow.down.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Domain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/TransactionTypeTests 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Domain/Enums/TransactionType+Display.swift \
        Features/Tests/DomainTests/Enums/TransactionTypeTests.swift && \
git commit -m "feat(domain): add TransactionType displayName and systemImageName"
```

---

## Task 2: Add DesignConstants to Common (TDD)

**Files:**
- Create: `Features/Sources/Common/DesignSystem/DesignConstants.swift`
- Modify: `Features/Tests/CommonTests/CommonTests.swift`

- [ ] **Step 1: Write failing tests**

Replace the placeholder in `CommonTests.swift`:

```swift
import Testing
@testable import Common

@Suite("DesignConstants Tests")
struct DesignConstantsTests {
    @Test("accountIconOptions is non-empty and all SF Symbol names")
    func testAccountIcons() {
        #expect(!DesignConstants.accountIconOptions.isEmpty)
        #expect(DesignConstants.accountIconOptions.contains("creditcard"))
    }

    @Test("categoryIconOptions is non-empty")
    func testCategoryIcons() {
        #expect(!DesignConstants.categoryIconOptions.isEmpty)
        #expect(DesignConstants.categoryIconOptions.contains("fork.knife"))
    }

    @Test("color palettes are non-empty and all hex strings")
    func testColorPalettes() {
        for hex in DesignConstants.accountColorOptions {
            #expect(hex.hasPrefix("#"))
        }
        for hex in DesignConstants.categoryColorOptions {
            #expect(hex.hasPrefix("#"))
        }
        for hex in DesignConstants.tagColorOptions {
            #expect(hex.hasPrefix("#"))
        }
    }

    @Test("tag palette is a superset of category palette")
    func testTagPaletteIsSuperset() {
        let tagSet = Set(DesignConstants.tagColorOptions)
        for hex in DesignConstants.categoryColorOptions {
            #expect(tagSet.contains(hex))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Common \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: compile error — `DesignConstants` not found.

- [ ] **Step 3: Create the implementation**

Create `Features/Sources/Common/DesignSystem/DesignConstants.swift`:

```swift
import Foundation

/// Shared design-system constants: icon lists and color palettes.
/// Features consume these to avoid hardcoding values in individual form views.
public enum DesignConstants {

    // MARK: - Icon Options

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

    // MARK: - Color Palettes (hex strings)

    /// Category and base tag colors.
    public static let categoryColorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#32ADE6", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55"
    ]

    /// Account colors — brand blue and warm yellow replace grey.
    public static let accountColorOptions: [String] = [
        "#3478F6", "#34C759", "#FF9500", "#FF3B30", "#5856D6",
        "#FF2D55", "#AF52DE", "#00C7BE", "#32ADE6", "#FF9F0A"
    ]

    /// Tag colors — superset of categoryColorOptions, adds brand blue and neutral grey.
    public static let tagColorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#3478F6", "#8E8E93"
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Common \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Common/DesignSystem/DesignConstants.swift \
        Features/Tests/CommonTests/CommonTests.swift && \
git commit -m "feat(common): add DesignConstants for icon/color palettes"
```

---

## Task 3: Add Common UI Components (IconBadge, IconPickerRow, ColorSwatchPicker)

These are pure SwiftUI components — no meaningful unit tests. Verified by build.

**Files:**
- Create: `Features/Sources/Common/Components/IconBadge.swift`
- Create: `Features/Sources/Common/Components/IconPickerRow.swift`
- Create: `Features/Sources/Common/Components/ColorSwatchPicker.swift`

- [ ] **Step 1: Create IconBadge**

```swift
import SwiftUI

/// A colored circle containing an SF Symbol.
/// Used for entity previews (account, category) and row icons.
public struct IconBadge: View {
    let systemImage: String
    let color: Color
    let size: CGFloat

    public init(systemImage: String, color: Color, size: CGFloat = 44) {
        self.systemImage = systemImage
        self.color = color
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.Design.textInverse)
                .font(.system(size: size * 0.45, weight: .medium))
        }
    }
}
```

- [ ] **Step 2: Create IconPickerRow**

```swift
import SwiftUI

/// A horizontal scrolling row of SF Symbol icon buttons with selection state.
/// Selected icon shows opaque accent fill with textInverse icon.
public struct IconPickerRow: View {
    let icons: [String]
    let selectedIcon: String
    let accentColor: Color
    let onSelect: (String) -> Void

    public init(
        icons: [String],
        selectedIcon: String,
        accentColor: Color,
        onSelect: @escaping (String) -> Void
    ) {
        self.icons = icons
        self.selectedIcon = selectedIcon
        self.accentColor = accentColor
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(icons, id: \.self) { iconName in
                    iconButton(iconName: iconName)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func iconButton(iconName: String) -> some View {
        let isSelected = selectedIcon == iconName
        return Button {
            onSelect(iconName)
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? accentColor : Color.Design.surfaceSecondary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if isSelected {
                            Circle().strokeBorder(accentColor, lineWidth: 2)
                        }
                    }
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.Design.textInverse : Color.Design.textSecondary)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Create ColorSwatchPicker**

```swift
import SwiftUI

public enum ColorSwatchLayout {
    case horizontalScroll
    case grid(columns: Int)
}

/// A picker showing colored circle swatches with a checkmark on selection.
/// Accepts hex color strings; converts internally using Color(hex:).
public struct ColorSwatchPicker: View {
    let colors: [String]
    let selectedHex: String
    let layout: ColorSwatchLayout
    let onSelect: (String) -> Void

    public init(
        colors: [String],
        selectedHex: String,
        layout: ColorSwatchLayout = .horizontalScroll,
        onSelect: @escaping (String) -> Void
    ) {
        self.colors = colors
        self.selectedHex = selectedHex
        self.layout = layout
        self.onSelect = onSelect
    }

    public var body: some View {
        switch layout {
        case .horizontalScroll:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { hex in colorSwatch(hex: hex) }
                }
                .padding(.vertical, 8)
            }
        case .grid(let columns):
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns),
                spacing: 12
            ) {
                ForEach(colors, id: \.self) { hex in colorSwatch(hex: hex) }
            }
            .padding(.vertical, 4)
        }
    }

    private func colorSwatch(hex: String) -> some View {
        let isSelected = selectedHex == hex
        return Button {
            onSelect(hex)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.Design.textInverse, lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.Design.textInverse)
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .overlay {
            if isSelected {
                Circle()
                    .strokeBorder(Color(hex: hex), lineWidth: 2)
                    .frame(width: 42, height: 42)
            }
        }
    }
}
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Common/Components/IconBadge.swift \
        Features/Sources/Common/Components/IconPickerRow.swift \
        Features/Sources/Common/Components/ColorSwatchPicker.swift && \
git commit -m "feat(common): add IconBadge, IconPickerRow, ColorSwatchPicker components"
```

---

## Task 4: Update TransactionRow API

**Files:**
- Modify: `Features/Sources/Common/Components/TransactionRow.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionsView.swift` (call site)
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (call site)

- [ ] **Step 1: Update TransactionRow (including Preview block)**

Replace the entire `TransactionRow.swift`. Note: the `#Preview` block must also use the new API or the build will fail.

```swift
import SwiftUI

/// A row displaying transaction details.
///
/// The caller (Features layer) is responsible for formatting the amount string
/// and choosing the amount color — this component has no Domain knowledge.
public struct TransactionRow: View {
    let title: String
    let subtitle: String
    let amountText: String
    let amountColor: Color
    let date: String
    let icon: String
    let iconColor: Color

    public init(
        title: String,
        subtitle: String,
        amountText: String,
        amountColor: Color,
        date: String,
        icon: String,
        iconColor: Color = .blue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amountText = amountText
        self.amountColor = amountColor
        self.date = date
        self.icon = icon
        self.iconColor = iconColor
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.Design.surfaceSecondary)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)
                Text(subtitle)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(Font.Design.amount.weight(.semibold))
                    .foregroundStyle(amountColor)
                Text(date)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.Design.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        VStack {
            TransactionRow(
                title: "Lunch",
                subtitle: "Food · Cash",
                amountText: "NT$120",
                amountColor: Color.Design.expenseRed,
                date: "Today 12:30",
                icon: "fork.knife",
                iconColor: .orange
            )
            TransactionRow(
                title: "Salary",
                subtitle: "Work · Bank",
                amountText: "NT$50,000",
                amountColor: Color.Design.incomeGreen,
                date: "Yesterday",
                icon: "briefcase.fill",
                iconColor: .blue
            )
        }
        .padding()
    }
}
```

- [ ] **Step 2: Update TransactionsView — remove private extension and update call site**

In `TransactionsView.swift`:

a) **Delete** the entire `private extension TransactionType` block (lines 211–235: `displayName`, `icon`, `color`). Do this in this task — not deferred to Task 5 — to avoid a `displayName` name-collision between Domain and the private extension.

b) Replace the `transactionRow` helper (lines ~146–167):

```swift
private func transactionRow(_ transaction: Domain.Transaction) -> some View {
    let amountColor: Color = transaction.type == .expense
        ? Color.Design.expenseRed
        : Color.Design.incomeGreen
    return Button {
        store.send(.transactionTapped(transaction))
    } label: {
        TransactionRow(
            title: transaction.note ?? transaction.type.displayName,
            subtitle: transaction.type.displayName,
            amountText: transaction.amount.twdFormatted,
            amountColor: amountColor,
            date: transaction.date.formatted(date: .omitted, time: .shortened),
            icon: transaction.type.systemImageName,
            iconColor: amountColor
        )
    }
    .buttonStyle(.plain)
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
            store.send(.deleteTransaction(transaction.id))
        } label: {
            Label(String(localized: "common_delete"), systemImage: "trash")
        }
    }
}
```

c) Remove the `private func amountValue(for:)` helper — it is no longer needed.

- [ ] **Step 3: Update DashboardScreen call site**

In `DashboardScreen.swift`, replace the `transactionButton(for:)` helper body. Remove the inline switch for subtitle and pass explicit primitives:

```swift
private func transactionButton(for transaction: Domain.Transaction) -> some View {
    let category = transaction.categoryId.flatMap { store.categoryMap[$0] }
    let (icon, iconColor) = resolvedIconAndColor(for: transaction, category: category)
    let amountColor: Color = transaction.type == .expense
        ? Color.Design.expenseRed
        : Color.Design.incomeGreen
    return Button {
        store.send(.transactionTapped(transaction.id))
    } label: {
        TransactionRow(
            title: transaction.note ?? String(localized: "dashboard_transaction_default"),
            subtitle: transaction.type.displayName,
            amountText: transaction.amount.twdFormatted,
            amountColor: amountColor,
            date: transaction.date.formatted(date: .abbreviated, time: .shortened),
            icon: icon,
            iconColor: iconColor
        )
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Common/Components/TransactionRow.swift \
        Features/Sources/Features/Transactions/TransactionsView.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift && \
git commit -m "refactor(common): replace TransactionRow amount:Decimal with amountText+amountColor"
```

---

## Task 5: Add TransactionType+UIColor and Remove Scattered Private Extensions

**Files:**
- Create: `Features/Sources/Features/Shared/TransactionType+UIColor.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionsView.swift`
- Modify: `Features/Sources/Features/Transactions/FilterView.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift`

- [ ] **Step 1: Create the Shared directory and UIColor extension**

Create `Features/Sources/Features/Shared/TransactionType+UIColor.swift`:

```swift
import SwiftUI
import Common
import Domain

public extension TransactionType {
    /// SwiftUI color for this transaction type using the app's design system.
    var uiColor: Color {
        switch self {
        case .expense:  Color.Design.expenseRed
        case .income:   Color.Design.incomeGreen
        case .transfer: Color.Design.textSecondary
        }
    }
}
```

- [ ] **Step 2: Verify TransactionsView (already done in Task 4)**

The `private extension TransactionType` block in `TransactionsView.swift` was deleted in Task 4 Step 2. No further changes needed here. Confirm the file compiles cleanly.

- [ ] **Step 3: Remove private extension from FilterView**

In `FilterView.swift`, delete the `private extension TransactionType { var displayName }` block (lines 148–156). The file's call sites already use `type.displayName` which now resolves from Domain.

- [ ] **Step 4: Clean up TransactionDetailView**

In `TransactionDetailView.swift`:

a) Delete the `private extension TransactionType` block (lines 225–249: `displayName`, `badgeColor`, `amountColor`).

b) Delete the `private extension Decimal { var formattedTWD }` block (lines 251–258).

c) Delete the `private struct FlowLayout: Layout` block (lines ~184–223). The view already imports `Common` which exports `FlowLayout`. **Important:** the existing call site uses `FlowLayout(spacing: 4)` — update it to `FlowLayout(horizontalSpacing: 4, verticalSpacing: 4)` to match Common's two-parameter initializer.

d) Update call sites in the same file:
- `transaction.type.badgeColor` → `transaction.type.uiColor`
- `transaction.type.amountColor` → `transaction.type.uiColor`
- `transaction.amount.formattedTWD` → `transaction.amount.twdFormatted`

> **Note (intentional visual change):** After this substitution, the large 48pt amount text for `.transfer` transactions changes color from `textPrimary` (black/white) to `textSecondary` (grey). This is deliberate per the spec (section 5) to achieve consistency with all other `.transfer` color usages in the app.

- [ ] **Step 5: Verify build**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run Features tests**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Features/Shared/TransactionType+UIColor.swift \
        Features/Sources/Features/Transactions/TransactionsView.swift \
        Features/Sources/Features/Transactions/FilterView.swift \
        Features/Sources/Features/Transactions/TransactionDetailView.swift && \
git commit -m "refactor(features): consolidate TransactionType display/color extensions into Shared"
```

---

## Task 6: Update AddTransactionView and DashboardScreen Inline Switches

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift`
- (DashboardScreen already updated in Task 4)

- [ ] **Step 1: Replace inline type labels in AddTransactionView**

In `AddTransactionView.swift`, the type picker section (lines 63–65) uses inline `Text(String(localized: "common_expense")).tag(...)` per case. Replace with:

```swift
private var typeSection: some View {
    Picker(String(localized: "common_type"), selection: Binding(
        get: { store.type },
        set: { store.send(.typeChanged($0)) }
    )) {
        ForEach(TransactionType.allCases, id: \.self) { type in
            Text(type.displayName).tag(type)
        }
    }
    .pickerStyle(.segmented)
}
```

- [ ] **Step 2: Verify build and run tests**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Features/Dashboard/AddTransactionView.swift && \
git commit -m "refactor(features): replace inline TransactionType strings with displayName"
```

---

## Task 7: Update Form Views (Account, Category, Tag)

**Files:**
- Modify: `Features/Sources/Features/AccountManagement/AddEditAccountView.swift`
- Modify: `Features/Sources/Features/CategoryManagement/AddEditCategoryView.swift`
- Modify: `Features/Sources/Features/TagManagement/AddEditTagView.swift`

- [ ] **Step 1: Update AddEditAccountView**

Replace the `predefinedIcons` and `predefinedColors` static arrays and their inline picker implementations with the new Common components.

Remove:
```swift
private static let predefinedIcons: [String] = [...]
private static let predefinedColors: [String] = [...]
```

Replace the icon Section body:
```swift
Section {
    IconPickerRow(
        icons: DesignConstants.accountIconOptions,
        selectedIcon: store.icon,
        accentColor: Color(hex: store.colorHex)
    ) { iconName in
        store.send(.iconChanged(iconName))
    }
    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
} header: {
    Text("common_icon")
}
```

Replace the color Section body:
```swift
Section {
    ColorSwatchPicker(
        colors: DesignConstants.accountColorOptions,
        selectedHex: store.colorHex
    ) { hex in
        store.send(.colorHexChanged(hex))
    }
    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
} header: {
    Text("common_color")
}
```

Replace the preview Section body (use `IconBadge`):
```swift
Section {
    HStack(spacing: 12) {
        IconBadge(
            systemImage: store.icon,
            color: Color(hex: store.colorHex).opacity(0.15),
            size: 44
        )
        Text(store.name.isEmpty
            ? String(localized: "account_form_name_placeholder")
            : store.name)
            .font(Font.Design.body)
            .foregroundStyle(store.name.isEmpty
                ? Color.Design.textTertiary
                : Color.Design.textPrimary)
    }
    .padding(.vertical, 4)
} header: {
    Text("common_preview")
}
```

Note: `IconBadge` uses `textInverse` for the icon color. For the account preview (which previously used the custom color, not textInverse), pass a lighter background and override if needed. If the preview style must match the original exactly, keep the preview section as inline code — the spec's goal is the picker section, not mandating IconBadge for the preview.

- [ ] **Step 2: Update AddEditCategoryView**

Remove `availableIcons` and `availableColors` arrays and the `iconButton`/`colorButton` private methods.

Replace the icon Section:
```swift
Section {
    IconPickerRow(
        icons: DesignConstants.categoryIconOptions,
        selectedIcon: store.icon,
        accentColor: Color(hex: store.colorHex)
    ) { iconName in
        store.send(.iconChanged(iconName))
    }
    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
} header: {
    Text("common_icon")
}
```

Replace the color Section:
```swift
Section {
    ColorSwatchPicker(
        colors: DesignConstants.categoryColorOptions,
        selectedHex: store.colorHex
    ) { hex in
        store.send(.colorHexChanged(hex))
    }
    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
} header: {
    Text("common_color")
}
```

- [ ] **Step 3: Update AddEditTagView**

Remove the `hexColor(_ hex:)` function at the top of the file (it duplicates `Color(hex:)` from Common).

Remove the `colorOptions` array.

Replace the color picker grid Section:
```swift
Section {
    ColorSwatchPicker(
        colors: DesignConstants.tagColorOptions,
        selectedHex: store.colorHex,
        layout: .grid(columns: 6)
    ) { hex in
        store.send(.colorHexChanged(hex))
    }
} header: {
    Text("common_color")
}
```

- [ ] **Step 4: Verify build**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run form feature tests**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AccountManagementFeatureTests \
  -only-testing:FeaturesTests/CategoryManagementFeatureTests \
  -only-testing:FeaturesTests/TagManagementFeatureTests 2>&1 | tail -30
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
git add Features/Sources/Features/AccountManagement/AddEditAccountView.swift \
        Features/Sources/Features/CategoryManagement/AddEditCategoryView.swift \
        Features/Sources/Features/TagManagement/AddEditTagView.swift && \
git commit -m "refactor(features): use IconPickerRow, ColorSwatchPicker, DesignConstants in form views"
```

---

## Task 8: Final Full Test Run

- [ ] **Step 1: Run all schemes**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(PASSED|FAILED|error:)"
```

Expected: All suites PASSED, no errors.

- [ ] **Step 2: Run Domain tests**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Domain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(PASSED|FAILED|error:)"
```

Expected: All suites PASSED.

- [ ] **Step 3: Run Common tests**

```bash
cd /Users/drakehuang/SideProject/iOSProject/NeuLedger && \
xcodebuild test -project NeuLedger.xcodeproj -scheme Common \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(PASSED|FAILED|error:)"
```

Expected: All suites PASSED.
