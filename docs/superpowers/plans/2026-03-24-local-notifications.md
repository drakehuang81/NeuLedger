# Local Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local notifications to NeuLedger — a daily reminder at a configurable time and a budget warning when spending crosses a user-defined threshold — both controlled from a new Notification Settings sub-screen.

**Architecture:** `NotificationClient` (@DependencyClient) in Domain abstracts all `UNUserNotificationCenter` calls; Core provides the live implementation plus budget warning trigger logic wired into `TransactionClient+Live`; `NotificationSettingsFeature` + `NotificationSettingsView` in Features exposes all settings to the user; `UserSettingsClient` is extended with `Int` read/write support to persist threshold and reminder time.

**Tech Stack:** Swift 6, iOS 26, TCA v1.23.1, SwiftUI, UserNotifications framework, Swift Testing

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `Features/Sources/Domain/Clients/UserSettingsClient.swift` | Modify | Add `int`/`setInt` closures + `SettingsKey<Int>` extension + new Bool/Int keys |
| `Features/Sources/Core/Clients/UserSettingsClient+Live.swift` | Modify | Add `int`/`setInt` live implementations |
| `Features/Sources/Domain/Clients/NotificationClient.swift` | Create | `@DependencyClient` interface + TestDependencyKey + DependencyValues |
| `Features/Sources/Core/Clients/NotificationClient+Live.swift` | Create | `DependencyKey` liveValue using UNUserNotificationCenter |
| `Features/Sources/Core/Clients/TransactionClient+Live.swift` | Modify | Capture `budgetClient`/`notificationClient`/`userSettingsClient`; call `checkBudgetWarnings` after `add`/`update` |
| `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift` | Create | TCA Reducer — settings load/save/schedule/permission logic |
| `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift` | Create | SwiftUI View — toggles, DatePicker, threshold Picker, permission banner |
| `Features/Sources/Features/Settings/SettingsView.swift` | Modify | Add `.notificationSettings` to `SettingsRoute` and navigation destination |
| `NeuLedger/Resources/Localizable.xcstrings` | Modify | Add 13 new localization keys (zh-Hant + en) |
| `Features/Tests/DomainTests/Clients/NotificationClientTests.swift` | Create | Domain client interface + testValue accessibility tests |
| `Features/Tests/CoreTests/Clients/UserSettingsClientTests.swift` | Modify | Add Int key and testValue Int tests |
| `Features/Tests/CoreTests/Clients/TransactionClientTests.swift` | Modify | Add `checkBudgetWarnings` tests |
| `Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift` | Create | Feature reducer tests — all action scenarios |

---

## Task 1: Extend UserSettingsClient with Int Support

**Files:**
- Modify: `Features/Sources/Domain/Clients/UserSettingsClient.swift`
- Modify: `Features/Sources/Core/Clients/UserSettingsClient+Live.swift`
- Modify: `Features/Tests/CoreTests/Clients/UserSettingsClientTests.swift`

- [ ] **Step 1: Write failing tests for Int keys and operations**

Add to `Features/Tests/CoreTests/Clients/UserSettingsClientTests.swift`:

```swift
// MARK: - Int Keys

@Test("dailyReminderHour key has correct rawValue and defaultValue")
func testDailyReminderHourKey() {
    let key = SettingsKey<Int>.dailyReminderHour
    #expect(key.rawValue == "dailyReminderHour")
    #expect(key.defaultValue == 21)
}

@Test("dailyReminderMinute key has correct rawValue and defaultValue")
func testDailyReminderMinuteKey() {
    let key = SettingsKey<Int>.dailyReminderMinute
    #expect(key.rawValue == "dailyReminderMinute")
    #expect(key.defaultValue == 0)
}

@Test("budgetWarningThreshold key has correct rawValue and defaultValue")
func testBudgetWarningThresholdKey() {
    let key = SettingsKey<Int>.budgetWarningThreshold
    #expect(key.rawValue == "budgetWarningThreshold")
    #expect(key.defaultValue == 80)
}

@Test("testValue int returns defaultValue")
func testTestValueIntReturnsDefault() {
    let client = UserSettingsClient.testValue
    let result = client.int(.dailyReminderHour)
    #expect(result == SettingsKey.dailyReminderHour.defaultValue)
}

// MARK: - Bool Keys (notification)

@Test("dailyReminderEnabled key has correct rawValue and defaultValue")
func testDailyReminderEnabledKey() {
    let key = SettingsKey<Bool>.dailyReminderEnabled
    #expect(key.rawValue == "dailyReminderEnabled")
    #expect(key.defaultValue == false)
}

@Test("budgetWarningEnabled key has correct rawValue and defaultValue")
func testBudgetWarningEnabledKey() {
    let key = SettingsKey<Bool>.budgetWarningEnabled
    #expect(key.rawValue == "budgetWarningEnabled")
    #expect(key.defaultValue == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/UserSettingsClientTests 2>&1 | tail -20
```

