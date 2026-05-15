# Transaction Detail Redesign — Design Spec

**Date:** 2026-05-15
**Branch:** `developer`
**Design source:** `design/source/transaction-detail.jsx`, `design/screens/03-Transaction-Detail.html`

---

## 1. Goal

將 Transaction Detail 從目前的「全螢幕 `NavigationStack` 內 list 樣式」重構為設計稿的「底部 sheet · half↔full 拖拽 · 唯讀為主」呈現，並補上：

- TxHero（category pill + 大金額 + title + AI Filled 徽章）
- AI Insight card（依交易類型客戶端計算的洞察文案）
- 5 秒延遲刪除 + Undo bar（取代既有 confirmationDialog → 立即刪除）
- Activity log（建立來源與時間，full-detent 才顯示）

採用 iOS 26 原生 `.presentationDetents([.medium, .large])` 達成 half↔full 拖拽；不自己刻拖拽手勢。

## 2. 範圍與非範圍

**範圍：**

- 重寫 `TransactionDetailView` 及對應 `TransactionDetailFeature` 的 State / Action
- 新增 `TransactionInsight` Domain entity + `transactionClient.detailStats(for:)` 介面 + Core 實作（`DatabaseClient.detailStats(for:)`）
- 新增 Common primitive：`DetailField`、`AccountChip`、`MetaCard`（若 Glass 容器尚未抽出）
- 新增 i18n key（zh-Hant / en）涵蓋所有畫面字串
- Swift Testing 覆蓋 Feature reducer 新行為（pendingDelete 視窗、undo、insight 載入）

**非範圍（YAGNI，spec 內標註但不實作）：**

- Compact 版面（V2）— 只實作 Spacious
- `merchant` 欄位 — Domain `Transaction` 沒有此欄位
- `sourceText` 欄位 — Domain 沒有；之後與 AI extract 一起補
- Recurring 連結與 `↻ Monthly` 徽章 — `Transaction` 沒有 recurring 關聯欄位；Activity log 也不顯示 next charge
- 「同步至 iCloud · 已加密」固定行 — 沒有真實同步狀態資料源
- 透過 deep-link / share 進入 Detail
- Transaction Detail 與 Recurring Detail 的合併

## 3. 進入點與導覽

現況：

- `TransactionsFeature` 透過 `@Presents var transactionDetail: TransactionDetailFeature.State?` + `.sheet(item:)` 開啟
- `DashboardFeature` 同樣模式

→ **保留兩個進入點不變**，只升級 `TransactionDetailView` 的 sheet 內容與 reducer 行為。

設計稿底層那層「被半透明 sheet 蓋住、隱約可見的交易列表」由原生 `presentationDetents([.medium, .large])` 的 medium detent 自動達成（sheet 之上 parent 仍可見 + scrim）—— 不需自行繪製假的 parent peek。

## 4. 主要元件分解

```
TransactionDetailView (sheet content)
├── TxTopBar              ── 「取消」按鈕 · 「TRANSACTION · DETAIL」標題
├── ScrollView
│   ├── TxHero            ── category pill / 金額 / title / AI Filled 徽章
│   ├── AIInsightCard     ── on-device 統計文案（type-aware）
│   ├── DetailFieldsCard  ── Account / From-To / Date / Note  （always）
│   ├── TagsRow           ── Tags（full detent only）
│   └── ActivityCard      ── 建立/更新 log（full detent only）
└── TxActionsBar          ── Edit / Delete（pinned）

Sub-flows:
├── DeleteConfirmDialog   ── confirmationDialog（系統 .destructive 樣式）
└── UndoBanner            ── 5s glass capsule（底部 floating）
```

**Detent-aware 顯示：**

- `medium`：Hero、Insight、DetailFields、Actions（隱藏 Tags、Activity）
- `large`：上述 + Tags + Activity

判斷方式：用 `@State private var detent: PresentationDetent = .medium` + `.presentationDetents([.medium, .large], selection: $detent)`，View 內依 `detent == .large` 條件渲染。

## 5. Data flow

### 5.1 新增 Domain 結構

```swift
// Domain/Entities/TransactionInsight.swift
public struct TransactionInsight: Equatable, Sendable {
    public enum Kind: Sendable {
        case incomeVsLast(percentDelta: Double, lastAmount: Decimal, monthlyCount: Int, netMonth: Decimal)
        case expenseVsCategoryAvg(percentDelta: Double, avg: Decimal, monthlyCount: Int, monthTotal: Decimal)
        case transfer(monthCount: Int, monthTotal: Decimal)
        case fallback(monthlyCategoryCount: Int)
    }
    public let kind: Kind
}
```

### 5.2 新增 client 介面

```swift
// Domain/Clients/TransactionClient.swift
public var detailStats: @Sendable (_ transaction: Transaction) async throws -> TransactionInsight
```

### 5.3 Core 實作

