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
- Permission request triggered on first toggle-on; if denied, inline message guides user to system settings

---

## Architecture

Follows the project's Clean Architecture + TCA pattern:

```
Domain/Clients/NotificationClient.swift        ← interface (@DependencyClient)
Core/Clients/NotificationClient+Live.swift     ← UNUserNotificationCenter implementation
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
    public var scheduleDailyReminder: @Sendable (_ hour: Int, _ minute: Int) async -> Void = { _, _ in }

    /// Cancel the daily reminder.
    public var cancelDailyReminder: @Sendable () async -> Void = {}

    /// Fire a one-shot budget warning notification immediately.
    public var sendBudgetWarning: @Sendable (_ budgetName: String, _ usedPercent: Int) async -> Void = { _, _ in }

    /// Check current authorization status (true = authorized).
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

### UserSettings Keys (additions to existing SettingsKey)

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `dailyReminderEnabled` | Bool | false | Toggle daily reminder on/off |
| `dailyReminderHour` | Int | 21 | Reminder hour (0–23) |
| `dailyReminderMinute` | Int | 0 | Reminder minute (0–59) |
| `budgetWarningEnabled` | Bool | false | Toggle budget warning on/off |
| `budgetWarningThreshold` | Int | 80 | Warning threshold (50–90, step 10) |

`UserSettingsClient` must be extended to support `Int` reads/writes (currently only `Bool` is supported).

---

## Core Layer

### NotificationClient Live Implementation

File: `Features/Sources/Core/Clients/NotificationClient+Live.swift`

Key implementation details:

- **Authorization**: `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])`
- **Daily reminder**: `UNCalendarNotificationTrigger` with `DateComponents(hour:minute:)` and `repeats: true`. Identifier: `"neuledger.daily_reminder"`. Re-scheduling cancels the previous request by using the same identifier.
- **Budget warning**: `UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)`. Identifier: `"neuledger.budget_warning.\(budgetName)"`.
- **isAuthorized**: queries `UNUserNotificationCenter.current().notificationSettings()` and checks `.authorizationStatus == .authorized`.

### Budget Warning Trigger Logic

Added to `TransactionClient+Live` as a private helper called after `add` and `update`:

```
func checkBudgetWarnings(for affectedAccountId: Account.ID) async
```

Steps:
1. Fetch all active budgets via `budgetClient.fetchActive()`
2. For each budget, compute `usedPercent = totalSpent / budget.amount * 100`
3. Read `budgetWarningEnabled` and `budgetWarningThreshold` from `UserSettingsClient`
4. Read previously notified percent from `UserDefaults` key `"neuledger.budget_warned.\(budget.id)"`
5. If `usedPercent >= threshold` AND `lastWarnedPercent < threshold`, call `notificationClient.sendBudgetWarning` and update the stored value
6. If `usedPercent < threshold`, reset the stored value (allows re-notification next period)

This ensures the warning fires exactly once per threshold crossing per budget cycle.

---

## Feature Layer

### NotificationSettingsFeature

File: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift`

**State:**
```swift
@ObservableState
public struct State: Equatable {
    public var dailyReminderEnabled: Bool = false
    public var reminderHour: Int = 21
    public var reminderMinute: Int = 0
    public var budgetWarningEnabled: Bool = false
    public var warningThreshold: Int = 80
    public var isAuthorized: Bool = false
    public var showPermissionDeniedBanner: Bool = false
}
```

**Actions:**
- `task` — load all settings from UserSettingsClient, check isAuthorized
- `dailyReminderToggled(Bool)` — if enabling and not authorized, request permission; on success schedule reminder; persist
- `reminderTimeChanged(hour: Int, minute: Int)` — reschedule reminder; persist
- `budgetWarningToggled(Bool)` — same permission flow; persist
- `warningThresholdChanged(Int)` — persist
- `authorizationStatusLoaded(Bool)` — update `isAuthorized`
- `permissionDenied` — set `showPermissionDeniedBanner = true`

**Dependencies:** `notificationClient`, `userSettingsClient`

### NotificationSettingsView

File: `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift`

Layout:
```
NavigationStack
└── ScrollView
    ├── [Banner] Permission denied warning (if showPermissionDeniedBanner)
    │
    ├── Section: 每日記帳提醒
    │   ├── Toggle "開啟每日提醒"
    │   └── (visible when enabled)
    │       DatePicker — 提醒時間 (displayedComponents: .hourAndMinute)
    │
    └── Section: 預算警告
        ├── Toggle "開啟預算警告"
        └── (visible when enabled)
            Picker "警告門檻" — 50% / 60% / 70% / 80% / 90%
```

- Uses `GlassContainer` for section cards (consistent with Settings style)
- Permission denied banner: orange inline card with "前往設定" button opening `UIApplication.openSettingsURLString`
- All toggles/pickers use `.task` to load initial values and bind via store actions

### Settings Integration

**SettingsRoute** — add `.notificationSettings` case

**SettingsView** — add NavigationLink in the "管理" section:
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

**navigationDestination** — handle `.notificationSettings` → `NotificationSettingsView`

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
| `notification_daily_reminder_body` | 記得記帳！點此快速新增一筆。 | Time to log your transactions! |
| `notification_budget_warning_body` | 預算「%@」已使用 %d%%，請注意支出。 | Budget "%@" is %d%% used. Watch your spending. |

---

## Error Handling

- If `requestAuthorization` returns false (user denied): set `showPermissionDeniedBanner = true`; do not schedule notifications; keep toggle in off state
- If UNUserNotificationCenter throws: silently ignore (best-effort delivery)
- Validation errors: none needed (all inputs are bounded pickers/steppers)

---

## Testing

Feature tests (`NotificationSettingsFeatureTests`):
- Toggle on when unauthorized → permission request fired, if denied banner shown, toggle stays off
- Toggle on when authorized → schedule called, settings persisted
- Time change → reschedule called with new values
- Threshold change → persisted, no notification client call needed

Core tests:
- `checkBudgetWarnings`: verify notification fires on first threshold crossing, does not fire again until reset

Use `NotificationClient.testValue` (unimplemented stubs) for feature tests; provide explicit overrides per test.
