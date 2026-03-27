# 記帳提醒遷移至通知設定 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將「定期交易」管理入口從設定頁移至通知設定頁，以「記帳提醒」section 呈現，並清理設定頁的對應按鈕與測試。

**Architecture:** `NotificationSettingsFeature` 透過 `Scope` 嵌入 `RecurringTransactionManagementFeature` 作為子 reducer；`NotificationSettingsView` 底部新增 `recurringSection` 顯示提醒列表與新增入口；`SettingsFeature` 移除 `.recurringTransactions` destination 與對應 action。底層 domain / Core / 通知點擊流程完全不動。

**Tech Stack:** Swift 5.10、SwiftUI、ComposableArchitecture 1.23.1、Swift Testing

---

## File Map

| 檔案 | 變動 |
|------|------|
| `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift` | 新增 `recurringManagement` state、action、Scope |
| `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift` | 新增 `recurringSection` |
| `Features/Sources/Features/Settings/SettingsFeature.swift` | 移除 `.recurringTransactions` destination、`recurringTransactionsTapped` action 及對應 reducer case |
| `Features/Sources/Features/Settings/SettingsView.swift` | 移除「定期交易」Button |
| `Features/Tests/FeaturesTests/SettingsFeatureTests.swift` | 移除 `recurringTransactionsTapped` 測試 |
| `Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift` | 新增 2 個測試：task 觸發 recurringManagement.task；addButtonTapped 開啟 form |
| `NeuLedger/Resources/Localizable.xcstrings` | 新增 4 個 `notification_recurring_*` key；移除 `settings_recurring_transactions` key |

---

## Task 1: 更新本地化字串

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: 新增 4 個 `notification_recurring_*` key**

在檔案中找到 `"notification_daily_reminder_title"` 附近（約第 3548 行），在其前方插入以下 4 個條目（JSON 陣列中新增，注意末尾逗號）：

```json
"notification_recurring_section": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Scheduled Reminders" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "記帳提醒" } }
  }
},
"notification_recurring_description": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Set up recurring reminders. You'll get a push notification when it's time to record." } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "設定週期性的記帳提醒，到期時推播通知，方便你快速完成記帳。" } }
  }
},
"notification_recurring_add": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Add Reminder" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "新增提醒" } }
  }
},
"notification_recurring_empty": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "No scheduled reminders yet" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "尚未設定任何記帳提醒" } }
  }
},
```

- [ ] **Step 2: 移除 `settings_recurring_transactions` key**

找到並刪除（約第 3646 行）：

```json
"settings_recurring_transactions": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Recurring Transactions" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "定期交易" } }
  }
},
```

- [ ] **Step 3: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`（若 SettingsView 仍引用 `settings_recurring_transactions` 則會 error，Task 3 會修掉，此時可先用 Task 3 一起完成）

- [ ] **Step 4: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
feat(l10n): add notification_recurring_* keys; remove settings_recurring_transactions

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 更新 NotificationSettingsFeature — 嵌入 RecurringTransactionManagementFeature

**Files:**
- Modify: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift`

目前檔案結構（關鍵部分）：

```swift
@ObservableState
public struct State: Equatable {
    public var dailyReminderEnabled: Bool = false
    public var reminderDate: Date = ...
    public var budgetWarningEnabled: Bool = false
    public var warningThreshold: Int = 80
    public var isAuthorized: Bool = false
    public var showPermissionDeniedBanner: Bool = false

    public init(...) { ... }
}

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

public var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action { ... }
    }
}
```

- [ ] **Step 1: 在 State 加入 `recurringManagement`**

在 `public var showPermissionDeniedBanner: Bool = false` 之後插入：

```swift
public var recurringManagement: RecurringTransactionManagementFeature.State = .init()
```

在 `public init(...)` 的參數列表最後新增（有預設值，不破壞現有呼叫）：

```swift
recurringManagement: RecurringTransactionManagementFeature.State = .init()
```

並在 init body 最後加：

```swift
self.recurringManagement = recurringManagement
```

- [ ] **Step 2: 在 Action 加入 `recurringManagement` case**

在 `case openSystemSettingsTapped` 之後插入：

```swift
case recurringManagement(RecurringTransactionManagementFeature.Action)
```

- [ ] **Step 3: 在 body 加入 Scope、轉發 .task、並處理 recurringManagement action**

將 `body` 改為：

```swift
public var body: some ReducerOf<Self> {
    Scope(state: \.recurringManagement, action: \.recurringManagement) {
        RecurringTransactionManagementFeature()
    }
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

            return .merge(
                .run { send in
                    let authorized = await notificationClient.isAuthorized()
                    await send(.authorizationStatusLoaded(authorized))
                }
                .cancellable(id: CancelID.task),
                .send(.recurringManagement(.task))   // ← 轉發給子 reducer 載入列表
            )

        // ... 其餘現有 case 保持不動 ...

        case .recurringManagement:
            return .none
        }
    }
}
```

