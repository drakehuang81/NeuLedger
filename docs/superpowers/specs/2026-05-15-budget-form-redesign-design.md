# Budget Form UI Redesign — Design Spec

**Date:** 2026-05-15
**Branch:** `developer`
**Design source:** `design/source/budget.jsx` —  function `NewBudgetSheet`

---

## 1. Goal

把 `BudgetFormView` 從目前的「`NavigationStack` + `Form` sections」表單改造成設計稿 `NewBudgetSheet` 的「底部 sheet + center 大金額 + AI 建議 chip + 4 欄分類 grid + 快速金額 chips」呈現，並與既有的 WarmGradient 視覺語言對齊（Detail / Onboarding 已採用）。

整個 form 從 `.sheet` 開啟，內層用 `.presentationDetents([.medium, .large])` + `.presentationBackground { WarmGradientBackground(variant: .top) }`。

## 2. 範圍與非範圍

**範圍：**

- 重寫 `BudgetFormView` 全部 UI 結構
- 擴展 `BudgetFormFeature` State / Action：suggestedAmount、auto-name 邏輯、quick-amount 套用
- 新增 Common primitives：`AmountHeroBlock`（含 AI suggestion chip + quick chips）、`CategoryGridPicker`
- 新增 Domain client 介面：`transactionClient.averageMonthly(categoryId:months:)` —— 算某 category 過去 N 個月每月平均花費
- Core 對應實作：`DatabaseClient.averageMonthly(categoryId:months:)`
- 既有的 2 種 Mode 全部支援（`.add` / `.edit(Budget)`）
- i18n（en + zh-Hant）新增 keys
- Swift Testing 覆蓋 reducer 新行為 + Core 計算

**非範圍（明確點名）：**

- `BudgetMain` / `BudgetCategoryDetail` 的重設計 — **另外一個 spec**
- Domain `Budget` schema 任何變更 — `name` / `period` / `startDate` 全部保留向後相容
- 自製 NumPad — 沿用系統 `keyboardType(.numberPad)`
- 設計稿固定 8 個分類 — V1 用真實 `categoryClient.fetchAll().filter { $0.type == .expense }`，4 欄 grid 自動換行（保有彈性）
- 預算 alarm / 預警閥值 — 不在此次 form scope

## 3. 進入點

不動。以下 2 個進入點繼續使用：

1. **BudgetManagementView 的 `+` 按鈕** → `.add`
2. **BudgetManagementView 點某既有 budget** → `.edit(budget)`

UI 對 2 種 mode 的差別：

- 標題：`.add` 顯示「新增預算」、`.edit` 顯示「編輯預算」
- 初始 state：`.edit` 用既有 budget 預填欄位（amount / category / period / startDate 全保留）
- 儲存：`.add` → `budgetClient.add(...)`；`.edit` → `budgetClient.update(...)`

## 4. 主要元件分解

```
BudgetFormView (sheet content, .presentationDetents([.medium, .large]))
├── (sheet) presentationBackground = WarmGradientBackground(variant: .top)
│
├── TopBar
│   ├── 取消（左，textSecondary）
│   ├── 「新增預算」/「編輯預算」（中央，semibold display）
│   └── 儲存（右，accent；disabled 條件 = amountValue <= 0 || (.add 且 categoryId == nil 且 expense categories 非空)）
│
└── ScrollView
    ├── AmountHeroBlock         ── 「每月金額」label + center NT$ 56pt mono 大字 + 可隱式 TextField 接收 .numberPad
    │   └── AISuggestionChip    ── 條件顯示：當 categoryId 有值且 suggestedAmount > 0 時；tap 套用金額
    ├── QuickAmountChipsRow    ── 5 個 preset chip [2000, 3000, 5000, 8000, 10000]；active 用 accent 填底
    └── CategoryGridPicker     ── 4 欄 grid；active 用 category color 填底 + white icon/text；inactive 用 glass surface
```

### NumPad 處理

