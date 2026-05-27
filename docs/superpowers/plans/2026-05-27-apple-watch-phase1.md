# Apple Watch Phase 1 — iPhone-side Communication Bridge

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the iPhone-side groundwork for Apple Watch — domain types (`WatchContextSnapshot`, `TransactionDraft`), the `WatchBridgeAdapter` interface, a testable `WatchSessionTransport` wrapper around `WCSession`, the snapshot builder, the idempotent inbound delegate, and the SwiftData observer that auto-pushes context to Watch.

**Architecture:**
- New domain entities (`WatchContextSnapshot`, `TransactionDraft`) and a new `WatchBridgeAdapter` interface following the existing `CloudKitSyncAdapter` pattern.
- `WatchSessionTransport` protocol wraps `WCSession` so the delegate logic can be unit-tested without touching the framework.
- `WatchSessionDelegate` consumes inbound drafts, deduplicates via `ProcessedDraftIdsStore`, and writes through the existing `transactionClient.add`.
- `WatchSyncObserver` watches SwiftData saves, rebuilds the snapshot via `WatchContextBuilder`, and pushes through `WatchBridgeAdapter.pushContext`.

**Tech Stack:** Swift 6, SwiftData, WatchConnectivity (iOS side only this phase), TCA `Dependencies` + `@DependencyClient`, Swift Testing.

**Scope of this plan:** **iOS target only.** No new Xcode target. No Watch code. No UI. Phase 2 (Watch App + UI) and Phase 3 (Complication) get their own plans after Phase 1 lands.

**Reference spec:** `docs/superpowers/specs/2026-05-27-apple-watch-design.md`

---

## File Structure

### Domain layer (new files)

```
Features/Sources/Domain/
├── Entities/
│   ├── TransactionDraft.swift           ← NEW: payload Watch sends to iPhone
│   └── WatchContextSnapshot.swift       ← NEW: snapshot iPhone pushes to Watch
└── Adapters/
    └── WatchBridgeAdapter.swift         ← NEW: outbound interface (push to Watch)
```

### Core layer (new files)

```
Features/Sources/Core/Adapters/Watch/
├── WatchSessionTransport.swift           ← NEW: protocol wrapping WCSession
├── WatchSessionTransport+Live.swift      ← NEW: concrete WCSession-backed transport
├── WatchBridgeAdapter+Live.swift         ← NEW: liveValue for WatchBridgeAdapter
├── WatchContextBuilder.swift             ← NEW: builds snapshot from SwiftData
├── WatchSessionDelegate.swift            ← NEW: receives inbound drafts, dedupes, writes DB
├── WatchSyncObserver.swift               ← NEW: ModelContext didSave → rebuild + push
└── ProcessedDraftIdsStore.swift          ← NEW: UserDefaults-backed dedup store
```

### Test files (new files)

```
NeuLedgerTests/Tests/DomainTests/
├── TransactionDraftTests.swift
├── WatchContextSnapshotTests.swift
└── WatchBridgeAdapterTests.swift

NeuLedgerTests/Tests/CoreTests/
├── ProcessedDraftIdsStoreTests.swift
├── WatchContextBuilderTests.swift
└── WatchSessionDelegateTests.swift
```

### Files modified

- `Features/Sources/Domain/Adapters/WatchBridgeAdapter.swift` — `DependencyValues` extension added inside this file (same pattern as `CloudKitSyncAdapter.swift`).

### Why this decomposition

