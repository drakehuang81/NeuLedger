# Apple Watch Phase 3 — Today Expense Complication

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a watchOS widget (Complication) — `TodayExpenseComplication` — that surfaces the current day's total expense in four widget families. Push-driven refresh: the Watch app's `WatchSessionGateway` calls `WidgetCenter.reloadAllTimelines()` whenever a fresh `WatchContextSnapshot` arrives from the iPhone.

**Architecture:**
- New Xcode target `NeuLedgerWatchComplication` (Widget Extension on watchOS), scaffold added in `docs/superpowers/guides/2026-05-27-apple-watch-phase3-complication-setup.md` before this plan runs.
- The Complication reads `WatchContextSnapshot` from `WatchCacheStore` (shared via `group.com.drake.NeuLedger` App Group).
- `TimelineProvider` returns one entry (the current snapshot). Timeline policy `.never` — refresh comes from explicit `WidgetCenter.reloadAllTimelines()` calls, not Apple's scheduling.
- Four families:
  - `.accessoryCircular` — small "NT$ X" badge
  - `.accessoryCorner` — corner arc with monthly budget progress (when present) + amount
  - `.accessoryRectangular` — header label + big amount + "X 筆" subtitle
  - `.accessoryInline` — text-line "今日 NT$ X"

**Tech Stack:** Swift 6, WidgetKit, SwiftUI, Swift Testing.

**Reference spec:** `docs/superpowers/specs/2026-05-27-apple-watch-design.md` (§4 Complication)

**Pre-flight requirement:** the `NeuLedgerWatchComplication` Xcode target must already exist on the branch (committed by the user per the setup guide).

---

## File Structure

### New files

```
NeuLedgerWatchComplication/
└── TodayExpenseComplication.swift          ← Task 1+2+3+4 (single file, multiple views)

NeuLedgerWatchTests/
└── ComplicationEntryTests.swift            ← Task 1 (small, pure-data tests)
```

### Modified files

```
Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift   ← Task 4 (uncomment reload)
```

### Untouched

- Existing Xcode target scaffold (already shipped by setup guide)
- All Phase 1/2/4 code

---

## Task 1: Complication entry + `TimelineProvider`

**Files:**
- Create: `NeuLedgerWatchComplication/TodayExpenseComplication.swift` (first iteration — entry + provider only)
- Create: `NeuLedgerWatchTests/ComplicationEntryTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
import Domain
@testable import WatchFeatures
// Note: Complication file is in the widget extension target, not WatchFeatures.
// We test the entry type by exposing the formatting helper publicly in WatchFeatures.

@Suite("ComplicationEntry Tests")
struct ComplicationEntryTests {

    @Test("Display amount formats Decimal as integer with no decimals")
    func displayAmountInteger() {
        let entry = ComplicationEntry(
            date: Date(),
            todayTotal: 480,
            todayCount: 2,
            monthBudgetProgress: nil
        )
        #expect(entry.displayAmount == "480")
    }

    @Test("Display amount uses thousand separators")
    func displayAmountThousandSeparator() {
        let entry = ComplicationEntry(
            date: Date(),
            todayTotal: 12_500,
            todayCount: 3,
            monthBudgetProgress: nil
        )
        #expect(entry.displayAmount == "12,500")
    }

    @Test("placeholder() returns dash-display safe defaults")
    func placeholderIsDashSafe() {
        let entry = ComplicationEntry.placeholder
        #expect(entry.todayTotal == 0)
        #expect(entry.todayCount == 0)
        #expect(entry.monthBudgetProgress == nil)
    }
}
```

