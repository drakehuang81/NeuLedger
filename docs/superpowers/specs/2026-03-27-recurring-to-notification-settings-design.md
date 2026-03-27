# 記帳提醒遷移至通知設定 — Design Spec

**Date:** 2026-03-27
**Status:** Approved
**Scope:** 將「定期交易」功能從設定頁管理區塊移至通知設定，並重新命名為「記帳提醒」

---

## Problem Statement

「定期交易」放在設定頁的「管理」區塊，定位模糊——它不像帳戶、分類、預算那樣是資料管理，本質上是「預約推播提醒 + 到期一鍵記帳」。放在通知設定裡語意更準確，使用者更容易找到。

---

## Chosen Approach

將 `RecurringTransactionManagementFeature` 作為子 scope 嵌入 `NotificationSettingsFeature`，在 `NotificationSettingsView` 底部新增「記帳提醒」section 顯示列表與新增入口。設定頁移除「定期交易」項目。

底層 domain / Core / 通知點擊流程完全不動。

---

## Architecture

### NotificationSettingsFeature 變更

新增子 scope：

```swift
// State
public var recurringManagement: RecurringTransactionManagementFeature.State = .init()

// Action
case recurringManagement(RecurringTransactionManagementFeature.Action)

// body
Scope(state: \.recurringManagement, action: \.recurringManagement) {
    RecurringTransactionManagementFeature()
}
```

### SettingsFeature 變更

- 移除 `Destination.recurringTransactions`
- 移除 `Action.recurringTransactionsTapped`
- 移除 reducer 對應 case
- 移除 `destination:` closure 裡的 `.recurringTransactions` case

### SettingsView 變更

- 移除 `sectionManage` 裡的「定期交易」Button

---

## NotificationSettingsView — 新增 Section

在現有 `budgetWarningSection` 之後新增：

```swift
// Section Header
"記帳提醒"

// 說明文字
"設定週期性的記帳提醒，到期時推播通知，方便你快速完成記帳。"

// 列表
RecurringTransactionManagementView 裡的 List 內容（inline，非 push）
加號按鈕開啟 RecurringTransactionFormView sheet
```

**UI 結構（GlassContainer 包裝）：**

```
[記帳提醒]  ← section header
設定週期性的記帳提醒，到期時推播通知，方便你快速完成記帳。

┌─────────────────────────────┐
│ 每月房租   NT$15,000  月  ●  │
│ 每月健身房  NT$1,200  月  ●  │
│ ...                         │
│ ＋ 新增提醒                  │ ← Button，點擊發送 .recurringManagement(.addButtonTapped)
└─────────────────────────────┘
```

- 每行顯示：備註（或「未命名」）、金額、頻率、啟用開關
- 向左滑動出現刪除按鈕
- 空狀態只顯示「＋ 新增提醒」按鈕
- Sheet：`RecurringTransactionFormView`（現有，不改）

---

## Localisation

新增字串：

| Key | 中文值 |
|-----|--------|
| `notification_recurring_section` | `記帳提醒` |
| `notification_recurring_description` | `設定週期性的記帳提醒，到期時推播通知，方便你快速完成記帳。` |
| `notification_recurring_add` | `新增提醒` |
| `notification_recurring_empty` | `尚未設定任何記帳提醒` |

---

## Files Changed

| 檔案 | 變動 |
|------|------|
| `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift` | 新增 `recurringManagement` state、action、Scope |
| `Features/Sources/Features/NotificationSettings/NotificationSettingsView.swift` | 新增 `recurringSection` |
| `Features/Sources/Features/Settings/SettingsFeature.swift` | 移除 `recurringTransactions` destination、action、reducer case |
| `Features/Sources/Features/Settings/SettingsView.swift` | 移除「定期交易」Button |
| `NeuLedger/Resources/Localizable.xcstrings` | 新增 4 個本地化字串 |

---

## Out of Scope

- `RecurringTransaction` domain entity、SwiftData model、client — 不動
- `RecurringTransactionManagementFeature` / `RecurringTransactionFormFeature` reducer 邏輯 — 不動
- 通知點擊 → 預填表單 → 確認記帳流程 — 不動
- `RecurringTransactionManagementView` 和 `RecurringTransactionFormView` — 不動（直接複用）
