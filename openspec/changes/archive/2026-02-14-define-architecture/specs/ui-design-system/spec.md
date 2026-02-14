# Spec: NeuLedger UI/UX Design System

## ADDED Requirements

---

### Requirement: Platform & Design Philosophy
- **Minimum Deployment Target**: iOS 26.0 (no backward-compatibility fallbacks needed).
- **Design Language**: Native iOS — leverage system components, Liquid Glass, SF Symbols, and system colors. Avoid custom chrome where platform components exist.
- **Principle**: "If SwiftUI provides it, use it." Custom UI only when no native equivalent exists.

---

### Requirement: Design Tool — Pencil
All screen designs are created and maintained using the **Pencil** tool, producing `.pen` design files.

---

### Requirement: Color System
Prefer **system semantic colors** over hardcoded hex values. Custom brand colors are defined in Asset Catalog with Light/Dark variants.

#### Scenario: System Colors (Primary Palette)
- **WHEN** styling UI elements
- **THEN** prefer SwiftUI semantic colors:

| Usage | Color | Notes |
|-------|-------|-------|
| Primary actions, tint | `.tint` / `.accentColor` | Set app-wide accent in Asset Catalog |
| Primary text | `.primary` | Adapts to Light/Dark automatically |
| Secondary text | `.secondary` | System gray, adapts automatically |
| Background (screen) | `Color(.systemBackground)` | System white/black |
| Background (grouped) | `Color(.systemGroupedBackground)` | For `List` / `Form` backgrounds |
| Card surface | `Color(.secondarySystemGroupedBackground)` | Elevated cards |
| Separator | `Color(.separator)` | Thin divider lines |

#### Scenario: Brand & Semantic Colors (Asset Catalog)
- **WHEN** the design system is established
- **THEN** define these custom colors in `Assets.xcassets`:

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `accentColor` | #007AFF (System Blue) | #0A84FF | App-wide accent / tint |
| `incomeGreen` | #34C759 | #30D158 | Income amounts, positive deltas |
| `expenseRed` | #FF3B30 | #FF453A | Expense amounts, negative deltas |
| `warningAmber` | #FF9500 | #FF9F0A | Budget warnings |

#### Scenario: Category Colors
- **WHEN** displaying category chips or charts
- **THEN** use a predefined palette of **12+ colors** from iOS system colors (`.blue`, `.purple`, `.orange`, `.pink`, `.mint`, `.teal`, `.cyan`, `.indigo`, `.brown`, `.red`, `.green`, `.yellow`) for chart differentiation.

---

### Requirement: Typography
Use **system text styles** (`Font.TextStyle`) exclusively — no hardcoded point sizes. This ensures Dynamic Type support by default.

| Style | SwiftUI Font | Usage |
|-------|-------------|-------|
| Large Title | `.largeTitle` | Screen headings |
| Title 2 | `.title2` | Section headings |
| Headline | `.headline` | Card titles, labels |
| Body | `.body` | General content |
| Callout | `.callout` | Supporting text |
| Subheadline | `.subheadline` | List subtitles |
| Caption | `.caption` | Timestamps, metadata |
| Amount (custom) | `.system(.title, design: .rounded, weight: .bold).monospacedDigit()` | Monetary values — monospaced digits |

---

### Requirement: Liquid Glass
Since the app targets **iOS 26+ only**, Liquid Glass is the default surface treatment for elevated UI elements. No `#available` checks or fallbacks needed.

#### Scenario: Glass Surfaces
- **WHEN** rendering cards, action bars, or floating elements
- **THEN** use `.glassEffect()` instead of custom backgrounds/materials:
  - **Balance Card**: `.glassEffect(.regular, in: .rect(cornerRadius: 20))`
  - **AI Insight Card**: `.glassEffect(.regular, in: .rect(cornerRadius: 16))`
  - **Quick Action Buttons**: `.glassEffect(.regular.interactive(), in: .capsule)` inside a `GlassEffectContainer`

#### Scenario: Glass Buttons
- **WHEN** rendering actionable buttons
- **THEN** use `.buttonStyle(.glass)` for standard actions, `.buttonStyle(.glassProminent)` for primary CTAs.

#### Scenario: Glass Morphing
- **WHEN** animated transitions change the view hierarchy (e.g., toggling quick actions, tab switches)
- **THEN** use `@Namespace` + `.glassEffectID(_:in:)` for smooth morphing transitions.

#### Scenario: Glass Containers
- **WHEN** multiple glass elements appear in close proximity
- **THEN** wrap them in `GlassEffectContainer(spacing:)` for optimized rendering and natural blending.

---

### Requirement: Native Components — SwiftUI First