不做自製 NumPad。`AmountHeroBlock` 中央用 SwiftUI `TextField(value:format:)` 配 `.keyboardType(.numberPad)`，TextField 本體無框線，由 hero 大字本體顯示金額。Caret 用系統預設即可。

## 5. Data flow

### 5.1 新增 / 修改 client

```swift
// Domain/Clients/TransactionClient.swift  — 新增
public var averageMonthly: @Sendable (
    _ categoryId: Domain.Category.ID,
    _ months: Int
) async throws -> Decimal
```

回傳：過去 `months` 個月內，同 categoryId 的 `.expense` 交易月平均花費（Decimal）。

### 5.2 Core 實作

`DatabaseClient.averageMonthly(categoryId:months:)`：

- 計算當下日期前 `months` 個月區間（依 `Calendar.current`）
- fetch `SDTransaction` where `type == "expense" && categoryId == ? && date >= rangeStart`
- 加總後除以 `months`
- 沒有資料回傳 0

### 5.3 Reducer state 變動

`BudgetFormFeature.State` 新增：

```swift
public var suggestedAmount: Decimal = 0
public var isLoadingSuggestion: Bool = false
```

並 **不再使用 / 不渲染** `name` / `period` / `startDate` 對應的 UI；State 中三個欄位保留，邏輯：

- `.add` mode：
  - `name` 在 saveTapped 時自動推導：`"\(selectedCategory.name) 預算"`；無 categoryId 則用 fallback `"本月預算"`
  - `period = .monthly`（不可從 UI 改）
  - `startDate = Date()`（不可從 UI 改）
- `.edit` mode：
  - `name` / `period` / `startDate` 保留原值不動（不顯示也不重設）
  - 編輯 amount + categoryId 為主

### 5.4 Reducer actions 新增 / 改名

```swift
case suggestionLoaded(Decimal)
case suggestionFailed
case suggestionChipTapped              // 套用 suggestedAmount 到 amountText
case quickAmountTapped(Decimal)        // 套用 preset chip
```

既有的 `nameChanged(String)` 與 `periodChanged(BudgetPeriod)` 與 `startDateChanged(Date)` **保留但變成 dead UI**（不從 View 觸發）—— 等之後其他 sub-screen 需要時可以復用。

### 5.5 Suggestion 流程

```
.task
  ↳ existing: load categories
  ↳ new: if state.categoryId != nil, fire suggestion fetch
          if .edit and categoryId != nil, fire immediately

.categoryChanged(newId)
  ↳ state.categoryId = newId
  ↳ if newId != nil:
      state.isLoadingSuggestion = true
      return .run { send in
          let avg = try await transactionClient.averageMonthly(newId, 3)
          await send(.suggestionLoaded(avg))
      } .cancellable(id: CancelID.suggestion, cancelInFlight: true)

.suggestionLoaded(value)
  ↳ state.suggestedAmount = value
  ↳ state.isLoadingSuggestion = false

.suggestionFailed
  ↳ state.suggestedAmount = 0
  ↳ state.isLoadingSuggestion = false

.suggestionChipTapped
  ↳ state.amountText = "\(NSDecimalNumber(decimal: suggestedAmount).intValue)"
  ↳ state.amountError = nil

.quickAmountTapped(value)
  ↳ state.amountText = "\(NSDecimalNumber(decimal: value).intValue)"
  ↳ state.amountError = nil
```

### 5.6 Save 流程（更新）

