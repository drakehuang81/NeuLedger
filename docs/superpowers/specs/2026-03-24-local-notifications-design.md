# Local Notifications Design

**Date:** 2026-03-24
**Status:** Approved

## Overview

Add local notification support to NeuLedger with two notification types:
1. **Daily reminder** — a fixed-time daily prompt to record transactions
2. **Budget warning** — an alert when a budget's usage crosses a user-defined threshold

Both types are fully opt-in, controlled from a dedicated **Notification Settings** sub-screen accessible from the existing Settings tab.

---

## Requirements Summary

- Both notification types implemented using `UNUserNotificationCenter` (local only, no server)
- User can toggle each type independently
- Daily reminder: single configurable time (hour + minute), repeating daily
- Budget warning: configurable threshold (50% / 60% / 70% / 80% / 90%), fires once per threshold crossing per budget period
- Notification settings live in a new sub-page (`NotificationSettingsView`) navigated to from Settings
- Permission request triggered on first toggle-on; if denied, inline banner guides user to system settings (never use `Alert` for this)

---

## Architecture

Follows the project's Clean Architecture + TCA pattern:

```
Domain/Clients/NotificationClient.swift        ← interface (@DependencyClient)
Core/Clients/NotificationClient+Live.swift     ← UNUserNotificationCenter implementation + DependencyKey
Features/NotificationSettings/
    NotificationSettingsFeature.swift          ← TCA Reducer
    NotificationSettingsView.swift             ← SwiftUI View
```

---

## Domain Layer

### NotificationClient

File: `Features/Sources/Domain/Clients/NotificationClient.swift`

```swift
@DependencyClient
public struct NotificationClient: Sendable {
    /// Request UNUserNotificationCenter authorization. Returns true if granted.
    public var requestAuthorization: @Sendable () async -> Bool = { false }

    /// Schedule (or reschedule) the daily reminder at the given hour/minute.
    /// Replaces any existing scheduled reminder.
    public var scheduleDailyReminder: @Sendable (_ hour: Int, _ minute: Int) async -> Void = { _, _ in }

    /// Cancel the daily reminder.
    public var cancelDailyReminder: @Sendable () async -> Void = {}

    /// Fire a one-shot budget warning notification immediately.
    /// budgetId is used as the unique notification identifier.
    /// title and body are pre-formatted, localized strings provided by the caller
    /// (keeping localization in the Features/Domain layer, not in Core).
    public var sendBudgetWarning: @Sendable (_ budgetId: String, _ title: String, _ body: String) async -> Void = { _, _, _ in }

    /// Read the last warned percent for a given budget+period key.
    /// Returns nil if no warning has been sent yet for this period.
    public var lastWarnedPercent: @Sendable (_ budgetId: String, _ periodKey: String) -> Int? = { _, _ in nil }

    /// Persist the warned percent for a given budget+period key.
    public var setLastWarnedPercent: @Sendable (_ percent: Int, _ budgetId: String, _ periodKey: String) -> Void = { _, _, _ in }

    /// Check current authorization status synchronously (true = authorized).
    public var isAuthorized: @Sendable () async -> Bool = { false }
}

extension NotificationClient: TestDependencyKey {
    public static let testValue = NotificationClient()
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
```

**Note:** `lastWarnedPercent` and `setLastWarnedPercent` keep all notification state inside `NotificationClient`, avoiding raw `UserDefaults` calls in other clients and keeping the feature fully testable via dependency injection.

### UserSettingsClient Int Extension

`UserSettingsClient` must be extended to support `Int` reads/writes. This requires changes in three places:

**1. `UserSettingsClient` struct** — add two new closure properties (following the existing `bool`/`setBool`, `string`/`setString` pattern):

```swift
/// Reads an Int value for the given key, returning `defaultValue` if unset.
public var int: @Sendable (_ key: SettingsKey<Int>) -> Int = { $0.defaultValue }

/// Writes an Int value for the given key.
public var setInt: @Sendable (_ value: Int, _ key: SettingsKey<Int>) -> Void
```

**2. `UserSettingsClient.testValue`** — add stubs:

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

**3. `UserSettingsClient+Live.swift`** — add live implementations, following the same guard-object idiom used by the existing `bool` implementation:

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