- `WatchBridgeAdapter` matches the `CloudKitSyncAdapter` shape: outbound-only `@DependencyClient`, sits in `Domain/Adapters/`. The inbound side (receiving drafts from Watch) lives in `Core` as `WatchSessionDelegate` because it's framework glue with no domain interface.
- `WatchSessionTransport` is a protocol seam that lets us mock `WCSession`. Apple's framework type isn't mockable directly. The protocol stays in Core (it's a thin framework wrapper, not a domain concept).
- `ProcessedDraftIdsStore` is small but isolated because it needs its own UserDefaults round-trip tests independent of the delegate.

---

## Task 1: `TransactionDraft` entity

**Files:**
- Create: `Features/Sources/Domain/Entities/TransactionDraft.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/TransactionDraftTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NeuLedgerTests/Tests/DomainTests/TransactionDraftTests.swift`:

```swift
import Foundation
import Testing
@testable import Domain

@Suite
struct TransactionDraftTests {

    @Test
    func encodesAndDecodes() throws {
        let original = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: 480,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionDraft.self, from: data)

        #expect(decoded == original)
    }

    @Test
    func isValidRequiresPositiveAmount() {
        let zero = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: 0,
            date: Date()
        )
        let positive = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: 1,
            date: Date()
        )
        let negative = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: -1,
            date: Date()
        )

        #expect(zero.isValid == false)
        #expect(positive.isValid == true)
        #expect(negative.isValid == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/TransactionDraftTests
```
Expected: FAIL — "cannot find 'TransactionDraft' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Features/Sources/Domain/Entities/TransactionDraft.swift`:

```swift
import Foundation

/// A pending transaction recorded on Apple Watch and queued for the iPhone
/// to commit into SwiftData.
///
/// `id` is generated by the Watch and carried through verbatim so the iPhone
/// side can deduplicate retries.
public struct TransactionDraft: Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public let categoryId: UUID
    public let accountId: UUID
    public let amount: Decimal
    public let date: Date

    public init(
        id: UUID = UUID(),
        categoryId: UUID,
        accountId: UUID,
        amount: Decimal,
        date: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.accountId = accountId
        self.amount = amount
        self.date = date
    }

    public var isValid: Bool {
        amount > 0
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Entities/TransactionDraft.swift \
        NeuLedgerTests/Tests/DomainTests/TransactionDraftTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add TransactionDraft entity for Watch → iPhone hand-off [ci skip]

Lightweight Codable payload carrying the minimum needed to commit a
transaction from Watch. The id is generated on Watch so the iPhone side
can deduplicate retries.
EOF
)"
```

---

## Task 2: `WatchContextSnapshot` entity

**Files:**
- Create: `Features/Sources/Domain/Entities/WatchContextSnapshot.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/WatchContextSnapshotTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NeuLedgerTests/Tests/DomainTests/WatchContextSnapshotTests.swift`:

```swift
import Foundation
import Testing
@testable import Domain

@Suite
struct WatchContextSnapshotTests {

    @Test
    func encodesAndDecodes() throws {
        let defaultAccountId = UUID()
        let category = Category(
            id: UUID(),
            name: "Food",
            icon: "fork.knife",
            color: "#FF9500",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        )
        let account = Account(
            id: defaultAccountId,
            name: "Cash",
            type: .cash,
            icon: "banknote",
            color: "#34C759",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date(timeIntervalSince1970: 1)
        )

        let original = WatchContextSnapshot(
            categories: [category],
            accounts: [account],
            defaultAccountId: defaultAccountId,
            todayTotal: 480,
            todayCount: 2,
            monthBudgetProgress: 0.62,
            snapshotAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchContextSnapshot.self, from: data)

        #expect(decoded == original)
    }

    @Test
    func nilBudgetProgressIsEncodedAsAbsent() throws {
        let snapshot = WatchContextSnapshot(
            categories: [],
            accounts: [],
            defaultAccountId: UUID(),
            todayTotal: 0,
            todayCount: 0,
            monthBudgetProgress: nil,
            snapshotAt: Date()
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WatchContextSnapshot.self, from: data)
        #expect(decoded.monthBudgetProgress == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchContextSnapshotTests
```
Expected: FAIL — "cannot find 'WatchContextSnapshot' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Features/Sources/Domain/Entities/WatchContextSnapshot.swift`:

```swift
import Foundation

/// The minimum-viable state the watchOS app needs to render its UI and
/// Complication without consulting SwiftData directly.
///
/// Built on iPhone via `WatchContextBuilder`, pushed across via
/// `WatchBridgeAdapter.pushContext`. The iPhone always sends a full
/// snapshot (not a delta) because `WCSession.updateApplicationContext`
/// only retains the latest one — so partial snapshots would lose data
/// on a rapid burst of writes.
public struct WatchContextSnapshot: Equatable, Codable, Sendable {
    public let categories: [Category]
    public let accounts: [Account]
    public let defaultAccountId: UUID
    public let todayTotal: Decimal
    public let todayCount: Int
    public let monthBudgetProgress: Double?
    public let snapshotAt: Date

    public init(
        categories: [Category],
        accounts: [Account],
        defaultAccountId: UUID,
        todayTotal: Decimal,
        todayCount: Int,
        monthBudgetProgress: Double?,
        snapshotAt: Date
    ) {
        self.categories = categories
        self.accounts = accounts
        self.defaultAccountId = defaultAccountId
        self.todayTotal = todayTotal
        self.todayCount = todayCount
        self.monthBudgetProgress = monthBudgetProgress
        self.snapshotAt = snapshotAt
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Entities/WatchContextSnapshot.swift \
        NeuLedgerTests/Tests/DomainTests/WatchContextSnapshotTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add WatchContextSnapshot entity for iPhone → Watch state push [ci skip]

Full-snapshot payload (categories, accounts, today aggregates, optional
budget progress) sent across WatchConnectivity. Always pushed in full
because updateApplicationContext only retains the latest one.
EOF
)"
```

---

## Task 3: `WatchBridgeAdapter` interface

**Files:**
- Create: `Features/Sources/Domain/Adapters/WatchBridgeAdapter.swift`
- Test: `NeuLedgerTests/Tests/DomainTests/WatchBridgeAdapterTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NeuLedgerTests/Tests/DomainTests/WatchBridgeAdapterTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite
struct WatchBridgeAdapterTests {

    @Test
    func testValueIsResolvable() {
        @Dependency(\.watchBridgeAdapter) var adapter
        #expect(adapter.isPaired() == false)
        #expect(adapter.isWatchAppInstalled() == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchBridgeAdapterTests
```
Expected: FAIL — "value of type 'DependencyValues' has no member 'watchBridgeAdapter'".

- [ ] **Step 3: Write minimal implementation**

Create `Features/Sources/Domain/Adapters/WatchBridgeAdapter.swift`:

```swift
import Foundation
import Dependencies
import DependenciesMacros

/// Outbound bridge from iPhone to Apple Watch. Mirrors the
/// `CloudKitSyncAdapter` shape — a low-level adapter wrapping the
/// `WCSession` lifecycle on the phone side. `WatchSyncUseCase`
/// (added in Phase 4) will orchestrate the broader flow.
///
/// The inbound side (Watch → iPhone `TransactionDraft` delivery) lives in
/// Core as `WatchSessionDelegate` because it's framework glue with no
/// stable domain interface.
@DependencyClient
public struct WatchBridgeAdapter: Sendable {
    /// `true` if a paired Apple Watch is currently associated with this
    /// iPhone. False if the device has never paired one, or pairing was
    /// removed.
    public var isPaired: @Sendable () -> Bool = { false }

    /// `true` if the watchOS companion app is installed on the paired
    /// Watch. False when paired but the user hasn't installed (or
    /// uninstalled) the Watch app.
    public var isWatchAppInstalled: @Sendable () -> Bool = { false }

    /// Push the latest snapshot to Watch via
    /// `WCSession.updateApplicationContext`. Errors propagate;
    /// `WatchSyncObserver` swallows them after logging because WC retries
    /// on its own schedule and a single failed push is not actionable.
    public var pushContext: @Sendable (WatchContextSnapshot) async throws -> Void
}

extension WatchBridgeAdapter: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var watchBridgeAdapter: WatchBridgeAdapter {
        get { self[WatchBridgeAdapter.self] }
        set { self[WatchBridgeAdapter.self] = newValue }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Adapters/WatchBridgeAdapter.swift \
        NeuLedgerTests/Tests/DomainTests/WatchBridgeAdapterTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add WatchBridgeAdapter outbound interface [ci skip]

Mirrors the CloudKitSyncAdapter shape — pairing state queries and a
pushContext sink. Live implementation arrives in Core in a follow-up
task. Inbound (Watch → iPhone drafts) handled by Core's
WatchSessionDelegate because it's framework glue.
EOF
)"
```

---

## Task 4: `ProcessedDraftIdsStore` (dedup)

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/ProcessedDraftIdsStore.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/ProcessedDraftIdsStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NeuLedgerTests/Tests/CoreTests/ProcessedDraftIdsStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Core

@Suite
struct ProcessedDraftIdsStoreTests {

    private func makeStore() -> (ProcessedDraftIdsStore, UserDefaults) {
        let suite = "ProcessedDraftIdsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = ProcessedDraftIdsStore(defaults: defaults, capacity: 3)
        return (store, defaults)
    }

    @Test
    func newIdsAreNotMarkedProcessed() {
        let (store, _) = makeStore()
        let id = UUID()
        #expect(store.contains(id) == false)
    }

    @Test
    func markedIdsAreReportedAsProcessed() {
        let (store, _) = makeStore()
        let id = UUID()
        store.mark(id)
        #expect(store.contains(id) == true)
    }

    @Test
    func evictsOldestBeyondCapacity() {
        let (store, _) = makeStore()
        let ids = (0..<4).map { _ in UUID() }
        for id in ids { store.mark(id) }

        // Capacity = 3; oldest (ids[0]) should be evicted.
        #expect(store.contains(ids[0]) == false)
        #expect(store.contains(ids[1]) == true)
        #expect(store.contains(ids[2]) == true)
        #expect(store.contains(ids[3]) == true)
    }

    @Test
    func survivesRoundTripThroughDefaults() {
        let suite = "ProcessedDraftIdsStoreTests.RoundTrip.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let id = UUID()
        ProcessedDraftIdsStore(defaults: defaults, capacity: 10).mark(id)

        let reopened = ProcessedDraftIdsStore(defaults: defaults, capacity: 10)
        #expect(reopened.contains(id) == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/ProcessedDraftIdsStoreTests
```
Expected: FAIL — "cannot find 'ProcessedDraftIdsStore' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Features/Sources/Core/Adapters/Watch/ProcessedDraftIdsStore.swift`:

```swift
import Foundation

/// FIFO ring of recently processed `TransactionDraft.id` values, backed by
/// `UserDefaults` so a process restart doesn't lose dedup state.
///
/// Capacity defaults to 200 — generous for "a Watch user records a few
/// dozen drafts a day"; small enough that JSON encoding stays trivial.
/// On overflow the oldest id is evicted.
public final class ProcessedDraftIdsStore: @unchecked Sendable {

    private static let storageKey = "watch.processed_draft_ids.v1"

    private let defaults: UserDefaults
    private let capacity: Int
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, capacity: Int = 200) {
        self.defaults = defaults
        self.capacity = capacity
    }

    public func contains(_ id: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return load().contains(id)
    }

    public func mark(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        var ids = load()
        if let existing = ids.firstIndex(of: id) {
            ids.remove(at: existing)
        }
        ids.append(id)
        while ids.count > capacity {
            ids.removeFirst()
        }
        save(ids)
    }

    private func load() -> [UUID] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings.compactMap(UUID.init(uuidString:))
    }

    private func save(_ ids: [UUID]) {
        let strings = ids.map(\.uuidString)
        guard let data = try? JSONEncoder().encode(strings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/ProcessedDraftIdsStore.swift \
        NeuLedgerTests/Tests/CoreTests/ProcessedDraftIdsStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(core): add ProcessedDraftIdsStore for Watch draft deduplication [ci skip]

UserDefaults-backed FIFO ring (default capacity 200) so a transferUserInfo
retry from Watch is recognized after an iPhone process restart and the
same TransactionDraft isn't committed twice.
EOF
)"
```

---

## Task 5: `WatchSessionTransport` protocol seam

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/WatchSessionTransport.swift`
- Create: `Features/Sources/Core/Adapters/Watch/WatchSessionTransport+Live.swift`

No tests on this task alone — it's pure framework wrapping. The protocol shows its value in Task 6 (`WatchSessionDelegate`) and Task 8 (`WatchBridgeAdapter+Live`), both of which test against fakes built on it.

- [ ] **Step 1: Define the protocol**

Create `Features/Sources/Core/Adapters/Watch/WatchSessionTransport.swift`:

```swift
import Foundation

/// Seam over `WCSession` so the iPhone-side delegate / adapter can be
/// unit-tested without launching the framework. Apple does not expose a
/// protocol form of `WCSession`; this is the smallest surface our code
/// actually uses.
///
/// Receivers register via `onReceiveUserInfo` (Watch → iPhone draft
/// hand-off). Senders use `updateApplicationContext` (iPhone → Watch
/// snapshot push). Both calls use Foundation types only so the seam is
/// platform-agnostic and Codable-friendly.
public protocol WatchSessionTransport: AnyObject, Sendable {

    /// `true` once `WCSession.activate()` has reported
    /// `.activated`. Adapter callers may push before activation; the
    /// transport buffers internally.
    var isActivated: Bool { get }

    /// `true` if the framework reports a paired Watch.
    var isPaired: Bool { get }

    /// `true` if the watchOS companion app is installed on the paired Watch.
    var isWatchAppInstalled: Bool { get }

    /// Begin the activation handshake. Idempotent — calling more than once
    /// is a no-op.
    func activate()

    /// Push the latest snapshot. WC's `updateApplicationContext` retains
    /// only the most recent dictionary, so callers send a full snapshot
    /// every time.
    func updateApplicationContext(_ context: [String: Any]) throws

    /// Register a handler for inbound `transferUserInfo` payloads (used by
    /// the Watch → iPhone draft path). Setting a new handler replaces the
    /// previous one.
    func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void)
}
```

- [ ] **Step 2: Implement the live transport**

Create `Features/Sources/Core/Adapters/Watch/WatchSessionTransport+Live.swift`:

```swift
#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// `WCSession`-backed implementation of `WatchSessionTransport`.
///
/// The class also serves as the `WCSessionDelegate`. We retain only the
/// inbound handler (`onReceiveUserInfo`) — the higher-level
/// `WatchSessionDelegate` (Core) decodes the payload and writes through
/// `transactionClient`.
public final class LiveWatchSessionTransport: NSObject, WatchSessionTransport, WCSessionDelegate, @unchecked Sendable {

    public static let shared = LiveWatchSessionTransport()

    private let lock = NSLock()
    private var inboundHandler: (@Sendable ([String: Any]) -> Void)?
    private var didActivate = false

    public var isActivated: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.activationState == .activated
    }

    public var isPaired: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }

    public var isWatchAppInstalled: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isWatchAppInstalled
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        lock.lock()
        guard didActivate == false else { lock.unlock(); return }
        didActivate = true
        lock.unlock()
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func updateApplicationContext(_ context: [String: Any]) throws {
        guard WCSession.isSupported() else { return }
        try WCSession.default.updateApplicationContext(context)
    }

    public func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        inboundHandler = handler
    }

    // MARK: WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // No-op: callers consult `isActivated` lazily.
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so a paired-device swap continues to work.
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let handler: (@Sendable ([String: Any]) -> Void)? = {
            lock.lock(); defer { lock.unlock() }
            return inboundHandler
        }()
        handler?(userInfo)
    }
}
#endif
```

- [ ] **Step 3: Verify compiles**

Run:
```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/WatchSessionTransport.swift \
        Features/Sources/Core/Adapters/Watch/WatchSessionTransport+Live.swift
