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
Domain/Clients/NotificationClient.swift             ← add 3 new fields to struct body + update testValue
Core/Models/SDRecurringTransaction.swift            ← SwiftData @Model
Core/Models/SDRecurringTransaction+Mapping.swift    ← DomainConvertible
Core/Clients/RecurringTransactionClient+Live.swift  ← DependencyKey liveValue
Core/Clients/NotificationClient+Live.swift          ← recurring schedule + delegate stream
Features/RecurringTransactions/
    RecurringTransactionManagementFeature.swift
    RecurringTransactionManagementView.swift
    RecurringTransactionFormFeature.swift
    RecurringTransactionFormView.swift
Features/Settings/SettingsView.swift                ← add case to SettingsRoute + navigationDestination
Features/Dashboard/AddTransactionFeature.swift      ← add recurringFrequency? + new Mode case
Features/Dashboard/AddTransactionView.swift         ← add recurring toggle + picker
Features/AppFeature.swift                           ← add .task action + subscribe to pendingConfirmations
Features/MainTab/MainTabFeature.swift               ← handle pendingRecurringConfirmation
NeuLedger/Resources/Localizable.xcstrings           ← new keys
```

> **Note:** `SettingsFeature.swift` does NOT need changes — routing is handled entirely in `SettingsView.swift` via `SettingsRoute` enum and `navigationDestination`, consistent with the existing pattern.
> **Note:** `AppFeature.swift` does NOT need changes — the notification tap stream is subscribed to from within `MainTabFeature.task`.

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
    public var tags: [Tag]                // full Tag objects, consistent with Transaction.tags
    public var frequency: BudgetPeriod    // .weekly / .monthly / .yearly
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date
}
```

Helper on `RecurringTransaction` — single canonical signature:
```swift
/// Returns the next due date after `base` given `frequency`.
/// Used both when creating (base = state.date) and when advancing after confirmation (base = self.nextDueDate).
public func nextDate(after base: Date, calendar: Calendar = .current) -> Date
// .weekly  → calendar.date(byAdding: .weekOfYear, value: 1, to: base)!
// .monthly → calendar.date(byAdding: .month, value: 1, to: base)!
// .yearly  → calendar.date(byAdding: .year, value: 1, to: base)!
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

`testValue = Self()` (unimplemented stubs via `@DependencyClient` macro). Registered on `DependencyValues` as `\.recurringTransactionClient`.

#### `NotificationClient` — New Fields (added to struct body)

The three new fields are added **directly inside the `NotificationClient` struct body** in `NotificationClient.swift`, and the explicit `testValue` memberwise init in the `TestDependencyKey` extension is updated to include them.

```swift
// Added inside NotificationClient struct body:

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
/// The live implementation owns the UNUserNotificationCenterDelegate internally.
/// testValue emits an immediately-finishing stream to prevent test hangs.
public var pendingConfirmations: @Sendable () -> AsyncStream<RecurringTransaction.ID> = {
    var continuation: AsyncStream<RecurringTransaction.ID>.Continuation?
    let stream = AsyncStream { continuation = $0 }
    continuation?.finish()
    return stream
}
```

Update `testValue` in the `TestDependencyKey` extension — the existing memberwise call must include the three new parameters:
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
        var continuation: AsyncStream<RecurringTransaction.ID>.Continuation?
        let stream = AsyncStream { continuation = $0 }
        continuation?.finish()
        return stream
    }
)
```

---

### Core Layer

#### `SDRecurringTransaction`