**重點說明：**
- `Scope` 放在 `Reduce` 之前（TCA 慣例：子 reducer 先跑）
- `.task` handler 用 `.merge` 同時執行授權檢查與 `.send(.recurringManagement(.task))`，確保 view 出現時子列表會自動載入
- `case .recurringManagement: return .none` 加在所有現有 case 之後；現有的 `.authorizationStatusLoaded`、`.dailyReminderToggled` 等 case **原封不動保留**，只新增這一個 case 和修改 `.task` return

- [ ] **Step 4: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 3: 更新 SettingsFeature — 移除 recurringTransactions

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`

- [ ] **Step 1: 移除 Destination enum 的 `.recurringTransactions` case**

將：
```swift
@Reducer(state: .equatable, action: .equatable)
public enum Destination {
    case accountManagement(AccountManagementFeature)
    case categoryManagement(CategoryManagementFeature)
    case budgetManagement(BudgetManagementFeature)
    case tagManagement(TagManagementFeature)
    case notificationSettings(NotificationSettingsFeature)
    case recurringTransactions(RecurringTransactionManagementFeature)
}
```

改為：
```swift
@Reducer(state: .equatable, action: .equatable)
public enum Destination {
    case accountManagement(AccountManagementFeature)
    case categoryManagement(CategoryManagementFeature)
    case budgetManagement(BudgetManagementFeature)
    case tagManagement(TagManagementFeature)
    case notificationSettings(NotificationSettingsFeature)
}
```

- [ ] **Step 2: 移除 Action 的 `recurringTransactionsTapped` 及 `path` case 不需動**

將 Action 中的：
```swift
case recurringTransactionsTapped
```
這一行刪除。

- [ ] **Step 3: 移除 reducer body 的 `recurringTransactionsTapped` case**

刪除：
```swift
case .recurringTransactionsTapped:
    state.path.append(.recurringTransactions(RecurringTransactionManagementFeature.State()))
    return .none
```

- [ ] **Step 4: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`（SettingsView 仍有「定期交易」Button，會因 action 不存在而 error，Task 4 會修掉）

---

## Task 4: 更新 SettingsView — 移除「定期交易」Button

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`

- [ ] **Step 1: 移除 sectionManage 裡的「定期交易」Button**

找到並刪除以下整個 Button block：

```swift
Button { store.send(.recurringTransactionsTapped) } label: {
    settingsRow(
        icon: "arrow.clockwise.circle",
        iconColor: Color.Design.brandPrimary,
        label: String(localized: "settings_recurring_transactions"),
        trailing: chevron
    )
}
.buttonStyle(.plain)
```

- [ ] **Step 2: 移除 destination closure 的 `.recurringTransactions` case**

在 `NavigationStack(path:) { } destination: { store in switch store.case { ... } }` 裡找到並刪除：

```swift
case .recurringTransactions(let s):
    RecurringTransactionManagementView(store: s)
```

- [ ] **Step 3: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit Tasks 2–4 一起**

```bash
git add Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift \
        Features/Sources/Features/Settings/SettingsFeature.swift \
        Features/Sources/Features/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
feat(notification-settings): embed RecurringTransactionManagement as child scope

Move recurring reminders management from Settings page to
NotificationSettingsFeature as a Scope child. Remove the
'定期交易' entry from SettingsFeature and SettingsView.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 更新 NotificationSettingsView — 新增 recurringSection

**Files:**
- Modify: `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift`

目前 body 結構：
```swift
ScrollView {
    VStack(spacing: 24) {
        if store.showPermissionDeniedBanner { permissionBanner }
        dailyReminderSection
        budgetWarningSection
    }
    .padding(16)
    .padding(.bottom, 84)
}
```

- [ ] **Step 1: 在 VStack 最後加入 `recurringSection`**

將：
```swift
    VStack(spacing: 24) {
        if store.showPermissionDeniedBanner { permissionBanner }
        dailyReminderSection
        budgetWarningSection
    }
```

改為：
```swift
    VStack(spacing: 24) {
        if store.showPermissionDeniedBanner { permissionBanner }
        dailyReminderSection
        budgetWarningSection
        recurringSection
    }
```

- [ ] **Step 2: 新增 `recurringSection` computed property**

在 `// MARK: - Helpers` 之前加入：

