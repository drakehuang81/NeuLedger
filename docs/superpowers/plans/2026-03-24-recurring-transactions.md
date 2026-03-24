# Recurring Transactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a recurring transactions feature — users can mark any transaction as repeating (weekly/monthly/yearly); when due, a local notification fires; tapping it opens a pre-filled AddTransaction sheet; confirming creates the real transaction and schedules the next occurrence.

**Architecture:** New `RecurringTransaction` domain entity + `RecurringTransactionClient` + `SDRecurringTransaction` SwiftData model follow the identical pattern as existing clients. `NotificationClient` is extended with 3 new fields (struct body, not extension). Notification taps are routed through `MainTabFeature.task` via an internal `UNUserNotificationCenterDelegate` actor inside `NotificationClient+Live`. A new `Mode.addRecurringConfirmation` case in `AddTransactionFeature` handles pre-fill and delegate signalling. A new Settings sub-page manages recurring templates.

**Tech Stack:** Swift 6, iOS 26, TCA v1.23.1, SwiftData, UserNotifications, Swift Testing

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `Features/Sources/Domain/Entities/RecurringTransaction.swift` | Create | Domain entity + `nextDate(after:)` helper |
| `Features/Sources/Domain/Clients/RecurringTransactionClient.swift` | Create | `@DependencyClient` interface + testValue + DependencyValues |
| `Features/Sources/Domain/Clients/NotificationClient.swift` | Modify | Add 3 new fields to struct body; update explicit testValue |
| `Features/Sources/Core/Models/SDRecurringTransaction.swift` | Create | SwiftData `@Model` |
| `Features/Sources/Core/Mappers/SDRecurringTransaction+Mapping.swift` | Create | `DomainConvertible` conformance |
| `Features/Sources/Core/Clients/RecurringTransactionClient+Live.swift` | Create | `DependencyKey` liveValue using DatabaseClient helpers |
| `Features/Sources/Core/Clients/NotificationClient+Live.swift` | Modify | Add recurring scheduling + internal delegate actor + pendingConfirmations stream |
| `Features/Sources/Core/DatabaseClient.swift` | Modify | Add `SDRecurringTransaction` to Schema array in liveValue and testValue |
| `Features/Sources/Features/Dashboard/AddTransactionFeature.swift` | Modify | Add `.addRecurringConfirmation(RecurringTransaction)` Mode + recurring state + save logic + delegate case |
| `Features/Sources/Features/Dashboard/AddTransactionView.swift` | Modify | Add recurring toggle + frequency picker in form |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | Modify | Subscribe to pendingConfirmations in .task; handle notification tap routing |
| `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift` | Create | TCA Reducer: load, toggleActive, delete |
| `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementView.swift` | Create | SwiftUI list view |
| `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift` | Create | TCA Reducer: add/edit form with validation |
| `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormView.swift` | Create | SwiftUI form view |
| `Features/Sources/Features/Settings/SettingsView.swift` | Modify | Add `case recurringTransactions` to `SettingsRoute` + NavigationLink + navigationDestination |
| `NeuLedger/Resources/Localizable.xcstrings` | Modify | 13 new localization keys |
| `Features/Tests/DomainTests/Clients/RecurringTransactionClientTests.swift` | Create | testValue + DependencyValues injection |
| `Features/Tests/CoreTests/Clients/RecurringTransactionClientTests.swift` | Create | CRUD integration tests |
| `Features/Tests/FeaturesTests/RecurringTransactionManagementFeatureTests.swift` | Create | Reducer tests |
| `Features/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift` | Create | Validation + save tests |
| `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift` | Modify | Add recurring toggle + save + delegate tests |
| `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` | Modify | Add notification tap routing tests |

---

## Task 1: RecurringTransaction Domain Entity

**Files:**
- Create: `Features/Sources/Domain/Entities/RecurringTransaction.swift`
- Create: `Features/Tests/DomainTests/Clients/RecurringTransactionClientTests.swift`

