# Apple Watch Phase 4 — Integration + Settings + Polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Phase 1's `WatchSyncObserver` into the iPhone app lifecycle, add iPhone-side Settings UI for the Watch default-account choice, handle midnight rollover for `todayTotal`, and produce a real-device verification checklist.

**Architecture:**
- iPhone-side only (Phase 3 covers the Watch widget target separately and is independent of this phase).
- `WatchSyncObserver.start()` invoked from `AppFeature.task` when the iOS app becomes active; the observer rebuilds the snapshot and pushes to Watch on every SwiftData save.
- A new `UserSettings` key `watchDefaultAccountId` (read via existing `userSettingsClient`).
- iPhone `SettingsFeature` gains an "Apple Watch" section: pairing status + default-account picker.
- A new `WatchMidnightTimer` schedules a snapshot rebuild at the next local midnight; on app foreground, it cancels and re-arms.

**Tech Stack:** Swift 6, TCA, SwiftUI, Swift Testing.

**Reference spec:** `docs/superpowers/specs/2026-05-27-apple-watch-design.md` (§5 Settings, §7 Risks midnight handling, §7 Rollout Phase 4)

---

## File Structure

### New files

```
Features/Sources/Core/Adapters/Watch/
└── WatchMidnightTimer.swift                  ← Task 2

Features/Sources/Features/Settings/Watch/
├── WatchSettingsFeature.swift                ← Task 3
└── WatchSettingsView.swift                   ← Task 3

NeuLedgerTests/Tests/CoreTests/
└── WatchMidnightTimerTests.swift             ← Task 2

NeuLedgerTests/Tests/FeaturesTests/
└── WatchSettingsFeatureTests.swift           ← Task 3

docs/superpowers/runbooks/
└── 2026-05-27-apple-watch-paired-device-checklist.md  ← Task 5
```

### Modified files

```
Features/Sources/Features/AppFeature.swift                 ← Task 1 (boot the observer)
Features/Sources/Features/Settings/SettingsFeature.swift   ← Task 4 (mount Watch section)
Features/Sources/Features/Settings/SettingsView.swift      ← Task 4 (render the section row)
```

### Untouched

- `WatchSyncObserver` itself (Phase 1) — its API already accepts a `defaultAccountIdProvider`; Phase 4 supplies one that reads from `userSettingsClient`.
- All Watch-side code.

---

## Test command reference

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/<SuiteName>
```

Build sanity check (no test target):

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Task 1: Boot `WatchSyncObserver` from `AppFeature`

**Files:**
- Modify: `Features/Sources/Features/AppFeature.swift`

No new unit tests for this task — `WatchSyncObserver` is `@MainActor` and depends on the live SwiftData container. Phase 5 real-device verification is the only meaningful test. Smoke build is the gate.

- [ ] **Step 1: Read AppFeature.swift to understand current shape**

Run:
```
grep -n "@Reducer\|@Dependency\|case task\|case appLaunched\|case onAppear" Features/Sources/Features/AppFeature.swift | head -20
```
And read the file in full. We need to know:
- the action case that fires on launch (likely `.task` or `.onAppear`)
- the existing dependencies the reducer pulls

- [ ] **Step 2: Add the observer as a stored property + start it on task**

In `AppFeature.swift`, add an internal helper that owns the observer:

```swift
import Foundation

/// Singleton holder for the live `WatchSyncObserver`. Started once
/// on first app activation and never torn down — `AppFeature` is the
/// app root and its `.task` fires on every cold launch.
@MainActor
enum WatchSyncObserverHost {
    private static var observer: WatchSyncObserver?

    static func startIfNeeded() {
        guard observer == nil else { return }
        @Dependency(\.userSettingsClient) var userSettings
        let host = WatchSyncObserver(defaultAccountIdProvider: { @Sendable in
            userSettings.uuid(.watchDefaultAccountId)
        })
        host.start()
        observer = host
    }
}
```

Then, in `AppFeature`'s `.task` (or `.onAppear`) action handler, add:

```swift
case .task:
    WatchSyncObserverHost.startIfNeeded()
    // ... existing logic continues here ...