`DatabaseClient.detailStats(for:)` 計算：

- **income**：本月同 categoryId 的最新一筆（不含當前）+ 本月 income 筆數 + 本月淨值（income − expense）
- **expense**：本月同 categoryId 平均金額 + 本月該分類筆數 + 該分類合計
- **transfer**：本月 transfer 筆數 + 合計
- **fallback**：本月該分類筆數（其餘為 nil）

回傳對應 `TransactionInsight.Kind`。

### 5.4 Reducer State 新增

```swift
@ObservableState public struct State: Equatable {
    public var transaction: Transaction
    public var categoryName: String?
    public var accountName: String?
    public var toAccountName: String?
    public var insight: TransactionInsight?       // ← 新增
    public var detent: Detent = .medium            // ← 新增（Detent 為 Equatable wrapper）
    public var pendingDelete: Bool = false         // ← 新增
    public var deleteCountdown: Int = 5            // ← 新增（顯示用，可選）
    @Presents var editTransaction: AddTransactionFeature.State?
    public var showDeleteConfirmation: Bool = false
}
```

### 5.5 Action 新增

```swift
case insightLoaded(TransactionInsight)
case detentChanged(Detent)
case undoTapped              // 取消 pendingDelete window
case deleteWindowExpired     // 5 秒到，真執行 delete
```

### 5.6 刪除 + Undo 流程

```
deleteTapped
  → showDeleteConfirmation = true
deleteConfirmed
  → showDeleteConfirmation = false
  → pendingDelete = true
  → .run { try await clock.sleep(5s); send(.deleteWindowExpired) }
    .cancellable(id: CancelID.deleteWindow, cancelInFlight: true)
undoTapped
  → pendingDelete = false
  → .cancel(id: CancelID.deleteWindow)
deleteWindowExpired
  → pendingDelete = false
  → .run { try await client.delete(id); send(.delegate(.deleted(id))); await dismiss() }
```

**Undo 期間 sheet 行為：**

- Sheet 內容仍可見（不立即關閉）
- UndoBanner 浮現於 sheet 底部上方
- 5 秒後 dismiss
- 若使用者在 5 秒內手動 swipe 關閉 sheet，則視為「確認刪除」—— 在 `dismiss` 時若 `pendingDelete` 為 true 不要 cancel timer，讓它自然到期執行 delete

實作層面：用 `@Dependency(\.continuousClock) var clock` 與 cancel ID `enum CancelID { case deleteWindow }`。

## 6. 視覺規格（對齊 Liquid Glass + Dashboard 既有調性）

| 元素 | 規格 |
|---|---|
| Sheet 圓角 | 系統預設（detent 自動處理） |
| Grabber | `.presentationDragIndicator(.visible)` |
| Background | sheet 本體用 `Color.Design.background` |
| Hero 金額 | `font: Font.Design.mono.size(52).weight(.medium).monospacedDigit()`；income 用 `Color.Design.incomeGreen`、expense 用 `Color.Design.textPrimary`、transfer 用 accent |
| Category pill | Glass capsule + emoji + label + sub-label |
| AI Filled 徽章 | `incomeGreen.opacity(0.15)` 背景 + sparkles icon + uppercase 9pt mono |
| DetailFieldsCard | `.glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18))` |
| AccountChip | 26pt 圓 + `account.color.opacity(0.15)` 背景 + SF Symbol（依 `account.type` 對應 icon） |
| Tag pill | 既有 `TagPill` 元件，accent tint |
| Undo banner | Glass capsule，底部 24pt padding，左 check icon + 「已刪除」+ 右 Undo 按鈕（accent 色） |

## 7. Localization

新增 i18n keys（en / zh-Hant）：

```
transaction_detail_title              // "Transaction · Detail" / "交易明細"
transaction_detail_ai_filled          // "AI Filled" / "AI 自動填入"
transaction_detail_account            // "Account" / "帳戶"
transaction_detail_from               // "From" / "從"
transaction_detail_to                 // "To" / "到"
transaction_detail_date               // "Date" / "日期"
transaction_detail_note               // "Note" / "備註"
transaction_detail_tags               // "Tags" / "標籤"
transaction_detail_activity           // "Activity" / "活動紀錄"
transaction_detail_activity_ai        // "Created by AI" / "AI 自動建立"
transaction_detail_activity_manual    // "Created manually" / "手動建立"
transaction_detail_activity_updated   // "Last updated" / "最後更新"
transaction_detail_insight_label      // "NeuLedger AI · On-device"
transaction_detail_undo               // "Undo" / "復原"
transaction_detail_undo_deleted       // "Deleted" / "已刪除"

transaction_insight_income_vs_last    // "+%.1f%% vs last %@. This month: %d income entries, net %@."
transaction_insight_expense_vs_avg    // "%@ %.0f%% vs %@ average (%@). This month: %d entries, total %@."
transaction_insight_transfer          // "Net value unchanged. %d transfers this month, total %@."
transaction_insight_fallback          // "Entry #%d in %@ this month."
```

