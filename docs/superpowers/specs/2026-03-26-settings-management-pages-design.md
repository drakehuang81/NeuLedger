# Settings Management Pages — Design Spec

**Date:** 2026-03-26
**Status:** Approved
**Scope:** 分類管理、預算管理、標籤管理、通知管理 四個設定子頁全面串接

---

## Problem Statement

SettingsView 的六個導航目的地（帳戶、分類、預算、標籤、通知、定期交易）目前皆無法進入。根本原因：

1. `CategoryManagementView` 自帶 `NavigationStack` wrapper
2. `TagManagementView` 自帶 `NavigationStack` wrapper

在 iOS 26，巢狀 NavigationStack 會讓父層（SettingsView）整個 navigation 系統失效，導致所有六個目的地都無法 push。

次要問題：
- `BudgetManagementView`、`TagManagementView`、`NotificationSettingsView` 缺少底部 padding，FloatTabBar 會遮住內容
- `NotificationClient+Live.swift` 使用 `bundle: .main` 讀 SPM package 內的本地化字串，應改為 `bundle: .module`

---

## Chosen Approach: TCA StackState Navigation

移除 SwiftUI-native value-based navigation（`SettingsRoute` enum + `NavigationLink(value:)`），改為 TCA StackState，讓 SettingsFeature reducer 完整管理所有子頁導航狀態。

**不選純修復（只移除 NavigationStack wrapper）的原因：**
AccountManagement 和 RecurringTransactions 目前雖可用，但同樣是 SwiftUI-native nav、store 在 view 裡直接建立。統一改為 TCA stack 後，所有六個子頁架構一致、導航狀態可測試。

---

## Architecture

### Destination Reducer（新增，位於 SettingsFeature.swift 內）

```swift
@Reducer
enum Destination {
    case accountManagement(AccountManagementFeature)
    case categoryManagement(CategoryManagementFeature)
    case budgetManagement(BudgetManagementFeature)
    case tagManagement(TagManagementFeature)
    case notificationSettings(NotificationSettingsFeature)
    case recurringTransactions(RecurringTransactionManagementFeature)
}
```

### SettingsFeature.State 新增

```swift
public var path: StackState<Destination.State> = []
```

### SettingsFeature.Action 新增

```swift
// Navigation tap actions
case accountManagementTapped
case categoryManagementTapped
case budgetManagementTapped
case tagManagementTapped
case notificationSettingsTapped
case recurringTransactionsTapped

// Stack path action
case path(StackActionOf<Destination>)
```

### SettingsFeature.body 新增

每個 tap action push 對應 State：
```swift
case .categoryManagementTapped:
    state.path.append(.categoryManagement(CategoryManagementFeature.State()))
    return .none
```
以及串接子頁 reducer：
```swift
.forEach(\.path, action: \.path)
```

---

## SettingsView Changes

### NavigationStack 改為 path-based

```swift
NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
    // 原有 ScrollView 內容不動
} destination: { store in
    switch store.case {
    case .accountManagement(let s):     AccountManagementView(store: s)
    case .categoryManagement(let s):    CategoryManagementView(store: s)
    case .budgetManagement(let s):      BudgetManagementView(store: s)
    case .tagManagement(let s):         TagManagementView(store: s)
    case .notificationSettings(let s):  NotificationSettingsView(store: s)
    case .recurringTransactions(let s): RecurringTransactionManagementView(store: s)
    }
}
```

### NavigationLink → Button

所有 `NavigationLink(value: SettingsRoute.x)` 改為 `Button { store.send(.xTapped) }`，視覺不變（`settingsRow` 有 chevron，`buttonStyle(.plain)` 避免藍色高亮）。

### 移除

- `enum SettingsRoute: Hashable`
- `.navigationDestination(for: SettingsRoute.self)` modifier

---

## Sub-view Fixes

### CategoryManagementView
- 移除最外層 `NavigationStack { }` wrapper
- 所有 `.navigationTitle`、`.toolbar`、`.sheet`、`.alert`、`.safeAreaInset` modifier 保持不動

### TagManagementView
- 移除最外層 `NavigationStack { }` wrapper
- 補底部 padding：`tagList` 加 `.padding(.bottom, 100)`

### BudgetManagementView
- 補底部 padding：`budgetList` 加 `.padding(.bottom, 100)`

### NotificationSettingsView
- 補底部 padding：VStack 加 `.padding(.bottom, 100)`

### NotificationClient+Live.swift
- `scheduleDailyReminder` 內的字串目前用 `bundle: .main`。`NotificationClient+Live` 在 Core package，字串若定義在 Features package，`bundle: .main` 和 `bundle: .module`（Core bundle）都找不到。
- 實作時需確認 "notification_daily_reminder_title" / "notification_daily_reminder_body" 定義在哪個 bundle，再決定正確的 bundle 參數或改用 Features bundle accessor。

---

## Files Changed

| 檔案 | 變動類型 |
|------|---------|
| `Features/Sources/Features/Settings/SettingsFeature.swift` | Destination enum、path state、6 tap actions、.forEach |
| `Features/Sources/Features/Settings/SettingsView.swift` | path-based NavigationStack、Button 取代 NavigationLink、移除 SettingsRoute |
| `Features/Sources/Features/CategoryManagement/CategoryManagementView.swift` | 移除 NavigationStack wrapper |
| `Features/Sources/Features/TagManagement/TagManagementView.swift` | 移除 NavigationStack wrapper + 補底部 padding |
| `Features/Sources/Features/BudgetManagement/BudgetManagementView.swift` | 補底部 padding |
| `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift` | 補底部 padding |
| `Features/Sources/Core/Clients/NotificationClient+Live.swift` | bundle: .main → .module |

---

## Out of Scope

- 預算管理顯示當期支出進度（BudgetGauge）— 另外處理
- 任何子頁的 UI 重設計
- 測試覆蓋（現有 Feature tests 架構已就位，可另外補）