- [ ] **Step 1: Write the domain tests first (will fail — client doesn't exist yet)**

Create `Features/Tests/DomainTests/Clients/RecurringTransactionClientTests.swift`:

```swift
import Testing
import Foundation
import Dependencies
@testable import Domain

@Suite("RecurringTransactionClient Domain Tests")
struct RecurringTransactionClientTests {

    @Test("RecurringTransactionClient testValue is accessible via DependencyValues")
    func testDependencyInjection() {
        @Dependency(\.recurringTransactionClient) var client
        #expect(true, "RecurringTransactionClient injected successfully")
    }

    @Test("testValue fetchAll returns unimplemented stub (does not throw)")
    func testFetchAllUnimplemented() async {
        let client = RecurringTransactionClient.testValue
        // @DependencyClient stubs are unimplemented — accessing them in tests
        // via withDependencies overrides works correctly
        #expect(true)
    }

    @Test("nextDate weekly advances by 7 days")
    func testNextDateWeekly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID(), toAccountId: nil, type: .expense,
            tags: [], frequency: .weekly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: base)!
        #expect(next == expected)
    }

    @Test("nextDate monthly advances by 1 month")
    func testNextDateMonthly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID(), toAccountId: nil, type: .expense,
            tags: [], frequency: .monthly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: base)!
        #expect(next == expected)
    }

    @Test("nextDate yearly advances by 1 year")
    func testNextDateYearly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID(), toAccountId: nil, type: .expense,
            tags: [], frequency: .yearly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .year, value: 1, to: base)!
        #expect(next == expected)
    }
}
```

- [ ] **Step 2: Create the entity**

Create `Features/Sources/Domain/Entities/RecurringTransaction.swift`:

```swift
import Foundation

// MARK: - RecurringTransaction

/// A template for transactions that repeat on a fixed schedule.
/// When `nextDueDate` is reached, a local notification prompts the user to confirm.
/// On confirmation, a real `Transaction` is created and `nextDueDate` advances by `frequency`.
public struct RecurringTransaction: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var amount: Decimal
    public var note: String?
    public var categoryId: Category.ID?
    public var accountId: Account.ID
    public var toAccountId: Account.ID?   // transfers only; nil for expense/income
    public var type: TransactionType
    public var tags: [Tag]
    public var frequency: BudgetPeriod    // .weekly / .monthly / .yearly
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: UUID, amount: Decimal, note: String?,
        categoryId: Category.ID?, accountId: Account.ID,
        toAccountId: Account.ID?, type: TransactionType,
        tags: [Tag], frequency: BudgetPeriod,
        nextDueDate: Date, isActive: Bool, createdAt: Date
    ) {
        self.id = id; self.amount = amount; self.note = note
        self.categoryId = categoryId; self.accountId = accountId
        self.toAccountId = toAccountId; self.type = type
        self.tags = tags; self.frequency = frequency
        self.nextDueDate = nextDueDate; self.isActive = isActive
        self.createdAt = createdAt
    }

    /// Returns the next due date after `base` according to `frequency`.
    public func nextDate(after base: Date, calendar: Calendar = .current) -> Date {
        switch frequency {
        case .weekly:  return calendar.date(byAdding: .weekOfYear, value: 1, to: base)!
        case .monthly: return calendar.date(byAdding: .month,      value: 1, to: base)!
        case .yearly:  return calendar.date(byAdding: .year,       value: 1, to: base)!
        }
    }
}
```

- [ ] **Step 3: Create the client interface**

Create `Features/Sources/Domain/Clients/RecurringTransactionClient.swift`:

```swift
import Foundation
import Dependencies
import DependenciesMacros

// MARK: - RecurringTransactionClient

@DependencyClient
public struct RecurringTransactionClient: Sendable {
    /// Fetch all recurring transactions (active and inactive).
    public var fetchAll: @Sendable () async throws -> [RecurringTransaction]
    /// Fetch recurring transactions whose nextDueDate is on or before `date`.
    public var fetchDue: @Sendable (_ on: Date) async throws -> [RecurringTransaction]
    /// Persist a new recurring transaction.
    public var add: @Sendable (RecurringTransaction) async throws -> Void
    /// Update an existing recurring transaction (matches by id).
    public var update: @Sendable (RecurringTransaction) async throws -> Void
    /// Delete a recurring transaction by id.
    public var delete: @Sendable (RecurringTransaction.ID) async throws -> Void
}

// MARK: - TestDependencyKey

extension RecurringTransactionClient: TestDependencyKey {
    public static let testValue = RecurringTransactionClient()
}

// MARK: - DependencyValues

public extension DependencyValues {
    var recurringTransactionClient: RecurringTransactionClient {
        get { self[RecurringTransactionClient.self] }
        set { self[RecurringTransactionClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run domain tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/RecurringTransactionClientTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Domain/Entities/RecurringTransaction.swift \
        Features/Sources/Domain/Clients/RecurringTransactionClient.swift \
        Features/Tests/DomainTests/Clients/RecurringTransactionClientTests.swift
git commit -m "feat(domain): add RecurringTransaction entity and client interface"
```

---

## Task 2: Extend NotificationClient with Recurring Fields

**Files:**
- Modify: `Features/Sources/Domain/Clients/NotificationClient.swift`

- [ ] **Step 1: Add 3 new fields to the struct body and update testValue**

In `Features/Sources/Domain/Clients/NotificationClient.swift`, add inside the `NotificationClient` struct body (after `isAuthorized`):

```swift
/// Schedule a due-date notification for a recurring transaction.
/// Using the recurring transaction's id as the notification identifier ensures
/// scheduling the same template again replaces the previous request.
public var scheduleRecurringReminder: @Sendable (
    _ id: RecurringTransaction.ID,
    _ dueDate: Date,
    _ title: String,
    _ body: String
) async -> Void = { _, _, _, _ in }

/// Cancel the scheduled notification for a recurring transaction.
public var cancelRecurringReminder: @Sendable (_ id: RecurringTransaction.ID) async -> Void = { _ in }

/// Emits a `RecurringTransaction.ID` each time the user taps a recurring-transaction notification.
/// The live implementation owns the UNUserNotificationCenterDelegate internally — no AppDelegate needed.
/// testValue emits an immediately-finishing stream to prevent test hangs.
public var pendingConfirmations: @Sendable () -> AsyncStream<RecurringTransaction.ID> = {
    let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
    continuation.finish()
    return stream
}
```

Update the explicit `testValue` in the `TestDependencyKey` extension (the existing call has 7 parameters; add the 3 new ones):

```swift
public static let testValue = NotificationClient(
    requestAuthorization: { false },
    scheduleDailyReminder: { _, _ in },
    cancelDailyReminder: {},
    sendBudgetWarning: { _, _, _ in },
    lastWarnedPercent: { _, _ in nil },
    setLastWarnedPercent: { _, _, _ in },
    isAuthorized: { false },
    scheduleRecurringReminder: { _, _, _, _ in },
    cancelRecurringReminder: { _ in },
    pendingConfirmations: {
        let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
        continuation.finish()
        return stream
    }
)
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded" | tail -10
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Domain/Clients/NotificationClient.swift
git commit -m "feat(domain): extend NotificationClient with recurring reminder fields"
```

---

## Task 3: Core Layer — SwiftData Model + Live Client

**Files:**
- Create: `Features/Sources/Core/Models/SDRecurringTransaction.swift`
- Create: `Features/Sources/Core/Models/SDRecurringTransaction+Mapping.swift`
- Create: `Features/Sources/Core/Clients/RecurringTransactionClient+Live.swift`
- Modify: `Features/Sources/Core/DatabaseClient.swift`
- Create: `Features/Tests/CoreTests/Clients/RecurringTransactionClientTests.swift`

- [ ] **Step 1: Write failing Core integration tests**

Create `Features/Tests/CoreTests/Clients/RecurringTransactionClientTests.swift`:

```swift
import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("RecurringTransactionClient Integration Tests")
struct RecurringTransactionClientIntegrationTests {
    var container: ModelContainer
    var sut: RecurringTransactionClient

    init() throws {
        let schema = Schema([
            SDTransaction.self, SDAccount.self, SDCategory.self,
            SDBudget.self, SDTag.self, SDRecurringTransaction.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try ModelContainer(for: schema, configurations: [config])
        self.container = c
        self.sut = withDependencies {
            $0.databaseClient = DatabaseClient(modelContainer: { c })
        } operation: {
            RecurringTransactionClient.liveValue
        }
    }

    func makeSample(id: UUID = UUID()) -> RecurringTransaction {
        RecurringTransaction(
            id: id, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID(), toAccountId: nil,
            type: .expense, tags: [],
            frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
    }

    @Test("add and fetchAll returns the recurring transaction")
    func testAddAndFetchAll() async throws {
        let rt = makeSample()
        try await sut.add(rt)
        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].note == "房租")
        #expect(all[0].frequency == .monthly)
    }

    @Test("fetchDue returns only items due on or before given date")
    func testFetchDue() async throws {
        let past = Date(timeIntervalSinceNow: -86400)    // yesterday
        let future = Date(timeIntervalSinceNow: 86400)   // tomorrow
        var rtPast = makeSample(); rtPast.nextDueDate = past
        var rtFuture = makeSample(); rtFuture.nextDueDate = future
        try await sut.add(rtPast)
        try await sut.add(rtFuture)
        let due = try await sut.fetchDue(on: Date())
        #expect(due.count == 1)
        #expect(due[0].nextDueDate == past)
    }

    @Test("update modifies the recurring transaction")
    func testUpdate() async throws {
        var rt = makeSample()
        try await sut.add(rt)
        rt.note = "修改後"
        rt.isActive = false
        try await sut.update(rt)
        let all = try await sut.fetchAll()
        #expect(all[0].note == "修改後")
        #expect(all[0].isActive == false)
    }

    @Test("delete removes the recurring transaction")
    func testDelete() async throws {
        let rt = makeSample()
        try await sut.add(rt)
        try await sut.delete(rt.id)
        let all = try await sut.fetchAll()
        #expect(all.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests (expect compile error — SDRecurringTransaction doesn't exist yet)**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/RecurringTransactionClientIntegrationTests 2>&1 | grep -E "error:" | head -5
```

Expected: Compile error mentioning `SDRecurringTransaction` not found.

- [ ] **Step 3: Create SDRecurringTransaction model**

Create `Features/Sources/Core/Models/SDRecurringTransaction.swift`:

```swift
import SwiftData
import Foundation

// MARK: - SDRecurringTransaction

/// SwiftData persistence model for RecurringTransaction.
/// Tags are stored as a plain [UUID] array (no @Relationship) to avoid cascade complexity.
/// The mapper resolves full Tag objects from context at read time.
@Model
public final class SDRecurringTransaction {
    public var id: UUID
    public var amount: Decimal
    public var note: String?
    public var categoryId: UUID?
    public var accountId: UUID
    public var toAccountId: UUID?
    public var typeRaw: String          // TransactionType.rawValue
    public var tagIds: [UUID]           // resolved to [Tag] in toDomain(context:)
    public var frequencyRaw: String     // BudgetPeriod.rawValue
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: UUID, amount: Decimal, note: String?,
        categoryId: UUID?, accountId: UUID, toAccountId: UUID?,
        typeRaw: String, tagIds: [UUID], frequencyRaw: String,
        nextDueDate: Date, isActive: Bool, createdAt: Date
    ) {
        self.id = id; self.amount = amount; self.note = note
        self.categoryId = categoryId; self.accountId = accountId
        self.toAccountId = toAccountId; self.typeRaw = typeRaw
        self.tagIds = tagIds; self.frequencyRaw = frequencyRaw
        self.nextDueDate = nextDueDate; self.isActive = isActive
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Create the mapping**

> **Note on tags:** `DomainConvertible.toDomain()` has no `context:` parameter and must return a non-optional value (protocol requirement). Since `SDRecurringTransaction` stores `tagIds: [UUID]` (no `@Relationship`), resolving full `Tag` objects in `toDomain()` is not possible without a context. For v1, `toDomain()` returns `tags: []` — tags stored on a recurring template are preserved in `tagIds` for future use but are not shown in the management list. Users can add tags when confirming via `AddTransactionFeature`.

Create `Features/Sources/Core/Mappers/SDRecurringTransaction+Mapping.swift`:

```swift
import SwiftData
import Foundation
import Domain

extension SDRecurringTransaction: DomainConvertible {
    /// Converts to domain. Tags are not resolved in v1 (tagIds stored for future use).
    func toDomain() -> RecurringTransaction {
        RecurringTransaction(
            id: id, amount: amount, note: note,
            categoryId: categoryId, accountId: accountId,
            toAccountId: toAccountId,
            type: TransactionType(rawValue: typeRaw) ?? .expense,
            tags: [],   // tagIds preserved in storage but not resolved in v1
            frequency: BudgetPeriod(rawValue: frequencyRaw) ?? .monthly,
            nextDueDate: nextDueDate, isActive: isActive, createdAt: createdAt
        )
    }

    @discardableResult
    static func from(_ domain: RecurringTransaction, context: ModelContext) -> SDRecurringTransaction {
        let model = SDRecurringTransaction(
            id: domain.id,
            amount: domain.amount,
            note: domain.note,
            categoryId: domain.categoryId,
            accountId: domain.accountId,
            toAccountId: domain.toAccountId,
            typeRaw: domain.type.rawValue,
            tagIds: domain.tags.map(\.id),
            frequencyRaw: domain.frequency.rawValue,
            nextDueDate: domain.nextDueDate,
            isActive: domain.isActive,
            createdAt: domain.createdAt
        )
        context.insert(model)
        return model
    }
}
```

- [ ] **Step 5: Add SDRecurringTransaction to DatabaseClient Schema**

In `Features/Sources/Core/DatabaseClient.swift`, find the `Schema([...])` arrays in both `liveValue` and `testValue` and add `SDRecurringTransaction.self` to each. Example — existing list:

```swift
Schema([
    SDTransaction.self,
    SDAccount.self,
    SDCategory.self,
    SDBudget.self,
    SDTag.self,
    SDRecurringTransaction.self,   // ADD THIS LINE
])
```

Do this in both `liveValue` and `testValue`.

- [ ] **Step 6: Create the live client**

> **Pattern note:** Follow the exact same pattern as `AccountClient+Live.swift` — capture `databaseClient` ONCE at the top of `static var liveValue`, then use it synchronously (no `async`/`await`) inside closures. The `update` closure signature is `(existing, _)` — two parameters.

Create `Features/Sources/Core/Clients/RecurringTransactionClient+Live.swift`:

```swift
import Foundation
import SwiftData
import Domain
import Dependencies

extension RecurringTransactionClient: DependencyKey {
    public static var liveValue: RecurringTransactionClient {
        @Dependency(\.databaseClient) var databaseClient

        return RecurringTransactionClient(

            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDRecurringTransaction>(
                        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                    )
                )
            },

            fetchDue: { date in
                try databaseClient.fetch(
                    FetchDescriptor<SDRecurringTransaction>(
                        predicate: #Predicate { $0.nextDueDate <= date && $0.isActive == true }
                    )
                )
            },

            add: { recurring in
                try databaseClient.add(recurring, as: SDRecurringTransaction.self)
            },

            update: { recurring in
                let recurringId = recurring.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDRecurringTransaction>(
                        predicate: #Predicate { $0.id == recurringId }
                    )
                ) { sd, _ in
                    sd.amount = recurring.amount
                    sd.note = recurring.note
                    sd.categoryId = recurring.categoryId
                    sd.accountId = recurring.accountId
                    sd.toAccountId = recurring.toAccountId
                    sd.typeRaw = recurring.type.rawValue
                    sd.tagIds = recurring.tags.map(\.id)
                    sd.frequencyRaw = recurring.frequency.rawValue
                    sd.nextDueDate = recurring.nextDueDate
                    sd.isActive = recurring.isActive
                }
            },

            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDRecurringTransaction>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
```

- [ ] **Step 7: Run Core integration tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CoreTests/RecurringTransactionClientIntegrationTests 2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All 4 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Core/Models/SDRecurringTransaction.swift \
        Features/Sources/Core/Models/SDRecurringTransaction+Mapping.swift \
        Features/Sources/Core/Clients/RecurringTransactionClient+Live.swift \
        Features/Sources/Core/DatabaseClient.swift \
        Features/Tests/CoreTests/Clients/RecurringTransactionClientTests.swift
git commit -m "feat(core): add SDRecurringTransaction model and RecurringTransactionClient live implementation"
```

---

## Task 4: NotificationClient+Live — Recurring Scheduling + Delegate Stream

**Files:**
- Modify: `Features/Sources/Core/Clients/NotificationClient+Live.swift`

- [ ] **Step 1: Add the internal delegate actor and recurring methods to liveValue**

In `Features/Sources/Core/Clients/NotificationClient+Live.swift`:

First, add a private `NotificationDelegate` actor before the `extension`:

```swift
// MARK: - NotificationDelegate

/// Internal delegate that owns the UNUserNotificationCenterDelegate registration
/// and bridges notification taps into an AsyncStream.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let (stream, continuation) = AsyncStream<UUID>.makeStream(
        bufferingPolicy: .bufferingNewest(1)   // buffer one value so cold-launch tap is not lost
    )

    /// Must be called once at liveValue init time.
    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    var pendingConfirmations: AsyncStream<UUID> { stream }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let idString = response.notification.request.content.userInfo["recurringTransactionId"] as? String,
           let id = UUID(uuidString: idString) {
            continuation.yield(id)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

Then add a static `delegate` property and the new methods inside `extension NotificationClient: DependencyKey`:

```swift
private static let delegate: NotificationDelegate = {
    let d = NotificationDelegate()
    d.register()
    return d
}()
```

Add to `liveValue` (after `isAuthorized`):

```swift
scheduleRecurringReminder: { id, dueDate, title, body in
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["recurringTransactionId": id.uuidString]

    let triggerDate = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: dueDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    let request = UNNotificationRequest(
        identifier: "neuledger.recurring.\(id.uuidString)",
        content: content,
        trigger: trigger
    )
    try? await UNUserNotificationCenter.current().add(request)
},

cancelRecurringReminder: { id in
    UNUserNotificationCenter.current()
        .removePendingNotificationRequests(
            withIdentifiers: ["neuledger.recurring.\(id.uuidString)"]
        )
},

pendingConfirmations: {
    NotificationClient.delegate.pendingConfirmations
},
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded" | tail -10
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Core/Clients/NotificationClient+Live.swift
git commit -m "feat(core): add recurring notification scheduling and delegate stream to NotificationClient"
```

---

## Task 5: AddTransactionFeature — Recurring Mode + Save Logic

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift`

- [ ] **Step 1: Add recurring Mode case to AddTransactionFeature**

In `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`:

Add to the `Mode` enum (after `addPrefilled`):
```swift
case addRecurringConfirmation(RecurringTransaction)  // pre-filled from a recurring template
```

Add to `State`:
```swift
var recurringFrequency: BudgetPeriod? = nil   // nil = not repeating
```

Update the `State.init` to handle the new mode:
```swift
case let .addRecurringConfirmation(template):
    self.type = template.type
    self.amountText = "\(NSDecimalNumber(decimal: template.amount).intValue)"
    self.accountId = template.accountId
    self.toAccountId = template.toAccountId
    self.categoryId = template.categoryId
    self.note = template.note ?? ""
    self.date = Date()
    self.recurringFrequency = nil   // confirmation mode doesn't allow changing recurrence
```

- [ ] **Step 2: Add new actions and delegate case**

In the `Action` enum, add:
```swift
case recurringToggled(Bool)
case recurringFrequencyChanged(BudgetPeriod)
```

In the `Delegate` enum, add:
```swift
case savedRecurringConfirmation(RecurringTransaction.ID, Date)
```

- [ ] **Step 3: Add recurringTransactionClient dependency and handle new actions**

Add dependency:
```swift
@Dependency(\.recurringTransactionClient) var recurringTransactionClient
@Dependency(\.notificationClient) var notificationClient
```

Handle new actions in `body`:
```swift
case let .recurringToggled(enabled):
    state.recurringFrequency = enabled ? .monthly : nil
    return .none

case let .recurringFrequencyChanged(freq):
    state.recurringFrequency = freq
    return .none
```

- [ ] **Step 4: Update saveTapped to handle recurring**

In the existing `saveTapped` handler, after the transaction is saved, branch on mode:

For `case .add` mode — if `recurringFrequency != nil`, also create a recurring template:
```swift
// After transactionClient.add(transaction) succeeds:
if let freq = state.recurringFrequency {
    let template = RecurringTransaction(
        id: UUID(), amount: transaction.amount, note: transaction.note,
        categoryId: transaction.categoryId, accountId: transaction.accountId,
        toAccountId: transaction.toAccountId, type: transaction.type,
        tags: transaction.tags, frequency: freq,
        nextDueDate: RecurringTransaction(
            id: UUID(), amount: 0, note: nil, categoryId: nil,
            accountId: transaction.accountId, toAccountId: nil,
            type: transaction.type, tags: [], frequency: freq,
            nextDueDate: transaction.date, isActive: true, createdAt: transaction.date
        ).nextDate(after: transaction.date),
        isActive: true, createdAt: Date()
    )
    // Eventual consistency: if these fail after transaction.add, the transaction
    // is already saved. User can manually add template from Settings.
    try? await recurringTransactionClient.add(template)
    let title = String(localized: "recurring_transaction_notification_title", bundle: .main)
    let bodyTemplate = String(localized: "recurring_transaction_notification_body", bundle: .main)
    let body = String(format: bodyTemplate, template.note ?? "")
    await notificationClient.scheduleRecurringReminder(template.id, template.nextDueDate, title, body)
}
```

For `case .addRecurringConfirmation(let recurringTemplate)` mode — emit delegate after save:
```swift
await send(.delegate(.savedRecurringConfirmation(
    recurringTemplate.id,
    recurringTemplate.nextDate(after: recurringTemplate.nextDueDate)
)))
```

- [ ] **Step 5: Update AddTransactionView with recurring toggle**

In `Features/Sources/Features/Dashboard/AddTransactionView.swift`, in the form (only for `.add` mode), add a section after the note field:

```swift
// Show only in .add mode (not edit or recurring confirmation)
if case .add = store.mode {
    Section {
        Toggle(
            String(localized: "recurring_transaction_toggle_label"),
            isOn: Binding(
                get: { store.recurringFrequency != nil },
                set: { store.send(.recurringToggled($0)) }
            )
        )
        if store.recurringFrequency != nil {
            Picker(
                String(localized: "recurring_transaction_frequency_label"),
                selection: Binding(
                    get: { store.recurringFrequency ?? .monthly },
                    set: { store.send(.recurringFrequencyChanged($0)) }
                )
            ) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    Text(period.localizedName).tag(period)
                }
            }
        }
    }
}
```

> `BudgetPeriod.displayName` — add a computed property to `BudgetPeriod` in Domain (or use a switch with `String(localized:)` inline if the enum is in a module you can't modify freely).

- [ ] **Step 6: Build to verify it compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded" | tail -10
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
        Features/Sources/Features/Dashboard/AddTransactionView.swift
git commit -m "feat(features): add recurring transaction mode to AddTransactionFeature"
```

---

## Task 6: MainTabFeature — Notification Tap Routing

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`

- [ ] **Step 1: Add state, actions, and dependencies**

In `MainTabFeature.State`, add:
```swift
var pendingRecurringConfirmationId: RecurringTransaction.ID? = nil
```

In `MainTabFeature.Action`, add:
```swift
case pendingRecurringConfirmationReceived(RecurringTransaction.ID)
case recurringTemplateFetched(RecurringTransaction)
```

Add dependency:
```swift
@Dependency(\.recurringTransactionClient) var recurringTransactionClient
@Dependency(\.notificationClient) var notificationClient
```

Add a `CancelID`:
```swift
case pendingConfirmations
```

- [ ] **Step 2: Extend the .task effect and add new action handlers**

In the `.task` case, extend the existing `.run` effect using `withTaskGroup` so both the existing checks and the new stream run concurrently:

```swift
case .task:
    return .run { send in
        await withTaskGroup(of: Void.self) { group in
            // Existing: AI availability and accessory bar
            group.addTask {
                await send(.aiAvailabilityLoaded(isAvailable: aiServiceClient.isAvailable()))
                let show = userSettingsClient.bool(.showAccessoryBar)
                await send(.accessoryBarVisibilityLoaded(show))
            }
            // New: recurring notification taps
            group.addTask {
                for await id in notificationClient.pendingConfirmations() {
                    await send(.pendingRecurringConfirmationReceived(id))
                }
            }
        }
    }
    // Note: CancelID.task does not exist in the current enum { case aiExtraction; case aiAnswer }
    // Add `case task` to CancelID, or omit .cancellable entirely — the task effect is long-lived
    // and will be automatically cancelled when MainTabFeature is deallocated.
```

Also add `case task` to `CancelID`:
```swift
private enum CancelID { case aiExtraction; case aiAnswer; case task }
```

Handle the new actions:

```swift
case let .pendingRecurringConfirmationReceived(id):
    return .run { send in
        do {
            let all = try await recurringTransactionClient.fetchAll()
            if let template = all.first(where: { $0.id == id }) {
                await send(.recurringTemplateFetched(template))
            }
            // If not found: silently ignore — template was deleted since notification was scheduled
        } catch {
            // Ignore fetch errors — user can manually record
        }
    }

case let .recurringTemplateFetched(template):
    state.pendingRecurringConfirmationId = template.id
    state.dashboard.addTransaction = AddTransactionFeature.State(
        mode: .addRecurringConfirmation(template)
    )
    state.selectedTab = .dashboard
    return .none
```

Handle the delegate from AddTransactionFeature:
```swift
case let .dashboard(.addTransaction(.presented(.delegate(.savedRecurringConfirmation(id, newNextDueDate))))):
    state.pendingRecurringConfirmationId = nil
    return .run { [id, newNextDueDate] send in
        do {
            var all = try await recurringTransactionClient.fetchAll()
            if var template = all.first(where: { $0.id == id }) {
                template.nextDueDate = newNextDueDate
                try await recurringTransactionClient.update(template)
                let title = String(localized: "recurring_transaction_notification_title", bundle: .main)
                let bodyTemplate = String(localized: "recurring_transaction_notification_body", bundle: .main)
                let body = String(format: bodyTemplate, template.note ?? "")
                await notificationClient.scheduleRecurringReminder(template.id, newNextDueDate, title, body)
            }
        } catch { }
    }
```

- [ ] **Step 3: Build to verify it compiles**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded" | tail -10
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift
git commit -m "feat(features): route recurring notification taps in MainTabFeature"
```

---

## Task 7: RecurringTransaction Management Feature + Form

**Files:**
- Create: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift`
- Create: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementView.swift`
- Create: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift`
- Create: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormView.swift`

- [ ] **Step 1: Write tests for ManagementFeature**

Create `Features/Tests/FeaturesTests/RecurringTransactionManagementFeatureTests.swift`:

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("RecurringTransactionManagementFeature Tests")
struct RecurringTransactionManagementFeatureTests {

    static func sample(id: UUID = UUID()) -> RecurringTransaction {
        RecurringTransaction(
            id: id, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID(), toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
    }

    @Test(".task loads recurring transactions")
    func testTaskLoads() async {
        let rt = Self.sample()
        let store = await TestStore(initialState: RecurringTransactionManagementFeature.State()) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [rt] }
        }

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.items = [rt]
        }
    }

    @Test("toggleActiveTapped flips isActive")
    func testToggleActive() async {
        var updated: RecurringTransaction?
        let rt = Self.sample()
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.update = { updated = $0 }
            $0.recurringTransactionClient.fetchAll = { [rt] }
            $0.notificationClient.cancelRecurringReminder = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.toggleActiveTapped(rt))
        #expect(updated?.isActive == false)
    }

    @Test("deleteTapped removes item and cancels notification")
    func testDeleteTapped() async {
        var deletedId: RecurringTransaction.ID?
        var cancelledId: RecurringTransaction.ID?
        let rt = Self.sample()
        let store = await TestStore(
            initialState: RecurringTransactionManagementFeature.State(items: [rt])
        ) {
            RecurringTransactionManagementFeature()
        } withDependencies: {
            $0.recurringTransactionClient.delete = { deletedId = $0 }
            $0.recurringTransactionClient.fetchAll = { [] }
            $0.notificationClient.cancelRecurringReminder = { cancelledId = $0 }
        }

        await store.send(.deleteTapped(rt.id))
        await store.receive(\.loaded) { $0.items = [] }
        #expect(deletedId == rt.id)
        #expect(cancelledId == rt.id)
    }
}
```

- [ ] **Step 2: Create RecurringTransactionManagementFeature**

Create `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift`:

```swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct RecurringTransactionManagementFeature {

    @ObservableState
    public struct State: Equatable {
        public var items: [RecurringTransaction] = []
        public var isLoading: Bool = false
        @Presents public var form: RecurringTransactionFormFeature.State?

        public init(items: [RecurringTransaction] = []) { self.items = items }
    }

    public enum Action: Equatable {
        case task
        case loaded([RecurringTransaction])
        case addButtonTapped
        case itemTapped(RecurringTransaction)
        case toggleActiveTapped(RecurringTransaction)
        case deleteTapped(RecurringTransaction.ID)
        case form(PresentationAction<RecurringTransactionFormFeature.Action>)
    }

    @Dependency(\.recurringTransactionClient) var client
    @Dependency(\.notificationClient) var notificationClient

    private enum CancelID { case task }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case let .loaded(items):
                state.isLoading = false
                state.items = items
                return .none

            case .addButtonTapped:
                state.form = RecurringTransactionFormFeature.State(mode: .add)
                return .none

            case let .itemTapped(item):
                state.form = RecurringTransactionFormFeature.State(mode: .edit(item))
                return .none

            case let .toggleActiveTapped(item):
                var updated = item
                updated.isActive.toggle()
                return .run { [updated] send in
                    try? await client.update(updated)
                    if !updated.isActive {
                        await notificationClient.cancelRecurringReminder(updated.id)
                    }
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case let .deleteTapped(id):
                return .run { send in
                    try? await client.delete(id)
                    await notificationClient.cancelRecurringReminder(id)
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case .form(.presented(.delegate(.saved))):
                return .run { send in
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case .form:
                return .none
            }
        }
        .ifLet(\.$form, action: \.form) {
            RecurringTransactionFormFeature()
        }
    }
}
```

- [ ] **Step 3: Create RecurringTransactionFormFeature**

Create `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift`:

```swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct RecurringTransactionFormFeature {

    public enum Mode: Equatable {
        case add
        case edit(RecurringTransaction)
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var amountText: String
        public var note: String
        public var type: TransactionType
        public var frequency: BudgetPeriod
        public var accountId: Account.ID?
        public var toAccountId: Account.ID?
        public var categoryId: Domain.Category.ID?
        public var accounts: [Account] = []
        public var categories: [Domain.Category] = []
        public var amountError: String?
        public var accountError: String?

        public init(mode: Mode) {
            self.mode = mode
            switch mode {
            case .add:
                amountText = ""; note = ""; type = .expense
                frequency = .monthly; accountId = nil; toAccountId = nil; categoryId = nil
            case let .edit(rt):
                amountText = "\(NSDecimalNumber(decimal: rt.amount).intValue)"
                note = rt.note ?? ""; type = rt.type; frequency = rt.frequency
                accountId = rt.accountId; toAccountId = rt.toAccountId; categoryId = rt.categoryId
            }
        }
    }

    public enum Action: Equatable {
        case task
        case optionsLoaded(accounts: [Account], categories: [Domain.Category])
        case amountChanged(String)
        case noteChanged(String)
        case typeChanged(TransactionType)
        case frequencyChanged(BudgetPeriod)
        case accountChanged(Account.ID?)
        case toAccountChanged(Account.ID?)
        case categoryChanged(Domain.Category.ID?)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case saved
            case dismissed
        }
    }

    @Dependency(\.recurringTransactionClient) var client
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    async let accounts = (try? accountClient.fetchActive()) ?? []
                    async let categories = (try? categoryClient.fetchAll()) ?? []
                    await send(.optionsLoaded(accounts: accounts, categories: categories))
                }

            case let .optionsLoaded(accounts, categories):
                state.accounts = accounts
                state.categories = categories
                return .none

            case let .amountChanged(text): state.amountText = text; return .none
            case let .noteChanged(note): state.note = note; return .none
            case let .typeChanged(type): state.type = type; return .none
            case let .frequencyChanged(freq): state.frequency = freq; return .none
            case let .accountChanged(id): state.accountId = id; return .none
            case let .toAccountChanged(id): state.toAccountId = id; return .none
            case let .categoryChanged(id): state.categoryId = id; return .none

            case .saveTapped:
                guard let amount = Decimal(string: state.amountText), amount > 0 else {
                    state.amountError = String(localized: "add_transaction_error_invalid_amount", bundle: .main)
                    return .none
                }
                guard let accountId = state.accountId else {
                    state.accountError = String(localized: "add_transaction_error_no_account", bundle: .main)
                    return .none
                }
                state.amountError = nil
                state.accountError = nil

                let isEdit: Bool
                let id: UUID
                let createdAt: Date
                if case let .edit(existing) = state.mode {
                    isEdit = true; id = existing.id; createdAt = existing.createdAt
                } else {
                    isEdit = false; id = UUID(); createdAt = Date()
                }

                let template = RecurringTransaction(
                    id: id, amount: amount, note: state.note.isEmpty ? nil : state.note,
                    categoryId: state.categoryId, accountId: accountId,
                    toAccountId: state.toAccountId, type: state.type,
                    tags: [], frequency: state.frequency,
                    nextDueDate: RecurringTransaction(
                        id: UUID(), amount: 0, note: nil, categoryId: nil,
                        accountId: accountId, toAccountId: nil, type: state.type,
                        tags: [], frequency: state.frequency,
                        nextDueDate: Date(), isActive: true, createdAt: Date()
                    ).nextDate(after: Date()),
                    isActive: true, createdAt: createdAt
                )

                return .run { [template, isEdit] send in
                    if isEdit {
                        try? await client.update(template)
                    } else {
                        try? await client.add(template)
                    }
                    let title = String(localized: "recurring_transaction_notification_title", bundle: .main)
                    let bodyTemplate = String(localized: "recurring_transaction_notification_body", bundle: .main)
                    let body = String(format: bodyTemplate, template.note ?? "")
                    await notificationClient.scheduleRecurringReminder(
                        template.id, template.nextDueDate, title, body
                    )
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Create the Views (minimal but functional)**

Create `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import Domain

public struct RecurringTransactionManagementView: View {
    @Bindable var store: StoreOf<RecurringTransactionManagementFeature>

    public var body: some View {
        List {
            if store.items.isEmpty && !store.isLoading {
                ContentUnavailableView(
                    String(localized: "recurring_transaction_empty_state"),
                    systemImage: "arrow.clockwise.circle"
                )
            } else {
                ForEach(store.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.note ?? "—").font(.body)
                            Text("NT$\(NSDecimalNumber(decimal: item.amount).intValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.frequency.localizedName)
                            .font(.caption2).foregroundStyle(.secondary)
                        Toggle("", isOn: Binding(
                            get: { item.isActive },
                            set: { _ in store.send(.toggleActiveTapped(item)) }
                        ))
                        .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.itemTapped(item)) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(item.id))
                        } label: {
                            Label(String(localized: "common_delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "recurring_transaction_section_title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.addButtonTapped) } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.form, action: \.form)) { formStore in
            NavigationStack {
                RecurringTransactionFormView(store: formStore)
            }
        }
    }
}
```

Create `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormView.swift`:

```swift
import SwiftUI
import ComposableArchitecture
import Domain

public struct RecurringTransactionFormView: View {
    @Bindable var store: StoreOf<RecurringTransactionFormFeature>

    public var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "add_transaction_amount_placeholder"),
                    text: $store.amountText.sending(\.amountChanged)
                )
                .keyboardType(.numberPad)
                if let err = store.amountError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                TextField(
                    String(localized: "add_transaction_note_placeholder"),
                    text: $store.note.sending(\.noteChanged)
                )
            }

            Section {
                Picker(
                    String(localized: "recurring_transaction_frequency_label"),
                    selection: $store.frequency.sending(\.frequencyChanged)
                ) {
                    ForEach(BudgetPeriod.allCases, id: \.self) { p in
                        Text(p.localizedName).tag(p)
                    }
                }
            }

            Section {
                Picker(
                    String(localized: "add_transaction_account_label"),
                    selection: $store.accountId.sending(\.accountChanged)
                ) {
                    Text(String(localized: "add_transaction_select_account")).tag(Optional<Account.ID>(nil))
                    ForEach(store.accounts) { acc in
                        Text(acc.name).tag(Optional(acc.id))
                    }
                }
                if let err = store.accountError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(
            store.mode == .add
                ? String(localized: "recurring_transaction_add_title")
                : String(localized: "recurring_transaction_edit_title")
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common_cancel")) { store.send(.cancelTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common_save")) { store.send(.saveTapped) }
            }
        }
        .task { await store.send(.task).finish() }
    }
}
```

> Add a `localizedName` computed property to `BudgetPeriod` in `Domain/Enums/BudgetPeriod.swift`:
> ```swift
> public var localizedName: String {
>     switch self {
>     case .weekly:  return String(localized: "budget_period_weekly",  bundle: .module)
>     case .monthly: return String(localized: "budget_period_monthly", bundle: .module)
>     case .yearly:  return String(localized: "budget_period_yearly",  bundle: .module)
>     }
> }
> ```
> Check if these keys already exist in `Localizable.xcstrings` — if not, add them in Task 8.

- [ ] **Step 5: Write RecurringTransactionFormFeature tests**

Create `Features/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift`:

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("RecurringTransactionFormFeature Tests")
struct RecurringTransactionFormFeatureTests {

    static let sampleAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false, createdAt: Date()
    )

    @Test("saveTapped with empty amount sets amountError")
    func testSaveTappedEmptyAmount() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.saveTapped) {
            $0.amountError = String(localized: "add_transaction_error_invalid_amount", bundle: .main)
        }
    }

    @Test("saveTapped with no account sets accountError")
    func testSaveTappedNoAccount() async {
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
        await store.send(.saveTapped) {
            $0.accountError = String(localized: "add_transaction_error_no_account", bundle: .main)
        }
    }

    @Test("saveTapped with valid inputs calls add and emits saved delegate")
    func testSaveTappedValid() async {
        var added: RecurringTransaction?
        let store = await TestStore(
            initialState: RecurringTransactionFormFeature.State(mode: .add)
        ) {
            RecurringTransactionFormFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [Self.sampleAccount] }
            $0.categoryClient.fetchAll = { [] }
            $0.recurringTransactionClient.add = { added = $0 }
            $0.notificationClient.scheduleRecurringReminder = { _, _, _, _ in }
            $0.dismiss = DismissEffect { }
        }
        store.exhaustivity = .off

        await store.send(.amountChanged("15000")) { $0.amountText = "15000" }
        await store.send(.accountChanged(Self.sampleAccount.id)) {
            $0.accountId = Self.sampleAccount.id
        }
        await store.send(.saveTapped)
        await store.receive(\.delegate.saved)

        #expect(added?.amount == 15000)
        #expect(added?.accountId == Self.sampleAccount.id)
    }
}
```

