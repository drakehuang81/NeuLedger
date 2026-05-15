# Add / Edit Transaction UI Redesign — Design Spec

**Date:** 2026-05-15
**Branch:** `developer`
**Design source:** `design/source/add-transaction.jsx`

---

## 1. Goal

把 `AddTransactionView` 從目前的「Picker + segmented + numberPad keyboard」表單改造成設計稿的「Amount Hero + 自製 NumPad + AI Extract Strip + Tap-to-Sheet 欄位群」呈現，並支援設計稿要求的：

- 自製 IOSNumPad（slide up / down）
- 金額支援 `+ / −` 數學運算（`100+50−20 = 130`）
- AI Extract Strip — 自然語言文字 → 自動填 amount / category / account
- Tags 欄位（form 端首次具備編輯能力）
- 統一 WarmGradient 視覺基底（與 Detail / Onboarding 一致）

整個 view 用 `.sheet` + `.presentationDetents([.large])` + `.presentationBackground { WarmGradientBackground }` 呈現。

## 2. 範圍與非範圍

**範圍：**

- 重寫 `AddTransactionView` 全部 UI 結構
- 擴展 `AddTransactionFeature` State / Action：custom-numpad、active-sheet、ai-extract、tags
- 新增 Common primitives：`NumPad`、`AmountInputField`、`AIExtractStrip`、`FieldTapRow`、`CategoryGridSheet`、`AccountListSheet`、`DateGridSheet`、`TagsField`
- 新增 Domain `AmountExpression` value type（純 string → Decimal 計算）+ tests
- 既有的 4 種 Mode 全部支援（`.add` / `.edit` / `.addPrefilled` / `.addRecurringConfirmation`）
- i18n（en + zh-Hant）新增 keys
- Swift Testing 覆蓋 reducer 新行為 + `AmountExpression` 解析

**非範圍（YAGNI 並在 spec 標註）：**

- Merchant 欄位 — Domain `Transaction` 沒有此欄位，沿用 note。AI 抽取結果中的 merchant 拼進 note。
- SaveSuccess 動畫 overlay — 用單純 `dismiss()`
- AccountSheet 顯示帳戶 balance — Domain `Account` 沒有 balance 欄位（balance 是 transaction 累加），sheet 只顯示名稱 + 顏色 dot
- 移除既有的 segmented Picker 視覺以外的所有行為破壞性變更（既有 4 種 mode 進入點不動）
- 簡體中文 / 其他語系（沿用 en + zh-Hant 兩語）

## 3. 進入點

不動。以下 4 個進入點全部繼續用：

1. **Dashboard FAB / TabBar `+` 按鈕** → `.add(.expense)` 等
2. **TransactionDetailView Edit 按鈕** → `.edit(transaction)`
3. **TabBar AI 輸入完成** → `.addPrefilled(ExtractedTransaction)`
4. **Recurring Transaction 到期通知確認** → `.addRecurringConfirmation(template)`

UI 對 4 種 mode 唯一的差別：

- 標題：`.add*` 顯示「新增交易」、`.edit` 顯示「編輯交易」
- 初始 state：依 mode 預填欄位（沿用既有 `init(mode:)` 邏輯）
- Recurring 區塊：只在 `.add` 顯示（沿用現況）

## 4. 主要元件分解

```
AddTransactionView (sheet content, .presentationDetents([.large]))
├── (sheet) presentationBackground = WarmGradientBackground(variant: .top)
│
├── TopBar              ── 取消（左） / 「新增交易」or「編輯交易」（中） / 儲存（右，accent 高亮 + disabled 控制）
│
├── ScrollView
│   ├── TypeSegmented           ── 三段 capsule（expense / income / transfer）
│   ├── AmountHeroCard          ── Glass card：標籤「金額」 + 大字 NT$ + 數字 + caret 閃爍
│   ├── AIExtractStrip          ── 文字輸入 + mic + 「AI 填入」按鈕，3 狀態：idle / extracting / filled
│   ├── FieldGroupCard          ── Glass card：FieldTapRow 串接
│   │   ├── (非 transfer) Category 列  ── tap 開 CategoryGridSheet
│   │   ├── (transfer 時) From 列     ── tap 開 AccountListSheet
│   │   ├── Account 列                 ── tap 開 AccountListSheet
│   │   ├── (transfer 時) To 列       ── tap 開 AccountListSheet
│   │   ├── Date 列                    ── tap 開 DateGridSheet
│   │   ├── Note 列                    ── inline TextField
│   │   ├── Tags 列                    ── inline TagsField（FlowLayout chips + 6 suggestions + 自訂輸入）
│   │   └── (.add only) Recurring 列  ── inline Toggle + 顯示 frequency menu
│   └── bottomSpacer            ── 高度依 numpadVisible 動態（保留 320pt 給 NumPad）
│
├── NumPad (overlay, bottom, slide-up 動畫)
│
└── Sub-sheets (each its own .sheet item-binding):
    ├── CategoryGridSheet   ── medium detent + scrollable + emoji + 顏色背景 + 已選 outline
    ├── AccountListSheet    ── medium detent + name list + 顏色 dot + 已選 checkmark
    └── DateGridSheet       ── medium detent + 月份切換 + 7x6 calendar grid + 今天 / 已選 outline
```