Expected: compile error — `SettingsKey<Int>` does not exist yet.

- [ ] **Step 3: Add `int`/`setInt` to `UserSettingsClient` struct**

In `Features/Sources/Domain/Clients/UserSettingsClient.swift`, inside the `UserSettingsClient` struct (after `setString`):

```swift
/// Reads an Int value for the given key, returning `defaultValue` if unset.
public var int: @Sendable (_ key: SettingsKey<Int>) -> Int = { $0.defaultValue }

/// Writes an Int value for the given key.
public var setInt: @Sendable (_ value: Int, _ key: SettingsKey<Int>) -> Void
```

Update `testValue` to include stubs:

```swift
public static let testValue = Self(
    bool: { $0.defaultValue },
    setBool: { _, _ in },
    string: { $0.defaultValue },
    setString: { _, _ in },
    int: { $0.defaultValue },
    setInt: { _, _ in }
)
```

- [ ] **Step 4: Add `SettingsKey<Int>` extension and new Bool keys**

In `Features/Sources/Domain/Clients/UserSettingsClient.swift`, add after the `// MARK: - String Keys` section:

```swift
// MARK: - Int Keys

public extension SettingsKey where Value == Int {
    /// Hour (0–23) for the daily recording reminder. Default: 21 (9 PM).
    static let dailyReminderHour = SettingsKey(rawValue: "dailyReminderHour", defaultValue: 21)
    /// Minute (0–59) for the daily recording reminder. Default: 0.
    static let dailyReminderMinute = SettingsKey(rawValue: "dailyReminderMinute", defaultValue: 0)
    /// Budget warning threshold as an integer percentage (50–90). Default: 80.
    static let budgetWarningThreshold = SettingsKey(rawValue: "budgetWarningThreshold", defaultValue: 80)
}
```

In the `// MARK: - Bool Keys` extension, add:

```swift
/// Whether the daily recording reminder notification is enabled.
static let dailyReminderEnabled = SettingsKey(rawValue: "dailyReminderEnabled", defaultValue: false)
/// Whether budget overspend warning notifications are enabled.
static let budgetWarningEnabled = SettingsKey(rawValue: "budgetWarningEnabled", defaultValue: false)
```

- [ ] **Step 5: Add `int`/`setInt` to `UserSettingsClient+Live.swift`**

In `Features/Sources/Core/Clients/UserSettingsClient+Live.swift`, add to the `liveValue` initializer (after `setString`):

```swift
int: { key in
    if UserDefaults.standard.object(forKey: key.rawValue) != nil {
        return UserDefaults.standard.integer(forKey: key.rawValue)
    }
    return key.defaultValue
},
setInt: { value, key in
    UserDefaults.standard.set(value, forKey: key.rawValue)
}
```

- [ ] **Step 6: Run tests and verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/UserSettingsClientTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Domain/Clients/UserSettingsClient.swift \
        Features/Sources/Core/Clients/UserSettingsClient+Live.swift \
        Features/Tests/CoreTests/Clients/UserSettingsClientTests.swift
git commit -m "feat(settings): add Int support and notification preference keys to UserSettingsClient"
```

---

## Task 2: Create NotificationClient Domain Interface

**Files:**
- Create: `Features/Sources/Domain/Clients/NotificationClient.swift`
- Create: `Features/Tests/DomainTests/Clients/NotificationClientTests.swift`

- [ ] **Step 1: Write failing domain tests**

Create `Features/Tests/DomainTests/Clients/NotificationClientTests.swift`:

```swift
import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("NotificationClient Tests")
struct NotificationClientTests {

    @Test("NotificationClient testValue is accessible via DependencyValues")
    func testDependencyKeyInjection() {
        @Dependency(\.notificationClient) var client
        #expect(true, "NotificationClient injected successfully")
    }

    @Test("testValue requestAuthorization returns false")
    func testRequestAuthorizationDefault() async {
        let client = NotificationClient.testValue
        let result = await client.requestAuthorization()
        #expect(result == false)
    }

    @Test("testValue isAuthorized returns false")
    func testIsAuthorizedDefault() async {
        let client = NotificationClient.testValue
        let result = await client.isAuthorized()
        #expect(result == false)
    }

    @Test("testValue lastWarnedPercent returns nil")
    func testLastWarnedPercentDefault() {
        let client = NotificationClient.testValue
        let result = client.lastWarnedPercent("budget-id", "2026-03-01")
        #expect(result == nil)
    }