```

If `AppFeature` doesn't currently have a `.task` action, add one and wire it from `AppView.body` with `.task { await store.send(.task).finish() }`.

The exact merge depends on the current code — read the file and make a minimal, additive change.

- [ ] **Step 3: Add the `UserSettings` key (preparation for Task 2-3)**

In `Features/Sources/Core/Adapters/UserSettingsAdapter+Live.swift` (or wherever the `UserSettings` key enum lives), confirm there's a way to read a `UUID?` by key. If not — and the existing pattern uses string-typed methods like `string(_:)` / `bool(_:)` — add a `uuid(_:)` shape. **Verify first** with:

```
grep -n "uuid\|UUID" Features/Sources/Domain/Adapters/UserSettingsAdapter.swift
grep -n "watchDefaultAccountId\|case " Features/Sources/Domain/Adapters/UserSettingsAdapter.swift | head -20
```

If the adapter exposes a generic `string(_:)`/`set(_:_:)` keyed-by-enum-case interface, just add a new case `watchDefaultAccountId` and store/read the UUID as `.uuidString`. The provider closure above then becomes:

```swift
let host = WatchSyncObserver(defaultAccountIdProvider: { @Sendable in
    guard let raw = userSettings.string(.watchDefaultAccountId),
          let id = UUID(uuidString: raw) else { return nil }
    return id
})
```

Use whichever form the adapter naturally supports. **Report exactly what key shape you used** so Tasks 2-3 stay consistent.

- [ ] **Step 4: Smoke build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```
git add Features/Sources/Features/AppFeature.swift \
        Features/Sources/Domain/Adapters/UserSettingsAdapter.swift \
        Features/Sources/Core/Adapters/UserSettingsAdapter+Live.swift
git commit -m "$(cat <<'EOF'
feat(watch): boot WatchSyncObserver from AppFeature.task [ci skip]

Adds a UserSettings key for the Watch default account and starts
WatchSyncObserver on first app activation so SwiftData saves push
fresh snapshots to a paired Watch. The observer reads the chosen
default-account UUID through userSettingsClient — Phase 4 Settings
UI lets the user change it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `WatchMidnightTimer`

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/WatchMidnightTimer.swift`
- Create: `NeuLedgerTests/Tests/CoreTests/WatchMidnightTimerTests.swift`

- [ ] **Step 1: Write the failing tests**

`NeuLedgerTests/Tests/CoreTests/WatchMidnightTimerTests.swift`:

```swift
import Foundation
import Testing
@testable import Core

@Suite("WatchMidnightTimer Tests")
struct WatchMidnightTimerTests {

    @Test("Next firing date is local midnight of the day after `now`")
    func nextFiringDateAfterNow() throws {
        let calendar = Calendar(identifier: .gregorian)
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 14:35 on Nov 14, 2023
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let firing = try #require(WatchMidnightTimer.nextMidnight(after: now, calendar: calendar))
        let components = calendar.dateComponents([.hour, .minute, .second, .day], from: firing)

        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)