zh-Hant 對應翻譯依設計稿原文。所有字串以 `String(localized: "key", bundle: .main)` 或 `Text("key")` 引用。

## 8. 錯誤處理

- `detailStats` 失敗 → State 內 `insight = nil`；View 直接隱藏 InsightCard（不顯示 error banner，因為這是 nice-to-have）
- `transactionClient.delete` 失敗（5 秒後執行階段）→ alert（reuse 既有 `AlertState` pattern），保留 transaction、Undo banner 消失
- name 載入失敗 → 維持現況（顯示 nil），不額外處理

## 9. Testing

使用 Swift Testing。新增測試：

| Test suite | 涵蓋 |
|---|---|
| `TransactionInsightTests` | `.kind` 結構 Equatable / Sendable 保留 |
| `TransactionClientDetailStatsTests` | Core 計算正確：income / expense / transfer / fallback 各 1 條 + 邊界（同類別 0 筆、月份切換） |
| `TransactionDetailFeatureLoadTests` | `.task` 同時觸發 name + insight；都接收後 state 完整 |
| `TransactionDetailFeatureDeleteTests` | confirm → pending → window expired → delegate(.deleted) + dismiss；undo 路徑：confirm → pending → undo → 不執行 delete |
| `TransactionDetailFeatureDetentTests` | detent change 反映 state；不觸發 effect |
| `TransactionDetailFeatureEditTests` | 既有編輯流程保留（reuse 現有測試） |

## 10. 切片計畫（8 slice）

| Slice | 內容 | Commit prefix |
|---|---|---|
| 0 | Common primitives — `DetailField`、`AccountChip` 公開 init、Glass 容器 helper | `feat(common):` |
| 1 | Domain — `TransactionInsight` entity + `transactionClient.detailStats` 介面 + i18n keys | `feat(domain):` |
| 2 | Core — `DatabaseClient.detailStats(for:)` 計算 helper + Live 實作 + tests | `feat(core):` |
| 3 | Sheet 容器 — `.presentationDetents` + TxTopBar + ScrollView 骨架（Hero placeholder） | `feat(transaction-detail):` |
| 4 | `TxHero` — category pill + 金額 + title + AI Filled 徽章 | `feat(transaction-detail):` |
| 5 | DetailFieldsCard + Tags + ActivityCard（含 detent-aware 顯示） | `feat(transaction-detail):` |
| 6 | AIInsightCard — 4 種 kind 對應文案 | `feat(transaction-detail):` |
| 7 | Actions + DeleteConfirm + UndoBanner + 5 秒延遲刪除 reducer 邏輯 + 對應 tests | `feat(transaction-detail):` |
| 8 | Polish — i18n 補完、accessibility label、舊 View 程式碼移除、視覺微調 | `chore(transaction-detail):` |

## 11. 風險與緩解

| 風險 | 緩解 |
|---|---|
| `.presentationDetents` 在 medium 狀態下，使用者向下 swipe 直接關閉導致誤刪 | `pendingDelete` 為 true 時 swipe-to-dismiss 視為確認刪除（不 cancel timer）。設計稿亦如此（5 秒一過即真刪） |
| 5 秒延遲讓使用者誤以為已刪、回到列表又看到資料 | UndoBanner 浮現於 sheet 內。Sheet 關閉前該筆仍存在於資料層；列表若已套用 optimistic UI 應該也接收 `delegate(.deleted)` 並重新整理 |
| 同類別統計成本（fetch all + 過濾） | 沿用 Dashboard `statsSnapshot` 同模式，month-range predicate；單筆 Detail 開啟僅執行一次，效能可接受 |
| 設計稿 `merchant` / `sourceText` 缺欄位 | 已標註為非範圍。Spec 未來補資料模型時再回頭加 |

## 12. 完成定義

- [ ] 既有 Transactions list / Dashboard 開啟 Detail 行為一致（從現有 `@Presents` 進入）
- [ ] 拖曳手把可在 medium / large 間切換
- [ ] medium 看到 Hero + Insight + 主要欄位 + Actions
- [ ] large 額外看到 Tags + Activity
- [ ] AI Filled 徽章正確反映 `transaction.aiSuggested`
- [ ] Insight 文案依 4 種 kind 正確顯示
- [ ] Delete 流程：確認 → 5 秒視窗 + Undo banner → 過期才真刪
- [ ] Undo 在 5 秒內可取消刪除
- [ ] 全部使用者可見字串走 i18n（en / zh-Hant 兩語）
- [ ] 所有新增 Reducer、Core helper、Domain entity 有對應 Swift Testing 測試，`xcodebuild test -scheme Features` 全綠
- [ ] 無 hardcoded `#000000` / `#FFFFFF`；色彩走 `Color.Design.*`
- [ ] Dark mode 對映正確