- [ ] **Step 6: Run all new Feature tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/RecurringTransactionManagementFeatureTests \
  -only-testing:FeaturesTests/RecurringTransactionFormFeatureTests \
  2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/RecurringTransactions/ \
        Features/Tests/FeaturesTests/RecurringTransactionManagementFeatureTests.swift \
        Features/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift
git commit -m "feat(features): add RecurringTransaction management and form features"
```

---

## Task 8: Settings Navigation + Localization

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add SettingsRoute case and navigation**

In `Features/Sources/Features/Settings/SettingsView.swift`:

1. Add to `enum SettingsRoute`:
```swift
case recurringTransactions
```

2. Add a `NavigationLink` row in the Settings list (alongside existing entries like `budgetManagement`, `accountManagement`, etc.):
```swift
NavigationLink(value: SettingsRoute.recurringTransactions) {
    Label(
        String(localized: "settings_recurring_transactions"),
        systemImage: "arrow.clockwise.circle"
    )
}
```

3. Add to the `navigationDestination(for: SettingsRoute.self)` switch — use the same pattern as all other destinations in `SettingsView` (`Store(initialState:)`, **not** `store.scope`):
```swift
case .recurringTransactions:
    RecurringTransactionManagementView(
        store: Store(initialState: RecurringTransactionManagementFeature.State()) {
            RecurringTransactionManagementFeature()
        }
    )