**NumPad 顯示邏輯：**

- 預設 visible
- 使用者 tap Amount Hero → visible
- 使用者 tap 任何 FieldTapRow 或 inline TextField focus → hidden
- NumPad 內按「完成」→ hidden
- 任何 sub-sheet 開啟期間 → hidden（避免 sheet 上有 keypad 怪）

## 5. Data flow

### 5.1 新增 Domain 結構

```swift
// Domain/Entities/AmountExpression.swift
public struct AmountExpression: Equatable, Sendable {
    public let raw: String
    public var value: Decimal { ... }   // evaluates raw via NSExpression after sanitizing
    public var isValid: Bool { value >= 0 && raw.first != "+" }
    public init(_ raw: String) { self.raw = raw }
}
```

只解析 `+ - .` 與數字，過濾其他字元。錯誤回傳 `.zero`。

### 5.2 Reducer state 變動

`AddTransactionFeature.State` 新增：

```swift
public var amountText: String           // 已有 — 改為直接接收 NumPad key 事件
public var tags: [Domain.Tag]            // 新增
public var availableTags: [Domain.Tag]   // 新增
public var numpadVisible: Bool = true     // 新增
public var activeSheet: SheetKind?        // 新增（enum: .category, .account, .toAccount, .date）

public var aiExtractText: String = ""     // 新增
public var aiExtractStatus: AIExtractStatus = .idle   // 新增 enum: .idle / .extracting / .filled / .failed(String)
```

### 5.3 Reducer actions 新增 / 改名

```swift
// 取代既有 amountTextChanged(String)
case numpadKeyTapped(NumPadKey)         // .digit("3"), .dot, .plus, .minus, .delete, .done
case numpadVisibilityChanged(Bool)       // tap field 收 numpad

case sheetOpened(SheetKind)
case sheetDismissed

case aiExtractTextChanged(String)
case aiExtractRunTapped
case aiExtractResultReceived(Result<ExtractedTransaction, ClientError>)
case aiExtractClearTapped

case tagToggled(Domain.Tag)             // chip tap
case tagAdded(String)                    // 自訂輸入新 tag
case tagsLoaded([Domain.Tag])            // .task fetch tagClient.fetchAll
```

### 5.4 既有 actions 保留

`task / typeChanged / accountSelected / toAccountSelected / categorySelected / noteChanged / dateChanged / saveTapped / dismiss / recurringToggled / recurringFrequencyChanged / recordingTapped / speechResultReceived` 全部保留。

### 5.5 AI Extract 流程

```
aiExtractRunTapped
  ↳ status = .extracting
  ↳ effect: aiServiceClient.extractTransaction(text)
  ↳ aiExtractResultReceived(.success(extracted))
      ↳ status = .filled
      ↳ if extracted.amount != nil → amountText = ... numpad hide
      ↳ if extracted.type != nil → type = ...
      ↳ if extracted.merchant != nil → append to note
      ↳ if extracted.description != nil → set note (if no merchant) or merge
      ↳ trigger categorySuggestion via existing suggestCategoryTapped flow (best match auto-set)
  ↳ aiExtractResultReceived(.failure(err))
      ↳ status = .failed(message)
```

### 5.6 NumPad key handling

```
numpadKeyTapped(.digit("5"))
  ↳ if amountText.count >= 12 → ignore (overflow guard)
  ↳ amountText += "5"
  ↳ recompute amountError (clear if amountValue > 0)
numpadKeyTapped(.dot)
  ↳ if last segment after +/- already contains "." → ignore
  ↳ amountText += "."
numpadKeyTapped(.plus | .minus)
  ↳ if amountText is empty → minus prepends, plus ignored
  ↳ else if last char is operator → replace
  ↳ else → append
numpadKeyTapped(.delete)
  ↳ drop last char
numpadKeyTapped(.done)
  ↳ numpadVisible = false
```

Display logic：當 `amountText` 包含 `+/−` 時，Amount Hero card 顯示計算結果（大字）+ 副字 `= 原表達式`。

## 6. 視覺規格（對齊 Liquid Glass + WarmGradient）

