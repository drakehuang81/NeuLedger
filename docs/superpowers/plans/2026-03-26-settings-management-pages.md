# Settings Management Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓設定頁的六個子頁（帳戶、分類、預算、標籤、通知、定期交易）可以正確進入，並修復 UX padding 問題；透過 TCA StackState 重構 SettingsFeature 的導航邏輯。

**Architecture:** SettingsFeature 加入 `@Reducer enum Destination` 包住所有六個子頁 Feature，以 `StackState<Destination.State>` 管理 push 導航狀態；SettingsView 改用 `NavigationStack(path:)` + `destination:` closure；CategoryManagementView 和 TagManagementView 移除自帶的 NavigationStack wrapper（根本原因是巢狀 NavigationStack 在 iOS 26 讓父層 navigation 完全失效）。

**Tech Stack:** Swift 5.10、SwiftUI、ComposableArchitecture 1.23.1、Swift Testing

---

## File Map

| 檔案 | 變動 |
|------|------|
| `Features/Sources/Features/Settings/SettingsFeature.swift` | 新增 Destination enum；State 加 path；Action 加 6 個 tap + path；Reduce 加 6 個 case + `.forEach` |
| `Features/Sources/Features/Settings/SettingsView.swift` | 改為 path-based NavigationStack；Button 取代 NavigationLink；移除 SettingsRoute |
| `Features/Sources/Features/CategoryManagement/CategoryManagementView.swift` | 移除 NavigationStack wrapper |
| `Features/Sources/Features/TagManagement/TagManagementView.swift` | 移除 NavigationStack wrapper；補 `.padding(.bottom, 100)` |
| `Features/Sources/Features/BudgetManagement/BudgetManagementView.swift` | 補 `.padding(.bottom, 100)` |
| `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift` | 補底部 padding |
| `Features/Tests/FeaturesTests/SettingsFeatureTests.swift` | 新增 6 個導航 action 測試 |

---

## Task 1: 更新 SettingsFeature — Destination、State、Action

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`

- [ ] **Step 1: 在 SettingsFeature 內加入 Destination enum**

在 `public init() {}` 之後、`// MARK: - State` 之前插入：

```swift
// MARK: - Destination

@Reducer
public enum Destination: Sendable {
    case accountManagement(AccountManagementFeature)
    case categoryManagement(CategoryManagementFeature)
    case budgetManagement(BudgetManagementFeature)
    case tagManagement(TagManagementFeature)
    case notificationSettings(NotificationSettingsFeature)
    case recurringTransactions(RecurringTransactionManagementFeature)
}
```

- [ ] **Step 2: 在 State 加入 path**

在 `public var isAIEnabled: Bool = true` 之前插入：

```swift
public var path: StackState<Destination.State> = []
```

`State.init` 不需要改（`path` 有預設值）。

- [ ] **Step 3: 在 Action 加入 6 個 tap action 和 path action**

在現有 `case task` 之前插入：

```swift
// Navigation
case accountManagementTapped
case categoryManagementTapped
case budgetManagementTapped
case tagManagementTapped
case notificationSettingsTapped
case recurringTransactionsTapped
case path(StackActionOf<Destination>)
```

- [ ] **Step 4: 在 Reduce body 加入新 case，並在尾端串 .forEach**

在 `switch action {` 裡的 `case .task:` 之前插入：

```swift
// MARK: Navigation
case .accountManagementTapped:
    state.path.append(.accountManagement(AccountManagementFeature.State()))
    return .none

case .categoryManagementTapped:
    state.path.append(.categoryManagement(CategoryManagementFeature.State()))
    return .none

case .budgetManagementTapped:
    state.path.append(.budgetManagement(BudgetManagementFeature.State()))
    return .none

case .tagManagementTapped:
    state.path.append(.tagManagement(TagManagementFeature.State()))
    return .none

case .notificationSettingsTapped:
    state.path.append(.notificationSettings(NotificationSettingsFeature.State()))
    return .none

case .recurringTransactionsTapped:
    state.path.append(.recurringTransactions(RecurringTransactionManagementFeature.State()))
    return .none

case .path:
    return .none
```

然後在 `body` 的 `Reduce { ... }` 後面加上 `.forEach`，讓整個 `body` 看起來像：

```swift
public var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        // ... all cases ...
        }
    }
    .forEach(\.path, action: \.path)
}
```

- [ ] **Step 5: 確認 build 不報錯**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 2: 為 6 個導航 action 寫測試

**Files:**
- Modify: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`

- [ ] **Step 1: 在檔案末尾（最後一個 `}` 之後）新增 Navigation test suite**

```swift
@Suite("SettingsFeature — navigation")
struct SettingsNavigationTests {

