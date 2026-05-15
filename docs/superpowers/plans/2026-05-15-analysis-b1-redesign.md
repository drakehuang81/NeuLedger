# Analysis (Analytics) B1 Warm Glass Redesign — Implementation Plan

**Goal:** Re-implement `AnalysisView` to match the **V3 Data-rich** variant of `design/source/analytics.jsx` + `design/screens/04-Analytics.html` (`AnalyticsV3`, lines 1948–2178), wrapped in the B1 Warm Glass design language already used by Dashboard / Add Transaction / Settings / Budget Form.

**Design reference:**
- Source: `design/source/analytics.jsx` (primitives only)
- Full variant layout: `design/screens/04-Analytics.html` → `function AnalyticsV3({ dark = false })` at lines 1948–2178
- Variant chosen: **V3 Data-rich** (matches current feature set: pie/donut, daily bars, trend, budgets, AI insight)

**State / Reducer:** **No reducer/state changes.** All `AnalysisFeature.State` and `Action` cases stay as-is — this is a pure View refactor. The new view consumes the same `store.summary` / `categoryProportions` / `dailyTrends` / `budgetMetrics` / `insight` / `aiAssistant`.

---

## Module Boundary (IMPORTANT — Target Membership)

All files live in the local SPM package `Features` (under `Features/Sources/`). The new files go into:

- `Features/Sources/Features/Analysis/Sections/` (new folder — same pattern as `Dashboard/Sections/`)
- `Features/Sources/Features/Analysis/Components/` (existing — refactor in place)

The view imports `Common` / `Domain` / `ComposableArchitecture` only. **Do NOT import `SwiftData`** directly.

`WarmGradientBackground`, `GlassContainer`, `MetricBadge`, `MiniSparkline`, `StatPill`, `AvatarBadge`, `SkeletonModifier`, `SectionFailureView`, `EmptyStateView` are all already in `Common/Components/` — reuse them; do NOT recreate them.

---

## Files Allowed to Modify (subagent boundary)

The executor agent is **only allowed** to read/write these paths. Anything outside this list → report `BLOCKED` instead of editing.

### Modify
- `Features/Sources/Features/Analysis/AnalysisView.swift` (slim composition root)
- `Features/Sources/Features/Analysis/Components/SummaryCardView.swift` (delete after migration to KPIStrip, or leave as-is unused if simpler)
- `Features/Sources/Features/Analysis/Components/CategoryPieChartView.swift` (refactor to donut + expandable rows OR replaced by new section file)
- `Features/Sources/Features/Analysis/Components/TrendBarChartView.swift` (refactor to DailyBars + monthly trend OR replaced by new section files)
- `Features/Localizations/Localizable.xcstrings` (add any new localization keys for new copy — DO NOT remove existing keys)

### Create
- `Features/Sources/Features/Analysis/Sections/AnalysisTopBar.swift`
- `Features/Sources/Features/Analysis/Sections/KPIStrip.swift`
- `Features/Sources/Features/Analysis/Sections/DailyBarsCard.swift`
- `Features/Sources/Features/Analysis/Sections/MonthlyTrendCard.swift`
- `Features/Sources/Features/Analysis/Sections/CategoryDonutCard.swift`
- `Features/Sources/Features/Analysis/Sections/AIDock.swift`

### Forbidden (do NOT touch)
- `AnalysisFeature.swift` — reducer/state is locked
- `AIAssistantFeature.swift` / `AIAssistantCardView.swift` — embed as-is via `store.scope`
- Any file outside `Features/Sources/Features/Analysis/` and the `.xcstrings`

---

## Section-by-Section Spec (V3 mapping)

