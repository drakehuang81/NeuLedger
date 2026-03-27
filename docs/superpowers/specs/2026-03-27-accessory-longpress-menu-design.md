# AccessoryView 長按 Menu 設計

**日期：** 2026-03-27
**狀態：** 已核准，待實作

---

## 背景

目前 AccessoryView 在 expanded 狀態下顯示兩個並排按鈕（「AI 記帳」和「＋ 新增」），視覺上不直覺、主次不明。改為單一按鈕 + 長按 contextMenu 切換模式的設計。

---

## 設計目標

- 單一按鈕，主次明確
- 長按開啟 contextMenu 切換模式
- 模式持久保存
- AI 不可用時優雅降級，完全禁止切換到 AI 模式

---

## 按鈕外觀

### Expanded 狀態（TabBar 展開）

| 模式 | 外觀 |
|------|------|
| 新增模式（預設） | `＋ 新增`，藍色，膠囊形，底部提示「長按可切換模式」 |
| AI 模式 | `✦ AI 記帳`，橘色（`accentColor`），膠囊形，底部提示「長按可切換模式」 |
| AI 不可用 | `＋ 新增`，不掛長按手勢，無提示文字 |

### Inline 狀態（TabBar 收起）

| 模式 | 外觀 |
|------|------|
| 新增模式 | `＋` icon，藍色 |
| AI 模式 | `✦` icon，橘色 |
| AI 不可用 | `＋` icon，藍色 |

---

## 行為邏輯

### 短按
- **新增模式**：觸發 `.contextActionTapped`（開啟 AddTransaction Sheet）
- **AI 模式**：觸發 `.aiInputButtonTapped`（展開 AI 輸入框）

### 長按
- 彈出 `.contextMenu`，包含兩個選項：
  - 「＋ 新增交易」
  - 「✦ AI 記帳」
- 選擇後切換 `accessoryMode`，透過 `userSettingsClient` 持久保存
- AI 不可用時：**不掛長按手勢**（不是 disabled，是完全不存在）

### AI 不可用 Fallback
- 啟動時讀取 `userSettingsClient` 中的模式設定
- 若存的是 AI 模式但 `aiServiceClient.isAvailable()` 回傳 `false`，強制切回新增模式
- 不寫入新設定（保留用戶選擇，下次 AI 恢復可用時自動還原）

---

## 狀態設計

### 新增 `AccessoryMode` enum（在 MainTabFeature 內）

```swift
enum AccessoryMode: String {
    case add
    case ai
}
```

### MainTabFeature.State 新增欄位

```swift
var accessoryMode: AccessoryMode = .add
```

### userSettingsClient Key

新增 `UserSettingsKey.accessoryMode`（raw value: `"accessoryMode"`），儲存 `AccessoryMode.rawValue`。

---

## 移除項目

- `compactPillContent` 中的雙按鈕 + Divider 設計
- `aiUnavailable` 用於 disable AI 按鈕的邏輯（改為控制是否掛長按手勢）

---

## 不在本次範圍內

- AI 輸入展開後的內部行為（record / ask sub-mode）維持不變
- Processing pill、Result pill 維持不變
- Expanded AI 輸入框的 UI 維持不變