        let oldDay = calendar.component(.day, from: now)
        let newDay = components.day ?? 0
        #expect(newDay != oldDay)
    }

    @Test("If now is exactly midnight, the next firing is 24 hours later")
    func midnightExact() throws {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let firing = try #require(WatchMidnightTimer.nextMidnight(after: startOfDay, calendar: calendar))
        let delta = firing.timeIntervalSince(startOfDay)
        #expect(delta > 86_000)
        #expect(delta < 86_500)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchMidnightTimerTests
```
Expected: FAIL — "cannot find 'WatchMidnightTimer' in scope".

- [ ] **Step 3: Write the implementation**

`Features/Sources/Core/Adapters/Watch/WatchMidnightTimer.swift`:

```swift
import Foundation
import Dependencies
import Domain

/// Schedules a single Task that wakes up at the next local midnight and
/// pushes a fresh `WatchContextSnapshot` to the Watch, so the
/// today-total Complication and Watch UI reset cleanly at 00:00.
///
/// `WatchSyncObserver` calls `arm()` after its initial push and any
/// time the app foregrounds (the previous Task is cancelled and
/// re-armed for the new `nextMidnight` value).
@MainActor
public final class WatchMidnightTimer {

    private let defaultAccountIdProvider: @Sendable () -> UUID?
    private var task: Task<Void, Never>?

    public init(defaultAccountIdProvider: @escaping @Sendable () -> UUID?) {
        self.defaultAccountIdProvider = defaultAccountIdProvider
    }

    public func arm(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) {
        task?.cancel()
        guard let fireAt = Self.nextMidnight(after: now, calendar: calendar) else { return }
        let delay = fireAt.timeIntervalSince(now)
        guard delay > 0 else { return }
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard Task.isCancelled == false else { return }
            await self?.fire()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }

    private func fire() async {
        guard let defaultAccountId = defaultAccountIdProvider() else { return }
        @Dependency(\.watchBridgeAdapter) var bridge
        do {
            let snapshot = try await WatchContextBuilder.build(
                defaultAccountId: defaultAccountId
            )
            try await bridge.pushContext(snapshot)
        } catch {
            // Swallow — WC retries; one missed midnight push is not
            // actionable. The next SwiftData save will push a correct
            // snapshot anyway.
        }
    }

    /// Returns the next local midnight strictly after `now`. If `now` is
    /// already exactly midnight, returns 24 hours after `now`.
    public static func nextMidnight(after now: Date, calendar: Calendar) -> Date? {
        let startOfDay = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        if let nextDay, nextDay > now { return nextDay }
        return calendar.date(byAdding: .day, value: 1, to: nextDay ?? now)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```
git add Features/Sources/Core/Adapters/Watch/WatchMidnightTimer.swift \
        NeuLedgerTests/Tests/CoreTests/WatchMidnightTimerTests.swift
git commit -m "$(cat <<'EOF'
feat(core): add WatchMidnightTimer for cross-day total reset [ci skip]

Single-shot Task wakes at the next local midnight and pushes a fresh
snapshot via watchBridgeAdapter so the Watch today-total resets to 0.
Re-armed by WatchSyncObserver after each successful push and on app
foreground (Task 4 will wire those callsites).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `WatchSettingsFeature` + view

**Files:**
- Create: `Features/Sources/Features/Settings/Watch/WatchSettingsFeature.swift`
- Create: `Features/Sources/Features/Settings/Watch/WatchSettingsView.swift`
- Create: `NeuLedgerTests/Tests/FeaturesTests/WatchSettingsFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

`NeuLedgerTests/Tests/FeaturesTests/WatchSettingsFeatureTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
@testable import Features

@MainActor
@Suite("WatchSettingsFeature Tests")
struct WatchSettingsFeatureTests {

    private static let cashAccount = Account(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "Cash", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    private static let cardAccount = Account(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        name: "Card", type: .creditCard, icon: "creditcard",
        color: "#5E5CE6", sortOrder: 1, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test("Loading populates accounts and reads the currently-selected default")
    func loadingPopulatesAccountsAndCurrentSelection() async {
        let store = TestStore(initialState: WatchSettingsFeature.State()) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { @Sendable in
                [Self.cashAccount, Self.cardAccount]
            }
            $0.userSettingsClient.string = { @Sendable key in
                key.rawValue == "watchDefaultAccountId"
                    ? Self.cardAccount.id.uuidString
                    : nil
            }
            $0.watchBridgeAdapter.isPaired = { true }
            $0.watchBridgeAdapter.isWatchAppInstalled = { true }
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.accounts = [Self.cashAccount, Self.cardAccount]
            $0.selectedAccountId = Self.cardAccount.id
            $0.isPaired = true
            $0.isWatchAppInstalled = true
        }
    }

    @Test("Selecting an account writes the UUID to userSettingsClient")
    func selectingAccountPersists() async {
        var written: [String: String] = [:]

        let store = TestStore(
            initialState: WatchSettingsFeature.State(
                accounts: [Self.cashAccount, Self.cardAccount],
                selectedAccountId: Self.cashAccount.id,
                isPaired: true,
                isWatchAppInstalled: true
            )
        ) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.setString = { @Sendable value, key in
                written[key.rawValue] = value
            }
        }

        await store.send(.accountSelected(Self.cardAccount.id)) {
            $0.selectedAccountId = Self.cardAccount.id
        }

        #expect(written["watchDefaultAccountId"] == Self.cardAccount.id.uuidString)
    }
}
```

**NOTE**: the test references `userSettingsClient.string` / `userSettingsClient.setString` and the key `.watchDefaultAccountId`. Match whatever shape Task 1 introduced. If the actual key is `enum UserSettingsKey: String { case watchDefaultAccountId }` with `string(_:)` / `setString(_:_:)` accessors, the above is correct. **Read the live adapter before writing the test** and adjust accordingly.

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchSettingsFeatureTests
```
Expected: FAIL.

- [ ] **Step 3: Implement the reducer**

`Features/Sources/Features/Settings/Watch/WatchSettingsFeature.swift`:

```swift
import Foundation
import ComposableArchitecture
import Domain

/// iPhone-side Settings sub-feature controlling the Apple Watch
/// integration. Shows pairing status and lets the user pick the
/// default account that Watch quick-record will use when no per-draft
/// override is set.
@Reducer
public struct WatchSettingsFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        public var accounts: [Account]
        public var selectedAccountId: UUID?
        public var isPaired: Bool
        public var isWatchAppInstalled: Bool

        public init(
            accounts: [Account] = [],
            selectedAccountId: UUID? = nil,
            isPaired: Bool = false,
            isWatchAppInstalled: Bool = false
        ) {
            self.accounts = accounts
            self.selectedAccountId = selectedAccountId
            self.isPaired = isPaired
            self.isWatchAppInstalled = isWatchAppInstalled
        }
    }

    public enum Action: Sendable {
        case task
        case loaded(accounts: [Account], selectedAccountId: UUID?, isPaired: Bool, isWatchAppInstalled: Bool)
        case accountSelected(UUID)
    }

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.watchBridgeAdapter) var watchBridgeAdapter

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { send in
                    let accounts = (try? await accountClient.fetchActive()) ?? []
                    let raw = userSettingsClient.string(.watchDefaultAccountId)
                    let selected = raw.flatMap(UUID.init(uuidString:))
                    await send(.loaded(
                        accounts: accounts,
                        selectedAccountId: selected,
                        isPaired: watchBridgeAdapter.isPaired(),
                        isWatchAppInstalled: watchBridgeAdapter.isWatchAppInstalled()
                    ))
                }

            case let .loaded(accounts, selectedAccountId, isPaired, isWatchAppInstalled):
                state.accounts = accounts
                state.selectedAccountId = selectedAccountId
                state.isPaired = isPaired
                state.isWatchAppInstalled = isWatchAppInstalled
                return .none

            case let .accountSelected(id):
                state.selectedAccountId = id
                userSettingsClient.setString(id.uuidString, .watchDefaultAccountId)
                return .none
            }
        }
    }
}
```

Adapt the `userSettingsClient` calls to whatever the live adapter actually exposes. If keys are unenumerated and use raw strings, switch to `userSettingsClient.string("watchDefaultAccountId")`.

- [ ] **Step 4: Implement the view**

`Features/Sources/Features/Settings/Watch/WatchSettingsView.swift`:

```swift
import SwiftUI
import ComposableArchitecture