    @Test("accountManagementTapped appends accountManagement to path")
    func accountManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.accountManagementTapped) {
            $0.path.append(.accountManagement(AccountManagementFeature.State()))
        }
    }

    @Test("categoryManagementTapped appends categoryManagement to path")
    func categoryManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.categoryManagementTapped) {
            $0.path.append(.categoryManagement(CategoryManagementFeature.State()))
        }
    }

    @Test("budgetManagementTapped appends budgetManagement to path")
    func budgetManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.budgetManagementTapped) {
            $0.path.append(.budgetManagement(BudgetManagementFeature.State()))
        }
    }

    @Test("tagManagementTapped appends tagManagement to path")
    func tagManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.tagManagementTapped) {
            $0.path.append(.tagManagement(TagManagementFeature.State()))
        }
    }

    @Test("notificationSettingsTapped appends notificationSettings to path")
    func notificationSettingsTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.notificationSettingsTapped) {
            $0.path.append(.notificationSettings(NotificationSettingsFeature.State()))
        }
    }

    @Test("recurringTransactionsTapped appends recurringTransactions to path")
    func recurringTransactionsTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.recurringTransactionsTapped) {
            $0.path.append(.recurringTransactions(RecurringTransactionManagementFeature.State()))
        }
    }
}
```

- [ ] **Step 2: 執行 Settings 相關測試，確認全部通過**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsFeatureTests \
  -only-testing:FeaturesTests/SettingsNavigationTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD FAILED|Executed"
```

Expected: 所有既有測試 + 6 個新測試全部 passed

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsFeature.swift \
        Features/Tests/FeaturesTests/SettingsFeatureTests.swift
git commit -m "$(cat <<'EOF'
feat(settings): add TCA StackState navigation to SettingsFeature