#### Scenario: Navigation & Tabs
- **WHEN** building the app shell
- **THEN** use:
  - `TabView` with `.tabViewStyle(.tabBarOnly)` for bottom tabs (Dashboard, Transactions, Analysis, Settings).
  - `NavigationStack(path:)` for push navigation within each tab.
  - `.sheet(item:)` for modal presentation (Add Transaction, Edit screens).
  - Sheet owns its own dismiss/save actions via `@Environment(\.dismiss)`.

#### Scenario: Lists & Data Display
- **WHEN** displaying transaction lists, settings, or grouped data
- **THEN** use:
  - `List` with `Section` headers for grouped transactions (by date).
  - `.swipeActions()` for edit/delete gestures.
  - `.searchable(text:placement:)` for search functionality.
  - `.refreshable { }` for pull-to-refresh.

#### Scenario: Forms & Settings
- **WHEN** building settings or data-entry screens
- **THEN** use:
  - `Form` with `Section` for grouped settings.
  - `Picker`, `Toggle`, `Stepper` — native controls only.
  - `LabeledContent` for display-only rows.

#### Scenario: SF Symbols
- **WHEN** displaying icons throughout the app
- **THEN** use SF Symbols exclusively via `Image(systemName:)`:
  - `.symbolRenderingMode(.hierarchical)` for multi-layered icons.
  - `.symbolEffect(.bounce)` for interactive feedback.
  - Category icons: map each category to an SF Symbol name.

---

### Requirement: Screen Designs

#### Scenario: 1. Onboarding Flow (First Launch)
- **WHEN** the app is launched for the first time
- **THEN** display a 3-step onboarding using `TabView` with `.tabViewStyle(.page)`:
    1. **Welcome**: App icon + title, value proposition ("AI 智慧記帳"). SF Symbol illustration.
    2. **Account Setup**: Prompt user to create their first account (default: "現金", currency: TWD). Use `Form` for input.
    3. **Ready**: Confirmation with `.buttonStyle(.glassProminent)` "開始使用" CTA.
- **AND** onboarding should be skippable and never shown again after completion.
- **STYLE**: Clean, minimal — rely on SF Symbols and system typography. No custom illustrations.

#### Scenario: 2. Dashboard Screen (Home Tab)
- **WHEN** the app opens (post-onboarding)
- **THEN** display the Dashboard as a `ScrollView` with:
    - **Balance Card**: Total balance, `.glassEffect(.regular, in: .rect(cornerRadius: 20))`, amount in monospaced digits.
    - **Quick Actions**: `GlassEffectContainer` with 3 interactive glass capsules — "支出", "收入", "轉帳".
    - **Account Cards**: Horizontally scrollable `ScrollView(.horizontal)` with glass-styled cards showing account name, SF Symbol icon, and balance.
    - **Recent Transactions**: `List` section showing latest 5-10 transactions. Each row: SF Symbol category icon, note, color-coded amount, relative date.
    - **AI Insight Card** (conditional): Glass card with `sparkles` SF Symbol + AI-generated insight text. Dismissable.

#### Scenario: 3. Add Transaction Screen (Modal Sheet)
- **WHEN** tapping "支出" / "收入" quick action
- **THEN** present via `.sheet(item:)` with `NavigationStack`:
    - **Amount Input**: Large `.title` font, monospaced digits, centered. Custom number pad or system keyboard.
    - **Note Field**: `TextField` with AI auto-suggestion sparkle indicator.
    - **Category Picker**: `LazyVGrid` of SF Symbol icons. AI-suggested category highlighted with `.glassEffect(.prominent.interactive())`.
    - **Account Selector**: `Picker` with `.pickerStyle(.menu)` or horizontal glass pills.
    - **Date Picker**: `DatePicker` — system UI, defaults to today.
    - **Tag Selector**: Optional — pill-shaped chips with autocomplete.
    - **Save Button**: `.buttonStyle(.glassProminent)` in `.toolbar(.confirmationAction)`.
- **AND** sheet owns its actions: Cancel in `.toolbar(.cancellationAction)`, Save in `.toolbar(.confirmationAction)`.

#### Scenario: 4. Transaction List Screen (Transactions Tab)
- **WHEN** navigating to the Transactions tab
- **THEN** display `NavigationStack` with `List`:
    - `.searchable(text:placement:prompt:)` for text search.
    - Filter chips below search — horizontal `ScrollView` with glass capsule chips (Category, Account, Date Range, Tags).
    - `Section` per date group ("Today", "Yesterday", formatted dates).
    - Each `TransactionRow`: SF Symbol icon, note, amount (color-coded), optional tag badges.
    - `.swipeActions(edge: .trailing)` for delete, `.swipeActions(edge: .leading)` for edit.

