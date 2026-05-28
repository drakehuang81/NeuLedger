# Apple Watch Phase 2 — Watch App Quick-Record Flow

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the watchOS 3-step quick-record flow (category → amount → confirm), the WC bridge that consumes the iPhone-pushed snapshot and ships drafts back, and a TCA reducer + Views wired up inside the new `NeuLedgerWatch Watch App` target.

**Architecture:** All Watch-side code lives in the `WatchFeatures` SPM target (depends on Domain + Common + TCA, NOT Core). `WatchCacheStore` reads/writes the App Group `group.com.drake.NeuLedger` UserDefaults; `WatchSessionGateway` is the Watch-side WCSessionDelegate; Watch-flavored `liveValue`s for `TransactionClient`/`CategoryClient`/`AccountClient` are registered via `prepareDependencies` in `NeuLedgerWatchApp.init()`. `WatchRecordFeature` is a TCA reducer with stack-based navigation; three SwiftUI views ride its `Path`.

**Tech Stack:** Swift 6, SwiftUI on watchOS 26, WatchConnectivity (Watch side), TCA 1.23.1, Swift Testing.

**Reference spec:** `docs/superpowers/specs/2026-05-27-apple-watch-design.md` (§3, §5)

**Reference plan:** `docs/superpowers/plans/2026-05-27-apple-watch-phase1.md` (Phase 1 wired the iPhone side)

**Pre-existing scaffold** (already on `feature/apple-watch-phase1` branch):
- `NeuLedgerWatch Watch App` Xcode target with App Group `group.com.drake.NeuLedger`
- `NeuLedgerWatchTests` Swift Testing target hosted by the Watch app
- `WatchFeatures` SPM target with placeholder `Features/Sources/WatchFeatures/Placeholder.swift`
- Watch app links `WatchFeatures`
- Domain compiles for watchOS (AI files gated by `#if canImport(FoundationModels)`)
- Common compiles for watchOS (color tokens gated by `#if os(iOS)`)

**Watch simulator used in commands:** `Apple Watch Series 11 (46mm)`

---

## File Structure

```
Features/Sources/WatchFeatures/
├── Persistence/
│   └── WatchCacheStore.swift               ← Task 1
├── Connectivity/
│   ├── WatchPhoneTransport.swift           ← Task 2 (protocol)
│   ├── WatchPhoneTransport+Live.swift      ← Task 2 (live)
│   └── WatchSessionGateway.swift           ← Task 2 (delegate logic)
├── Clients/
│   ├── WatchTransactionClient.swift        ← Task 3
│   ├── WatchCategoryClient.swift           ← Task 4
│   ├── WatchAccountClient.swift            ← Task 4
│   └── WatchDependencies.swift             ← Task 4 (registration helper)
└── Record/
    ├── WatchRecordFeature.swift            ← Task 5
    ├── WatchRootView.swift                 ← Task 6
    ├── CategoryGridView.swift              ← Task 6
    ├── AmountKeypadView.swift              ← Task 7
    └── ConfirmView.swift                   ← Task 8

NeuLedgerWatch Watch App/
├── NeuLedgerWatchApp.swift                 ← Task 9 (modify)
└── ContentView.swift                       ← Task 9 (delete)

NeuLedgerWatchTests/
├── WatchCacheStoreTests.swift              ← Task 1
├── WatchSessionGatewayTests.swift          ← Task 2
├── WatchTransactionClientTests.swift       ← Task 3
├── WatchCategoryClientTests.swift          ← Task 4
├── WatchAccountClientTests.swift           ← Task 4
└── WatchRecordFeatureTests.swift           ← Task 5
```

Remove `NeuLedgerWatchTests.swift` (the auto-generated example) in Task 1 or as part of the first real test commit.
Remove `Features/Sources/WatchFeatures/Placeholder.swift` once `WatchCacheStore.swift` exists (Task 1 commit).

---

## Wire format reference (kept in sync with Phase 1's `WatchSessionDelegate`)

- **iPhone → Watch (snapshot push)**, via `WCSession.updateApplicationContext`:
  ```
  ["v": 1, "snapshot": <Data — JSON-encoded WatchContextSnapshot>]
  ```
- **Watch → iPhone (draft send)**, via `WCSession.transferUserInfo`:
  ```
  ["op": "addTx", "payload": <Data — JSON-encoded TransactionDraft>]
  ```

---

## Test command reference

Run a single suite:

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/<SuiteName>
```

Run the whole test bundle:

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Build the Watch app:

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

iOS still builds (regression gate):

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Task 1: `WatchCacheStore`

**Files:**
- Create: `Features/Sources/WatchFeatures/Persistence/WatchCacheStore.swift`
- Create: `NeuLedgerWatchTests/WatchCacheStoreTests.swift`
- Delete: `Features/Sources/WatchFeatures/Placeholder.swift`
- Delete: `NeuLedgerWatchTests/NeuLedgerWatchTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `NeuLedgerWatchTests/WatchCacheStoreTests.swift`:

```swift
import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("WatchCacheStore Tests")
struct WatchCacheStoreTests {

    private func makeStore() -> (WatchCacheStore, UserDefaults) {
        let suite = "WatchCacheStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (WatchCacheStore(defaults: defaults), defaults)
    }

    private func makeSnapshot(
        todayTotal: Decimal = 480,
        defaultAccountId: UUID = UUID()
    ) -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [
                Category(id: UUID(), name: "Food", icon: "fork.knife",
                         color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true)
            ],
            accounts: [
                Account(id: defaultAccountId, name: "Cash", type: .cash,
                        icon: "banknote", color: "#34C759", sortOrder: 0,
                        isArchived: false, createdAt: Date(timeIntervalSince1970: 0))
            ],
            defaultAccountId: defaultAccountId,
            todayTotal: todayTotal,
            todayCount: 2,
            monthBudgetProgress: 0.62,
            snapshotAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("Reading an empty store returns nil")
    func emptyStoreReturnsNil() {
        let (store, _) = makeStore()
        #expect(store.load() == nil)
    }

    @Test("Saved snapshot round-trips through UserDefaults")
    func savedSnapshotRoundTrips() {
        let (store, _) = makeStore()
        let original = makeSnapshot()
        store.save(original)
        let loaded = store.load()
        #expect(loaded == original)
    }

    @Test("Saving overwrites previous snapshot")
    func savingOverwritesPrevious() {
        let (store, _) = makeStore()
        store.save(makeSnapshot(todayTotal: 100))
        store.save(makeSnapshot(todayTotal: 999))
        #expect(store.load()?.todayTotal == 999)
    }

    @Test("Saved snapshot survives a fresh store opened on the same defaults")
    func persistsAcrossInstances() {
        let suite = "WatchCacheStoreTests.Persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let snapshot = makeSnapshot(todayTotal: 250)
        WatchCacheStore(defaults: defaults).save(snapshot)

        let reopened = WatchCacheStore(defaults: defaults).load()
        #expect(reopened?.todayTotal == 250)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/WatchCacheStoreTests
```
Expected: FAIL — "cannot find 'WatchCacheStore' in scope".