    @Test("NotificationClient mock override for requestAuthorization")
    func testRequestAuthorizationOverride() async {
        await withDependencies {
            $0.notificationClient.requestAuthorization = { true }
        } operation: {
            @Dependency(\.notificationClient) var client
            let result = await client.requestAuthorization()
            #expect(result == true)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/NotificationClientTests 2>&1 | tail -20
```

Expected: compile error — `NotificationClient` does not exist yet.

- [ ] **Step 3: Create `NotificationClient.swift`**

Create `Features/Sources/Domain/Clients/NotificationClient.swift`:

```swift
import Foundation
import Dependencies
import DependenciesMacros

// MARK: - NotificationClient

/// A client interface for scheduling and managing local notifications.
///
/// All UNUserNotificationCenter operations are abstracted here so that
/// feature reducers can be tested without a real notification system.
@DependencyClient
public struct NotificationClient: Sendable {
    /// Request UNUserNotificationCenter authorization. Returns true if granted.
    public var requestAuthorization: @Sendable () async -> Bool = { false }

    /// Schedule (or reschedule) the daily reminder at the given hour/minute.
    /// Using the same fixed identifier replaces any previous request automatically.
    public var scheduleDailyReminder: @Sendable (_ hour: Int, _ minute: Int) async -> Void = { _, _ in }

    /// Cancel the daily reminder.
    public var cancelDailyReminder: @Sendable () async -> Void = {}

    /// Fire a one-shot budget warning notification immediately.
    /// - Parameters:
    ///   - budgetId: Used as the unique notification identifier (UUID string).
    ///   - title: Pre-formatted, localized notification title.
    ///   - body: Pre-formatted, localized notification body.
    public var sendBudgetWarning: @Sendable (_ budgetId: String, _ title: String, _ body: String) async -> Void = { _, _, _ in }

    /// Read the last warned percent for a given budget + period key.
    /// Returns nil if no warning has been sent yet for this period.
    public var lastWarnedPercent: @Sendable (_ budgetId: String, _ periodKey: String) -> Int? = { _, _ in nil }

    /// Persist the warned percent for a given budget + period key.
    public var setLastWarnedPercent: @Sendable (_ percent: Int, _ budgetId: String, _ periodKey: String) -> Void = { _, _, _ in }

    /// Check current authorization status (true = .authorized).
    public var isAuthorized: @Sendable () async -> Bool = { false }
}

// MARK: - TestDependencyKey

extension NotificationClient: TestDependencyKey {
    public static let testValue = NotificationClient()
}

// MARK: - DependencyValues

public extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/NotificationClientTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Clients/NotificationClient.swift \
        Features/Tests/DomainTests/Clients/NotificationClientTests.swift
git commit -m "feat(domain): add NotificationClient interface"
```

---

## Task 3: Create NotificationClient Live Implementation

**Files:**
- Create: `Features/Sources/Core/Clients/NotificationClient+Live.swift`

No unit tests for the live value (requires real UNUserNotificationCenter which can't be unit-tested without an iOS target). Build verification is the test here.

- [ ] **Step 1: Create `NotificationClient+Live.swift`**

Create `Features/Sources/Core/Clients/NotificationClient+Live.swift`:

```swift
import Foundation
import UserNotifications
import Domain
import Dependencies

extension NotificationClient: DependencyKey {
    public static let liveValue = NotificationClient(

        requestAuthorization: {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            // requestAuthorization throws if called in extension context;
            // check resulting status rather than relying on the throw.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        },

        scheduleDailyReminder: { hour, minute in
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification_daily_reminder_title", bundle: .main)
            content.body = String(localized: "notification_daily_reminder_body", bundle: .main)
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "neuledger.daily_reminder",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        },

        cancelDailyReminder: {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["neuledger.daily_reminder"])
        },

        sendBudgetWarning: { budgetId, title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "neuledger.budget_warning.\(budgetId)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        },

        lastWarnedPercent: { budgetId, periodKey in
            UserDefaults.standard.object(
                forKey: "neuledger.budget_warned.\(budgetId).\(periodKey)"
            ) as? Int
        },

        setLastWarnedPercent: { percent, budgetId, periodKey in
            UserDefaults.standard.set(
                percent,
                forKey: "neuledger.budget_warned.\(budgetId).\(periodKey)"
            )
        },

        isAuthorized: {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    )
}
```

- [ ] **Step 2: Build to verify no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Clients/NotificationClient+Live.swift
git commit -m "feat(core): add NotificationClient live implementation"
```

---

## Task 4: Add Budget Warning Logic to TransactionClient+Live

**Files:**
- Modify: `Features/Sources/Core/Clients/TransactionClient+Live.swift`
- Modify: `Features/Tests/CoreTests/Clients/TransactionClientTests.swift`

- [ ] **Step 1: Write failing tests for budget warning trigger**

Add to `Features/Tests/CoreTests/Clients/TransactionClientTests.swift`:

```swift
// MARK: - Budget Warning Tests

@Test("checkBudgetWarnings fires notification on first threshold crossing")
func testBudgetWarningFiresOnFirstCrossing() async throws {
    let db = DatabaseClient.testValue
    var warningFired = false
    var storedPercent: Int? = nil

    try await withDependencies {
        $0.databaseClient = db
        $0.userSettingsClient.bool = { key in
            key == .budgetWarningEnabled ? true : key.defaultValue
        }
        $0.userSettingsClient.int = { key in
            key == .budgetWarningThreshold ? 80 : key.defaultValue
        }
        $0.budgetClient.fetchActive = {
            [Budget(
                name: "餐飲預算",
                amount: 1000,
                categoryId: nil,
                period: .monthly,
                startDate: Calendar.current.startOfDay(for: Date()),
                isActive: true
            )]
        }
        $0.notificationClient.lastWarnedPercent = { _, _ in nil }
        $0.notificationClient.setLastWarnedPercent = { percent, _, _ in storedPercent = percent }
        $0.notificationClient.sendBudgetWarning = { _, _, _ in warningFired = true }
    } operation: {
        @Dependency(\.transactionClient) var transactionClient
        // Add a transaction that brings spending to 85% of budget
        try await transactionClient.add(Transaction(
            amount: 850,
            date: Date(),
            note: "Test",
            categoryId: nil,
            accountId: UUID(),
            type: .expense
        ))
        #expect(warningFired == true)
        #expect(storedPercent == 85)
    }
}

@Test("checkBudgetWarnings does not re-fire when already warned at same threshold")
func testBudgetWarningDoesNotRefire() async throws {
    let db = DatabaseClient.testValue
    var warnCount = 0

    try await withDependencies {
        $0.databaseClient = db
        $0.userSettingsClient.bool = { key in
            key == .budgetWarningEnabled ? true : key.defaultValue
        }
        $0.userSettingsClient.int = { key in
            key == .budgetWarningThreshold ? 80 : key.defaultValue
        }
        $0.budgetClient.fetchActive = {
            [Budget(
                name: "Test",
                amount: 1000,
                categoryId: nil,
                period: .monthly,
                startDate: Calendar.current.startOfDay(for: Date()),
                isActive: true
            )]
        }
        // Simulate already warned at 85%
        $0.notificationClient.lastWarnedPercent = { _, _ in 85 }
        $0.notificationClient.setLastWarnedPercent = { _, _, _ in }
        $0.notificationClient.sendBudgetWarning = { _, _, _ in warnCount += 1 }
    } operation: {
        @Dependency(\.transactionClient) var transactionClient
        try await transactionClient.add(Transaction(
            amount: 900,
            date: Date(),
            note: "Test",
            categoryId: nil,
            accountId: UUID(),
            type: .expense
        ))
        #expect(warnCount == 0)
    }
}

@Test("checkBudgetWarnings skips when budgetWarningEnabled is false")
func testBudgetWarningSkipsWhenDisabled() async throws {
    let db = DatabaseClient.testValue
    var warningFired = false

    try await withDependencies {
        $0.databaseClient = db
        $0.userSettingsClient.bool = { _ in false }   // all disabled
        $0.userSettingsClient.int = { $0.defaultValue }
        $0.budgetClient.fetchActive = { [] }
        $0.notificationClient.sendBudgetWarning = { _, _, _ in warningFired = true }
    } operation: {
        @Dependency(\.transactionClient) var transactionClient
        try await transactionClient.add(Transaction(
            amount: 999,
            date: Date(),
            note: "Test",
            categoryId: nil,
            accountId: UUID(),
            type: .expense
        ))
        #expect(warningFired == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/TransactionClientTests 2>&1 | tail -30
```

Expected: Tests fail / compile error.

- [ ] **Step 3: Add dependency captures and `checkBudgetWarnings` helper to `TransactionClient+Live.swift`**

At the top of `TransactionClient.liveValue`, add the new dependency captures after `databaseClient`. Also add `@Dependency(\.transactionClient) var selfClient` to resolve the self-capture problem — TCA lazily resolves `selfClient.fetch` at call time without infinite recursion because `BudgetClient.liveValue` never calls back into `TransactionClient`:

```swift
public static var liveValue: TransactionClient {
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.transactionClient) var selfClient   // for checkBudgetWarnings fetch

    return TransactionClient(
        // ... existing closures unchanged ...
    )
}
```

Inside the `add` closure, after the existing `databaseClient.add(...)` call, append:

```swift
await checkBudgetWarnings(
    budgetClient: budgetClient,
    notificationClient: notificationClient,
    userSettingsClient: userSettingsClient,
    transactionClient: selfClient
)
```

Inside the `update` closure, append the same call after the update completes.

Add the helper function at the bottom of the file (outside the `extension`):

```swift
// MARK: - Budget Warning Helper

/// Checks all active budgets and fires a notification if any crosses the user-defined threshold.
/// Called after add/update only — NOT after delete (intentional simplification).
/// String(localized:bundle:.main) in Core is acceptable; AIServiceClient+Live.swift uses the same pattern.
private func checkBudgetWarnings(
    budgetClient: BudgetClient,
    notificationClient: NotificationClient,
    userSettingsClient: UserSettingsClient,
    transactionClient: TransactionClient
) async {
    guard userSettingsClient.bool(.budgetWarningEnabled) else { return }
    let threshold = userSettingsClient.int(.budgetWarningThreshold)
    guard let activeBudgets = try? await budgetClient.fetchActive() else { return }

    let today = Date()
    for budget in activeBudgets {
        guard budget.amount > 0 else { continue }

        let cal = Calendar.current
        let interval: DateInterval
        switch budget.period {
        case .weekly:  interval = cal.dateInterval(of: .weekOfYear, for: today)!
        case .monthly: interval = cal.dateInterval(of: .month, for: today)!
        case .yearly:  interval = cal.dateInterval(of: .year, for: today)!
        }

        // categoryId is UUID? — build Set<UUID>? accordingly
        let categoryIds: Set<UUID>? = budget.categoryId.map { Set([$0]) }
        let filter = TransactionFilter(
            categoryIds: categoryIds,
            types: Set([.expense]),
            dateRange: interval.start...interval.end
        )

        guard let transactions = try? await transactionClient.fetch(filter) else { continue }

        let totalSpent = transactions.reduce(into: Decimal(0)) { $0 += $1.amount }
        let ratio = (totalSpent / budget.amount * 100) as NSDecimalNumber
        let usedPercent = ratio.intValue   // truncation is intentional (conservative)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let pKey = formatter.string(from: interval.start)

        // budget.id is UUID — use .uuidString as the String key
        let bidStr = budget.id.uuidString
        let lastWarned = notificationClient.lastWarnedPercent(bidStr, pKey)
        guard usedPercent >= threshold,
              lastWarned == nil || lastWarned! < threshold else { continue }

        let title = String(localized: "notification_budget_warning_title", bundle: .main)
        let body = String(
            format: String(localized: "notification_budget_warning_body", bundle: .main),
            budget.name,
            usedPercent
        )
        await notificationClient.sendBudgetWarning(bidStr, title, body)
        notificationClient.setLastWarnedPercent(usedPercent, bidStr, pKey)
    }
}

- [ ] **Step 4: Run tests and verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/TransactionClientTests 2>&1 | tail -30
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Clients/TransactionClient+Live.swift \
        Features/Tests/CoreTests/Clients/TransactionClientTests.swift
git commit -m "feat(core): add budget warning trigger to TransactionClient"
```

---

## Task 5: Create NotificationSettingsFeature

**Files:**
- Create: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift`
- Create: `Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift`

- [ ] **Step 1: Write failing feature tests**

Create `Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift`:

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("NotificationSettingsFeature Tests")
struct NotificationSettingsFeatureTests {

    // MARK: - .task

    @Test(".task loads settings and checks authorization")
    func testTaskLoadsSettings() async throws {
        let store = await TestStore(initialState: NotificationSettingsFeature.State()) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { key in
                key == .dailyReminderEnabled ? true : key.defaultValue
            }
            $0.userSettingsClient.int = { key in
                key == .dailyReminderHour ? 8 : key.defaultValue
            }
            $0.notificationClient.isAuthorized = { true }
        }

        await store.send(.task)

        await store.receive(\.authorizationStatusLoaded) {
            $0.isAuthorized = true
            $0.dailyReminderEnabled = true
        }
    }

    // MARK: - Daily Reminder Toggle

    @Test("toggling daily reminder on when authorized schedules notification")
    func testDailyReminderToggleOnAuthorized() async throws {
        var scheduledHour: Int? = nil
        var scheduledMinute: Int? = nil
        var persistedEnabled: Bool? = nil

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: true)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationClient.scheduleDailyReminder = { h, m in
                scheduledHour = h
                scheduledMinute = m
            }
            $0.userSettingsClient.setBool = { val, _ in persistedEnabled = val }
            $0.userSettingsClient.setInt = { _, _ in }
        }

        await store.send(.dailyReminderToggled(true)) {
            $0.dailyReminderEnabled = true
        }

        #expect(scheduledHour == 21)  // default hour
        #expect(scheduledMinute == 0)
        #expect(persistedEnabled == true)
    }

    @Test("toggling daily reminder off cancels notification")
    func testDailyReminderToggleOff() async throws {
        var cancelCalled = false

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(
                dailyReminderEnabled: true,
                isAuthorized: true
            )
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationClient.cancelDailyReminder = { cancelCalled = true }
            $0.userSettingsClient.setBool = { _, _ in }
        }

        await store.send(.dailyReminderToggled(false)) {
            $0.dailyReminderEnabled = false
        }

        #expect(cancelCalled == true)
    }

    // MARK: - Permission Denied

    @Test("toggling on when unauthorized requests permission; denial shows banner")
    func testToggleOnUnauthorizedDenied() async throws {
        var setBoolCalled = false

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationClient.requestAuthorization = { false }  // denied
            $0.notificationClient.scheduleDailyReminder = { _, _ in }
            $0.userSettingsClient.setBool = { _, _ in setBoolCalled = true }
            $0.userSettingsClient.setInt = { _, _ in }
        }

        await store.send(.dailyReminderToggled(true))
        await store.receive(\.permissionDenied) {
            $0.showPermissionDeniedBanner = true
            $0.dailyReminderEnabled = false
        }

        #expect(setBoolCalled == false, "Should not persist when permission denied")
    }

    // MARK: - Banner Self-Heal

    @Test(".task self-heals banner when permission granted in system Settings")
    func testBannerSelfHeals() async throws {
        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(
                isAuthorized: false,
                showPermissionDeniedBanner: true
            )
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationClient.isAuthorized = { true }  // user granted permission in Settings
            $0.userSettingsClient.bool = { $0.defaultValue }
            $0.userSettingsClient.int = { $0.defaultValue }
        }

        await store.send(.task)
        await store.receive(\.authorizationStatusLoaded) {
            $0.isAuthorized = true
            $0.showPermissionDeniedBanner = false
        }
    }

    // MARK: - Reminder Time

    @Test("reminderDateChanged reschedules and persists hour/minute")
    func testReminderDateChanged() async throws {
        var savedHour: Int? = nil
        var savedMinute: Int? = nil

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(
                dailyReminderEnabled: true,
                isAuthorized: true
            )
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationClient.scheduleDailyReminder = { h, m in
                savedHour = h
                savedMinute = m
            }
            $0.userSettingsClient.setInt = { val, key in
                if key == .dailyReminderHour { savedHour = val }
                if key == .dailyReminderMinute { savedMinute = val }
            }
        }

        let newDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 30))!
        await store.send(.reminderDateChanged(newDate)) {
            $0.reminderDate = newDate
        }

        #expect(savedHour == 8)
        #expect(savedMinute == 30)
    }

    // MARK: - Budget Warning Toggle (Unauthorized)

    @Test("toggling budget warning on when unauthorized and denied shows banner")
    func testBudgetWarningToggleOnUnauthorizedDenied() async throws {
        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationClient.requestAuthorization = { false }
            $0.userSettingsClient.setBool = { _, _ in }
            $0.userSettingsClient.setInt = { _, _ in }
        }

        await store.send(.budgetWarningToggled(true))
        await store.receive(\.permissionDenied) {
            $0.showPermissionDeniedBanner = true
            $0.budgetWarningEnabled = false
        }
    }

    // MARK: - Budget Warning Threshold

    @Test("warningThresholdChanged persists without triggering notification")
    func testWarningThresholdChanged() async throws {
        var persistedThreshold: Int? = nil
        var warningFired = false

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(budgetWarningEnabled: true)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.setInt = { val, key in
                if key == .budgetWarningThreshold { persistedThreshold = val }
            }
            $0.notificationClient.sendBudgetWarning = { _, _, _ in warningFired = true }
        }

        await store.send(.warningThresholdChanged(70)) {
            $0.warningThreshold = 70
        }

        #expect(persistedThreshold == 70)
        #expect(warningFired == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/NotificationSettingsFeatureTests 2>&1 | tail -20
```

Expected: compile error — `NotificationSettingsFeature` does not exist yet.

- [ ] **Step 3: Create `NotificationSettingsFeature.swift`**

Create `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift`:

```swift
import ComposableArchitecture
import Domain
import Foundation
import UIKit

@Reducer
public struct NotificationSettingsFeature: Sendable {
    public init() {}

    private enum CancelID { case task }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var dailyReminderEnabled: Bool = false
        /// Only hour and minute components are meaningful; date portion is irrelevant.
        public var reminderDate: Date = Calendar.current.date(
            from: DateComponents(hour: 21, minute: 0)
        ) ?? Date()
        public var budgetWarningEnabled: Bool = false
        public var warningThreshold: Int = 80
        public var isAuthorized: Bool = false
        public var showPermissionDeniedBanner: Bool = false

        public init(
            dailyReminderEnabled: Bool = false,
            reminderDate: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date(),
            budgetWarningEnabled: Bool = false,
            warningThreshold: Int = 80,
            isAuthorized: Bool = false,
            showPermissionDeniedBanner: Bool = false
        ) {
            self.dailyReminderEnabled = dailyReminderEnabled
            self.reminderDate = reminderDate
            self.budgetWarningEnabled = budgetWarningEnabled
            self.warningThreshold = warningThreshold
            self.isAuthorized = isAuthorized
            self.showPermissionDeniedBanner = showPermissionDeniedBanner
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case authorizationStatusLoaded(Bool)
        case dailyReminderToggled(Bool)
        case reminderDateChanged(Date)
        case budgetWarningToggled(Bool)
        case warningThresholdChanged(Int)
        case permissionDenied
        case openSystemSettingsTapped
    }

    // MARK: - Dependencies

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                let reminderEnabled = userSettingsClient.bool(.dailyReminderEnabled)
                let warningEnabled = userSettingsClient.bool(.budgetWarningEnabled)
                let hour = userSettingsClient.int(.dailyReminderHour)
                let minute = userSettingsClient.int(.dailyReminderMinute)
                let threshold = userSettingsClient.int(.budgetWarningThreshold)

                state.dailyReminderEnabled = reminderEnabled
                state.budgetWarningEnabled = warningEnabled
                state.warningThreshold = threshold
                state.reminderDate = Calendar.current.date(
                    from: DateComponents(hour: hour, minute: minute)
                ) ?? state.reminderDate

                return .run { send in
                    let authorized = await notificationClient.isAuthorized()
                    await send(.authorizationStatusLoaded(authorized))
                }
                .cancellable(id: CancelID.task)

            case let .authorizationStatusLoaded(authorized):
                state.isAuthorized = authorized
                if authorized {
                    state.showPermissionDeniedBanner = false
                }
                return .none

            case let .dailyReminderToggled(enabled):
                if !enabled {
                    state.dailyReminderEnabled = false
                    userSettingsClient.setBool(false, .dailyReminderEnabled)
                    return .run { _ in await notificationClient.cancelDailyReminder() }
                }
                // Enabling — request permission if needed
                if state.isAuthorized {
                    state.dailyReminderEnabled = true
                    userSettingsClient.setBool(true, .dailyReminderEnabled)
                    let hour = Calendar.current.component(.hour, from: state.reminderDate)
                    let minute = Calendar.current.component(.minute, from: state.reminderDate)
                    return .run { _ in await notificationClient.scheduleDailyReminder(hour, minute) }
                } else {
                    return .run { send in
                        let granted = await notificationClient.requestAuthorization()
                        if granted {
                            await send(.authorizationStatusLoaded(true))
                            await send(.dailyReminderToggled(true))  // retry with auth
                        } else {
                            await send(.permissionDenied)
                        }
                    }
                }

            case let .reminderDateChanged(date):
                state.reminderDate = date
                let hour = Calendar.current.component(.hour, from: date)
                let minute = Calendar.current.component(.minute, from: date)
                userSettingsClient.setInt(hour, .dailyReminderHour)
                userSettingsClient.setInt(minute, .dailyReminderMinute)
                guard state.dailyReminderEnabled else { return .none }
                return .run { _ in await notificationClient.scheduleDailyReminder(hour, minute) }

            case let .budgetWarningToggled(enabled):
                if !enabled {
                    state.budgetWarningEnabled = false
                    userSettingsClient.setBool(false, .budgetWarningEnabled)
                    return .none
                }
                if state.isAuthorized {
                    state.budgetWarningEnabled = true
                    userSettingsClient.setBool(true, .budgetWarningEnabled)
                    return .none
                } else {
                    return .run { send in
                        let granted = await notificationClient.requestAuthorization()
                        if granted {
                            await send(.authorizationStatusLoaded(true))
                            await send(.budgetWarningToggled(true))
                        } else {
                            await send(.permissionDenied)
                        }
                    }
                }

            case let .warningThresholdChanged(threshold):
                state.warningThreshold = threshold
                userSettingsClient.setInt(threshold, .budgetWarningThreshold)
                return .none

            case .permissionDenied:
                state.showPermissionDeniedBanner = true
                return .none

            case .openSystemSettingsTapped:
                return .run { _ in
                    await openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/NotificationSettingsFeatureTests 2>&1 | tail -30
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift \
        Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift
git commit -m "feat(features): add NotificationSettingsFeature reducer"
```

---

## Task 6: Add Localization Keys

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add all 13 new localization keys**

Open `NeuLedger/Resources/Localizable.xcstrings` in Xcode's string catalog editor (or edit as JSON). Add the following entries with both `zh-Hant` and `en` translations:

| Key | zh-Hant | en |
|-----|---------|-----|
| `settings_notification_settings` | 通知設定 | Notification Settings |
| `notification_daily_reminder_section` | 每日記帳提醒 | Daily Reminder |
| `notification_daily_reminder_toggle` | 開啟每日提醒 | Enable Daily Reminder |
| `notification_reminder_time` | 提醒時間 | Reminder Time |
| `notification_budget_warning_section` | 預算警告 | Budget Warnings |
| `notification_budget_warning_toggle` | 開啟預算警告 | Enable Budget Warnings |
| `notification_warning_threshold` | 警告門檻 | Warning Threshold |
| `notification_permission_denied_banner` | 請前往系統「設定」開啟通知權限 | Please enable notifications in system Settings |
| `notification_open_settings` | 前往設定 | Open Settings |
| `notification_daily_reminder_title` | NeuLedger 記帳提醒 | NeuLedger Reminder |
| `notification_daily_reminder_body` | 記得記帳！點此快速新增一筆。 | Time to log your transactions! |
| `notification_budget_warning_title` | 預算使用警告 | Budget Warning |
| `notification_budget_warning_body` | 預算「%@」已使用 %d%%，請注意支出。 | Budget "%@" is %d%% used. Watch your spending. |

- [ ] **Step 2: Build to verify all keys compile cleanly**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED (no missing localization warnings relevant to new keys).

- [ ] **Step 3: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(i18n): add localization keys for notification settings"
```

---

## Task 7: Create NotificationSettingsView

**Files:**
- Create: `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift`

- [ ] **Step 1: Create the view**

Create `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import Common

public struct NotificationSettingsView: View {
    @Bindable var store: StoreOf<NotificationSettingsFeature>

    public init(store: StoreOf<NotificationSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Permission denied banner
                if store.showPermissionDeniedBanner {
                    permissionBanner
                }

                // Daily reminder section
                dailyReminderSection

                // Budget warning section
                budgetWarningSection
            }
            .padding(16)
        }
        .background(Color.Design.background.ignoresSafeArea())
        .navigationTitle(String(localized: "settings_notification_settings"))
        .navigationBarTitleDisplayMode(.large)
        .task { await store.send(.task).finish() }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        GlassContainer(cornerRadius: 12, padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "notification_permission_denied_banner"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button(String(localized: "notification_open_settings")) {
                    store.send(.openSystemSettingsTapped)
                }
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Daily Reminder Section

    private var dailyReminderSection: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "notification_daily_reminder_section"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    row {
                        Toggle(
                            String(localized: "notification_daily_reminder_toggle"),
                            isOn: Binding(
                                get: { store.dailyReminderEnabled },
                                set: { store.send(.dailyReminderToggled($0)) }
                            )
                        )
                    }

                    if store.dailyReminderEnabled {
                        Divider().padding(.horizontal, 16)
                        row {
                            DatePicker(
                                String(localized: "notification_reminder_time"),
                                selection: Binding(
                                    get: { store.reminderDate },
                                    set: { store.send(.reminderDateChanged($0)) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Budget Warning Section

    private var budgetWarningSection: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "notification_budget_warning_section"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    row {
                        Toggle(
                            String(localized: "notification_budget_warning_toggle"),
                            isOn: Binding(
                                get: { store.budgetWarningEnabled },
                                set: { store.send(.budgetWarningToggled($0)) }
                            )
                        )
                    }

                    if store.budgetWarningEnabled {
                        Divider().padding(.horizontal, 16)
                        row {
                            Picker(
                                String(localized: "notification_warning_threshold"),
                                selection: Binding(
                                    get: { store.warningThreshold },
                                    set: { store.send(.warningThresholdChanged($0)) }
                                )
                            ) {
                                ForEach([50, 60, 70, 80, 90], id: \.self) { value in
                                    Text("\(value)%").tag(value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift
git commit -m "feat(features): add NotificationSettingsView"
```

---

## Task 8: Integrate into SettingsView + Final Build

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add `.notificationSettings` to `SettingsRoute`**

In `Features/Sources/Features/Settings/SettingsView.swift`, add to the `SettingsRoute` enum:

```swift
enum SettingsRoute: Hashable {
    case accountManagement
    case categoryManagement
    case budgetManagement
    case tagManagement
    case notificationSettings   // add this
}
```

- [ ] **Step 2: Add `NavigationLink` in the "管理" section**

In `SettingsView.sectionManage`, after the `tagManagement` `NavigationLink`:

```swift
NavigationLink(value: SettingsRoute.notificationSettings) {
    settingsRow(
        icon: "bell.badge",
        iconColor: .orange,
        label: String(localized: "settings_notification_settings"),
        trailing: chevron
    )
}
```

- [ ] **Step 3: Add `navigationDestination` case**

In the `navigationDestination(for: SettingsRoute.self)` switch, add:

```swift
case .notificationSettings:
    NotificationSettingsView(
        store: Store(initialState: NotificationSettingsFeature.State()) {
            NotificationSettingsFeature()
        }
    )
```

- [ ] **Step 4: Final build and full test suite**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsView.swift
git commit -m "feat(settings): add notification settings navigation entry"
```