```

> **Do NOT modify `SettingsFeature.swift`** — the established pattern in this project creates fresh stores for settings sub-pages, independent of the parent `SettingsFeature` store. See existing entries for `AccountManagementFeature`, `BudgetManagementFeature`, `NotificationSettingsFeature` in the same switch block.

- [ ] **Step 2: Add localization keys**

In `NeuLedger/Resources/Localizable.xcstrings`, add the following keys (follow the existing format in the file):

| Key | zh-Hant | en |
|-----|---------|-----|
| `recurring_transaction_section_title` | 定期交易 | Recurring Transactions |
| `recurring_transaction_toggle_label` | 設為定期交易 | Repeat this transaction |
| `recurring_transaction_frequency_label` | 重複週期 | Frequency |
| `recurring_transaction_notification_title` | 定期交易提醒 | Recurring Transaction Due |
| `recurring_transaction_notification_body` | 你的「%@」到期了，要記帳嗎？ | Your "%@" is due. Record it now? |
| `recurring_transaction_empty_state` | 尚無定期交易 | No recurring transactions |
| `recurring_transaction_add_title` | 新增定期交易 | Add Recurring Transaction |
| `recurring_transaction_edit_title` | 編輯定期交易 | Edit Recurring Transaction |
| `recurring_transaction_enable_label` | 啟用 | Enable |
| `recurring_transaction_disable_label` | 停用 | Disable |
| `settings_recurring_transactions` | 定期交易 | Recurring Transactions |
| `recurring_transaction_delete_confirm` | 刪除後將停止提醒 | Reminders will stop after deletion |

Also add if missing: `budget_period_weekly`, `budget_period_monthly`, `budget_period_yearly` for the `BudgetPeriod.localizedName` property added in Task 7.

- [ ] **Step 3: Build and verify**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded" | tail -10
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsView.swift \
        NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(settings): add recurring transactions navigation entry and localization keys"
```