**4. `SettingsKey<Int>` extension** — add all notification preference keys:

```swift
public extension SettingsKey where Value == Int {
    static let dailyReminderHour   = SettingsKey(rawValue: "dailyReminderHour",   defaultValue: 21)
    static let dailyReminderMinute = SettingsKey(rawValue: "dailyReminderMinute", defaultValue: 0)
    static let budgetWarningThreshold = SettingsKey(rawValue: "budgetWarningThreshold", defaultValue: 80)
}
```

### UserSettings Bool Keys (additions)

Add to `SettingsKey where Value == Bool` extension:

```swift
static let dailyReminderEnabled   = SettingsKey(rawValue: "dailyReminderEnabled",   defaultValue: false)
static let budgetWarningEnabled   = SettingsKey(rawValue: "budgetWarningEnabled",   defaultValue: false)
```

---

## Core Layer

### NotificationClient Live Implementation

File: `Features/Sources/Core/Clients/NotificationClient+Live.swift`

Conforms to `DependencyKey` and declares `liveValue`:

```swift
extension NotificationClient: DependencyKey {
    public static let liveValue = NotificationClient(
        requestAuthorization: { ... },
        scheduleDailyReminder: { hour, minute in ... },
        cancelDailyReminder: { ... },
        sendBudgetWarning: { budgetId, budgetName, usedPercent in ... },
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
        isAuthorized: { ... }
    )
}
```

Key implementation details:

- **Authorization**: `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])` — `.badge` is omitted since we do not manage badge counts in this feature.
- **Daily reminder**: `UNCalendarNotificationTrigger` with `DateComponents(hour:minute:)` and `repeats: true`. Fixed identifier: `"neuledger.daily_reminder"`. Re-scheduling with the same identifier replaces the previous request automatically via `add(_:)` — no explicit cancel needed before reschedule.
- **Budget warning**: `UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)`. Identifier: `"neuledger.budget_warning.\(budgetId)"` — uses budget's UUID, not name, to guarantee uniqueness.
- **isAuthorized**: `await UNUserNotificationCenter.current().notificationSettings()` → `.authorizationStatus == .authorized`.

### Budget Warning Trigger Logic

Added to `TransactionClient+Live` as a private helper, called after `add` and `update` complete.

**Not called after `delete`** — this is an intentional simplification. A deletion reduces spending totals, which could clear an over-threshold state, but `lastWarnedPercent` is keyed on `periodKey` and naturally resets at the next period boundary. The edge case (a user deletes a large expense that drops them below the threshold) means the warning will not re-fire until the next period, which is acceptable. This avoids the complexity of downward threshold tracking.

**Dependency capture in `TransactionClient.liveValue`:**

All cross-client dependencies must be captured at the top level of the `liveValue` computed property, not inside individual closures:

```swift
extension TransactionClient: DependencyKey {
    public static var liveValue: TransactionClient {
        @Dependency(\.databaseClient) var databaseClient
        @Dependency(\.budgetClient) var budgetClient            // for budget warning checks
        @Dependency(\.notificationClient) var notificationClient // for budget warning checks
        @Dependency(\.userSettingsClient) var userSettingsClient // for budget warning checks

        // ... return TransactionClient(...) with closures capturing the above
    }
}
```

**No circular dependency risk:** `BudgetClient.liveValue` only depends on `databaseClient`. It does not call `transactionClient`, so adding `budgetClient` as a dependency of `TransactionClient.liveValue` is safe.

**Helper signature:**

```swift
private func checkBudgetWarnings(
    budgetClient: BudgetClient,
    notificationClient: NotificationClient,
    userSettingsClient: UserSettingsClient,
    transactionClient: TransactionClient
) async
```

(No `affectedAccountId` parameter — budgets are not account-scoped.)