```swift
// MARK: - Recurring Section

private var recurringSection: some View {
    VStack(spacing: 6) {
        sectionHeader(String(localized: "notification_recurring_section"))
        Text(String(localized: "notification_recurring_description"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        GlassContainer(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                if store.recurringManagement.items.isEmpty {
                    Button {
                        store.send(.recurringManagement(.addButtonTapped))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.Design.brandPrimary)
                            Text(String(localized: "notification_recurring_add"))
                                .foregroundStyle(Color.Design.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(store.recurringManagement.items) { item in
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.note ?? String(localized: "notification_recurring_empty"))
                                        .font(.body)
                                        .foregroundStyle(Color.Design.textPrimary)
                                    Text("NT$\(NSDecimalNumber(decimal: item.amount).intValue) · \(item.frequency.localizedName)")
                                        .font(.caption)
                                        .foregroundStyle(Color.Design.textSecondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { item.isActive },
                                    set: { _ in store.send(.recurringManagement(.toggleActiveTapped(item))) }
                                ))
                                .labelsHidden()
                                .tint(Color.Design.incomeGreen)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.send(.recurringManagement(.itemTapped(item)))
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.send(.recurringManagement(.deleteTapped(item.id)))
                                } label: {
                                    Label(String(localized: "common_delete"), systemImage: "trash")
                                }
                            }
                        }
                        if item.id != store.recurringManagement.items.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                    Divider().padding(.horizontal, 16)
                    Button {
                        store.send(.recurringManagement(.addButtonTapped))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.Design.brandPrimary)
                            Text(String(localized: "notification_recurring_add"))
                                .foregroundStyle(Color.Design.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

- [ ] **Step 3: 在 body 掛上 recurringManagement 的 `.task` 與 `.sheet`**

在 `.navigationBarTitleDisplayMode(.large)` 之後加入（`.task` 下方）：

```swift
.task { await store.send(.task).finish() }
.sheet(
    item: $store.scope(
        state: \.recurringManagement.form,
        action: \.recurringManagement.form
    )
) { formStore in
    NavigationStack {
        RecurringTransactionFormView(store: formStore)
    }
}
```

注意：`NotificationSettingsView` 目前已有 `.task { await store.send(.task).finish() }`，這個 `.task` **不重複新增**，確認只有一個。新增的是 `.sheet`。

完整 body modifiers 順序應為：

```swift
.background(Color.Design.background.ignoresSafeArea())
.navigationTitle(String(localized: "settings_notification_settings"))
.navigationBarTitleDisplayMode(.large)
.task { await store.send(.task).finish() }
.sheet(
    item: $store.scope(
        state: \.recurringManagement.form,
        action: \.recurringManagement.form
    )
) { formStore in
    NavigationStack {
        RecurringTransactionFormView(store: formStore)
    }
}
```

- [ ] **Step 4: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift
git commit -m "$(cat <<'EOF'
feat(notification-settings): add recurring reminders section

Show recurring reminders list inline in NotificationSettingsView.
Tapping items opens RecurringTransactionFormView sheet for edit.
Empty state shows 'Add Reminder' button.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 更新測試

**Files:**
- Modify: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`
- Modify: `Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift`

- [ ] **Step 1: 移除 SettingsFeatureTests 裡的 `recurringTransactionsTapped` 測試**

找到並刪除（約第 460–469 行）：

```swift
@Test("recurringTransactionsTapped appends recurringTransactions to path")
func recurringTransactionsTapped() async {
    let store = await TestStore(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    await store.send(.recurringTransactionsTapped) {
        $0.path.append(.recurringTransactions(RecurringTransactionManagementFeature.State()))
    }
}
```

- [ ] **Step 2: 在 NotificationSettingsFeatureTests 末尾新增 2 個測試**

在最後的 `}` 之後新增：

```swift
@Suite("NotificationSettingsFeature — recurring management")
struct NotificationSettingsRecurringTests {

    @Test("task triggers recurringManagement.task which loads items")
    func testTaskTriggersRecurringLoad() async {
        let sampleItem = RecurringTransaction(
            id: UUID(),
            amount: 1200,
            note: "健身房",
            categoryId: nil,
            accountId: UUID(),
            toAccountId: nil,
            type: .expense,
            tags: [],
            frequency: .monthly,
            nextDueDate: Date(),
            isActive: true,
            createdAt: Date()
        )

        let store = await TestStore(initialState: NotificationSettingsFeature.State()) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [sampleItem] }
            $0.notificationClient.isAuthorized = { false }
            $0.userSettingsClient.bool = { $0.defaultValue }
            $0.userSettingsClient.int = { $0.defaultValue }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.recurringManagement.loaded) {
            $0.recurringManagement.items = [sampleItem]
        }
    }

    @Test("addButtonTapped via recurringManagement presents form")
    func testAddButtonTappedPresentsForm() async {
        let store = await TestStore(initialState: NotificationSettingsFeature.State()) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetch = { _ in [] }
        }

        await store.send(.recurringManagement(.addButtonTapped)) {
            $0.recurringManagement.form = RecurringTransactionFormFeature.State(mode: .add)
        }
    }
}
```

- [ ] **Step 3: 執行測試確認**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsNavigationTests \
  -only-testing:FeaturesTests/NotificationSettingsFeatureTests \
  -only-testing:FeaturesTests/NotificationSettingsRecurringTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD FAILED|Executed"
```

Expected: 全部 passed，0 failed

- [ ] **Step 4: Commit**

```bash
git add Features/Tests/FeaturesTests/SettingsFeatureTests.swift \
        Features/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift
git commit -m "$(cat <<'EOF'
test(settings/notification): update tests for recurring reminders migration

Remove recurringTransactionsTapped from SettingsNavigationTests.
Add NotificationSettingsRecurringTests: task loads items, addButton presents form.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 全套測試 + 最終 Build 驗證

- [ ] **Step 1: 執行 Features scheme 全部測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD FAILED|Executed [0-9]+ test"
```

Expected: 全部 passed（已知 pre-existing 4 個失敗：`MainTabFeature` 3 個 + `AddTransactionFeature` 1 個，與本次修改無關）

- [ ] **Step 2: 確認 app build**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`
