# AccessoryView 排版改版設計文件

**日期：** 2026-03-22
**範圍：** `MainTabView.swift`（`CustomAccessoryView`）、`SettingsView`、`UserSettings`

---

## 背景與問題

目前 `CustomAccessoryView` 的 expanded 狀態存在兩個主要排版問題：

1. **Compact 狀態**：AI wand 和 plus 按鈕靠右對齊（`Spacer()` 在左），左側大片空白，視覺失衡。
2. **AI 輸入展開狀態**：mode toggle（記帳／詢問）、text field、動作按鈕全擠在同一行，文字輸入區過窄。

---

## 設計目標

- 修正 compact 狀態的視覺失衡
- 解決 AI 輸入列的空間擁擠問題
- 補足 AI 處理中與有結果時的 compact 狀態呈現
- 新增 Settings 開關讓使用者控制整個底部快捷列的顯示

---

## 五個狀態設計

### ① Compact — 一般狀態

**呈現：** 置中 pill，左右兩個動作並排。

```
[  ✨ AI 記帳  |  ⊕ 新增  ]
```

- `HStack` 改為 `pill` 樣式，`frame(maxWidth: .infinity)` + `.glassEffect` 在 Capsule
- 兩個 Button 之間加 `Divider()`（垂直，1pt 寬）
- 移除原本的 `Spacer()` + 右對齊結構

---

### ② Compact — AI 處理中（`isAIInputLoading == true`）

**呈現：** 整個 pill 替換為橙色光暈掃描動畫，禁用所有互動。

```
[  ✨  AI 正在分析你的交易…  ◌  ]   ← shimmer 動畫
```

- 使用 `TimelineView` 或 `withAnimation(.easeInOut.repeatForever)` 製作左右掃光效果
- 整個 pill 不可點擊（`.disabled(true)`）
- 「新增」按鈕不渲染

**觸發條件：** `store.isAIInputLoading == true`（且 `!store.isAIInputExpanded`）

---

### ③ Compact — AI 有結果（`aiAnswer != nil`，`!isAIInputExpanded`）

**呈現：** Pill 顯示 aiAnswer 單行摘要，右側「▲ 展開」提示，點擊重新展開 AI 卡片。

```
[  ✨  早餐 NT$60 已記錄至早餐類別  ▲ 展開  ]
```

- `aiAnswer` 文字以 `.lineLimit(1)` + `.truncationMode(.tail)` 截斷
- 整個 pill 可點擊 → 觸發 `store.send(.aiInputButtonTapped)` 重新展開
- 「新增」按鈕不渲染

**觸發條件：** `store.aiAnswer != nil && !store.isAIInputExpanded && !store.isAIInputLoading`

---

### ④ AI 輸入展開中（`isAIInputExpanded == true`）

**呈現：** Input bar 左側放置 icon 模式指示器（badge），右側保留完整文字輸入寬度。

```
[ ✏️記  今天早餐 60 元…              ⬆️  ✖️ ]
```

- Mode toggle 從兩個文字按鈕改為單一 **badge**（圖示 + 單字：`✏️ 記` / `💬 問`）
- Badge 可點擊 → 呼叫 `store.send(.inputPurposeSwitched(…))` 切換模式
- Badge 使用 `accentColor.opacity(0.2)` 背景 + `Capsule()` 圓角
- TextField 可用寬度大幅增加（原本的 mode toggle 文字佔位消失）
- 其餘（send button、dismiss button、error label、aiAnswer card）邏輯不變

---

### ⑤ Settings — 顯示底部快捷列

**位置：** `SettingsView` 中適當區塊（建議放在「外觀」或「一般」section）。

```
顯示底部快捷列          [  ●  ]  ← 預設開啟
AI 記帳與快速新增按鈕
```

- 新增 `UserSettings` key：`showAccessoryBar`，型別 `Bool`，預設 `true`
- `MainTabView` 讀取此設定：若為 `false` → 不加 `.tabViewBottomAccessory { … }` modifier
- 關閉時：底部無任何 accessory；各 tab 內的功能入口不受影響

---

## 狀態優先順序

當多個條件同時成立時，compact 狀態依以下優先序決定呈現：

```
isAIInputExpanded  →  顯示 AI 輸入列（狀態④）
isAIInputLoading   →  顯示處理中動畫（狀態②）
aiAnswer != nil    →  顯示結果摘要（狀態③）
否則               →  顯示一般 compact pill（狀態①）
```

---

## 影響範圍

| 檔案 | 變動類型 |
|------|---------|
| `Features/Sources/Features/MainTab/MainTabView.swift` | 修改 `CustomAccessoryView` 所有 case |
| `Features/Sources/Features/Settings/SettingsView.swift` | 新增 toggle |
| `Domain/UserSettings.swift`（或同等路徑） | 新增 `showAccessoryBar` key |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | 讀取 `showAccessoryBar` 設定（若需要） |

---

## 不在範圍內

- Inline 狀態（tab bar 收起時）：現有設計不變
- AI 功能邏輯（submit、ask、extract）：不改動
- 其他 tab 的新增入口：不受影響