Steps:
1. Read `budgetWarningEnabled` from `userSettingsClient`. If `false`, return early.
2. Read `budgetWarningThreshold` from `userSettingsClient`.
3. Fetch all active budgets via `budgetClient.fetchActive()`.
4. For each budget:
   a. Determine the current period window: compute `periodStart` from `budget.startDate` and `budget.period` (weekly: start of current ISO week relative to today; monthly: start of current calendar month; yearly: start of current year). Compute `periodEnd` as one period later.
   b. Build a `TransactionFilter` scoped to `[.expense]` types, the period's date range (`periodStart...periodEnd`), and the budget's `categoryId` (if non-nil, use `Set([budget.categoryId])`; if nil, no category filter — budget applies globally).
   c. Fetch matching transactions via `transactionClient.fetch(filter)`.
   d. Compute `totalSpent = transactions.reduce(into: Decimal(0)) { $0 += $1.amount }`.
   e. Guard `budget.amount > 0` — if zero, skip (avoid division by zero).
   f. Compute `usedPercent` using `NSDecimalNumber` to avoid `Decimal` rounding ambiguity.
      **Rounding behavior: truncation toward zero is intentional** (conservative — the user must definitively exceed the threshold before a warning fires; 79.9% does not trigger an 80% warning):
      ```swift
      let ratio = (totalSpent / budget.amount * 100) as NSDecimalNumber
      let usedPercent = ratio.intValue  // truncates toward zero
      ```
   g. Compute `periodKey` as a stable string representing the current cycle (ISO date string of `periodStart`, e.g., `"2026-03-01"`).
   h. Read `lastWarnedPercent(budgetId: budget.id, periodKey:)` from `notificationClient`.
   i. If `usedPercent >= threshold` AND `(lastWarnedPercent == nil || lastWarnedPercent! < threshold)`:
      - Format localized title and body strings (caller is responsible for localization — Core never formats localized strings directly):
        ```swift
        let title = String(localized: "notification_budget_warning_title")
        let body = String(format: String(localized: "notification_budget_warning_body"), budget.name, usedPercent)
        ```
      - Call `notificationClient.sendBudgetWarning(budgetId: budget.id, title:, body:)`.
      - Call `notificationClient.setLastWarnedPercent(usedPercent, budgetId: budget.id, periodKey:)`.
   j. (No explicit reset needed: the `periodKey` changes automatically when a new period begins, so `lastWarnedPercent` returns `nil` for the new period, allowing the warning to fire again from scratch.)

**Period key derivation:**
```swift
func periodKey(for budget: Budget, relativeTo date: Date) -> String {
    let cal = Calendar.current
    let interval: DateInterval
    switch budget.period {
    case .weekly:  interval = cal.dateInterval(of: .weekOfYear, for: date)!
    case .monthly: interval = cal.dateInterval(of: .month, for: date)!
    case .yearly:  interval = cal.dateInterval(of: .year, for: date)!
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.string(from: interval.start)
}
```

---

## Feature Layer

### NotificationSettingsFeature

File: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift`

**State:**
```swift
@ObservableState
public struct State: Equatable {
    public var dailyReminderEnabled: Bool = false
    /// Stored as a Date for easy DatePicker binding; only the hour and minute components
    /// are meaningful — the date portion is irrelevant and is not persisted.
    /// On load, reconstruct from stored hour/minute via Calendar.current.date(from:).
    /// On save, extract via Calendar.current.component(.hour/.minute, from:).
    public var reminderDate: Date = Calendar.current.date(
        from: DateComponents(hour: 21, minute: 0)
    ) ?? Date()
    public var budgetWarningEnabled: Bool = false
    public var warningThreshold: Int = 80
    public var isAuthorized: Bool = false
    public var showPermissionDeniedBanner: Bool = false
}
```

`reminderDate` stores a `Date` for clean `DatePicker` binding. On persist/load, decompose to/from `reminderHour`/`reminderMinute` via `Calendar.current.component(.hour, from:)` / `.minute`.

**Actions:**
```swift
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
```

**Reducer logic highlights:**
- `.task`: load all settings from `userSettingsClient` (`int`/`bool`), reconstruct `reminderDate` from stored hour/minute, check `notificationClient.isAuthorized()`, dispatch `authorizationStatusLoaded`. Re-checks auth status on every appearance so the banner self-heals if the user grants permission in system Settings and returns.
- `dailyReminderToggled(true)` / `budgetWarningToggled(true)`: if `!isAuthorized`, call `notificationClient.requestAuthorization()`; if it returns `false`, dispatch `.permissionDenied` and keep the toggle `false`; if `true`, update `isAuthorized`, persist, and schedule/arm.
- `reminderDateChanged`: extract hour/minute from the new `Date`, persist to `userSettingsClient`, reschedule via `notificationClient.scheduleDailyReminder`.
- `permissionDenied`: set `showPermissionDeniedBanner = true`.
- `openSystemSettingsTapped`: open `URL(string: UIApplication.openSettingsURLString)!` via `@Dependency(\.openURL)` — consistent with the existing project pattern (e.g. `SettingsFeature`), and testable via dependency injection.
- `authorizationStatusLoaded(true)`: set `isAuthorized = true`, `showPermissionDeniedBanner = false` — banner self-heals.

**Dependencies:** `notificationClient`, `userSettingsClient`

### NotificationSettingsView

File: `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift`

Layout:
```
NavigationStack
└── ScrollView
    ├── [Banner] showPermissionDeniedBanner
    │   "請前往系統「設定」開啟通知權限" + "前往設定" button
    │   (orange inline GlassContainer, not an Alert)
    │
    ├── GlassContainer — 每日記帳提醒
    │   ├── Toggle "開啟每日提醒"  ← bound to store.dailyReminderEnabled
    │   └── (visible when enabled)
    │       DatePicker "提醒時間"
    │         displayedComponents: .hourAndMinute
    │         Binding<Date> → store.reminderDate / reminderDateChanged(_:)
    │
    └── GlassContainer — 預算警告
        ├── Toggle "開啟預算警告"  ← bound to store.budgetWarningEnabled
        └── (visible when enabled)
            Picker "警告門檻"
              [50%, 60%, 70%, 80%, 90%] → store.warningThreshold / warningThresholdChanged(_:)