Place `ComplicationEntry` in `WatchFeatures` (not the widget target) so it's testable AND importable by both the Watch app and the widget extension. The widget extension code in `TodayExpenseComplication.swift` will `import WatchFeatures` and use it.

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/ComplicationEntryTests
```
Expected: FAIL — "cannot find 'ComplicationEntry' in scope".

- [ ] **Step 3: Create `ComplicationEntry` in WatchFeatures**

Create `Features/Sources/WatchFeatures/Complication/ComplicationEntry.swift`:

```swift
import Foundation
import Domain
#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(WidgetKit)
/// `TimelineEntry` carrying just the data the today-total Complication
/// needs. Built from `WatchContextSnapshot` (or `.placeholder` when the
/// snapshot is missing).
public struct ComplicationEntry: TimelineEntry, Equatable, Sendable {
    public let date: Date
    public let todayTotal: Decimal
    public let todayCount: Int
    public let monthBudgetProgress: Double?

    public init(
        date: Date,
        todayTotal: Decimal,
        todayCount: Int,
        monthBudgetProgress: Double?
    ) {
        self.date = date
        self.todayTotal = todayTotal
        self.todayCount = todayCount
        self.monthBudgetProgress = monthBudgetProgress
    }

    public static let placeholder = ComplicationEntry(
        date: Date(),
        todayTotal: 0,
        todayCount: 0,
        monthBudgetProgress: nil
    )

    public static func from(snapshot: WatchContextSnapshot, now: Date = Date()) -> ComplicationEntry {
        ComplicationEntry(
            date: now,
            todayTotal: snapshot.todayTotal,
            todayCount: snapshot.todayCount,
            monthBudgetProgress: snapshot.monthBudgetProgress
        )
    }

    /// Pre-formatted thousand-separated integer string for display.
    /// Watches show "NT$ \(displayAmount)" or just "\(displayAmount)".
    public var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: todayTotal as NSDecimalNumber) ?? "0"
    }
}
#endif
```

If WidgetKit isn't importable on whatever build target compiles WatchFeatures for iOS, the `#if canImport(WidgetKit)` guard skips the whole type. WatchFeatures was built for watchOS in Phase 2; the guard is defensive.

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```
git add Features/Sources/WatchFeatures/Complication/ComplicationEntry.swift \
        NeuLedgerWatchTests/ComplicationEntryTests.swift
git commit -m "$(cat <<'EOF'
feat(watch): add ComplicationEntry timeline entry for Watch widget [ci skip]

Lives in WatchFeatures so both the Watch app and the Complication
widget extension share the same type. Provides .placeholder for the
"no snapshot yet" state and .from(snapshot:) for live data, plus a
pre-formatted thousand-separated displayAmount.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `TodayExpenseComplication` provider + views

**Files:**
- Modify: `NeuLedgerWatchComplication/TodayExpenseComplication.swift` (rewrite the auto-generated widget stub)

No new unit tests — view rendering is verified on a Watch simulator via the widget gallery + the Phase 4 runbook. Smoke build is the gate.

- [ ] **Step 1: Identify the auto-generated file**

After the setup guide ran, Xcode added a widget stub at `NeuLedgerWatchComplication/NeuLedgerWatchComplication.swift` (or similar — the exact filename depends on what the user named the target's main file). Run:

```
ls NeuLedgerWatchComplication/
```

Identify the file containing `@main struct ...: Widget` and the auto-generated `TimelineProvider`. **You will overwrite that file** (or rename to `TodayExpenseComplication.swift` and rewrite).

- [ ] **Step 2: Replace its contents**

Replace with `NeuLedgerWatchComplication/TodayExpenseComplication.swift`:

```swift
import SwiftUI
import WidgetKit
import WatchFeatures

/// Today's expense total displayed as a watchOS Complication.
///
/// Reads the latest `WatchContextSnapshot` from `WatchCacheStore`
/// (shared App Group `group.com.drake.NeuLedger`). Refresh comes from
/// explicit `WidgetCenter.reloadAllTimelines()` calls in
/// `WatchSessionGateway` whenever a new snapshot arrives — Apple's
/// own timeline scheduler is set to `.never`.
struct TodayExpenseProvider: TimelineProvider {

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let timeline = Timeline(entries: [currentEntry()], policy: .never)
        completion(timeline)
    }

    private func currentEntry() -> ComplicationEntry {
        guard let snapshot = WatchCacheStore().load() else {
            return ComplicationEntry.placeholder
        }
        return ComplicationEntry.from(snapshot: snapshot)
    }
}