git commit -m "$(cat <<'EOF'
feat(core): add WatchSessionTransport seam over WCSession [ci skip]

Protocol wrapping the four WCSession affordances we use (activation,
pairing state, updateApplicationContext push, transferUserInfo receive).
LiveWatchSessionTransport is the WCSession-backed concrete; tests inject
fakes built on the same protocol.
EOF
)"
```

---

## Task 6: `WatchSessionDelegate` (inbound)

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/WatchSessionDelegate.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/WatchSessionDelegateTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NeuLedgerTests/Tests/CoreTests/WatchSessionDelegateTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
import Domain
@testable import Core

@Suite
struct WatchSessionDelegateTests {

    /// Fake transport that only exercises the `onReceiveUserInfo` path.
    final class FakeTransport: WatchSessionTransport, @unchecked Sendable {
        var isActivated = false
        var isPaired = false
        var isWatchAppInstalled = false
        private var handler: (@Sendable ([String: Any]) -> Void)?

        func activate() { isActivated = true }
        func updateApplicationContext(_ context: [String: Any]) throws {}
        func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {
            self.handler = handler
        }
        func deliver(_ payload: [String: Any]) { handler?(payload) }
    }

    private func makeDedupStore() -> ProcessedDraftIdsStore {
        let suite = "WatchSessionDelegateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ProcessedDraftIdsStore(defaults: defaults, capacity: 10)
    }

    private func encodeDraft(_ draft: TransactionDraft) throws -> [String: Any] {
        let data = try JSONEncoder().encode(draft)
        return [
            "op": "addTx",
            "payload": data
        ]
    }

    @Test
    func validDraftIsForwardedToTransactionClient() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID(),
            amount: 480
        )

        let added = LockIsolated<[Transaction]>([])

        await withDependencies {
            $0.transactionClient.add = { @Sendable transaction in
                added.withValue { $0.append(transaction) }
            }
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            // Allow the Task spawned inside the delegate to run.
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let committed = added.value
        #expect(committed.count == 1)
        #expect(committed.first?.id == draft.id)
        #expect(committed.first?.amount == 480)
        #expect(committed.first?.accountId == draft.accountId)
        #expect(committed.first?.categoryId == draft.categoryId)
        #expect(committed.first?.type == .expense)
    }

    @Test
    func duplicateDraftIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID(),
            amount: 100
        )

        let callCount = LockIsolated(0)

        await withDependencies {
            $0.transactionClient.add = { @Sendable _ in
                callCount.withValue { $0 += 1 }
            }
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 50_000_000)
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(callCount.value == 1)
    }

    @Test
    func invalidPayloadIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let callCount = LockIsolated(0)

        await withDependencies {
            $0.transactionClient.add = { @Sendable _ in
                callCount.withValue { $0 += 1 }
            }
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(["op": "addTx", "payload": "not-data"])
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(callCount.value == 0)
    }
}
```