```

- `GlassContainer` is used for section cards, consistent with `SettingsView`.
- The permission denied banner uses `GlassContainer` with `.overlay` accent color orange, not `Alert`.

### Settings Integration

**SettingsRoute** — add `.notificationSettings` case.

**SettingsView** — add `NavigationLink` in the "管理" section (after tagManagement row):
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

**`navigationDestination`** — handle `.notificationSettings` → `NotificationSettingsView`.

---

## Localization Keys

New keys needed in `Localizable.xcstrings`:

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

---

## Error Handling

- If `requestAuthorization` returns `false` (user denied): set `showPermissionDeniedBanner = true`; keep toggle in `false` state; do not schedule notifications. Banner self-heals on next `.task` if user later grants permission in system Settings.
- If UNUserNotificationCenter throws on `add`: silently ignore (best-effort delivery — not a hard error).
- Validation: all inputs are bounded pickers/steppers; no free-form validation needed.

---

## Testing

### NotificationSettingsFeatureTests

- **Toggle on, unauthorized**: permission request fired; if denied → `permissionDenied` dispatched, `showPermissionDeniedBanner = true`, toggle remains `false`
- **Toggle on, authorized**: schedule/arm called, settings persisted, toggle `true`
- **Time changed**: `reminderDateChanged` → reschedule called with correct hour/minute extracted from new `Date`
- **Threshold changed**: `warningThresholdChanged` → persisted; no notification client call needed
- **`.task` with previously denied permission now granted**: `authorizationStatusLoaded(true)` → `isAuthorized = true`, `showPermissionDeniedBanner = false` (banner self-heals)
- **`openSystemSettingsTapped`**: settings URL opened

### Budget Warning Core Tests (in `TransactionClientTests`)

- First threshold crossing: notification fires; `setLastWarnedPercent` called
- Spending stays above threshold: second `add` does not re-fire notification (guard `lastWarnedPercent >= threshold`)
- New period (new `periodKey`): `lastWarnedPercent` returns `nil` → warning re-fires on next crossing

Use `NotificationClient.testValue` with explicit closure overrides per test case.

**Note:** The default `testValue` stubs for `lastWarnedPercent` (always returns `nil`) and `setLastWarnedPercent` (no-op) cannot exercise the "does not re-fire" scenario. That test must override both closures with a shared in-memory store:
```swift
var store: [String: Int] = [:]
var client = NotificationClient.testValue
client.lastWarnedPercent = { budgetId, periodKey in store["\(budgetId).\(periodKey)"] }
client.setLastWarnedPercent = { percent, budgetId, periodKey in store["\(budgetId).\(periodKey)"] = percent }
```