### 1. `AnalysisTopBar`
- Replace stock `.navigationTitle("…")` + `.navigationBarTitleDisplayMode(.large)`. Set `.navigationBarHidden(true)` on the NavigationStack root, render top bar inside the ScrollView at the top.
- Left side: small square chevron-back affordance (28×28, rounded 8, subtle bg `Color.black.opacity(0.05)`) — **purely decorative** (the screen is a root tab; if there's no back action, just show the icon as a static badge OR omit it for the root use-case and replace with a small icon-only chip showing `chart.bar.xaxis` / `sparkles`).
- Center-left: 2-line stack
  - Eyebrow: `fontMono`, 10pt, uppercase, `letterSpacing: 1.2`, secondary color — shows the period label (e.g. "APR 2026" for `.month`, "WEEK 19" for `.week`, "2026" for `.year`). Use `period.eyebrowLabel(for: Date.now)` helper inside the view file.
  - Title: `fontDisplay` (Bricolage Grotesque), 18pt, weight 600, primary text, "Analytics" (localized `analysis_title`).
- Right side: custom segmented control for period (月/週/日 → maps to `.month` / `.week` / `.year`). Implement as an HStack of pill buttons, NOT `.pickerStyle(.segmented)` (that's the old look). Sends `.periodChanged(_)`.
- Account filter Menu stays — move it to the trailing edge of the top bar (or keep as small icon chip next to segmented).

### 2. `KPIStrip` (4 cards in a 2×2 or 1×4 grid)
- Replaces the existing `SummaryCardView` content for the top of the screen.
- 4 stat cards using `Card` style: white bg (light) / `.glassEffect()` look (frosted), rounded 14, padding 10pt.
- Each card: eyebrow (`fontMono`, 8pt, uppercase, letterSpacing 0.8, secondary) + value (`fontMono`, 14pt, weight 500, with "NT$" 8pt prefix for currency values) + delta caption (`fontMono`, 9pt, color-coded).
- Cards:
  - **支出** (`analysis_kpi_expense`) — value: `summary.totalExpense.twdFormatted`, delta: month-over-month diff if available (skip delta until we have it — show empty if `nil`)
  - **收入** (`analysis_kpi_income`) — value: `summary.totalIncome.twdFormatted`
  - **結餘** (`analysis_kpi_net`) — value: `(income − expense).twdFormatted`, color: warm accent if positive
  - **存錢率** (`analysis_kpi_savings_rate`) — value: `(net / totalIncome * 100)%` rounded; if income is 0, show "—".
- **Do not invent fake deltas.** If we don't have prior-period data in state, **omit the delta caption** entirely for that card. (Future task can add prior-period.)

### 3. `DailyBarsCard`
- Glass card. Header: eyebrow `近 7 天支出` (mono 9pt uppercase) + summed total ("NT$" prefix) + ` · avg NT$ X/日`. Right side optional StatPill (skip if we don't have the data — e.g. "週六最高" requires day-of-week aggregation we may not have).
- 7-day bars: take the last 7 distinct dates from `store.dailyTrends`. If fewer than 7 days available, pad with zero-bars at the start. Today's bar uses accent color; others use accent at 33% alpha.
- X labels: weekday short symbols from `Calendar.current.shortWeekdaySymbols` aligned to each date.
- Reuse `MiniSparkline` if it has a bar variant; otherwise inline the bars as `GeometryReader`+`HStack`.

### 4. `MonthlyTrendCard`
- Glass card. Header: eyebrow `6 月趨勢` + mean line "平均 NT$ X/月". Right side: optional delta pill ("本月 −X%" or "+X%") vs 6-month average — only show if computable.
- Bars: 6 short bars (one per month) using `MiniSparkline`-style. Latest month = accent color; others = neutral.
- **Data source:** the current reducer ONLY loads transactions for the selected `period`. To compute a true 6-month trend we'd need to fetch separately. **For this iteration: gracefully hide this card entirely if we don't have enough data**, OR derive a simple proxy from `dailyTrends` grouped by month (but with `.week`/`.month` periods the data window is too short — so hiding is the safer choice). Wrap the card in `if hasMonthlyTrendData { … }` and treat `hasMonthlyTrendData` as `false` for now. Leave a `// TODO:` comment with the reason.

### 5. `CategoryDonutCard`
- Glass card. Header: eyebrow `類別細項` + right-aligned hint `點選展開 ↓` (in accent color).
- Donut: 108pt diameter, 14pt stroke. Segments = `store.categoryProportions` colored by Category.color (already on Domain.Category). Center: `TOTAL` eyebrow + total expense value.
- Right of donut: top-3 category list (color dot + name + percent).
- "+ N 其他類別" caption if there are more than 3.
- Expandable list below: every category row shows IconBadge (Category.icon) + name + amount + horizontal progress bar + percent + delta vs prior period (if we have it; otherwise omit).
- Tap row → expand a sub-panel that reuses the existing drill-down sheet trigger (`store.send(.categoryTapped(proportion))`). **Keep the drill-down sheet route as-is** — the inline expansion in the design is a "preview"; for now, simply make the row tap call the existing action. (Inline accordion of subcategories is a future task.)

### 6. `AIDock` (collapsed AI insight)
- Replaces today's `InsightCard` rendering and lives below the category card.
- Closed: pill row — `sparkles` icon (accent) + line "想知道為什麼…?" placeholder (use `insight.title` when available; fallback to localized prompt) + chevron-down on the right. Tap to expand.
- Open: same header + body text rendered from `insight.description`. Tap header again to collapse.
- If `store.insight == nil`, render nothing.
- The `AIAssistantCardView` (separate feature, not the same as `InsightDetail`) **stays as-is** at the bottom and is rendered only when `store.aiAssistant.isAvailable`. Do not merge the two.

### 7. Budget gauges
- Keep `BudgetGauge` block as-is (already glass-wrapped). Move it between `CategoryDonutCard` and `AIDock`. Header label uses the existing `analysis_budget_progress` key.

### 8. Loading & Empty states
- Replace `ProgressView()` block with skeleton placeholders via `SkeletonModifier` on each section card while `store.isLoading`.
- `EmptyStateView` for `!store.hasData` is kept; just sit it on top of `WarmGradientBackground`.

---

## Implementation Steps

> Use the **superpowers:subagent-driven-development** discipline within the executor. **Edit only the files listed above. Anything outside → STOP and report.**

### Step 1 — Create new section files (scaffolding)
Create the 6 new `Sections/*.swift` files with the View shells (parameters + body skeleton). Each should compile in isolation against the existing `AnalysisFeature.State`.

### Step 2 — Migrate KPIStrip
Pull data from `store.summary`. Wire up 4 cards. Run `swift build` after.

### Step 3 — Migrate top bar + segmented + account menu
Build `AnalysisTopBar`. Remove the stock `.navigationTitle` / `Picker` from `AnalysisView`.

### Step 4 — Migrate donut + category list
Build `CategoryDonutCard` consuming `categoryProportions`. Tap → reuse `.categoryTapped(_)`.

### Step 5 — Migrate daily bars
Build `DailyBarsCard` from `dailyTrends`. Last 7 days only; pad missing days.

### Step 6 — AI dock + budgets + cleanup
Build `AIDock`. Move BudgetGauge block. Delete now-unused `SummaryCardView` / `CategoryPieChartView` / `TrendBarChartView` if no longer referenced (verify with LSP `find_references` first).

### Step 7 — Backgrounds and final polish
Wrap the whole `body` in a ZStack with `WarmGradientBackground(variant: .top)`. Adjust spacing/padding to match V3 (14pt horizontal, 16pt between cards, 100pt bottom padding for floating tab bar).

### Step 8 — Localization keys
Add to `Localizable.xcstrings`:
- `analysis_kpi_expense` → `支出` / `Expense`
- `analysis_kpi_income` → `收入` / `Income`
- `analysis_kpi_net` → `結餘` / `Net`
- `analysis_kpi_savings_rate` → `存錢率` / `Savings rate`
- `analysis_kpi_savings_unavailable` → `—`
- `analysis_daily_eyebrow` → `近 7 天支出` / `Last 7 days`
- `analysis_daily_avg_format` → `avg NT$%1$@/日` / `avg NT$%1$@/day`
- `analysis_donut_eyebrow` → `類別細項` / `Categories`
- `analysis_donut_tap_hint` → `點選展開 ↓` / `Tap to expand ↓`
- `analysis_donut_total` → `TOTAL`
- `analysis_donut_more_format` → `+ %1$d 其他類別` / `+ %1$d more`
- `analysis_ai_dock_prompt` → `想知道為什麼?` / `Want to know why?`

Keep keys consistent with the existing `analysis_*` namespace.

---

## Verification

After all steps complete:

1. **Build (no warnings/errors):**
   ```bash
   xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```

2. **Run AnalysisFeature tests in isolation:**
   ```bash
   xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing:FeaturesTests/AnalysisFeatureTests
   ```

3. **Run the FULL Features test scheme** (per user-level rule — `-only-testing:` is not sufficient):
   ```bash
   xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   ```

4. **Visual check** — at minimum confirm no missing-asset warnings (`xcassets` lookup failures) in build log. SwiftUI Preview blocks must compile.

**Done criteria:** All three xcodebuild commands exit code 0. No new test failures. Reducer + state still match the original tests untouched.

---

## Notes for the executor

- This is a **View-only refactor**. If a step would require changing `AnalysisFeature` reducer/state, **STOP and report** — do NOT modify the reducer.
- If `MiniSparkline` does not support the variant you need (bar with today-accent), inline a tiny bar view in the same Sections file. Do NOT modify `Common/Components/MiniSparkline.swift`.
- For colors / fonts: use `Color.Design.*` and `Font.Design.*` (already established in DesignSystem). Do NOT hardcode hex strings outside of those API surfaces.
- Use `String(localized:)` for all visible copy — no raw strings.