Note: `LockIsolated` is part of `swift-concurrency-extras` which is transitively available through TCA's dependencies. If the import is missing in `Core` tests, prefix the test with `import ConcurrencyExtras`.

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchSessionDelegateTests
```
Expected: FAIL — "cannot find 'WatchSessionDelegate' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Features/Sources/Core/Adapters/Watch/WatchSessionDelegate.swift`:

```swift
import Foundation
import Dependencies
import Domain

/// Receives inbound payloads from the watchOS companion app and commits
/// them into SwiftData via `transactionClient`. Uses
/// `ProcessedDraftIdsStore` to discard retried sends of the same draft.
///
/// Wire-format (must stay in sync with the Watch sender, added in Phase 2):
///   ```
///   ["op": "addTx", "payload": <Data — JSON-encoded TransactionDraft>]
///   ```
public final class WatchSessionDelegate: @unchecked Sendable {

    private let transport: WatchSessionTransport
    private let dedupStore: ProcessedDraftIdsStore

    public init(transport: WatchSessionTransport, dedupStore: ProcessedDraftIdsStore = ProcessedDraftIdsStore()) {
        self.transport = transport
        self.dedupStore = dedupStore
    }

    /// Begin listening for inbound payloads. Calling more than once
    /// replaces the previous handler.
    public func start() {
        transport.onReceiveUserInfo { [weak self] payload in
            self?.handle(payload)
        }
    }

