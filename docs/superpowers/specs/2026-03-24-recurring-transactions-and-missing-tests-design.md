# Recurring Transactions & Missing Tests Design

**Date:** 2026-03-24
**Status:** Approved

## Overview

Two parallel work streams:

1. **Recurring Transactions** — a new feature that lets users define repeating transaction templates (weekly/monthly/yearly). When a template is due, a local notification is sent; the user taps it to open a pre-filled `AddTransaction` sheet and confirms. The real transaction is then created and the next due date is scheduled automatically.

2. **Missing Test Coverage** — fill in unit/integration tests for `BudgetManagementFeature`, `BudgetFormFeature`, `TransactionsFeature`, `FilterFeature`, `BudgetClient` (Core), and `TagClient` (Core).

---

## Part 1: Recurring Transactions

### Requirements

- User can mark any transaction as recurring when saving via `AddTransaction` sheet (toggle + frequency picker).
- Frequencies supported: **weekly / monthly / yearly** (reuses `BudgetPeriod`).
- When a recurring transaction becomes due, the app fires a **local notification**.
- Tapping the notification (cold launch or background) opens a pre-filled `AddTransaction` sheet.
- User can adjust amount/note before confirming. On confirm: real `Transaction` is created + `nextDueDate` is advanced + next notification is scheduled.
- Settings → new **"定期交易" sub-page** lists all recurring transactions with enable/disable/delete actions.
- Deleting a recurring transaction cancels its pending notification.

### Architecture

```
Domain/Entities/RecurringTransaction.swift          ← new entity
Domain/Clients/RecurringTransactionClient.swift     ← @DependencyClient interface
Core/Models/SDRecurringTransaction.swift            ← SwiftData @Model
Core/Models/SDRecurringTransaction+Mapping.swift    ← DomainConvertible
Core/Clients/RecurringTransactionClient+Live.swift  ← DependencyKey liveValue
Core/Clients/NotificationClient+Live.swift          ← extend: recurring schedule + delegate stream
Features/RecurringTransactions/
    RecurringTransactionManagementFeature.swift
    RecurringTransactionManagementView.swift
    RecurringTransactionFormFeature.swift
    RecurringTransactionFormView.swift
Features/Settings/SettingsFeature.swift             ← add recurringTransactions route
Features/Settings/SettingsView.swift                ← add navigation entry
Features/Dashboard/AddTransactionFeature.swift      ← add recurringFrequency? field
Features/Dashboard/AddTransactionView.swift         ← add recurring toggle + picker
Features/AppFeature.swift                           ← subscribe to pendingConfirmations stream
Features/MainTab/MainTabFeature.swift               ← handle pendingRecurringConfirmation action
NeuLedger/Resources/Localizable.xcstrings           ← new keys
```

---

### Domain Layer

#### `RecurringTransaction` Entity

```swift
public struct RecurringTransaction: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var amount: Decimal
    public var note: String?
    public var categoryId: Category.ID?
    public var accountId: Account.ID
    public var toAccountId: Account.ID?   // transfers only
    public var type: TransactionType
    public var tags: Set<Tag.ID>
    public var frequency: BudgetPeriod    // .weekly / .monthly / .yearly
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date
}
```

Helper on `RecurringTransaction`:
```swift
public func advancedNextDueDate(calendar: Calendar = .current) -> Date
// .weekly  → +1 week
// .monthly → +1 month
// .yearly  → +1 year
```

#### `RecurringTransactionClient`

```swift
@DependencyClient
public struct RecurringTransactionClient: Sendable {
    public var fetchAll:  @Sendable () async throws -> [RecurringTransaction]
    public var fetchDue:  @Sendable (_ on: Date) async throws -> [RecurringTransaction]
    public var add:       @Sendable (RecurringTransaction) async throws -> Void
    public var update:    @Sendable (RecurringTransaction) async throws -> Void
    public var delete:    @Sendable (RecurringTransaction.ID) async throws -> Void
}
```

`testValue = Self()` (unimplemented stubs). Registered on `DependencyValues` as `\.recurringTransactionClient`.

#### `NotificationClient` Extensions

Add to the existing `NotificationClient` struct:

```swift
/// Schedule a due-date notification for a recurring transaction.
/// Replaces any existing notification for the same ID.
public var scheduleRecurringReminder: @Sendable (
    _ id: RecurringTransaction.ID,
    _ dueDate: Date,
    _ title: String,
    _ body: String
) async -> Void = { _, _, _, _ in }

/// Cancel the scheduled notification for a recurring transaction.
public var cancelRecurringReminder: @Sendable (_ id: RecurringTransaction.ID) async -> Void = { _ in }

/// Emits a `RecurringTransaction.ID` each time the user taps a recurring-transaction notification.
/// The live implementation sets `UNUserNotificationCenter.current().delegate` internally.
public var pendingConfirmations: @Sendable () -> AsyncStream<RecurringTransaction.ID> = {
    AsyncStream { _ in }
}
```

---

### Core Layer

#### `SDRecurringTransaction`

```swift
@Model
public final class SDRecurringTransaction {
    public var id: UUID
    public var amount: Decimal
    public var note: String?
    public var categoryId: UUID?
    public var accountId: UUID
    public var toAccountId: UUID?
    public var typeRaw: String          // TransactionType.rawValue
    public var tagIds: [UUID]           // stored as plain array (no relationship needed)
    public var frequencyRaw: String     // BudgetPeriod.rawValue
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date
}
```