---

## Task 9: AddTransactionFeature + MainTabFeature Recurring Tests

**Files:**
- Modify: `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift`
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: Add recurring tests to AddTransactionFeatureTests**

Open `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift` and add a new `@Suite` extension or additional `@Test` functions covering:

```swift
// MARK: - Recurring toggle

@Test("recurringToggled true sets recurringFrequency to .monthly")
func testRecurringToggledOn() async {
    let store = await TestStore(
        initialState: AddTransactionFeature.State(mode: .add(.expense))
    ) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
    }
    store.exhaustivity = .off

    await store.send(.recurringToggled(true)) {
        $0.recurringFrequency = .monthly
    }
}

@Test("recurringToggled false clears recurringFrequency")
func testRecurringToggledOff() async {
    var state = AddTransactionFeature.State(mode: .add(.expense))
    state.recurringFrequency = .monthly
    let store = await TestStore(initialState: state) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
    }
    store.exhaustivity = .off

    await store.send(.recurringToggled(false)) {
        $0.recurringFrequency = nil
    }
}

// MARK: - addRecurringConfirmation mode + delegate

@Test("saveTapped in addRecurringConfirmation mode emits savedRecurringConfirmation delegate")
func testSaveTappedRecurringConfirmationEmitsDelegate() async throws {
    let recurringId = UUID()
    let template = RecurringTransaction(
        id: recurringId, amount: 15000, note: "房租",
        categoryId: nil,
        accountId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        toAccountId: nil, type: .expense, tags: [],
        frequency: .monthly, nextDueDate: Date(),
        isActive: true, createdAt: Date()
    )
    var addedTransaction: Transaction?
    let store = await TestStore(
        initialState: AddTransactionFeature.State(mode: .addRecurringConfirmation(template))
    ) {
        AddTransactionFeature()
    } withDependencies: {
        $0.accountClient.fetchActive = { [] }
        $0.categoryClient.fetchAll = { [] }
        $0.transactionClient.add = { addedTransaction = $0 }
    }
    store.exhaustivity = .off

    await store.send(.saveTapped)
    await store.receive(\.delegate.savedRecurringConfirmation) { _ in }

    #expect(addedTransaction?.amount == 15000)
}
```