    private func handle(_ payload: [String: Any]) {
        guard let op = payload["op"] as? String, op == "addTx" else { return }
        guard let data = payload["payload"] as? Data else { return }
        guard let draft = try? JSONDecoder().decode(TransactionDraft.self, from: data) else { return }
        guard draft.isValid else { return }
        guard dedupStore.contains(draft.id) == false else { return }
        dedupStore.mark(draft.id)

        // Hop off the WC delegate queue onto a Task so transactionClient
        // (async) can run.
        Task { [draft] in
            @Dependency(\.transactionClient) var transactionClient
            let transaction = Transaction(
                id: draft.id,
                amount: draft.amount,
                date: draft.date,
                categoryId: draft.categoryId,
                accountId: draft.accountId,
                type: .expense
            )
            try? await transactionClient.add(transaction)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/WatchSessionDelegate.swift \
        NeuLedgerTests/Tests/CoreTests/WatchSessionDelegateTests.swift
git commit -m "$(cat <<'EOF'
feat(core): add WatchSessionDelegate for inbound Watch drafts [ci skip]

Receives {op: addTx, payload: Data} payloads from WatchSessionTransport,
decodes TransactionDraft, dedupes via ProcessedDraftIdsStore, and writes
through transactionClient.add as a Transaction(type: .expense).
EOF
)"
```

---

## Task 7: `WatchContextBuilder`

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/WatchContextBuilderTests.swift`

- [ ] **Step 1: Write the failing test**

Create `NeuLedgerTests/Tests/CoreTests/WatchContextBuilderTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
import Domain
@testable import Core

@Suite
struct WatchContextBuilderTests {

    @Test
    func aggregatesTodaysExpensesOnly() async throws {
        let accountId = UUID()
        let category = Category(
            id: UUID(),
            name: "Food",
            icon: "fork.knife",
            color: "#FF9500",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        )
        let account = Account(
            id: accountId,
            name: "Cash",
            type: .cash,
            icon: "banknote",
            color: "#34C759",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        let now = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14 UTC
        let yesterday = now.addingTimeInterval(-60 * 60 * 24)
        let earlierToday = now.addingTimeInterval(-3600)

        let txns: [Transaction] = [
            Transaction(amount: 300, date: now, accountId: accountId, type: .expense),
            Transaction(amount: 180, date: earlierToday, accountId: accountId, type: .expense),
            Transaction(amount: 500, date: yesterday, accountId: accountId, type: .expense),
            Transaction(amount: 1000, date: now, accountId: accountId, type: .income),
        ]

        let snapshot = try await withDependencies {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.transactionClient.fetchAll = { @Sendable in txns }
            $0.categoryClient.fetchAll = { @Sendable in [category] }
            $0.accountClient.fetchActive = { @Sendable in [account] }
            $0.budgetClient.fetchActive = { @Sendable in [] }
        } operation: {
            try await WatchContextBuilder.build(now: now, defaultAccountId: accountId)
        }

        #expect(snapshot.todayTotal == 480)
        #expect(snapshot.todayCount == 2)
        #expect(snapshot.categories.count == 1)
        #expect(snapshot.accounts.count == 1)
        #expect(snapshot.defaultAccountId == accountId)
        #expect(snapshot.monthBudgetProgress == nil)
    }

    @Test
    func monthBudgetProgressNilWhenNoBudgetActive() async throws {
        let snapshot = try await withDependencies {
            $0.transactionClient.fetchAll = { @Sendable in [] }
            $0.categoryClient.fetchAll = { @Sendable in [] }
            $0.accountClient.fetchActive = { @Sendable in [] }
            $0.budgetClient.fetchActive = { @Sendable in [] }
        } operation: {
            try await WatchContextBuilder.build(now: Date(), defaultAccountId: UUID())
        }

        #expect(snapshot.monthBudgetProgress == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchContextBuilderTests
```
Expected: FAIL — "type 'WatchContextBuilder' has no member 'build'".

- [ ] **Step 3: Write minimal implementation**

Create `Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift`:

```swift
import Foundation
import Dependencies
import Domain

/// Aggregates the data the watchOS app needs from the iPhone-side
/// SwiftData store into a single `WatchContextSnapshot`. Used by
/// `WatchSyncObserver` (push on data change) and at app launch (initial
/// push).
public enum WatchContextBuilder {

    public static func build(
        now: Date = Date(),
        defaultAccountId: UUID
    ) async throws -> WatchContextSnapshot {
        @Dependency(\.calendar) var calendar
        @Dependency(\.transactionClient) var transactionClient
        @Dependency(\.categoryClient) var categoryClient
        @Dependency(\.accountClient) var accountClient
        @Dependency(\.budgetClient) var budgetClient

        let categories = try await categoryClient.fetchAll()
        let accounts = try await accountClient.fetchActive()
        let allTxns = try await transactionClient.fetchAll()
        let activeBudgets = try await budgetClient.fetchActive()

        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            throw CoreError.operationDenied
        }
        let todayRange = startOfToday..<startOfTomorrow

        let todayExpenses = allTxns.filter {
            $0.type == .expense && todayRange.contains($0.date)
        }
        let todayTotal = todayExpenses.reduce(Decimal(0)) { $0 + $1.amount }

        let monthBudgetProgress = monthBudgetProgress(
            now: now,
            calendar: calendar,
            transactions: allTxns,
            budgets: activeBudgets
        )

        return WatchContextSnapshot(
            categories: categories,
            accounts: accounts,
            defaultAccountId: defaultAccountId,
            todayTotal: todayTotal,
            todayCount: todayExpenses.count,
            monthBudgetProgress: monthBudgetProgress,
            snapshotAt: now
        )
    }

    /// Returns the share of the active *uncategorized monthly* budget
    /// consumed so far this month, or `nil` if no such budget is active.
    /// Watch UI only surfaces this as the Corner Complication gauge — the
    /// minimum sufficient signal.
    private static func monthBudgetProgress(
        now: Date,
        calendar: Calendar,
        transactions: [Transaction],
        budgets: [Budget]
    ) -> Double? {
        guard let overall = budgets.first(where: {
            $0.period == .monthly && $0.categoryId == nil
        }) else { return nil }

        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let startOfNextMonth = calendar.date(
                byAdding: .month, value: 1, to: startOfMonth
              ) else { return nil }
        let monthRange = startOfMonth..<startOfNextMonth

        let monthExpenseTotal = transactions
            .filter { $0.type == .expense && monthRange.contains($0.date) }
            .reduce(Decimal(0)) { $0 + $1.amount }

        guard overall.amount > 0 else { return nil }
        let ratio = (monthExpenseTotal as NSDecimalNumber).doubleValue
               / (overall.amount as NSDecimalNumber).doubleValue
        return ratio
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift \
        NeuLedgerTests/Tests/CoreTests/WatchContextBuilderTests.swift
git commit -m "$(cat <<'EOF'
feat(core): add WatchContextBuilder for snapshot assembly [ci skip]

Aggregates today's expense total + count and (when present) overall
monthly budget progress into a WatchContextSnapshot using existing
clients. Pure async function — no WC side-effect.
EOF
)"
```

---

## Task 8: `WatchBridgeAdapter+Live`

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/WatchBridgeAdapter+Live.swift`

This task wires the live transport into the domain adapter. No new tests — the moving parts already have coverage and the wire-up is a single function. A smoke build is the gate.

- [ ] **Step 1: Write implementation**

Create `Features/Sources/Core/Adapters/Watch/WatchBridgeAdapter+Live.swift`:

```swift
import Foundation
import Dependencies
import Domain

extension WatchBridgeAdapter: DependencyKey {

    public static var liveValue: WatchBridgeAdapter {
        let transport: WatchSessionTransport = {
            #if canImport(WatchConnectivity)
            return LiveWatchSessionTransport.shared
            #else
            return UnavailableWatchSessionTransport()
            #endif
        }()
        transport.activate()

        return WatchBridgeAdapter(
            isPaired: { transport.isPaired },
            isWatchAppInstalled: { transport.isWatchAppInstalled },
            pushContext: { snapshot in
                let data = try JSONEncoder().encode(snapshot)
                let context: [String: Any] = [
                    "v": 1,
                    "snapshot": data
                ]
                try transport.updateApplicationContext(context)
            }
        )
    }
}

#if !canImport(WatchConnectivity)
/// Fallback for non-iOS targets that still link Core but cannot use WC.
private final class UnavailableWatchSessionTransport: WatchSessionTransport, @unchecked Sendable {
    var isActivated: Bool { false }
    var isPaired: Bool { false }
    var isWatchAppInstalled: Bool { false }
    func activate() {}
    func updateApplicationContext(_ context: [String: Any]) throws {}
    func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {}
}
#endif
```

- [ ] **Step 2: Verify compiles**

Run:
```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/WatchBridgeAdapter+Live.swift
git commit -m "$(cat <<'EOF'
feat(core): add WatchBridgeAdapter live implementation [ci skip]

Wires LiveWatchSessionTransport into the Domain adapter. Encodes the
snapshot to JSON Data and ships it through WCSession's
updateApplicationContext under {v: 1, snapshot: Data}. The {v:} field
lets us evolve the wire format later.
EOF
)"
```

---

## Task 9: `WatchSyncObserver`

**Files:**
- Create: `Features/Sources/Core/Adapters/Watch/WatchSyncObserver.swift`

No automated tests for this task — it's a single observer that subscribes to `Notification.Name.NSManagedObjectContextDidSave` (or the SwiftData equivalent) and calls `WatchContextBuilder` + `WatchBridgeAdapter.pushContext`. End-to-end behavior is exercised manually by running the iPhone app with a paired Watch in Phase 2.

- [ ] **Step 1: Write implementation**

Create `Features/Sources/Core/Adapters/Watch/WatchSyncObserver.swift`:

```swift
import Foundation
import SwiftData
import Dependencies
import Domain

/// Watches the SwiftData container for saves and pushes a fresh
/// `WatchContextSnapshot` to the Apple Watch. Coalesces bursty saves by
/// debouncing for 300 ms before rebuilding the snapshot.
@MainActor
public final class WatchSyncObserver {