- [ ] **Step 3: Delete placeholders + write implementation**

Delete:
```
rm Features/Sources/WatchFeatures/Placeholder.swift
rm NeuLedgerWatchTests/NeuLedgerWatchTests.swift
```

Create `Features/Sources/WatchFeatures/Persistence/WatchCacheStore.swift`:

```swift
import Foundation
import Domain

/// `WatchContextSnapshot` persisted in the Watch-side App Group's
/// `UserDefaults`, so the Watch app and (Phase 3) the Complication
/// widget extension can read the same latest snapshot.
///
/// Always writes the full snapshot — iPhone never sends deltas (see
/// `WatchContextSnapshot` doc comment).
public final class WatchCacheStore: @unchecked Sendable {

    /// App Group identifier configured on the watchOS target.
    /// Matches the entitlement set up in Phase 2 scaffold.
    public static let appGroupSuite = "group.com.drake.NeuLedger"

    private static let storageKey = "watch.context_snapshot.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = UserDefaults(suiteName: WatchCacheStore.appGroupSuite) ?? .standard) {
        self.defaults = defaults
    }

    public func load() -> WatchContextSnapshot? {
        lock.lock(); defer { lock.unlock() }
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(WatchContextSnapshot.self, from: data)
    }

    public func save(_ snapshot: WatchContextSnapshot) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same `xcodebuild test` command. Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```
git add Features/Sources/WatchFeatures/Persistence/WatchCacheStore.swift \
        NeuLedgerWatchTests/WatchCacheStoreTests.swift
git rm Features/Sources/WatchFeatures/Placeholder.swift \
       NeuLedgerWatchTests/NeuLedgerWatchTests.swift
git commit -m "$(cat <<'EOF'
feat(watch): add WatchCacheStore for snapshot persistence [ci skip]

UserDefaults-backed cache keyed under the Watch app group
group.com.drake.NeuLedger. Phase 3 Complication will read the same
snapshot via the same suite. Replaces the WatchFeatures placeholder
and the auto-generated NeuLedgerWatchTests stub.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `WatchSessionGateway` (Watch-side WC delegate)

**Files:**
- Create: `Features/Sources/WatchFeatures/Connectivity/WatchPhoneTransport.swift`
- Create: `Features/Sources/WatchFeatures/Connectivity/WatchPhoneTransport+Live.swift`
- Create: `Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift`
- Create: `NeuLedgerWatchTests/WatchSessionGatewayTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `NeuLedgerWatchTests/WatchSessionGatewayTests.swift`:

```swift
import Foundation
import Testing
import Domain
import ConcurrencyExtras
@testable import WatchFeatures

@Suite("WatchSessionGateway Tests")
struct WatchSessionGatewayTests {

    final class FakeTransport: WatchPhoneTransport, @unchecked Sendable {
        var isActivated = false
        var isReachable = true

        let sentUserInfo = LockIsolated<[[String: Any]]>([])
        private var contextHandler: (@Sendable ([String: Any]) -> Void)?

        func activate() { isActivated = true }
        func sendUserInfo(_ payload: [String: Any]) {
            sentUserInfo.withValue { $0.append(payload) }
        }
        func onReceiveApplicationContext(
            _ handler: @escaping @Sendable ([String: Any]) -> Void
        ) {
            contextHandler = handler
        }
        func deliverContext(_ payload: [String: Any]) {
            contextHandler?(payload)
        }
    }

    private func makeCacheStore() -> WatchCacheStore {
        let suite = "WatchSessionGatewayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WatchCacheStore(defaults: defaults)
    }

    private func makeSnapshot() -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [], accounts: [], defaultAccountId: UUID(),
            todayTotal: 420, todayCount: 1, monthBudgetProgress: nil,
            snapshotAt: Date()
        )
    }

    @Test("Inbound application context decodes and writes the cache")
    func inboundContextWritesCache() async throws {
        let transport = FakeTransport()
        let cache = makeCacheStore()
        let gateway = WatchSessionGateway(transport: transport, cache: cache)
        gateway.start()

        let snapshot = makeSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        transport.deliverContext(["v": 1, "snapshot": data])

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(cache.load()?.todayTotal == 420)
    }

    @Test("Malformed inbound context is ignored without writing cache")
    func malformedInboundIsIgnored() async throws {
        let transport = FakeTransport()
        let cache = makeCacheStore()
        let gateway = WatchSessionGateway(transport: transport, cache: cache)
        gateway.start()

        transport.deliverContext(["v": 1, "snapshot": "not-data"])
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(cache.load() == nil)
    }

    @Test("Outbound draft is encoded under op=addTx and sent via transport")
    func outboundDraftIsSent() throws {
        let transport = FakeTransport()
        let cache = makeCacheStore()
        let gateway = WatchSessionGateway(transport: transport, cache: cache)
        let draft = TransactionDraft(
            categoryId: UUID(), accountId: UUID(), amount: 480
        )

        gateway.send(draft: draft)

        let sent = transport.sentUserInfo.value
        #expect(sent.count == 1)
        #expect(sent.first?["op"] as? String == "addTx")
        guard let data = sent.first?["payload"] as? Data else {
            Issue.record("payload missing or wrong type"); return
        }
        let decoded = try JSONDecoder().decode(TransactionDraft.self, from: data)
        #expect(decoded == draft)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/WatchSessionGatewayTests
```
Expected: FAIL — multiple "cannot find" errors.

- [ ] **Step 3: Implement the protocol**

Create `Features/Sources/WatchFeatures/Connectivity/WatchPhoneTransport.swift`:

```swift
import Foundation

/// Watch-side seam over `WCSession`. Mirrors Phase 1's iPhone-side
/// `WatchSessionTransport` (in Core) but with reversed traffic
/// direction:
///
/// - Watch **receives** snapshots via `onReceiveApplicationContext`
///   (iPhone pushes through `updateApplicationContext`).
/// - Watch **sends** drafts via `sendUserInfo` (queued by
///   `transferUserInfo`; survives reachability outages).
///
/// Apple does not expose a protocol form of `WCSession`; this protocol
/// is the minimum surface our delegate uses, mockable in tests.
public protocol WatchPhoneTransport: AnyObject, Sendable {

    /// `true` once `WCSession.activate()` has reported `.activated`.
    var isActivated: Bool { get }

    /// `true` if the iPhone counterpart is currently reachable for
    /// immediate `sendMessage` traffic. Not required for our flow
    /// (we use `transferUserInfo`), exposed for diagnostics.
    var isReachable: Bool { get }

    /// Begin the activation handshake. Idempotent.
    func activate()

    /// Enqueue a payload to the iPhone via `transferUserInfo`. The OS
    /// retries until delivered, so callers don't need their own
    /// backoff.
    func sendUserInfo(_ payload: [String: Any])

    /// Register a handler for inbound `updateApplicationContext`
    /// pushes. Setting a new handler replaces the previous one.
    func onReceiveApplicationContext(
        _ handler: @escaping @Sendable ([String: Any]) -> Void
    )
}
```

Create `Features/Sources/WatchFeatures/Connectivity/WatchPhoneTransport+Live.swift`:

```swift
#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// `WCSession`-backed Watch-side transport. Also serves as the
/// `WCSessionDelegate`.
public final class LiveWatchPhoneTransport: NSObject, WatchPhoneTransport, WCSessionDelegate, @unchecked Sendable {

    public static let shared = LiveWatchPhoneTransport()

    private let lock = NSLock()
    private var contextHandler: (@Sendable ([String: Any]) -> Void)?
    private var didActivate = false

    public var isActivated: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.activationState == .activated
    }

    public var isReachable: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isReachable
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

    public func sendUserInfo(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(payload)
    }

    public func onReceiveApplicationContext(
        _ handler: @escaping @Sendable ([String: Any]) -> Void
    ) {
        lock.lock(); defer { lock.unlock() }
        contextHandler = handler
    }

    // MARK: WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let handler: (@Sendable ([String: Any]) -> Void)? = {
            lock.lock(); defer { lock.unlock() }
            return contextHandler
        }()
        handler?(context)
    }
}
#endif
```

Create `Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift`:

```swift
import Foundation
import Domain
#if canImport(WatchKit)
import WatchKit
#endif