Add Destination enum, path: StackState, and six tap actions so the
reducer owns all Settings push-navigation state. Tests verify each
action appends the correct destination state to path.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 重構 SettingsView

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`

- [ ] **Step 1: 移除 `enum SettingsRoute`**

刪除整個：
```swift
enum SettingsRoute: Hashable {
    case accountManagement
    case categoryManagement
    case budgetManagement
    case tagManagement
    case notificationSettings
    case recurringTransactions
}
```

- [ ] **Step 2: 改寫 body 裡的 NavigationStack**

將：
```swift
NavigationStack {
    ScrollView { ... }
    .background(...)
    .navigationTitle(...)
    .navigationBarTitleDisplayMode(.large)
    .task { ... }
    .navigationDestination(for: SettingsRoute.self) { route in
        switch route {
        case .accountManagement:
            AccountManagementView(store: Store(initialState: AccountManagementFeature.State()) { AccountManagementFeature() })
        case .categoryManagement:
            CategoryManagementView(store: Store(initialState: CategoryManagementFeature.State()) { CategoryManagementFeature() })
        case .budgetManagement:
            BudgetManagementView(store: Store(initialState: BudgetManagementFeature.State()) { BudgetManagementFeature() })
        case .tagManagement:
            TagManagementView(store: Store(initialState: TagManagementFeature.State()) { TagManagementFeature() })
        case .notificationSettings:
            NotificationSettingsView(store: Store(initialState: NotificationSettingsFeature.State()) { NotificationSettingsFeature() })
        case .recurringTransactions:
            RecurringTransactionManagementView(store: Store(initialState: RecurringTransactionManagementFeature.State()) { RecurringTransactionManagementFeature() })
        }
    }
    .sheet(...) { ... }
}
```

改為：
```swift
NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
    ScrollView { ... }
    .background(Color.Design.background.ignoresSafeArea())
    .navigationTitle(String(localized: "settings_title"))
    .navigationBarTitleDisplayMode(.large)
    .task { await store.send(.task).finish() }
    .sheet(
        item: Binding(
            get: { store.exportedFileURL.map { IdentifiableURL(url: $0) } },
            set: { if $0 == nil { store.send(.exportSheetDismissed) } }
        )
    ) { identifiable in
        ShareSheet(items: [identifiable.url])
    }
} destination: { store in
    switch store.case {
    case .accountManagement(let s):
        AccountManagementView(store: s)
    case .categoryManagement(let s):
        CategoryManagementView(store: s)
    case .budgetManagement(let s):
        BudgetManagementView(store: s)
    case .tagManagement(let s):
        TagManagementView(store: s)
    case .notificationSettings(let s):
        NotificationSettingsView(store: s)
    case .recurringTransactions(let s):
        RecurringTransactionManagementView(store: s)
    }
}
```

- [ ] **Step 3: 改寫 sectionManage — 用 Button 取代 NavigationLink**

將 `sectionManage` 裡的 `GlassContainer` 內容整個替換：

```swift
GlassContainer(cornerRadius: 16, padding: 0) {
    VStack(spacing: 0) {
        Button { store.send(.accountManagementTapped) } label: {
            settingsRow(
                icon: "wallet.bifold",
                iconColor: Color.Design.brandPrimary,
                label: String(localized: "settings_account_management"),
                trailing: chevron
            )
        }
        .buttonStyle(.plain)
        Button { store.send(.categoryManagementTapped) } label: {
            settingsRow(
                icon: "square.grid.2x2",
                iconColor: Color.Design.brandSecondary,
                label: String(localized: "settings_category_management"),
                trailing: chevron
            )
        }
        .buttonStyle(.plain)
        Button { store.send(.budgetManagementTapped) } label: {
            settingsRow(
                icon: "banknote",
                iconColor: Color.Design.incomeGreen,
                label: String(localized: "settings_budget_management"),
                trailing: chevron
            )
        }
        .buttonStyle(.plain)
        Button { store.send(.tagManagementTapped) } label: {
            settingsRow(
                icon: "tag",
                iconColor: Color.Design.brandAccent,
                label: String(localized: "settings_tag_management"),
                trailing: chevron
            )
        }
        .buttonStyle(.plain)
        Button { store.send(.notificationSettingsTapped) } label: {
            settingsRow(
                icon: "bell.badge",
                iconColor: .orange,
                label: String(localized: "settings_notification_settings"),
                trailing: chevron
            )
        }
        .buttonStyle(.plain)
        Button { store.send(.recurringTransactionsTapped) } label: {
            settingsRow(
                icon: "arrow.clockwise.circle",
                iconColor: Color.Design.brandPrimary,
                label: String(localized: "settings_recurring_transactions"),
                trailing: chevron
            )
        }
        .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
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
git add Features/Sources/Features/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
refactor(settings): switch SettingsView to TCA path-based navigation

Replace SwiftUI-native NavigationLink(value:)/SettingsRoute with
NavigationStack(path:) driven by SettingsFeature.path StackState.
All six management pages are now destination cases in the stack.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 修復 CategoryManagementView — 移除巢狀 NavigationStack

**Files:**
- Modify: `Features/Sources/Features/CategoryManagement/CategoryManagementView.swift`

- [ ] **Step 1: 移除外層 NavigationStack wrapper**

將：
```swift
public var body: some View {
    NavigationStack {
        Group {
            if store.isLoading { ... }
            else if store.filteredCategories.isEmpty { ... }
            else { categoriesList }
        }
        .navigationTitle(String(localized: "category_management_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ... }
        .safeAreaInset(edge: .top) { typePicker ... }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.addEdit, action: \.addEdit)) { ... }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
```

改為（只移除 `NavigationStack {` 和對應的 `}`，內部一字不改）：

```swift
public var body: some View {
    Group {
        if store.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.filteredCategories.isEmpty {
            EmptyStateView(
                icon: "tag.slash",
                title: String(localized: "category_management_empty_title"),
                description: String(localized: "category_management_empty_desc")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            categoriesList
        }
    }
    .navigationTitle(String(localized: "category_management_title"))
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
        ToolbarItem(placement: .topBarLeading) {
            EditButton()
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.send(.addButtonTapped)
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    .safeAreaInset(edge: .top) {
        typePicker
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.Design.background)
    }
    .task {
        await store.send(.task).finish()
    }
    .sheet(
        item: $store.scope(state: \.addEdit, action: \.addEdit)
    ) { addEditStore in
        AddEditCategoryView(store: addEditStore)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
}
```

- [ ] **Step 2: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/CategoryManagement/CategoryManagementView.swift
git commit -m "$(cat <<'EOF'
fix(category-management): remove nested NavigationStack wrapper

CategoryManagementView was wrapping itself in NavigationStack,
which caused iOS 26 to break all push navigation in SettingsView.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 修復 TagManagementView — 移除 NavigationStack 並補底部 Padding

**Files:**
- Modify: `Features/Sources/Features/TagManagement/TagManagementView.swift`

- [ ] **Step 1: 移除外層 NavigationStack wrapper**

將：
```swift
public var body: some View {
    NavigationStack {
        Group {
            if store.isLoading { ... }
            else if store.tags.isEmpty { emptyState }
            else { tagList }
        }
        .navigationTitle(...)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ... }
        .task { ... }
        .sheet(...) { ... }
        .alert(...)
    }
}
```

改為（只移除 `NavigationStack {` 和對應的 `}`）：

```swift
public var body: some View {
    Group {
        if store.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.tags.isEmpty {
            emptyState
        } else {
            tagList
        }
    }
    .navigationTitle(String(localized: "tag_management_title"))
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                store.send(.addButtonTapped)
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    .task {
        await store.send(.task).finish()
    }
    .sheet(item: $store.scope(state: \.addEdit, action: \.addEdit)) { addEditStore in
        AddEditTagView(store: addEditStore)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
}
```

- [ ] **Step 2: 在 tagList 補底部 padding**

將：
```swift
private var tagList: some View {
    List {
        ForEach(store.tags) { tag in
            // ...
        }
    }
    .listStyle(.insetGrouped)
}
```

改為：
```swift
private var tagList: some View {
    List {
        ForEach(store.tags) { tag in
            Button {
                store.send(.tagTapped(tag))
            } label: {
                tagRow(tag)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    store.send(.deleteRequested(tag.id))
                } label: {
                    Label(String(localized: "common_delete"), systemImage: "trash")
                }
            }
        }
    }
    .listStyle(.insetGrouped)
    .padding(.bottom, 100)
}
```

- [ ] **Step 3: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/TagManagement/TagManagementView.swift
git commit -m "$(cat <<'EOF'
fix(tag-management): remove nested NavigationStack; add bottom padding

Same root cause as CategoryManagementView. Also adds .padding(.bottom, 100)
so content is not hidden by the floating split TabBar.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 補 BudgetManagement 和 NotificationSettings 底部 Padding

**Files:**
- Modify: `Features/Sources/Features/BudgetManagement/BudgetManagementView.swift`
- Modify: `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift`

- [ ] **Step 1: BudgetManagementView — budgetList 加 padding**

將：
```swift
private var budgetList: some View {
    List {
        ForEach(store.budgets) { budget in
            // ...
        }
    }
    .listStyle(.insetGrouped)
}
```

改為：
```swift
private var budgetList: some View {
    List {
        ForEach(store.budgets) { budget in
            Button {
                store.send(.budgetTapped(budget))
            } label: {
                BudgetRow(budget: budget) {
                    store.send(.toggleActive(budget))
                }
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    store.send(.deleteRequested(budget.id))
                } label: {
                    Label(String(localized: "common_delete"), systemImage: "trash")
                }
            }
        }
    }
    .listStyle(.insetGrouped)
    .padding(.bottom, 100)
}
```

- [ ] **Step 2: NotificationSettingsView — VStack 補底部 padding**

將：
```swift
ScrollView {
    VStack(spacing: 24) {
        // ...
    }
    .padding(16)
}
```

改為：
```swift
ScrollView {
    VStack(spacing: 24) {
        // ...
    }
    .padding(16)
    .padding(.bottom, 84)
}
```

（`.padding(16)` 已有 16pt 底部，再加 84 = 100pt 總底部 padding，與其他頁一致。）

- [ ] **Step 3: Build 確認**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/BudgetManagement/BudgetManagementView.swift \
        Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift
git commit -m "$(cat <<'EOF'
fix(settings): add bottom padding to budget and notification views

Prevents floating split TabBar from obscuring list content,
consistent with CategoryManagementView (.padding(.bottom, 100)).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 驗證 NotificationClient bundle

**Files:**
- Read: `NeuLedger/Resources/Localizable.xcstrings`
- Possibly modify: `Features/Sources/Core/Clients/NotificationClient+Live.swift`

- [ ] **Step 1: 確認 notification 字串存在於主 bundle**

在 `NeuLedger/Resources/Localizable.xcstrings` 搜尋是否有以下 key：
- `notification_daily_reminder_title`
- `notification_daily_reminder_body`

如果存在 → `bundle: .main` 正確，無需改動。
如果不存在 → 在 `Localizable.xcstrings` 新增這兩個 key（中文值建議：`"記帳提醒"` / `"別忘了記錄今天的支出！"`）。

- [ ] **Step 2: 如需新增字串，更新 Localizable.xcstrings 後 commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
fix(notification): ensure daily reminder strings in main bundle

notification_daily_reminder_title and notification_daily_reminder_body
must exist in the main app bundle for NotificationClient+Live to use
bundle: .main when scheduling the system notification.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

（若字串已存在則跳過此 commit。）

---

## Task 8: 全套測試 + 最終 Build 驗證

- [ ] **Step 1: 執行 Features scheme 全部測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD FAILED|Executed [0-9]+ test"
```

Expected: 全部 passed，0 failed。

- [ ] **Step 2: 若有失敗，依錯誤訊息修復後重跑**

常見問題：
- `SettingsFeature.State` 新增的 `path` 破壞了既有測試的狀態比對 → 在測試裡對 path 作明確的 assertion 或確認初始值為 `[]`（empty StackState 是 `Equatable` 且預設值等同 `[]`，已有測試不應受影響）
- Destination enum 的某個 Feature 的 `State.init()` 需要 dependency → 檢查該 Feature 的 State 是否有非預設值的必填欄位

- [ ] **Step 3: 確認 app build**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`