    private let defaultAccountIdProvider: @Sendable () -> UUID?
    private var observerToken: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?

    public init(defaultAccountIdProvider: @escaping @Sendable () -> UUID?) {
        self.defaultAccountIdProvider = defaultAccountIdProvider
    }

    public func start() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRebuild()
        }
        // Push an initial snapshot at boot regardless of whether saves
        // happen in this session.
        scheduleRebuild()
    }

    public func stop() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
        observerToken = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func scheduleRebuild() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard Task.isCancelled == false else { return }
            await self?.rebuildAndPush()
        }
    }

    private func rebuildAndPush() async {
        guard let defaultAccountId = defaultAccountIdProvider() else { return }
        @Dependency(\.watchBridgeAdapter) var bridge
        do {
            let snapshot = try await WatchContextBuilder.build(
                defaultAccountId: defaultAccountId
            )
            try await bridge.pushContext(snapshot)
        } catch {
            // Swallow — WC retries on its own and a single failure is not
            // actionable. Surface via os_log in future iteration.
        }
    }
}
```

- [ ] **Step 2: Verify compiles**

Run:
```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Adapters/Watch/WatchSyncObserver.swift
git commit -m "$(cat <<'EOF'
feat(core): add WatchSyncObserver for SwiftData → Watch push [ci skip]