/// The Watch app's single point of contact with the iPhone over
/// WatchConnectivity.
///
/// On `start()`:
/// - registers an inbound handler that decodes incoming
///   `WatchContextSnapshot` payloads and writes them to `WatchCacheStore`
/// - (Phase 3) will also call `WidgetCenter.reloadAllTimelines()` so the
///   Complication picks up the new today-total
///
/// `send(draft:)` ships a `TransactionDraft` back to the iPhone under
/// the wire envelope `{op: "addTx", payload: Data}`.
public final class WatchSessionGateway: @unchecked Sendable {

    private let transport: WatchPhoneTransport
    private let cache: WatchCacheStore

    public init(transport: WatchPhoneTransport, cache: WatchCacheStore) {
        self.transport = transport
        self.cache = cache
    }

    /// Begin listening for inbound snapshots. Activates the underlying
    /// transport if it hasn't been yet.
    public func start() {
        transport.activate()
        transport.onReceiveApplicationContext { [weak self] payload in
            self?.handleContext(payload)
        }
    }

    /// Ship a draft to the iPhone. Idempotent on the iPhone side
    /// (`ProcessedDraftIdsStore` dedups via `TransactionDraft.id`).
    public func send(draft: TransactionDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        transport.sendUserInfo([
            "op": "addTx",
            "payload": data
        ])
    }