```swift
case .saveTapped:
    let amount = Decimal(string: state.amountText) ?? 0
    guard amount > 0 else {
        state.amountError = String(localized: "error_amount_must_be_positive")
        return .none
    }

    // Auto-name only for .add when name is empty (the View no longer touches `name`)
    let resolvedName: String
    switch state.mode {
    case .add:
        let suffix = String(localized: "budget_form_default_name_suffix")  // "預算"
        if let cid = state.categoryId,
           let cat = state.availableCategories.first(where: { $0.id == cid }) {
            resolvedName = "\(cat.name)\(suffix)"
        } else {
            resolvedName = String(localized: "budget_form_default_name_all")  // "本月預算"
        }
    case let .edit(existing):
        resolvedName = existing.name   // preserve
    }

    // period/startDate: untouched from current state
    return .run { send in
        switch state.mode {
        case .add:
            let budget = Budget(name: resolvedName, amount: amount, ...)
            try await budgetClient.add(budget)
        case let .edit(existing):
            let updated = Budget(id: existing.id, name: resolvedName, amount: amount, ...)
            try await budgetClient.update(updated)
        }
        await send(.savedSuccessfully)
    }
```

## 6. 視覺規格

| 元素 | 規格 |
|---|---|
| Sheet background | `presentationBackground { WarmGradientBackground(variant: .top) }` |
| TopBar | 透明背景，取消（textSecondary 15pt regular）/ 標題（17pt semibold display）/ 儲存（accent 15pt semibold；`.disabled` 時 opacity 0.5） |
| Amount Hero | label「每月金額」（mono 10pt UPPERCASE textSecondary）+ HStack center: `NT$`（28pt mono textSecondary）+ amount（56pt display semibold textPrimary）；TextField 隱形 overlay 接收 numberPad |
| AI Suggestion chip | Capsule 28pt 高 padding 12px；`accentBlue.opacity(0.15)` 背景 + 0.5pt accent stroke + sparkles icon + `AI 建議 NT$ x,xxx (3 個月平均)` 字 |
| Quick amount chips | 5 個 chip，capsule，未選 = glass surface；已選 = `accentOrange` 填底 + white text；mono 字體 |
| CategoryGrid 4 欄 | 每格 14pt 圓角 padding 14×6；icon 20pt + name 11pt；inactive = glass surface；active = `category.color` 填底 + white icon/text + 顏色陰影 `0 8px 20px color.opacity(0.5)` |
| ScrollView | 全部用同一 ScrollView，spacing 20pt；底部 padding 100pt 給安全區 |
| Save button | 用 toolbar item；disabled 條件如 §4 所述；`.fontWeight(.semibold)` |

## 7. Localization

新增 keys（en / zh-Hant）：

| Key | en | zh-Hant |
|---|---|---|
| `budget_form_amount_label` | `Monthly amount` | `每月金額` |
| `budget_form_category_label` | `Choose a category` | `選擇分類` |
| `budget_form_quick_amount_label` | `Quick amount` | `快速金額` |
| `budget_form_ai_suggestion_label` | `AI suggests NT$%@ (3-month avg)` | `AI 建議 NT$%@ (3 個月平均)` |
| `budget_form_default_name_suffix` | ` Budget` | `預算` |
| `budget_form_default_name_all` | `Monthly budget` | `本月預算` |

既有的 `budget_form_add_title` / `budget_form_edit_title` / `common_cancel` / `common_save` / `error_amount_must_be_positive` 等保留沿用。

既有但不再 View 顯示的：`budget_form_name_placeholder` / `budget_form_period` / `budget_form_start_date` / `budget_form_apply_category` / `budget_form_all_expenses` / `budget_form_all_expenses_hint` — **保留 i18n keys**，未來其他 form 復用。

## 8. 錯誤處理

- `amountError`：inline 紅字顯示在 Amount Hero 下方
- `suggestion` 載入失敗：suggested chip 不顯示（state.suggestedAmount = 0），不顯示錯誤提示 — 屬於 nice-to-have
- save 失敗（`budgetClient.add/update` throws）：sheet 仍開啟，amount/category 保留；錯誤訊息由現有的 `AlertState` 機制處理（沿用 BudgetManagementFeature 接到 `delegate(.saveFailed)` 後彈 alert）—— 若目前沒有此路徑，新增 `.saveFailed(String)` action 與 inline error display

## 9. Testing

Swift Testing。新增 / 修改 suites：