Add `SDRecurringTransaction` to the `Schema` array in both `DatabaseClient.liveValue` and `testValue`.

#### `NotificationClient+Live` — Delegate Stream

The live implementation holds an internal `UNUserNotificationCenterDelegate`-conforming actor that:
- Is set as `UNUserNotificationCenter.current().delegate` once, when `liveValue` is initialised.
- On `userNotificationCenter(_:didReceive:withCompletionHandler:)`, reads `notification.request.content.userInfo["recurringTransactionId"]` (a UUID string) and yields it into an `AsyncStream.Continuation`.
- `pendingConfirmations` returns the stream backed by this continuation.

Notification `userInfo` format: `["recurringTransactionId": id.uuidString]`

---

### Features Layer

#### `AddTransactionFeature` Changes

New state fields:
```swift
var recurringFrequency: BudgetPeriod? = nil   // nil = not recurring
```

New actions:
```swift
case recurringToggled(Bool)
case recurringFrequencyChanged(BudgetPeriod)
```

On `saveTapped` (when `recurringFrequency != nil`):
1. Save the `Transaction` as usual.
2. Construct a `RecurringTransaction` from current state with `nextDueDate = advancedNextDueDate(from: state.date)`.
3. Call `recurringTransactionClient.add`.
4. Call `notificationClient.scheduleRecurringReminder`.

#### `AppFeature` Changes

In `.task` effect, subscribe to `notificationClient.pendingConfirmations()`:
```swift
for await recurringId in notificationClient.pendingConfirmations() {
    await send(.pendingRecurringConfirmationReceived(recurringId))
}
```

New action: `case pendingRecurringConfirmationReceived(RecurringTransaction.ID)`

Route this to `MainTabFeature` via delegate or direct child action.

#### `MainTabFeature` Changes

New state field:
```swift
var pendingRecurringConfirmation: RecurringTransaction.ID? = nil
```

When `pendingRecurringConfirmationReceived`:
1. Fetch the `RecurringTransaction` from `recurringTransactionClient`.
2. Set `dashboard.addTransaction` to a `AddTransactionFeature.State` pre-filled from the recurring template.
3. Switch to `.dashboard` tab.

After user confirms and saves:
- Update `recurringTransaction.nextDueDate = template.advancedNextDueDate()`.
- Call `recurringTransactionClient.update`.
- Call `notificationClient.scheduleRecurringReminder` for next occurrence.

#### `RecurringTransactionManagementFeature`

- `.task`: loads all recurring transactions via `recurringTransactionClient.fetchAll`.
- `toggleActiveTapped(id)`: updates `isActive`, cancels or reschedules notification.
- `deleteTapped(id)`: deletes + cancels notification.
- Navigates to `RecurringTransactionFormFeature` for add/edit.

#### `RecurringTransactionFormFeature`

- Fields: amount (required), type, account, toAccount (transfer), category, note, tags, frequency.
- Validation: amount > 0, accountId set, toAccountId ≠ accountId for transfers.
- On save: `add` or `update` + schedule/reschedule notification.

---

### Localization Keys (新增)

| Key | zh-Hant | en |
|-----|---------|----|
| `recurring_transaction_section_title` | 定期交易 | Recurring Transactions |
| `recurring_transaction_toggle_label` | 設為定期交易 | Repeat this transaction |
| `recurring_transaction_frequency_label` | 重複週期 | Frequency |
| `recurring_transaction_notification_title` | 定期交易提醒 | Recurring Transaction Due |
| `recurring_transaction_notification_body` | 你的「%@」到期了，要記帳嗎？ | Your "%@" is due. Record it now? |
| `recurring_transaction_empty_state` | 尚無定期交易 | No recurring transactions |
| `recurring_transaction_delete_confirm` | 刪除後將停止提醒 | Reminders will stop after deletion |

---

## Part 2: Missing Test Coverage

### Files to Create

| File | Scope |
|------|-------|
| `FeaturesTests/BudgetManagementFeatureTests.swift` | load budgets, delete, toggle active |
| `FeaturesTests/BudgetFormFeatureTests.swift` | validation (empty name, zero amount), save new, save edit |
| `FeaturesTests/TransactionsFeatureTests.swift` | load list, search delegate, filter delegate |
| `FeaturesTests/FilterFeatureTests.swift` | filter field changes, apply action, reset |
| `CoreTests/BudgetClientTests.swift` | add, fetch, update, delete integration (in-memory SwiftData) |
| `CoreTests/TagClientTests.swift` | add, fetch, update, delete, auto-disassociate from transactions |

### Test Standards

- Use `@Suite` / `@Test` (Swift Testing, not XCTest).
- Feature tests use TCA `TestStore` with dependency overrides.
- Core tests use `DatabaseClient.testValue` (in-memory container).
- Each test covers one behaviour; no multi-assertion tests.

---

## Implementation Order

1. **Missing tests** (independent, no new files required) — do first to build confidence.
2. **Domain layer** — `RecurringTransaction` entity + `RecurringTransactionClient` interface + `NotificationClient` extension.
3. **Core layer** — `SDRecurringTransaction` + `RecurringTransactionClient+Live` + `NotificationClient+Live` delegate stream.
4. **AddTransactionFeature** — recurring toggle + save logic.
5. **AppFeature + MainTabFeature** — notification tap routing.
6. **RecurringTransactionManagementFeature + Form** — Settings sub-page.
7. **Localization** — all new keys.
8. **Tests for new feature** — all test files listed above.