    private func handleContext(_ payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data else { return }
        guard let snapshot = try? JSONDecoder().decode(WatchContextSnapshot.self, from: data) else { return }
        cache.save(snapshot)
        #if canImport(WidgetKit)
        // Phase 3 will uncomment:
        // WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/WatchSessionGatewayTests
```
Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```
git add Features/Sources/WatchFeatures/Connectivity/ \
        NeuLedgerWatchTests/WatchSessionGatewayTests.swift
git commit -m "$(cat <<'EOF'
feat(watch): add WatchSessionGateway for Watch ↔ iPhone WC traffic [ci skip]

WatchPhoneTransport is the protocol seam (mirroring Phase 1's iPhone-
side WatchSessionTransport but with reversed traffic). LiveTransport
wraps WCSession; WatchSessionGateway routes inbound snapshots to
WatchCacheStore and outbound drafts to transferUserInfo under the
{op: addTx, payload: Data} envelope.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Watch-flavored `TransactionClient`

**Files:**
- Create: `Features/Sources/WatchFeatures/Clients/WatchTransactionClient.swift`
- Create: `NeuLedgerWatchTests/WatchTransactionClientTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `NeuLedgerWatchTests/WatchTransactionClientTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
import Domain
import ConcurrencyExtras
@testable import WatchFeatures

@Suite("WatchTransactionClient Tests")
struct WatchTransactionClientTests {

    final class FakeGateway: WatchDraftSender, @unchecked Sendable {
        let sent = LockIsolated<[TransactionDraft]>([])
        func send(draft: TransactionDraft) {
            sent.withValue { $0.append(draft) }
        }
    }

    @Test("add converts Transaction to TransactionDraft and forwards to the gateway")
    func addForwardsToGateway() async throws {
        let gateway = FakeGateway()
        let client = TransactionClient.watchLive(gateway: gateway)

        let tx = Transaction(
            id: UUID(),
            amount: 250,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            categoryId: UUID(),
            accountId: UUID(),
            type: .expense
        )

        try await client.add(tx)

        let sent = gateway.sent.value
        #expect(sent.count == 1)
        #expect(sent.first?.id == tx.id)
        #expect(sent.first?.amount == 250)
        #expect(sent.first?.categoryId == tx.categoryId)
        #expect(sent.first?.accountId == tx.accountId)
    }

    @Test("add drops a transaction whose categoryId is nil")
    func addDropsTransactionWithNilCategory() async throws {
        let gateway = FakeGateway()
        let client = TransactionClient.watchLive(gateway: gateway)

        let tx = Transaction(
            amount: 100,
            date: Date(),
            categoryId: nil,
            accountId: UUID(),
            type: .expense
        )

        // Should not throw, just no-op.
        try await client.add(tx)
        #expect(gateway.sent.value.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/WatchTransactionClientTests
```
Expected: FAIL.

- [ ] **Step 3: Write implementation**

Create `Features/Sources/WatchFeatures/Clients/WatchTransactionClient.swift`:

```swift
import Foundation
import Dependencies
import Domain

/// Minimal protocol the Watch-flavored `TransactionClient` needs from
/// `WatchSessionGateway`. Lets the client be unit-tested with a fake
/// without pulling the full gateway into tests.
public protocol WatchDraftSender: Sendable {
    func send(draft: TransactionDraft)
}

extension WatchSessionGateway: WatchDraftSender {}

extension TransactionClient {

    /// Watch-side live value. Only `add` is implemented — Watch UI has
    /// no entry points for fetch/update/delete/analytics, so those keys
    /// remain at their `@DependencyClient` unimplemented defaults and
    /// will trap if called.
    public static func watchLive(gateway: WatchDraftSender) -> TransactionClient {
        var client = TransactionClient()
        client.add = { @Sendable transaction in
            guard let categoryId = transaction.categoryId else { return }
            let draft = TransactionDraft(
                id: transaction.id,
                categoryId: categoryId,
                accountId: transaction.accountId,
                amount: transaction.amount,
                date: transaction.date
            )
            gateway.send(draft: draft)
        }
        return client
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same `xcodebuild test` command. Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```
git add Features/Sources/WatchFeatures/Clients/WatchTransactionClient.swift \
        NeuLedgerWatchTests/WatchTransactionClientTests.swift
git commit -m "$(cat <<'EOF'
feat(watch): add Watch-side TransactionClient.watchLive [ci skip]

Only implements add — Watch has no fetch/update/delete entry points,
so other keys stay at @DependencyClient's unimplemented defaults.
WatchDraftSender protocol decouples the client from the gateway so
tests can inject a fake.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Watch-flavored `CategoryClient` + `AccountClient` + dependency registration helper

**Files:**
- Create: `Features/Sources/WatchFeatures/Clients/WatchCategoryClient.swift`
- Create: `Features/Sources/WatchFeatures/Clients/WatchAccountClient.swift`
- Create: `Features/Sources/WatchFeatures/Clients/WatchDependencies.swift`
- Create: `NeuLedgerWatchTests/WatchCategoryClientTests.swift`
- Create: `NeuLedgerWatchTests/WatchAccountClientTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `NeuLedgerWatchTests/WatchCategoryClientTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
import Domain
@testable import WatchFeatures

@Suite("WatchCategoryClient Tests")
struct WatchCategoryClientTests {

    private func makeCache(with categories: [Category]) -> WatchCacheStore {
        let suite = "WatchCategoryClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = WatchCacheStore(defaults: defaults)
        store.save(WatchContextSnapshot(
            categories: categories, accounts: [], defaultAccountId: UUID(),
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date()
        ))
        return store
    }

    @Test("fetchAll returns the categories from the cached snapshot")
    func fetchAllReturnsCachedCategories() async throws {
        let category = Category(
            id: UUID(), name: "Food", icon: "fork.knife",
            color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true
        )
        let cache = makeCache(with: [category])
        let client = CategoryClient.watchLive(cache: cache)

        let categories = try await client.fetchAll()
        #expect(categories == [category])
    }

    @Test("fetch(.expense) filters out non-expense categories")
    func fetchExpenseFiltersIncomeCategories() async throws {
        let expense = Category(
            id: UUID(), name: "Food", icon: "fork.knife",
            color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true
        )
        let income = Category(
            id: UUID(), name: "Salary", icon: "dollarsign.circle",
            color: "#34C759", type: .income, sortOrder: 0, isDefault: true
        )
        let cache = makeCache(with: [expense, income])
        let client = CategoryClient.watchLive(cache: cache)

        let filtered = try await client.fetch(.expense)
        #expect(filtered == [expense])
    }

    @Test("fetchAll returns empty when cache has no snapshot")
    func fetchAllEmptyWhenCacheEmpty() async throws {
        let suite = "WatchCategoryClientTests.Empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let cache = WatchCacheStore(defaults: defaults)
        let client = CategoryClient.watchLive(cache: cache)

        let categories = try await client.fetchAll()
        #expect(categories.isEmpty)
    }
}
```

Create `NeuLedgerWatchTests/WatchAccountClientTests.swift`:

```swift
import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("WatchAccountClient Tests")
struct WatchAccountClientTests {

    private func makeCache(with accounts: [Account]) -> WatchCacheStore {
        let suite = "WatchAccountClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = WatchCacheStore(defaults: defaults)
        store.save(WatchContextSnapshot(
            categories: [], accounts: accounts, defaultAccountId: accounts.first?.id ?? UUID(),
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date()
        ))
        return store
    }

    @Test("fetchActive returns the accounts from the cached snapshot")
    func fetchActiveReturnsCachedAccounts() async throws {
        let cash = Account(
            id: UUID(), name: "Cash", type: .cash, icon: "banknote",
            color: "#34C759", sortOrder: 0, isArchived: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let cache = makeCache(with: [cash])
        let client = AccountClient.watchLive(cache: cache)

        let accounts = try await client.fetchActive()
        #expect(accounts == [cash])
    }

    @Test("fetchActive returns empty when cache is empty")
    func fetchActiveEmptyWhenCacheEmpty() async throws {
        let suite = "WatchAccountClientTests.Empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let cache = WatchCacheStore(defaults: defaults)
        let client = AccountClient.watchLive(cache: cache)

        let accounts = try await client.fetchActive()
        #expect(accounts.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/WatchCategoryClientTests \
  -only-testing:NeuLedgerWatchTests/WatchAccountClientTests
```
Expected: FAIL.

- [ ] **Step 3: Write implementations**

Create `Features/Sources/WatchFeatures/Clients/WatchCategoryClient.swift`:

```swift
import Foundation
import Domain

extension CategoryClient {

    /// Watch-side live value. All read methods consult `WatchCacheStore`;
    /// mutation methods remain at their `@DependencyClient` defaults
    /// because Watch has no UI for category mutation.
    public static func watchLive(cache: WatchCacheStore) -> CategoryClient {
        var client = CategoryClient()
        client.fetchAll = { @Sendable in
            cache.load()?.categories ?? []
        }
        client.fetch = { @Sendable type in
            (cache.load()?.categories ?? []).filter { $0.type == type }
        }
        return client
    }
}
```

Create `Features/Sources/WatchFeatures/Clients/WatchAccountClient.swift`:

```swift
import Foundation
import Domain

extension AccountClient {

    /// Watch-side live value. Read methods consult `WatchCacheStore`;
    /// mutation methods stay unimplemented (Watch has no entry point for
    /// editing accounts).
    public static func watchLive(cache: WatchCacheStore) -> AccountClient {
        var client = AccountClient()
        client.fetchAll = { @Sendable in
            cache.load()?.accounts ?? []
        }
        client.fetchActive = { @Sendable in
            (cache.load()?.accounts ?? []).filter { $0.isArchived == false }
        }
        return client
    }
}
```

Create `Features/Sources/WatchFeatures/Clients/WatchDependencies.swift`:

```swift
import Foundation
import Dependencies
import Domain

/// Wires the Watch-flavored live values onto `DependencyValues` so any
/// reducer that takes `@Dependency(\.transactionClient)` etc. behaves
/// correctly when running inside the watchOS app.
///
/// Called from `NeuLedgerWatchApp.init()` via TCA's `prepareDependencies`.
public enum WatchDependencies {

    public static func register(in dependencies: inout DependencyValues) {
        let cache = WatchCacheStore()
        let gateway = WatchSessionGateway(
            transport: LiveWatchPhoneTransport.shared,
            cache: cache
        )
        gateway.start()

        dependencies.transactionClient = .watchLive(gateway: gateway)
        dependencies.categoryClient = .watchLive(cache: cache)
        dependencies.accountClient = .watchLive(cache: cache)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same `xcodebuild test` command. Expected: PASS (3 from CategoryClient + 2 from AccountClient).

- [ ] **Step 5: Commit**

```
git add Features/Sources/WatchFeatures/Clients/ \
        NeuLedgerWatchTests/WatchCategoryClientTests.swift \
        NeuLedgerWatchTests/WatchAccountClientTests.swift
git commit -m "$(cat <<'EOF'
feat(watch): add cache-backed CategoryClient + AccountClient live values [ci skip]

WatchCategoryClient and WatchAccountClient read from WatchCacheStore so
the Watch UI never needs SwiftData. Mutation methods stay at their
@DependencyClient unimplemented defaults (Watch has no editor UI).
WatchDependencies.register() wires the three Watch-flavored live values
+ the live gateway into DependencyValues at app start.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `WatchRecordFeature` TCA reducer

**Files:**
- Create: `Features/Sources/WatchFeatures/Record/WatchRecordFeature.swift`
- Create: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
import ConcurrencyExtras
@testable import WatchFeatures

@MainActor
@Suite("WatchRecordFeature Tests")
struct WatchRecordFeatureTests {

    private static let foodCategory = Category(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Food", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: true
    )

    private static let transportCategory = Category(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Transport", icon: "car", color: "#5AC8FA",
        type: .expense, sortOrder: 1, isDefault: true
    )

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

    @Test("Loading state populates categories, default account, and accounts")
    func loadingPopulatesState() async {
        let store = TestStore(initialState: WatchRecordFeature.State()) {
            WatchRecordFeature()
        } withDependencies: {
            $0.categoryClient.fetch = { @Sendable type in
                type == .expense ? [Self.foodCategory, Self.transportCategory] : []
            }
            $0.accountClient.fetchActive = { @Sendable in
                [Self.cashAccount, Self.cardAccount]
            }
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.categories = [Self.foodCategory, Self.transportCategory]
            $0.accounts = [Self.cashAccount, Self.cardAccount]
            $0.defaultAccountId = Self.cashAccount.id
        }
    }

    @Test("Selecting a category advances to amount step")
    func selectingCategoryAdvancesToAmount() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.categoryTapped(Self.foodCategory.id)) {
            $0.draft = WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: nil
            )
            $0.step = .amount
        }
    }

    @Test("Confirming a draft sends to transactionClient and resets state")
    func confirmingSendsAndResets() async {
        let added = LockIsolated<[Transaction]>([])

        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id,
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 480
                ),
                step: .confirm
            )
        ) {
            WatchRecordFeature()
        } withDependencies: {
            $0.transactionClient.add = { @Sendable tx in
                added.withValue { $0.append(tx) }
            }
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .incrementing
        }

        await store.send(.confirmTapped)
        await store.receive(\.draftSent) {
            $0.draft = nil
            $0.step = .category
        }

        let committed = added.value
        #expect(committed.count == 1)
        #expect(committed.first?.amount == 480)
        #expect(committed.first?.categoryId == Self.foodCategory.id)
        #expect(committed.first?.accountId == Self.cashAccount.id)
        #expect(committed.first?.type == .expense)
    }