#### Scenario: 5. Transaction Detail Screen (Push)
- **WHEN** tapping a transaction row
- **THEN** push via `NavigationStack` to a detail view:
    - `Form` or grouped layout showing: amount, date, category, account, note, tags.
    - `.toolbar` with Edit button (re-presents Add Transaction sheet in edit mode).
    - Delete button (with `.confirmationDialog`).
    - "AI 建議" badge if the transaction was AI-categorized.

#### Scenario: 6. Analysis Screen (Analysis Tab)
- **WHEN** navigating to the Analysis tab
- **THEN** display `ScrollView` with:
    - **Period Selector**: `Picker(.segmented)` — 週 / 月 / 年 / 自訂.
    - **Summary Card**: Glass card with income / expense / net. Monospaced amount display.
    - **Pie Chart**: `Chart` (Swift Charts) — spending breakdown by category. Interactive tap to select slice.
    - **Bar Chart**: `Chart` — daily/weekly spending trend.
    - **Budget Progress**: Native `Gauge` or `ProgressView` for each budget.
    - **AI Insights**: Glass card with `sparkles` icon + natural language spending summary.
    - **Top Categories**: `List` with ranked spending categories.

#### Scenario: 7. Settings Screen (Settings Tab)
- **WHEN** navigating to Settings
- **THEN** display `NavigationStack` with `Form`:
    - **Section "帳戶"**: Manage accounts (add, edit, archive). `NavigationLink` to sub-lists.
    - **Section "分類"**: Manage categories (add, edit, reorder). Use `.onMove` for reordering.
    - **Section "預算"**: Manage budgets.
    - **Section "標籤"**: Manage tags.
    - **Section "偏好設定"**:
        - Default account — `Picker`
        - Language (zh-Hant / en) — `Picker`
    - **Section "AI 設定"**:
        - Auto-categorization — `Toggle`
        - AI insights — `Toggle`
    - **Section "資料"**:
        - Export (CSV / JSON) — `Button`
        - Backup & Restore — `Button`
    - **Section "關於"**: Version (`LabeledContent`), licenses, privacy.

---

### Requirement: Reusable UI Components
Focus on components that **don't exist natively**. Use native SwiftUI for everything else.

| Component | Description | Implementation |
|-----------|-------------|----------------|
| `TransactionRow` | Category SF Symbol, note, color-coded amount, relative date, tag badges | Custom `View` — used in `List` rows |
| `AccountCard` | Account SF Symbol, name, balance, glass surface | Custom `View` with `.glassEffect()` |
| `CategoryChip` | SF Symbol + label, selectable glass states | `.glassEffect(.regular.interactive())` vs `.glassEffect(.prominent.interactive())` |
| `TagPill` | Small capsule with tag name, removable (x button) | Custom `View` with `.glassEffect(in: .capsule)` |
| `BalanceDisplay` | Monospaced large amount with currency symbol, color-coded | Custom `View` — `.monospacedDigit()` |
| `InsightCard` | `sparkles` SF Symbol, AI text, glass surface, dismissable | Custom `View` with `.glassEffect()` |
| `BudgetGauge` | Category name, progress indicator, spent/total text | Uses native `Gauge` or `ProgressView` |

**Removed from previous spec** (replaced by native components):
- ~~`PrimaryButton`~~ → `.buttonStyle(.glassProminent)`
- ~~`SectionHeader`~~ → `Section("Title") { }` in `List` / `Form`
- ~~`AmountDisplay`~~ → Inline styled `Text` with `.monospacedDigit()`

---

### Requirement: Dark Mode & Dynamic Type
- **WHEN** system appearance changes
- **THEN** all colors adapt automatically via system semantic colors and Asset Catalog color sets.
- **AND** all text scales with Dynamic Type automatically (using `Font.TextStyle`, never hardcoded sizes).
- **AND** all interactive elements have minimum 44pt touch targets.
- **AND** Liquid Glass surfaces adapt automatically to Light/Dark mode.

---

### Requirement: Animations & Micro-interactions
- **WHEN** adding a transaction successfully
- **THEN** show a brief `.symbolEffect(.bounce)` on the save confirmation icon.
- **WHEN** balance changes
- **THEN** animate with `.contentTransition(.numericText())` for smooth number transitions.
- **WHEN** switching tabs or expanding sections
- **THEN** use `.animation(.smooth, value:)` — the iOS 26 default smooth spring.
- **WHEN** quick action buttons appear/morph
- **THEN** use `GlassEffectContainer` + `@Namespace` + `.glassEffectID` for Liquid Glass morphing transitions.
- **WHEN** charts update data
- **THEN** use Swift Charts built-in animations.