`tags` on the domain entity are full `Tag` objects (consistent with `Transaction.tags: [Tag]`). The SwiftData model stores tag IDs as a plain `[UUID]` array (no `@Relationship` — avoids cascade complexity). The `toDomain()` mapper resolves full `Tag` objects by fetching them from context by ID.

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
    public var tagIds: [UUID]           // resolved to [Tag] in toDomain()
    public var frequencyRaw: String     // BudgetPeriod.rawValue
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date
}
```

`toDomain(context:)` fetches `SDTag` objects by their IDs to reconstruct `[Tag]`. Add `SDRecurringTransaction` to the `Schema` array in both `DatabaseClient.liveValue` and `testValue`.

#### `NotificationClient+Live` — Delegate Stream

The live implementation holds an internal `UNUserNotificationCenterDelegate`-conforming actor (`NotificationDelegate`) that:
- Is created once when `liveValue` is initialised and set as `UNUserNotificationCenter.current().delegate`.
- Uses `AsyncStream.makeStream()` to obtain a `(stream, continuation)` pair stored on the actor.
- On `userNotificationCenter(_:didReceive:withCompletionHandler:)`: reads `userInfo["recurringTransactionId"]` (a UUID string), yields the parsed UUID into the continuation.
- `pendingConfirmations` closure returns the stream. The `AsyncStream` continuation buffers one pending value, so a notification tap that arrives before `AppFeature.task` subscribes is not lost.

Notification `userInfo` format: `["recurringTransactionId": id.uuidString]`

---

### Features Layer

#### `AddTransactionFeature` Changes

New `Mode` case for recurring confirmation pre-fill — the existing `.add(TransactionType)` and `.addPrefilled(ExtractedTransaction)` cases are **unchanged**. Only one new case is added:
```swift
public enum Mode: Equatable, Sendable {
    case add(TransactionType)                            // unchanged
    case edit(Transaction)                               // unchanged
    case addPrefilled(ExtractedTransaction)              // unchanged — AI prefill
    case addRecurringConfirmation(RecurringTransaction)  // NEW: pre-filled from template
}
```

New state field (only relevant in `.add` and `.addRecurringConfirmation` modes):
```swift
var recurringFrequency: BudgetPeriod? = nil   // nil = not recurring
```

New actions:
```swift
case recurringToggled(Bool)
case recurringFrequencyChanged(BudgetPeriod)
```

`saveTapped` when `recurringFrequency != nil` (`.add` mode only):
1. Call `transactionClient.add` as usual.
2. Construct `RecurringTransaction` with `nextDueDate = template.nextDate(after: state.date)`.
3. Call `recurringTransactionClient.add`.
4. Call `notificationClient.scheduleRecurringReminder`.

> **Eventual consistency note:** If step 3 or 4 fails after step 1 succeeds, the transaction is persisted but the recurring template is not created. This is acceptable for v1 — the user can manually add the template from Settings. No rollback is implemented.

`saveTapped` in `.addRecurringConfirmation(let template)` mode:
1. Call `transactionClient.add` as usual.
2. Compute `newNextDueDate = template.nextDate(after: template.nextDueDate)`.
3. Emit `.delegate(.savedRecurringConfirmation(template.id, newNextDueDate))` so `MainTabFeature` can update + reschedule.

New delegate case:
```swift
case savedRecurringConfirmation(RecurringTransaction.ID, Date)
```

#### `AppFeature` — No Changes Required

`AppFeature` uses `.ifLet(\.destination.main, action: \.main)` to compose `MainTabFeature`. The notification stream subscription is handled entirely inside `MainTabFeature.task` (see below), so `AppFeature.swift` does not need to be modified.

#### `MainTabFeature` Changes

The `pendingConfirmations` stream is subscribed to **inside `MainTabFeature.task`** (which already exists). Add a second `for await` loop in the same `.task` `.run` block, or use `withTaskGroup` to run both the existing AI availability check and the new stream subscription concurrently.

New state field:
```swift
var pendingRecurringConfirmationId: RecurringTransaction.ID? = nil
```

Add action: `case pendingRecurringConfirmationReceived(RecurringTransaction.ID)`.

In `MainTabFeature.task`:
```swift
// Existing: AI availability check
// New: subscribe to recurring notification taps
for await recurringId in notificationClient.pendingConfirmations() {
    await send(.pendingRecurringConfirmationReceived(recurringId))
}
```

When `.pendingRecurringConfirmationReceived(id)`:
```swift
return .run { send in
    do {
        let all = try await recurringTransactionClient.fetchAll()
        guard let template = all.first(where: { $0.id == id }) else { return }
        await send(.recurringTemplateFetched(template))
    } catch {
        // silently ignore — template may have been deleted
    }
}
```

New action `case recurringTemplateFetched(RecurringTransaction)`:
1. Store `pendingRecurringConfirmationId = template.id`.
2. Set `dashboard.addTransaction = AddTransactionFeature.State(mode: .addRecurringConfirmation(template))`.
3. Switch `selectedTab = .dashboard`.

When `dashboard` emits `.delegate(.savedRecurringConfirmation(id, newNextDueDate))`:
1. Update the `RecurringTransaction.nextDueDate` via `recurringTransactionClient.update`.
2. Reschedule notification via `notificationClient.scheduleRecurringReminder`.
3. Clear `pendingRecurringConfirmationId`.

#### `RecurringTransactionManagementFeature`

- `.task`: loads all recurring transactions via `recurringTransactionClient.fetchAll`.
- `toggleActiveTapped(id)`: updates `isActive`, cancels or reschedules notification accordingly.
- `deleteTapped(id)`: deletes + cancels notification via `notificationClient.cancelRecurringReminder`.
- Navigates to `RecurringTransactionFormFeature` for add/edit.

#### `RecurringTransactionFormFeature`

- Fields: amount (required), type, account, toAccount (transfer), category, note, tags, frequency.
- Validation: amount > 0, accountId set, toAccountId ≠ accountId for transfers.
- On save: `add` or `update` + schedule/reschedule notification.

#### `SettingsView` Changes

Add to `SettingsRoute` enum:
```swift
case recurringTransactions
```

Add `NavigationLink(value: SettingsRoute.recurringTransactions)` row in the Settings list.

Add `case .recurringTransactions` to the `navigationDestination` switch, rendering `RecurringTransactionManagementView`.

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
| `recurring_transaction_add_title` | 新增定期交易 | Add Recurring Transaction |
| `recurring_transaction_edit_title` | 編輯定期交易 | Edit Recurring Transaction |
| `recurring_transaction_enable_label` | 啟用 | Enable |
| `recurring_transaction_disable_label` | 停用 | Disable |
| `settings_recurring_transactions` | 定期交易 | Recurring Transactions |

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

### New Feature Test Files

| File | Scope |
|------|-------|
| `DomainTests/RecurringTransactionClientTests.swift` | testValue accessibility, dependency injection |
| `CoreTests/RecurringTransactionClientTests.swift` | add, fetchAll, fetchDue, update, delete (in-memory SwiftData) |
| `FeaturesTests/RecurringTransactionManagementFeatureTests.swift` | load, toggleActive, delete + notification cancel |
| `FeaturesTests/RecurringTransactionFormFeatureTests.swift` | validation, save new, save edit |
| `FeaturesTests/AddTransactionFeatureTests` (extend) | recurringToggled, saveTapped creates template + schedules notification, savedRecurringConfirmation delegate emitted |
| `FeaturesTests/MainTabFeatureTests` (extend) | pendingRecurringConfirmationReceived pre-fills sheet, post-save advances nextDueDate + reschedules |

### Test Standards

- Use `@Suite` / `@Test` (Swift Testing, not XCTest).
- Feature tests use TCA `TestStore` with dependency overrides.
- Core tests use `DatabaseClient.testValue` (in-memory container).
- Each test covers one behaviour; no multi-assertion tests.

---

## Implementation Order

1. **Missing tests for existing features** (independent) — BudgetManagement, BudgetForm, Transactions, Filter, BudgetClient, TagClient.
2. **Domain layer** — `RecurringTransaction` entity + `RecurringTransactionClient` interface + new fields in `NotificationClient` struct.
3. **Core layer** — `SDRecurringTransaction` + `RecurringTransactionClient+Live` + `NotificationClient+Live` delegate stream.
4. **AddTransactionFeature** — new Mode case + recurring toggle + save logic + delegate.
5. **AppFeature + MainTabFeature** — `.task` stream subscription + notification tap routing.
6. **RecurringTransactionManagementFeature + Form** — Settings sub-page.
7. **SettingsView** — add `SettingsRoute.recurringTransactions`.
8. **Localization** — all new keys.
9. **Tests for new feature** — all new test files listed above.