| Suite | 涵蓋 |
|---|---|
| 既有 `BudgetFormFeatureTests` | 更新：移除 name/period/startDate 變更測試；新增 auto-name resolution（.add with category → "餐飲預算"、.add without category → "本月預算"、.edit 保留原 name）|
| 新增 `BudgetFormFeatureSuggestionTests` | suggestion 載入：categoryChanged → suggestionLoaded；suggestionFailed → suggestedAmount = 0；suggestionChipTapped 套金額；quickAmountTapped 套金額 |
| 新增 `TransactionClientAverageMonthlyTests` (CoreTests) | DatabaseClient.averageMonthly：3 筆同 category 3 個月 → 平均；空資料 → 0；跨 category 不計入 |

## 10. 切片計畫（5 slice）

| Slice | 內容 | Commit prefix |
|---|---|---|
| 0 | Common primitives — `AmountHeroBlock`（含 NT$ center 大字 + AI chip placeholder + quick chips row）、`CategoryGridPicker` | `feat(common):` |
| 1 | Domain / Core — `transactionClient.averageMonthly` 介面 + `DatabaseClient.averageMonthly` 實作 + 對應 tests | `feat(core):` |
| 2 | Reducer extension — `BudgetFormFeature` 加 suggestedAmount/isLoadingSuggestion/auto-name；既有測試適配 + 新 suggestion tests + i18n keys | `feat(budget-form):` |
| 3 | View 重寫 — sheet + WarmGradient + TopBar + AmountHeroBlock 串接 + CategoryGridPicker + quick chips | `feat(budget-form):` |
| 4 | Polish — accessibility、i18n 補完、舊 Form `Picker(.segmented)` / `DatePicker` 等程式碼移除、edit-mode 對 non-monthly budget 容錯 | `chore(budget-form):` |

## 11. 風險與緩解

| 風險 | 緩解 |
|---|---|
| `name` 改為 auto-derive 後若 user 想自訂 name 怎辦 | V1 不開放（YAGNI）；可在未來於 sheet 加入 "Customize name" disclosure |
| edit 既有 weekly / yearly budget 在新 UI 看不到 period 提示 | edit mode 下，View 標題加副標 `"\(period.localizedName)"` 提示週期不變 |
| `averageMonthly` 在使用者剛安裝（無資料）回傳 0 | View 自動隱藏 suggestion chip（state.suggestedAmount == 0 不顯示） |
| Sheet 內巢狀的 categoryChanged → suggestion fetch 在快速切換時 race | `.cancellable(id: CancelID.suggestion, cancelInFlight: true)` |
| Quick chips 與 AI chip 的 active state 衝突 | 分別判斷：amountText 等於 chip value 時顯示 active；點選後皆只設 amountText，不互相影響 |

## 12. 完成定義

- [ ] 從 BudgetManagementView 的 `+` 與 row tap 兩個進入點都正常開啟新版 form
- [ ] Sheet 用 WarmGradient + drag indicator，medium / large 拖拽切換
- [ ] Amount Hero 中央大字 + NT$ 前綴顯示正確；輸入透過 numberPad 鍵盤
- [ ] AI 建議 chip 在有 categoryId 且 suggestedAmount > 0 時顯示；tap 套金額
- [ ] Quick amount chips 5 個 tap 套金額；active 樣式正確
- [ ] CategoryGrid 4 欄自動換行；active 用 category color 高亮
- [ ] `.add` 模式儲存：auto-derive name 寫入正確；budget 寫入資料庫
- [ ] `.edit` 模式儲存：原 name / period / startDate 保留；amount / categoryId 更新
- [ ] 全部使用者可見字串走 i18n（en / zh-Hant）
- [ ] 新增 reducer + Core helper 有對應 Swift Testing；`xcodebuild test -scheme FeaturesTests` 全綠
- [ ] 無 hardcoded `#000000` / `#FFFFFF`；色彩走 `Color.Design.*`
- [ ] Dark mode 對映正確