struct TodayExpenseComplicationView: View {

    @Environment(\.widgetFamily) var family
    let entry: ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    circularBody
        case .accessoryCorner:      cornerBody
        case .accessoryRectangular: rectangularBody
        case .accessoryInline:      inlineBody
        @unknown default:           Text("—")
        }
    }

    private var hasSnapshot: Bool {
        // todayTotal could legitimately be 0 on a clean day; differentiate
        // "no snapshot" from "snapshot says zero" by checking the date
        // sentinel — placeholder uses Date() at boot which is fine since
        // we never compare to placeholder identity. Just use a simple
        // proxy: if todayCount == 0 AND total == 0 the user likely hasn't
        // recorded anything today.
        // To avoid lying when the user actually had 0 today, prefer the
        // safe "—" rendering. Phase 5 can introduce a more precise
        // "snapshot received" flag if needed.
        !(entry.todayTotal == 0 && entry.todayCount == 0)
    }

    private var displayAmount: String {
        hasSnapshot ? entry.displayAmount : "—"
    }

    // MARK: families

    private var circularBody: some View {
        VStack(spacing: 0) {
            Text("今日")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(displayAmount)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
    }

    private var cornerBody: some View {
        Text(displayAmount)
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .widgetCurvesContent()
            .widgetLabel {
                if let progress = entry.monthBudgetProgress {
                    Gauge(value: progress.clamped(to: 0...1), in: 0...1) {
                        Text("月")
                    }
                } else {
                    Text("今日支出")
                }
            }
    }

    private var rectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("今日支出")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("NT$ \(displayAmount)")
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
            if entry.todayCount > 0 {
                Text("\(entry.todayCount) 筆交易")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineBody: some View {
        Text("今日 NT$ \(displayAmount)")
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct TodayExpenseComplication: Widget {

    let kind: String = "TodayExpenseComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayExpenseProvider()) { entry in
            TodayExpenseComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日支出")
        .description("顯示今日累計支出與本月預算進度。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct NeuLedgerWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        TodayExpenseComplication()
    }
}
```

**Notes:**
- If Xcode's auto-generated file had a different `@main` struct name (e.g. `NeuLedgerWatchComplicationBundle` vs `NeuLedgerWatchComplication`), use whatever Xcode placed — the file content above is meant to fully replace it.
- Make sure exactly one `@main` exists in the widget extension target. If you encounter a duplicate-`@main` error, delete the other widget stub file Xcode generated.

- [ ] **Step 3: Smoke build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatchComplication" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify the Watch app still builds**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```
git add NeuLedgerWatchComplication/TodayExpenseComplication.swift
git commit -m "$(cat <<'EOF'
feat(watch): add TodayExpenseComplication widget extension [ci skip]

Four families (circular, corner, rectangular, inline) read the latest
WatchContextSnapshot from WatchCacheStore via the shared App Group.
Timeline policy is .never — refresh is push-driven by
WatchSessionGateway calling WidgetCenter.reloadAllTimelines() on each
inbound snapshot. corner family additionally shows the monthly budget
progress as an arc gauge when a monthly budget exists.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If Xcode's original auto-generated file had a different name and you renamed via `git mv`, the `git add` line above should include the rename so the diff stays clean.

---

## Task 3: Wire `WidgetCenter.reloadAllTimelines()` into `WatchSessionGateway`

**Files:**
- Modify: `Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift`

- [ ] **Step 1: Uncomment the WidgetCenter reload**

Open `Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift`. Find the comment block in `handleContext(_:)`:

```swift
#if canImport(WidgetKit)
// Phase 3 will uncomment:
// WidgetCenter.shared.reloadAllTimelines()
#endif
```

Replace with:

```swift
#if canImport(WidgetKit)
WidgetCenter.shared.reloadAllTimelines()
#endif
```

You'll need to add `import WidgetKit` at the top of the file (inside `#if canImport(WidgetKit)` if you want belt-and-suspenders, but a top-level `import WidgetKit` is fine — WidgetKit is available on watchOS).

- [ ] **Step 2: Run existing Watch tests to confirm no regression**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -10
```
Expected: 23/23 — Phase 2's 20 plus the 3 new ComplicationEntryTests from Task 1.

- [ ] **Step 3: Smoke build both Watch targets**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3

xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatchComplication" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3
```
Both: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```
git add Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift
git commit -m "$(cat <<'EOF'
feat(watch): activate WidgetCenter reload on snapshot receipt [ci skip]

WatchSessionGateway.handleContext now calls
WidgetCenter.shared.reloadAllTimelines() after writing the new snapshot
to WatchCacheStore. The TodayExpenseComplication picks up the fresh
data within seconds.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Full suite green + Phase 3 runbook update

- [ ] **Step 1: Watch tests + iOS regression**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -10

xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests 2>&1 | tail -10
```

Both: zero failures. Watch test count should now be 23 (20 Phase 2 + 3 new); iOS count unchanged from Phase 4 (~505).

- [ ] **Step 2: All three Watch builds + iOS build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3

xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatchComplication" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3

xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

All: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Append Complication checklist to the runbook**

Open `docs/superpowers/runbooks/2026-05-27-apple-watch-paired-device-checklist.md`. After section "Known limitations", add a new section:

```markdown
## Complication families

After Phase 3 lands, also verify each Complication family renders correctly:

1. **Add a Complication to a watch face**: long-press the watch face → Edit → add a Complication slot → choose "NeuLedger" → pick "今日支出". Repeat for each of the four supported families:
   - Modular Small / Circular (`.accessoryCircular`)
   - Modular Corner (`.accessoryCorner`)
   - Modular Rectangular (`.accessoryRectangular`)
   - Modular Inline (`.accessoryInline`)
2. After step 1 above, the Complication should display "—" if no snapshot has been received yet.
3. Record a transaction on iPhone → the Complication should update within ~30 sec without the Watch app being open.
4. Cross midnight → Complication should reset to "—" or "0" depending on whether `WatchMidnightTimer` fired.
```

Then commit:

```
git add docs/superpowers/runbooks/2026-05-27-apple-watch-paired-device-checklist.md
git commit -m "$(cat <<'EOF'
docs(runbook): extend Watch checklist with Complication families [ci skip]

Four-family Complication verification appended to the paired-device
checklist now that Phase 3 ships TodayExpenseComplication.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## What this phase delivers

- ✅ `ComplicationEntry` shared type in WatchFeatures with unit-test coverage.
- ✅ `TodayExpenseComplication` widget extension with four families.
- ✅ Push-driven Complication refresh via `WidgetCenter.reloadAllTimelines()` in `WatchSessionGateway`.
- ✅ Updated paired-device runbook section for Complication validation.

## What's still deferred

- A more precise "snapshot received" sentinel (today the placeholder shows "—" if both `todayTotal == 0` and `todayCount == 0`; a user who legitimately has 0 today sees "—" — acceptable for MVP).
- Multi-Complication SKUs (different complications for budget progress, account balance, etc.) — out of scope; only today-total ships.

## Self-Review

- §4 Complication families coverage: all four → Task 2's view switch.
- §4 push-driven refresh: → Task 3.
- §4 placeholder "—" behavior: → Task 2's `hasSnapshot`/`displayAmount` logic.
- §4 corner family budget gauge: → Task 2's `cornerBody.widgetLabel`.
- No placeholders. Code blocks complete.
- Type consistency: `ComplicationEntry` defined in Task 1, used verbatim in Tasks 2-3 with the same field names.