    @Test("Long-press picks account override that's used in the next draft")
    func longPressAccountOverride() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount, Self.cardAccount],
                defaultAccountId: Self.cashAccount.id
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.categoryLongPressed(Self.foodCategory.id)) {
            $0.accountPickerForCategoryId = Self.foodCategory.id
        }
        await store.send(.accountPicked(Self.cardAccount.id)) {
            $0.accountPickerForCategoryId = nil
            $0.draft = WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: Self.cardAccount.id
            )
            $0.step = .amount
        }
    }

    @Test("Amount input appends digit and respects 7-digit cap")
    func amountAppendsAndCaps() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                draft: WatchRecordFeature.Draft(categoryId: UUID(), accountIdOverride: nil),
                step: .amount
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.amountDigit(4)) {
            $0.draft?.amount = 4
        }
        await store.send(.amountDigit(8)) {
            $0.draft?.amount = 48
        }
        await store.send(.amountDigit(0)) {
            $0.draft?.amount = 480
        }
        await store.send(.amountBackspace) {
            $0.draft?.amount = 48
        }

        // Cap at 7 digits.
        await store.send(.amountDigit(0))   // 480
        await store.send(.amountDigit(0))   // 4800
        await store.send(.amountDigit(0))   // 48000
        await store.send(.amountDigit(0))   // 480000
        await store.send(.amountDigit(0))   // 4800000
        await store.send(.amountDigit(0))   // 48000000 — should be capped to 9999999

        // Final amount should not exceed 9,999,999.
        #expect((store.state.draft?.amount ?? 0) <= 9_999_999)
    }

    @Test("Cancel from confirm clears draft and returns to category")
    func cancelClearsDraft() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id,
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 100
                ),
                step: .confirm
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.cancelTapped) {
            $0.draft = nil
            $0.step = .category
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -only-testing:NeuLedgerWatchTests/WatchRecordFeatureTests
```
Expected: FAIL.

- [ ] **Step 3: Write implementation**

Create `Features/Sources/WatchFeatures/Record/WatchRecordFeature.swift`:

```swift
import Foundation
import ComposableArchitecture
import Domain

/// Apple Watch quick-record reducer. Drives the 3-step flow
/// (category → amount → confirm) plus the long-press-to-pick-account
/// override.
@Reducer
public struct WatchRecordFeature: Sendable {

    /// Where in the flow the user currently is.
    @CasePathable
    public enum Step: Equatable, Sendable {
        case category
        case amount
        case confirm
    }

    /// In-flight draft assembled by the user. Reset to nil after
    /// send/cancel.
    public struct Draft: Equatable, Sendable {
        public var categoryId: UUID
        public var accountIdOverride: UUID?
        public var amount: Decimal

        public init(categoryId: UUID, accountIdOverride: UUID?, amount: Decimal = 0) {
            self.categoryId = categoryId
            self.accountIdOverride = accountIdOverride
            self.amount = amount
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var categories: [Category]
        public var accounts: [Account]
        public var defaultAccountId: UUID?
        public var draft: Draft?
        public var step: Step
        public var accountPickerForCategoryId: UUID?

        public init(
            categories: [Category] = [],
            accounts: [Account] = [],
            defaultAccountId: UUID? = nil,
            draft: Draft? = nil,
            step: Step = .category,
            accountPickerForCategoryId: UUID? = nil
        ) {
            self.categories = categories
            self.accounts = accounts
            self.defaultAccountId = defaultAccountId
            self.draft = draft
            self.step = step
            self.accountPickerForCategoryId = accountPickerForCategoryId
        }

        /// The category the user is currently working on, derived from
        /// the active draft. `nil` if no draft is in flight.
        public var activeCategory: Category? {
            guard let id = draft?.categoryId else { return nil }
            return categories.first { $0.id == id }
        }

        /// The account that will own the in-flight draft — the override
        /// if set, otherwise the global default.
        public var activeAccountId: UUID? {
            draft?.accountIdOverride ?? defaultAccountId
        }

        public var activeAccount: Account? {
            guard let id = activeAccountId else { return nil }
            return accounts.first { $0.id == id }
        }
    }

    public enum Action: Sendable {
        case task
        case loaded(categories: [Category], accounts: [Account], defaultAccountId: UUID?)

        case categoryTapped(UUID)
        case categoryLongPressed(UUID)
        case accountPickerDismissed
        case accountPicked(UUID)

        case amountDigit(Int)
        case amountBackspace
        case amountConfirmed

        case confirmTapped
        case cancelTapped
        case draftSent
    }

    private static let amountCap: Decimal = 9_999_999

    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { send in
                    async let categories = (try? await categoryClient.fetch(.expense)) ?? []
                    async let accounts = (try? await accountClient.fetchActive()) ?? []
                    let cats = await categories
                    let accs = await accounts
                    await send(.loaded(
                        categories: cats,
                        accounts: accs,
                        defaultAccountId: accs.first?.id
                    ))
                }

            case let .loaded(categories, accounts, defaultAccountId):
                state.categories = categories
                state.accounts = accounts
                state.defaultAccountId = defaultAccountId
                return .none

            case let .categoryTapped(id):
                state.draft = Draft(categoryId: id, accountIdOverride: nil)
                state.step = .amount
                return .none

            case let .categoryLongPressed(id):
                state.accountPickerForCategoryId = id
                return .none

            case .accountPickerDismissed:
                state.accountPickerForCategoryId = nil
                return .none

            case let .accountPicked(accountId):
                guard let categoryId = state.accountPickerForCategoryId else { return .none }
                state.accountPickerForCategoryId = nil
                state.draft = Draft(categoryId: categoryId, accountIdOverride: accountId)
                state.step = .amount
                return .none

            case let .amountDigit(digit):
                guard var draft = state.draft else { return .none }
                let candidate = draft.amount * 10 + Decimal(digit)
                draft.amount = min(candidate, Self.amountCap)
                state.draft = draft
                return .none

            case .amountBackspace:
                guard var draft = state.draft else { return .none }
                let truncated = (draft.amount as NSDecimalNumber).intValue / 10
                draft.amount = Decimal(truncated)
                state.draft = draft
                return .none

            case .amountConfirmed:
                guard state.draft?.amount ?? 0 > 0 else { return .none }
                state.step = .confirm
                return .none

            case .confirmTapped:
                guard let draft = state.draft,
                      let accountId = state.activeAccountId else { return .none }
                let nowDate = now
                let transaction = Transaction(
                    id: UUID(),
                    amount: draft.amount,
                    date: nowDate,
                    categoryId: draft.categoryId,
                    accountId: accountId,
                    type: .expense
                )
                return .run { send in
                    try? await transactionClient.add(transaction)
                    await send(.draftSent)
                }

            case .cancelTapped:
                state.draft = nil
                state.step = .category
                return .none

            case .draftSent:
                state.draft = nil
                state.step = .category
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same `xcodebuild test` command. Expected: PASS (6/6).

- [ ] **Step 5: Commit**

```
git add Features/Sources/WatchFeatures/Record/WatchRecordFeature.swift \
        NeuLedgerWatchTests/WatchRecordFeatureTests.swift
git commit -m "$(cat <<'EOF'
feat(watch): add WatchRecordFeature reducer [ci skip]

TCA reducer driving category → amount → confirm. Long-press on a
category opens an account picker that sets a per-draft override.
Amount input enforces a 7-digit cap (NT$ 9,999,999). Confirm calls
transactionClient.add (which on Watch forwards to the gateway and ships
a TransactionDraft to the iPhone). After send the state resets to the
category step.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `WatchRootView` + `CategoryGridView` (Screen 1)

**Files:**
- Create: `Features/Sources/WatchFeatures/Record/WatchRootView.swift`
- Create: `Features/Sources/WatchFeatures/Record/CategoryGridView.swift`

No unit tests on the SwiftUI views (Phase 4 covers manual visual review on simulator). Smoke build is the gate.

- [ ] **Step 1: Implement the root view**

Create `Features/Sources/WatchFeatures/Record/WatchRootView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import Domain

/// Top-level view for the Apple Watch quick-record flow. Routes between
/// the three steps based on `state.step`.
public struct WatchRootView: View {

    @Bindable public var store: StoreOf<WatchRecordFeature>

    public init(store: StoreOf<WatchRecordFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.step {
            case .category:
                CategoryGridView(store: store)
            case .amount:
                AmountKeypadView(store: store)
            case .confirm:
                ConfirmView(store: store)
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(
            isPresented: Binding(
                get: { store.accountPickerForCategoryId != nil },
                set: { newValue in
                    if newValue == false { store.send(.accountPickerDismissed) }
                }
            )
        ) {
            AccountPickerSheet(store: store)
        }
    }
}

/// Sheet content for long-press account override.
struct AccountPickerSheet: View {

    let store: StoreOf<WatchRecordFeature>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(store.accounts, id: \.id) { account in
                    Button {
                        store.send(.accountPicked(account.id))
                    } label: {
                        HStack {
                            Image(systemName: account.icon)
                                .foregroundStyle(Color.Design.fromHex(account.color))
                            Text(account.name)
                                .font(Font.Design.body)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
```

- [ ] **Step 2: Implement Screen 1 (category grid)**

Create `Features/Sources/WatchFeatures/Record/CategoryGridView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import Domain

/// Screen 1: a 3-column grid of expense categories. Tap → pick;
/// long-press → open the per-draft account picker.
struct CategoryGridView: View {

    let store: StoreOf<WatchRecordFeature>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        ScrollView {
            if store.categories.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(store.categories, id: \.id) { category in
                        categoryButton(category)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .navigationTitle("記一筆")
    }

    private func categoryButton(_ category: Category) -> some View {
        Button {
            store.send(.categoryTapped(category.id))
        } label: {
            ZStack {
                Circle()
                    .fill(Color.Design.fromHex(category.color).opacity(0.25))
                Image(systemName: category.icon)
                    .font(Font.Design.size22SemiboldRounded)
                    .foregroundStyle(Color.Design.fromHex(category.color))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4) {
            store.send(.categoryLongPressed(category.id))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3.slash")
                .font(Font.Design.size22SemiboldRounded)
            Text("請先在 iPhone 開啟並設定分類")
                .font(Font.Design.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

- [ ] **Step 3: Smoke-build the Watch app**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```
Expected: BUILD SUCCEEDED. (The views aren't reached until Task 9 wires them; the build just confirms they compile.)

Note: if `Font.Design.size22SemiboldRounded` is missing on watchOS, fall back to `Font.Design.body.weight(.semibold)` for now and report DONE_WITH_CONCERNS — the design tokens may need a Watch-side audit in a follow-up.

- [ ] **Step 4: Commit**

```
git add Features/Sources/WatchFeatures/Record/WatchRootView.swift \
        Features/Sources/WatchFeatures/Record/CategoryGridView.swift
git commit -m "$(cat <<'EOF'
feat(watch): add CategoryGridView (Screen 1) and WatchRootView [ci skip]

Root view drives step switching and the long-press account-picker
sheet. CategoryGridView is the 3-column grid users tap to pick a
category (or long-press to override the account for this single
draft).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `AmountKeypadView` (Screen 2)

**Files:**
- Create: `Features/Sources/WatchFeatures/Record/AmountKeypadView.swift`

- [ ] **Step 1: Implement the keypad**

Create `Features/Sources/WatchFeatures/Record/AmountKeypadView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import Domain

/// Screen 2: a fixed 3×4 numeric keypad with a live amount preview.
/// Layout, top to bottom:
///   row 0: 7 8 9
///   row 1: 4 5 6
///   row 2: 1 2 3
///   row 3: ⌫ 0 ✓
struct AmountKeypadView: View {

    let store: StoreOf<WatchRecordFeature>

    private let rows: [[Key]] = [
        [.digit(7), .digit(8), .digit(9)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(1), .digit(2), .digit(3)],
        [.backspace, .digit(0), .confirm]
    ]

    var body: some View {
        VStack(spacing: 6) {
            amountDisplay
            VStack(spacing: 4) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var amountDisplay: some View {
        Text("NT$ \(formatted(store.draft?.amount ?? 0))")
            .font(Font.Design.size22SemiboldRounded)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 6)
    }

    private func keyButton(_ key: Key) -> some View {
        Button {
            switch key {
            case let .digit(d):
                store.send(.amountDigit(d))
            case .backspace:
                store.send(.amountBackspace)
            case .confirm:
                store.send(.amountConfirmed)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                key.label
                    .font(Font.Design.body.weight(.semibold))
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(key.isDisabled(amount: store.draft?.amount ?? 0))
    }

    private func formatted(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    private enum Key: Hashable {
        case digit(Int)
        case backspace
        case confirm

        @ViewBuilder var label: some View {
            switch self {
            case let .digit(d):  Text(String(d))
            case .backspace:     Image(systemName: "delete.left")
            case .confirm:       Image(systemName: "checkmark")
            }
        }

        func isDisabled(amount: Decimal) -> Bool {
            switch self {
            case .confirm:  return amount <= 0
            case .backspace: return amount <= 0
            case .digit:    return false
            }
        }
    }
}
```

- [ ] **Step 2: Smoke-build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```
git add Features/Sources/WatchFeatures/Record/AmountKeypadView.swift
git commit -m "$(cat <<'EOF'
feat(watch): add AmountKeypadView (Screen 2) [ci skip]

Fixed 3×4 numeric keypad: 7-9 / 4-6 / 1-3 / ⌫-0-✓. Live amount
preview uses monospacedDigit. ⌫ and ✓ disable when amount is zero;
✓ dispatches .amountConfirmed which routes the reducer to .confirm.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `ConfirmView` (Screen 3)

**Files:**
- Create: `Features/Sources/WatchFeatures/Record/ConfirmView.swift`

- [ ] **Step 1: Implement the confirm view**

Create `Features/Sources/WatchFeatures/Record/ConfirmView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
#if canImport(WatchKit)
import WatchKit
#endif

/// Screen 3: shows the assembled draft and lets the user confirm or
/// cancel. Confirm fires a `.success` haptic (optimistic — we don't
/// wait for the iPhone to ack).
struct ConfirmView: View {

    let store: StoreOf<WatchRecordFeature>

    var body: some View {
        VStack(spacing: 10) {
            summary
            actions
        }
        .padding(.horizontal, 6)
    }

    private var summary: some View {
        VStack(spacing: 6) {
            if let category = store.activeCategory {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .foregroundStyle(Color.Design.fromHex(category.color))
                    Text(category.name)
                        .font(Font.Design.body.weight(.semibold))
                }
            }
            Text("NT$ \(formatted(store.draft?.amount ?? 0))")
                .font(Font.Design.size22SemiboldRounded)
                .monospacedDigit()
            if let account = store.activeAccount {
                Text(account.name)
                    .font(Font.Design.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                store.send(.confirmTapped)
                #if canImport(WatchKit)
                WKInterfaceDevice.current().play(.success)
                #endif
            } label: {
                Text("確認")
                    .font(Font.Design.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Design.accentOrange)

            Button {
                store.send(.cancelTapped)
            } label: {
                Text("取消")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
    }

    private func formatted(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}
```

If `Color.Design.accentOrange` doesn't resolve on watchOS (Common's token name may differ), substitute `.orange` and note DONE_WITH_CONCERNS.

- [ ] **Step 2: Smoke-build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```
git add Features/Sources/WatchFeatures/Record/ConfirmView.swift
git commit -m "$(cat <<'EOF'
feat(watch): add ConfirmView (Screen 3) with haptic feedback [ci skip]

Shows the assembled category + amount + account, with prominent
Confirm + secondary Cancel. Confirm plays WKInterfaceDevice.success
haptic optimistically (we don't wait for iPhone ack — Phase 1's
ProcessedDraftIdsStore dedups retries on the iPhone side).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Wire `NeuLedgerWatchApp` to the feature

**Files:**
- Modify: `NeuLedgerWatch Watch App/NeuLedgerWatchApp.swift`
- Delete: `NeuLedgerWatch Watch App/ContentView.swift`

- [ ] **Step 1: Replace the app entry**

Overwrite `NeuLedgerWatch Watch App/NeuLedgerWatchApp.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import WatchFeatures

@main
struct NeuLedgerWatch_Watch_AppApp: App {

    init() {
        prepareDependencies { dependencies in
            WatchDependencies.register(in: &dependencies)
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(
                store: Store(initialState: WatchRecordFeature.State()) {
                    WatchRecordFeature()
                }
            )
        }
    }
}
```

Delete the placeholder ContentView:

```
rm "NeuLedgerWatch Watch App/ContentView.swift"
```

You'll also need to remove the reference to `ContentView.swift` from `NeuLedger.xcodeproj/project.pbxproj`. Easiest path: open the project in Xcode, in the navigator right-click `ContentView.swift` → Delete → "Move to Trash". This updates `.pbxproj` automatically. If you prefer a terminal-only flow, run the build and Xcode will gracefully ignore the missing file reference; clean it up later.

- [ ] **Step 2: Smoke-build the Watch app**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run on simulator (manual visual)**

```
xcrun simctl boot 'Apple Watch Series 11 (46mm)' 2>/dev/null || true
open -a Simulator
xcodebuild -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -derivedDataPath /tmp/neuledger-watch-derived install 2>&1 | tail -5
```

Visually confirm:
- App opens to Screen 1 (the empty state if no snapshot has ever been received, which is the default for a brand-new Watch app — the iPhone hasn't been on the same paired pair).
- Long-press a category opens the account picker sheet (you won't see categories yet without a snapshot — that's Phase 4's job to verify with a paired physical Watch).

If the simulator doesn't open or the install hangs, skip and note that real-device verification falls under Phase 4. This task is **not blocked** on visual confirmation — only on the build succeeding.

- [ ] **Step 4: Commit**

```
git add "NeuLedgerWatch Watch App/NeuLedgerWatchApp.swift" \
        NeuLedger.xcodeproj/project.pbxproj
git rm "NeuLedgerWatch Watch App/ContentView.swift" 2>/dev/null || true
git commit -m "$(cat <<'EOF'
feat(watch): wire NeuLedgerWatchApp to WatchRecordFeature [ci skip]

App init() registers Watch-flavored TransactionClient/CategoryClient/
AccountClient + boots the WatchSessionGateway through
WatchDependencies.register. Removes the placeholder ContentView. The
app now opens to CategoryGridView, ready to render whatever
WatchContextSnapshot the iPhone has pushed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Full-suite green + iOS regression check

- [ ] **Step 1: Run all Watch tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedgerWatchTests \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
```

Expected: all suites pass. Suites added in Phase 2:
- `WatchCacheStoreTests` (4)
- `WatchSessionGatewayTests` (3)
- `WatchTransactionClientTests` (2)
- `WatchCategoryClientTests` (3)
- `WatchAccountClientTests` (2)
- `WatchRecordFeatureTests` (6)

Total: 20 new tests.

- [ ] **Step 2: Run all iOS tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests 2>&1 | tail -10
```

Expected: ≥ 502 tests pass (same as Phase 1 end-state). No new regressions.

- [ ] **Step 3: Verify both build targets**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3

xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -3
```

Both: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: No commit needed**

If all three pass, Phase 2 is complete.

---

## What this phase delivers

- ✅ Watch-side persistence (`WatchCacheStore` over App Group UserDefaults).
- ✅ Watch-side WC gateway (`WatchSessionGateway`) that decodes inbound snapshots and ships outbound drafts.
- ✅ Watch-flavored `liveValue`s for `TransactionClient` / `CategoryClient` / `AccountClient`, wired at app boot via `WatchDependencies.register`.
- ✅ `WatchRecordFeature` TCA reducer with full TestStore coverage.
- ✅ Three Views (CategoryGrid, AmountKeypad, Confirm) rendering the 3-step flow.
- ✅ `NeuLedgerWatchApp` boots the feature; no placeholder code left.
- ✅ All Watch tests pass; iOS tests still pass.

## What's still deferred

| Phase | Scope |
|---|---|
| **Phase 3** | `NeuLedgerWatchComplication` widget extension + `TodayExpenseComplication` (four families). Watch app already calls the (commented-out) `WidgetCenter.reloadAllTimelines` hook; Phase 3 just adds the widget target and uncomments. |
| **Phase 4** | iPhone Settings → Apple Watch section (default-account picker), midnight rollover for `todayTotal`, hooking `WatchSyncObserver.start()` into `AppFeature.task`, manual paired-device test checklist. |

## Self-Review

**Spec coverage (Phase 2 slice of `2026-05-27-apple-watch-design.md`):**
- §3 Screen 1 (category grid + long-press) → Task 6.
- §3 Screen 2 (amount keypad) → Task 7.
- §3 Screen 3 (confirm + haptic) → Task 8.
- §3 stack-based TCA navigation, app entry → Task 5 + Task 9.
- §5 `WatchSessionGateway` → Task 2.
- §5 `WatchCacheStore` → Task 1.
- §5 Watch-side `TransactionClient`/`CategoryClient`/`AccountClient` live → Tasks 3-4.

Deviations from spec (intentional):
- Spec placed Watch-side gateway/cache/clients in `Core/Watch/`. The actual project structure (post-scaffold) has them in `WatchFeatures/` because Core retains iOS-only SwiftData/CloudKit code that would force a platform-conditional rewrite. WatchFeatures depends on Domain + Common only — clean split.
- Spec referenced `step: enum Path` with `StackState`; this plan uses a simpler `enum Step` + `state.step` switching because the three steps share a single state (the in-flight draft) and Watch UI doesn't benefit from a navigation stack.

**Placeholders:** none. All code is complete and the simulator name + App Group ID are hard-coded.

**Type consistency:**
- `WatchPhoneTransport` (this plan) is named differently from `WatchSessionTransport` (Phase 1, iPhone side) on purpose — the protocols are platform-asymmetric.
- `WatchDraftSender` is a Task 3 protocol; `WatchSessionGateway` (Task 2) declares conformance via an extension in Task 3. Order is correct.
- `Draft.amount: Decimal` is consistent with `TransactionDraft.amount: Decimal` and `Transaction.amount: Decimal`.
- `WatchRecordFeature.State.step: Step` uses `.category` / `.amount` / `.confirm` — the same case names used in Task 6's `WatchRootView.body` switch.