Listens for NSManagedObjectContextDidSave, debounces 300 ms, then
rebuilds the snapshot via WatchContextBuilder and pushes it through
WatchBridgeAdapter. The default account id is injected via a closure so
the eventual Settings UI can change it without restarting the observer.
EOF
)"
```

---

## Task 10: Full-suite green + housekeeping

- [ ] **Step 1: Run the full test target**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests
```
Expected: All tests pass, including the six new test suites:
- `TransactionDraftTests` (2)
- `WatchContextSnapshotTests` (2)
- `WatchBridgeAdapterTests` (1)
- `ProcessedDraftIdsStoreTests` (4)
- `WatchSessionDelegateTests` (3)
- `WatchContextBuilderTests` (2)

- [ ] **Step 2: Confirm no warnings introduced**

Scroll the build log. Expected: no new warnings from the `Features/Sources/Core/Adapters/Watch/` files or the new tests.

- [ ] **Step 3: Update CLAUDE.md key constraints (deferred to Phase 4)**

No file changes this step — just a reminder for the Phase 4 plan: Watch-related constraints should be added to `CLAUDE.md` after the full feature lands (architecture overview of Watch target, `WatchBridgeAdapter` mention in Adapter catalog).

- [ ] **Step 4: No commit needed**

If Step 1 / Step 2 pass, Phase 1 is complete. The bridge is dormant until Phase 2 ships the watchOS target.