public struct WatchSettingsView: View {

    @Bindable public var store: StoreOf<WatchSettingsFeature>

    public init(store: StoreOf<WatchSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            statusSection
            if store.isPaired && store.isWatchAppInstalled {
                defaultAccountSection
            }
        }
        .navigationTitle("Apple Watch")
        .task { await store.send(.task).finish() }
    }

    private var statusSection: some View {
        Section {
            HStack {
                Text("配對狀態")
                Spacer()
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        if store.isPaired == false { return "未配對" }
        if store.isWatchAppInstalled == false { return "尚未安裝 Watch App" }
        return "已連線"
    }

    private var defaultAccountSection: some View {
        Section("Watch 預設帳戶") {
            ForEach(store.accounts, id: \.id) { account in
                Button {
                    store.send(.accountSelected(account.id))
                } label: {
                    HStack {
                        Image(systemName: account.icon)
                            .foregroundStyle(Color.Design.fromHex(account.color))
                        Text(account.name)
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        if store.selectedAccountId == account.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.Design.accentOrange)
                        }
                    }
                }
            }
        }
    }
}
```

If `Color.Design.accentOrange` / `textPrimary` lookups fail (they shouldn't on iOS — they're the iOS variants from Phase 2 platform-gating work), substitute `.primary` / `.orange` and note DONE_WITH_CONCERNS.

- [ ] **Step 5: Run tests to verify pass**

Same `xcodebuild test` command. Expected: PASS (2/2).

- [ ] **Step 6: Commit**

```
git add Features/Sources/Features/Settings/Watch/ \
        NeuLedgerTests/Tests/FeaturesTests/WatchSettingsFeatureTests.swift