| 元素 | 規格 |
|---|---|
| Sheet background | `presentationBackground { WarmGradientBackground(variant: .top) }` |
| TopBar | 透明，3 區塊：取消（textSecondary 15pt regular）/ 中央標題（17pt semibold display font）/ 儲存（accent 15pt semibold；disabled 時 textSecondary + opacity 0.5） |
| TypeSegmented | Capsule glass background，3 段；active 段 `transactionType.amountDisplayColor.opacity(0.20)` 填充 + 該色文字 |
| Amount Hero card | `glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 22))`；mono font 44pt；caret 用 2pt 寬 36pt 高、`amountDisplayColor` 填色，0.8s 閃爍 |
| AIExtractStrip | Glass capsule + Image(systemName: "sparkles") + TextField + （mic 圖示）+ trailing「AI 填入」 button；filled 後變「重新填」+ clear icon |
| FieldGroupCard | `glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18))`；內部 `FieldTapRow` 76pt 寬左側 mono uppercase label，右側 value + chevron |
| CategoryGridSheet | `.presentationDetents([.medium])`；emoji 28pt + name 13pt；多 group 分段 |
| AccountListSheet | `.presentationDetents([.medium])`；list row（顏色 dot 8pt + 名稱）+ 已選 checkmark |
| DateGridSheet | `.presentationDetents([.medium])`；月份切換 + 7x6 grid；今天細圓圈、已選實心圓 accent |
| NumPad | bottom-anchored capsule grid；4 列 x 4 欄（0–9 + . + 完成 + +/- + ←）；按下高亮 |

## 7. Localization

新增 i18n keys（en / zh-Hant）：

| Key | en | zh-Hant |
|---|---|---|
| `add_transaction_save` | `Save` | `儲存` |
| `add_transaction_amount_label` | `Amount` | `金額` |
| `add_transaction_type_expense` | `Expense` | `支出` |
| `add_transaction_type_income` | `Income` | `收入` |
| `add_transaction_type_transfer` | `Transfer` | `轉帳` |
| `add_transaction_ai_strip_placeholder` | `Describe — AI will fill the form` | `用一句話描述,AI 自動填入` |
| `add_transaction_ai_run` | `Fill with AI` | `AI 填入` |
| `add_transaction_ai_filled` | `Refill` | `重新填` |
| `add_transaction_ai_status_extracting` | `Extracting…` | `分析中…` |
| `add_transaction_ai_status_failed` | `Couldn't extract — please edit manually` | `無法分析,請手動填寫` |
| `add_transaction_field_category` | `Category` | `分類` |
| `add_transaction_field_account` | `Account` | `帳戶` |
| `add_transaction_field_from` | `From` | `從` |
| `add_transaction_field_to` | `To` | `到` |
| `add_transaction_field_date` | `Date` | `日期` |
| `add_transaction_field_note` | `Note` | `備註` |
| `add_transaction_field_tags` | `Tags` | `標籤` |
| `add_transaction_field_unselected` | `Not selected` | `未選` |
| `add_transaction_tags_placeholder` | `Add a tag…` | `新增標籤…` |
| `add_transaction_numpad_done` | `Done` | `完成` |
| `category_sheet_title` | `Choose a category` | `選擇分類` |
| `account_sheet_title_account` | `Choose an account` | `選擇帳戶` |
| `account_sheet_title_from` | `From which account` | `從哪個帳戶` |
| `account_sheet_title_to` | `To which account` | `到哪個帳戶` |
| `date_sheet_title` | `Choose a date` | `選擇日期` |

既有的 `add_transaction_title` / `add_transaction_edit_title` / `common_cancel` / `common_save` / `add_transaction_amount` / `add_transaction_note_placeholder` 等保留沿用。

Recurring 既有 keys (`recurring_transaction_toggle_label` / `recurring_transaction_frequency_label`) 也保留。

## 8. 錯誤處理

- `amountError` / `accountError` / `categoryError` / `transferError`：保留現況，inline 紅字顯示在 Amount Hero card 底部或對應 FieldTapRow 右下角
- AI extract 失敗：`aiExtractStatus = .failed(message)`，AIStrip 顯示橘色 warning 文字 + 「再試」按鈕；表單其他欄位不動
- 任何 sheet 載入失敗（categories / accounts 為空）：在對應 sheet 顯示 `EmptyStateView`
- 語音輸入失敗：保留現況 `speechError` inline 紅字

## 9. Testing

Swift Testing。新增 suites：