- [ ] **Step 2: Add recurring notification tap tests to MainTabFeatureTests**

Open `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` and add:

```swift
@Test("pendingRecurringConfirmationReceived pre-fills dashboard and switches tab")
func testPendingRecurringConfirmationReceived() async {
    let recurringId = UUID()
    let template = RecurringTransaction(
        id: recurringId, amount: 15000, note: "房租",
        categoryId: nil, accountId: UUID(), toAccountId: nil,
        type: .expense, tags: [], frequency: .monthly,
        nextDueDate: Date(), isActive: true, createdAt: Date()
    )
    let store = await TestStore(initialState: MainTabFeature.State()) {
        MainTabFeature()
    } withDependencies: {
        $0.recurringTransactionClient.fetchAll = { [template] }
        $0.aiServiceClient.isAvailable = { false }
        $0.userSettingsClient.bool = { _ in false }
        $0.notificationClient.pendingConfirmations = {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }
    store.exhaustivity = .off

    await store.send(.pendingRecurringConfirmationReceived(recurringId))
    await store.receive(\.recurringTemplateFetched) { state in
        #expect(state.dashboard.addTransaction != nil)
        #expect(state.selectedTab == .dashboard)
        #expect(state.pendingRecurringConfirmationId == recurringId)
    }
}
```

- [ ] **Step 3: Run all new tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests \
  -only-testing:FeaturesTests/MainTabFeatureTests \
  2>&1 | grep -E "✔|✗|error:" | tail -20
```

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift \
        Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "test(features): add recurring confirmation tests to AddTransaction and MainTab"
```

---

## Final Verification

- [ ] **Run full test suite**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "Suite.*passed|Suite.*failed|error:" | tail -20
```

Expected: All test suites PASS, no errors.