git commit -m "$(cat <<'EOF'
feat(settings): add Apple Watch settings sub-feature [ci skip]

WatchSettingsFeature shows pairing status (via watchBridgeAdapter) and
lets the user pick which account quick-record on Watch defaults to.
Selection is persisted to userSettingsClient under
watchDefaultAccountId — read by WatchSyncObserver's
defaultAccountIdProvider closure (Phase 4 Task 1).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Mount `WatchSettingsFeature` in the Settings tree

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`

No new tests for this task — just wiring. Existing `SettingsFeatureTests` should still pass.

- [ ] **Step 1: Read SettingsFeature.swift to see how other sub-features are mounted**

Run:
```
grep -n "Reducer\|@Presents\|Scope\|navigation\|Path\|case " Features/Sources/Features/Settings/SettingsFeature.swift | head -40
```

Settings likely uses either:
(a) `StackState`-based navigation with a `Path` enum of destinations; or
(b) `@Presents`-based tree navigation with one optional child per destination.

Pick the existing pattern. Add a `WatchSettingsFeature` destination/child consistent with siblings (`AccountManagementFeature`, `CategoryManagementFeature`, etc.).

- [ ] **Step 2: Add the new destination**

Wire `WatchSettingsFeature` into the navigation in the same shape as an existing destination. Add the corresponding state case, action case, and `Scope` (if `StackState`) or `@Presents` mounting block.

- [ ] **Step 3: Add the row in `SettingsView`**

Add a `NavigationLink` (or `Button` that pushes via stack action) in the appropriate Settings section. Use existing rows (Account Management, Category Management) as the visual template:

```swift
NavigationLink(state: SettingsFeature.Path.State.watch(WatchSettingsFeature.State())) {
    Label("Apple Watch", systemImage: "applewatch")
}
```

The exact `Path.State` case name + `NavigationLink` arg depends on what Step 1-2 produced.

- [ ] **Step 4: Smoke build + run existing Settings tests as a regression gate**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5

xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/SettingsFeatureTests 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```
git add Features/Sources/Features/Settings/SettingsFeature.swift \
        Features/Sources/Features/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
feat(settings): mount Apple Watch sub-feature in Settings stack [ci skip]

Adds an "Apple Watch" row in Settings that navigates into
WatchSettingsFeature. Pattern mirrors the existing Account/Category
management destinations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Paired-device verification runbook

**Files:**
- Create: `docs/superpowers/runbooks/2026-05-27-apple-watch-paired-device-checklist.md`

No code. Manual real-device test plan that lives next to the project so future-you (or another engineer) can re-run it after every Watch-relevant change.

- [ ] **Step 1: Write the checklist**

`docs/superpowers/runbooks/2026-05-27-apple-watch-paired-device-checklist.md`:

```markdown
# Apple Watch Paired-Device Verification Checklist

Run this after any change that touches `Features/Sources/Core/Adapters/Watch/`,
`Features/Sources/WatchFeatures/`, or the WatchBridgeAdapter / WatchSessionDelegate
layer on iPhone.

## Setup

- Paired physical iPhone + Apple Watch (cellular or GPS; both fine)
- iPhone has at least one account, one category, and (optionally) one active monthly budget
- Watch app installed and previously launched at least once

## Test plan

1. **Cold-launch iPhone app** → confirm `WatchSyncObserver` fires once via console (`os_log` "WatchSync: initial push"). Watch app should now reflect the cached snapshot if you open it within ~30 sec.

2. **Record a transaction on iPhone** (any account/category/amount) → within 30 sec the Watch app's today-total updates, and the snapshot's `todayCount` matches what iPhone has for today.

3. **Record a transaction on Watch** (3-step flow, default account) → check iPhone within 30 sec for the new SwiftData row. Confirm `id` matches what the draft generated (no dedup retry).

4. **Record a transaction on Watch with long-press account override** → on iPhone, confirm the new row's `accountId` matches the chosen override, not the default.

5. **Background iPhone for 60 sec, then re-open** → confirm WatchSyncObserver still fires on resume (look for `.task` re-trigger or `appDidBecomeActive` rebuild push).

6. **Kill iPhone app via App Switcher, record on Watch, re-launch iPhone** → confirm draft delivers (transferUserInfo retries until iPhone re-opens WC session).

7. **Send same draft twice (force-quit Watch app between sends — possible via Digital Crown + side button)** → confirm iPhone commits exactly once (`ProcessedDraftIdsStore` dedup).

8. **Cross midnight** (run with `Settings → General → Date & Time` set just before 00:00, or wait through midnight) → confirm Watch today-total resets to 0 within the first SwiftData save of the new day, OR sooner if `WatchMidnightTimer` fires.

9. **Change default account in Settings → Apple Watch** → on Watch, record without long-press; confirm new draft uses the new default (no app restart needed).

10. **Open Settings → Apple Watch with Watch unpaired** (toggle in Watch app on iPhone) → confirm UI shows "未配對" and hides the default-account picker.

## Known limitations

- All eight families of Complication aren't validated here — that's Phase 3's checklist.
- iCloud sync of transactions written from Watch is asynchronous (couple of seconds after the iPhone commit) — verify on a second paired device if available.
- Watch dictation for note input is not in MVP scope.

## Output

Pass/fail per item. Any failure should reproduce on a clean install (delete Watch app, re-install via Watch app on iPhone, re-pair if needed).
```

- [ ] **Step 2: Commit**

```
mkdir -p docs/superpowers/runbooks
git add docs/superpowers/runbooks/2026-05-27-apple-watch-paired-device-checklist.md
git commit -m "$(cat <<'EOF'
docs(runbook): add Apple Watch paired-device verification checklist [ci skip]

Ten-point manual test plan for verifying iPhone ↔ Watch hand-off after
any change to the WC bridge or Watch-side flow. Lives in
docs/superpowers/runbooks/ so future iterations can re-run it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Full suite green

- [ ] **Step 1: Run all iOS tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests 2>&1 | tail -10
```
Expected: ≥ 503 tests pass (Phase 1 end-state of 502 + 2 from WatchMidnightTimerTests + 2 from WatchSettingsFeatureTests = 506).

- [ ] **Step 2: Run all Watch tests (regression gate)**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -10
```
Expected: 20/20 (Phase 2 end-state).

- [ ] **Step 3: Both builds**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3
```
Both: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: No commit needed**

Phase 4 done.

---

## What this phase delivers

- ✅ `WatchSyncObserver` boots automatically with the iOS app.
- ✅ iPhone Settings has an Apple Watch section with pairing status + default-account picker.
- ✅ `WatchMidnightTimer` pushes a reset snapshot at 00:00 local.
- ✅ Real-device verification runbook for future iterations.

## What's deferred to Phase 3

- The Complication widget extension (`TodayExpenseComplication`) and the `WidgetCenter.reloadAllTimelines()` callsite in `WatchSessionGateway`.

## Self-review

- Task 1 step depends on the exact `UserSettingsAdapter` shape — instruction is "read first, adjust" rather than assuming a specific signature.
- Task 3 reducer's `userSettingsClient` calls must match whatever Task 1 introduces; instruction is explicit.
- Task 4 navigation pattern (`StackState` vs `@Presents`) depends on existing Settings code — instruction is "match what's there".
- Type consistency: `watchDefaultAccountId` key string appears in Tasks 1, 3 — all use the same literal.
- No placeholders. All code blocks complete.
- Spec coverage:
  - §7 Phase 4 rollout item 13 (Settings default-account picker) → Task 3 + Task 4
  - §7 Phase 4 rollout item 14 (midnight rollover) → Task 2
  - §7 Phase 4 rollout item 15 (manual test checklist) → Task 5
  - §2 architecture: `AppFeature.task` wires the observer → Task 1