---

## What this phase delivers

- ✅ Domain types `TransactionDraft` and `WatchContextSnapshot` available for both iOS and (future) watchOS targets.
- ✅ `WatchBridgeAdapter` outbound interface registered in `DependencyValues`.
- ✅ Idempotent inbound-draft handling via `WatchSessionDelegate` + `ProcessedDraftIdsStore`.
- ✅ Snapshot assembly via `WatchContextBuilder`.
- ✅ Auto-push on SwiftData saves via `WatchSyncObserver`.
- ✅ Test coverage on every unit that has non-trivial logic.
- ❌ No user-visible feature yet. Watch app and Complication arrive in Phase 2 / Phase 3.

## What's deferred to later phases

| Phase | Scope | Why deferred |
|---|---|---|
| **Phase 2** | `NeuLedgerWatch` Xcode target + `WatchFeatures` SPM target + `WatchRecordFeature` + three Watch screens + Watch-side clients | Needs its own plan; introduces new build artifact + new SPM target |
| **Phase 3** | `NeuLedgerWatchComplication` Xcode target + `TodayExpenseComplication` (four families) + Widget reload wiring | Independent of Phase 2 UI; can ship after Phase 2 |
| **Phase 4** | iPhone Settings → Apple Watch section + midnight rollover + `AppFeature.task` wiring to start `WatchSyncObserver` + manual real-device test checklist | Polish + integration; can't write until Phases 2/3 land |

## Self-Review

**Spec coverage (Phase 1 slice):**
- §2 architecture iPhone-side elements: `WatchBridgeAdapter` (Task 3), `WatchSessionDelegate` (Task 6), `WatchContextBuilder` (Task 7), `WatchSyncObserver` (Task 9) — all covered.
- §5 Domain new types: `TransactionDraft` (Task 1), `WatchContextSnapshot` (Task 2), `WatchBridgeAdapter` interface (Task 3) — all covered.
- §6 testing for iPhone-side: snapshot/draft/adapter/builder/delegate/dedup — all covered.

**Placeholders:** none. Every code step shows the full code.

**Type consistency:**
- `TransactionDraft.amount` and `WatchContextSnapshot.todayTotal` both use `Decimal` (matches `Transaction.amount`).
- `WatchSessionDelegate` accepts `WatchSessionTransport` (same type used in Task 5 and Task 8).
- `WatchContextBuilder.build` signature `(now:defaultAccountId:)` matches the call site in `WatchSyncObserver.rebuildAndPush`.

**Naming consistency notes (deviations from the spec, intentional):**
- Spec called it `WatchBridgeClient` and put it under `Domain/Clients/`. The project's convention is `Repositories/` for data-access clients and `Adapters/` for framework bridges. WatchConnectivity is a framework bridge → renamed to `WatchBridgeAdapter` and placed in `Domain/Adapters/` (matches `CloudKitSyncAdapter`).
- Spec referenced `Domain/Models/`; the project uses `Domain/Entities/`. Files placed in `Entities/`.