| Suite | 涵蓋 |
|---|---|
| `AmountExpressionTests` | `AmountExpression` 解析：`""` → 0、`"100"` → 100、`"100+50"` → 150、`"100−20"` → 80、`"−100"` → 0（無效）、超過 12 位 → clamp、含字母 → strip |
| `AddTransactionFeatureNumPadTests` | numpadKeyTapped 各分支：digit / dot / +/- / delete / done；overflow guard；`+/-` 之後再 `+/-` replace |
| `AddTransactionFeatureSheetTests` | sheetOpened → activeSheet 設定，numpadVisible = false；sheetDismissed 清空 |
| `AddTransactionFeatureAITests` | aiExtractRun → status = .extracting → result.success → state 對應 fields 被 fill；failure → status = .failed |
| `AddTransactionFeatureTagsTests` | tagToggled 加入 / 移除；tagAdded 自訂；tagsLoaded |
| 既有 `AddTransactionFeatureTests` | 補修：amountTextChanged 已被 numpadKeyTapped 取代，update 既有測試（每個 amount 變化改成 send `.numpadKeyTapped(.digit(...))`） |

## 10. 切片計畫（9 slice）

| Slice | 內容 | Commit prefix |
|---|---|---|
| 0 | Common primitives — `NumPad`、`AmountInputField`、`FieldTapRow`、`AIExtractStrip` skeleton | `feat(common):` |
| 1 | Domain — `AmountExpression` value type + tests + i18n batch | `feat(domain):` |
| 2 | Reducer extension — `AddTransactionFeature` 新 state + actions + cancel IDs；既有測試適配 numpadKeyTapped；tests | `feat(add-transaction):` |
| 3 | View skeleton — `.presentationBackground` WarmGradient + 自訂 TopBar + TypeSegmented + AmountHero placeholder | `feat(add-transaction):` |
| 4 | AmountHeroCard + 自製 NumPad slide + 數學運算 display | `feat(add-transaction):` |
| 5 | AIExtractStrip 完整實作（含 voice 整合） | `feat(add-transaction):` |
| 6 | FieldGroupCard + CategoryGridSheet + AccountListSheet + DateGridSheet | `feat(add-transaction):` |
| 7 | TagsField + Recurring 移位 + 編輯 mode 補齊 tags | `feat(add-transaction):` |
| 8 | Polish — accessibility identifiers、i18n 補完、4 種 mode entry 驗證、舊 View 程式碼移除 | `chore(add-transaction):` |

## 11. 風險與緩解

| 風險 | 緩解 |
|---|---|
| NumPad 與 SwiftUI focus 衝突（其他欄位 TextField 拿到 keyboard） | NumPad 透過 `numpadVisible` state 控制；其他 TextField 取得 focus 時 reducer 也設 `numpadVisible = false`，且強制 `.keyboardType(.default)` 不要 numberPad 雙顯 |
| `NSExpression` 解析有 inf / nan / 過大數字風險 | Sanitize 只允許 `[0-9.+\-]`，最大長度 16；計算結果 cast 成 Decimal 並 clamp 上限 999999999 |
| AI extract API 慢 / 失敗影響 UX | 1.5s timeout（既有 client 是否支持要確認），UI 立刻轉 idle 並提示；表單不阻塞 |
| 4 種 mode 進入點測試矩陣大 | Slice 8 用 Feature TestStore 個別 send `task` 並驗 initial state；現有 `AddTransactionFeatureTests` 已覆蓋部分 |
| sheet 套 sheet（外層 AddTransactionView 是 sheet、內含 CategoryGridSheet 等也是 sheet） | SwiftUI iOS 16+ 支援多層 sheet；確認 `.presentationDetents` 對巢狀 sheet 各自獨立 |

## 12. 完成定義

- [ ] 從 4 個進入點（Dashboard FAB、Detail Edit、TabBar AI、Recurring confirm）打開都正常運作
- [ ] Amount Hero card 顯示金額 + caret 閃爍 + type 變色
- [ ] NumPad slide up/down 動畫流暢；按其他欄位自動收起
- [ ] `100+50−20` 顯示計算結果 `130` 並在副字顯示 `= 100+50−20`
- [ ] AIExtractStrip 三狀態切換正確；filled 後填入 amount / category / account / note
- [ ] CategoryGridSheet / AccountListSheet / DateGridSheet 可開可關，選擇後 dismiss
- [ ] TagsField 可選 / 移除 / 自訂新增；存檔後 tags 寫入 transaction.tags
- [ ] Recurring toggle / frequency 在 `.add` mode 顯示且能編輯
- [ ] 全部使用者可見字串走 i18n（en / zh-Hant）
- [ ] 新增的 reducer 行為、`AmountExpression` 有對應 Swift Testing；`xcodebuild test -scheme FeaturesTests` 全綠
- [ ] 無 hardcoded `#000000` / `#FFFFFF`；色彩走 `Color.Design.*`
- [ ] Dark mode 對映正確
- [ ] Detail 點 Edit 開啟新 UI（視覺與 Detail 一致：暖橘漸層 + Glass cards）
