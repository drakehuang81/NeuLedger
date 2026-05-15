# Budget Form UI Redesign — Design Spec

**Date:** 2026-05-15
**Branch:** `developer`
**Design source:** `design/source/budget-form.jsx`（3 artboards：Add Default / Add Filled / Edit Error）
**Design screen:** `design/screens/15-Budget-Form.html`

---

## 1. Goal

把 `BudgetFormView` 從目前的「`Form` + 系統 inset-grouped sections」表單升級成設計稿規範的「自訂 mono UPPERCASE section header + Glass section card + 大字 amount + per-period 換算 + radio-style category picker」呈現。

**設計稿明確 anchor 在現有 `BudgetFormFeature` / `BudgetFormView` 結構：5 個 sections（Name / Amount / Period / StartDate / Category）全部保留，actions 不改。只是視覺重做。**

進入點不動：`BudgetManagementView` 的 `+`（`.add`）與 row tap（`.edit(budget)`），都繼續走 sheet 呈現。

## 2. 範圍與非範圍

**範圍：**

- 重寫 `BudgetFormView` 的 5 個 sections 視覺
- 新增 Common primitives：`FormSection`（mono header + Glass card + optional footer）、`BudgetCategoryListPicker`（radio list）
- 新增 Domain helper：`BudgetPeriod.suffix`（「週 / 月 / 年」）、`Decimal.perPeriodBreakdown(_:)`（換算文字 `≈ NT$X / 天 · 約 NT$Y / 週`）
- 補齊 i18n keys（en + zh-Hant）涵蓋 placeholder / period suffix / breakdown 字串
- Swift Testing 覆蓋 `perPeriodBreakdown` helper

**非範圍：**

- `BudgetFormFeature` reducer 邏輯變動 — State / Action shape 不動，僅 view 用法調整
- Domain `Budget` schema 任何變更
- AI 建議金額 chip / Quick amount chips — **不在本次設計稿**（之前誤讀的 `budget.jsx` 才有這些）
- WarmGradientBackground sheet — 設計稿背景是 `#ECE9E2` 系統淺灰，非暖橘漸層；保留 `.sheet` 但內部用 `Color.Design.background`，不套 WarmGradient
- 自訂 NavBar — 沿用 SwiftUI `NavigationStack` toolbar（功能等價，且設計稿明確標註「Toolbar: Cancel · Save」）
- BudgetMain / BudgetCategoryDetail 重設計

## 3. 進入點

不動：

1. **BudgetManagementView 的 `+` 按鈕** → `.add`
2. **BudgetManagementView 點某既有 budget** → `.edit(budget)`

呈現方式不動 — 透過上層 `.sheet(item:)` present `BudgetFormView`。內層仍是 `NavigationStack`，toolbar 維持 leading Cancel + trailing Save。

## 4. 主要元件分解

```
BudgetFormView
└── NavigationStack
    ├── toolbar
    │   ├── ToolbarItem(.cancellationAction) — 取消
    │   └── ToolbarItem(.confirmationAction)  — 儲存（accent semibold；disabled = invalid）
    ├── navigationTitle: "新增預算" / "編輯預算"
    └── ScrollView
        ├── FormSection(header: "名稱")
        │   └── NameField                    ── TextField + nameError
        ├── FormSection(header: "預算金額")
        │   └── AmountField                   ── NT$ prefix + 32pt mono TextField + " / <週期>" suffix + breakdown helper
        ├── FormSection(header: "週期")
        │   └── PeriodSegmented               ── Picker(.segmented) for BudgetPeriod.allCases
        ├── FormSection(header: "起始日")
        │   └── StartDatePill                 ── DatePicker(.compact)
        └── FormSection(header: "套用分類", footer: "選擇分類後…")     // only when availableCategories non-empty
            └── BudgetCategoryListPicker      ── radio list, 「全部支出」首項 + N expense categories
```

## 5. 視覺規格

### FormSection 容器

| 元素 | 規格 |
|---|---|
| Section spacing（外） | 22pt 垂直間距 |
| Section header | `Text(headerKey)` font system 11pt monospaced UPPERCASE tracking 1.2 textSecondary；padding `.horizontal 6 .bottom 8` |
| Section content card | `glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))`；內容 padding 由各 field 自管 |
| Section footer | `Text(footerKey)` 12pt textSecondary line-spacing 1.45；padding `.top 8 .horizontal 6` |
| Container 對外 padding | horizontal 16pt，top 20pt，bottom 100pt（避免 keyboard 遮擋） |

### NameField

| 元素 | 規格 |
|---|---|
| 容器 padding | 12pt × 16pt |
| TextField placeholder | `budget_form_name_placeholder` → en `e.g. Food, Transport…` / zh-Hant `例:餐飲、交通…` |
| Font | 17pt body |
| 文字 color | filled = textPrimary；placeholder 由 SwiftUI 自動 textSecondary |
| Error | `ErrorText` 元件（紅 alert icon 12pt + 12.5pt expenseRed 文字）|

### AmountField（核心升級）

| 元素 | 規格 |
|---|---|
| 容器 padding | 14pt × 16pt |
| 列布局 | HStack(alignment: `.lastTextBaseline`, spacing: 8)：`Text("NT$")` 15pt mono medium textSecondary → `TextField`（32pt mono medium tabularDigit textPrimary，輸入時 caret 系統樣式）→ `Text(" / \(period.suffix)")` 14pt textSecondary |
| TextField keyboardType | `.numberPad` |
| Breakdown helper | `perPeriodBreakdown(amount, period)` 不為 nil 且無 error 時，VStack 在 baseline 下方加一行 12pt mono textSecondary：例 `≈ NT$ 267 / 天 · 約 NT$ 1,848 / 週` |
| Error | 同 NameField，error 顯示時 breakdown 不顯示 |

### PeriodSegmented

沿用 SwiftUI `Picker(.segmented)` for `BudgetPeriod.allCases`。

| 元素 | 規格 |
|---|---|
| 容器 padding | 12pt × 16pt |
| Picker style | `.segmented` |
| Tag 文字 | 既有 `BudgetPeriod.localizedName` |

### StartDatePill

| 元素 | 規格 |
|---|---|
| 容器 padding | 14pt × 16pt |
| 布局 | HStack：`Text("起始日") + Spacer() + DatePicker("", selection:, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)` |
| 沒有 label（label 由 HStack 左側手動 render） | DatePicker `.labelsHidden()` |

### BudgetCategoryListPicker

新元件，**radio-style list**，**不是** Picker / Grid。

| 元素 | 規格 |
|---|---|
| 每列 padding | 12pt × 16pt |
| 列布局 | HStack(spacing: 12)：色塊 32pt 圓 + 名稱 + Spacer + 已選 checkmark |
| 色塊 | `Circle().fill(color.opacity(0.12))` 內含 emoji（24pt 字級，category 標的）或「∗」（display font，accent 色，作為「全部支出」標識）|
| 名稱字級 | 15.5pt textPrimary |
| Checkmark | `Image(systemName: "checkmark")` 18pt semibold `accentOrange`，只在 active 顯示 |
| 列間分隔 | `Divider().padding(.leading, 60)`（縮排避開左側色塊） |
| 第一列固定為「全部支出」 | item id == nil，emoji 「∗」，color = `accentOrange` |
| 後續列 | 由 `availableCategories` 提供，順序維持原 sortOrder |

當 `availableCategories.isEmpty`：整個 FormSection 不渲染（沿用既有 `BudgetFormView` 邏輯）。

### ErrorText（新 Common primitive）

```swift
HStack(alignment: .firstTextBaseline, spacing: 6) {
    Image(systemName: "exclamationmark.circle")
        .font(.system(size: 12))
        .foregroundStyle(Color.Design.expenseRed)
    Text(messageKey)
        .font(.system(size: 12.5))
        .lineSpacing(1.4)
        .foregroundStyle(Color.Design.expenseRed)
}
.padding(.top, 6)
```

### 整體 sheet 背景

`Color.Design.background`（不套 WarmGradient — 設計稿是淺灰底）。`ScrollView.scrollContentBackground(.hidden)` 與 `Form` 系統樣式無關（不再用 Form）。

## 6. Data flow

State / Action 無變動。沿用既有 `BudgetFormFeature`：

- `nameChanged(String)` — 已有
- `amountChanged(String)` — 已有
- `periodChanged(BudgetPeriod)` — 已有
- `startDateChanged(Date)` — 已有
- `categoryChanged(Domain.Category.ID?)` — 已有
- `saveTapped` / `cancelTapped` / `savedSuccessfully` — 已有

僅 **View 端** 處理 amount text 的格式化顯示：

```swift
// AmountField breakdown 仰賴 Decimal 解析
let amountValue = Decimal(string: store.amountText) ?? 0
let breakdown = amountValue.perPeriodBreakdown(store.period)   // String?
```

`Decimal.perPeriodBreakdown(_:)`：

```swift
extension Decimal {
    func perPeriodBreakdown(_ period: BudgetPeriod) -> String? {
        guard self > 0 else { return nil }
        switch period {
        case .weekly:
            let perDay = (self / 7).rounded()
            return String(format: String(localized: "budget_form_breakdown_weekly", bundle: .main), perDay.toIntString())
        case .monthly:
            let perDay  = (self / 30).rounded()
            let perWeek = (self / Decimal(string: "4.33")!).rounded()
            return String(format: String(localized: "budget_form_breakdown_monthly", bundle: .main), perDay.toIntString(), perWeek.toIntString())
        case .yearly:
            let perMonth = (self / 12).rounded()
            return String(format: String(localized: "budget_form_breakdown_yearly", bundle: .main), perMonth.toIntString())
        }
    }
}
```

（helper rounding 用 `NSDecimalRound` banker's mode，輸出整數字串。）

`BudgetPeriod.suffix`：

```swift
public extension BudgetPeriod {
    var suffix: LocalizedStringKey {
        switch self {
        case .weekly:  return "budget_period_suffix_weekly"   // 週
        case .monthly: return "budget_period_suffix_monthly"  // 月
        case .yearly:  return "budget_period_suffix_yearly"   // 年
        }
    }
}
```

## 7. Localization

新增 keys（en / zh-Hant）：

| Key | en | zh-Hant |
|---|---|---|
| `budget_form_breakdown_weekly` | `≈ NT$%@ / day` | `≈ NT$%@ / 天` |
| `budget_form_breakdown_monthly` | `≈ NT$%@ / day · about NT$%@ / week` | `≈ NT$%@ / 天 · 約 NT$%@ / 週` |
| `budget_form_breakdown_yearly` | `≈ NT$%@ / month` | `≈ NT$%@ / 月` |
| `budget_period_suffix_weekly` | `week` | `週` |
| `budget_period_suffix_monthly` | `month` | `月` |
| `budget_period_suffix_yearly` | `year` | `年` |

既有 keys 沿用：`budget_form_add_title` / `budget_form_edit_title` / `budget_form_name_placeholder` / `budget_form_amount` / `budget_form_period` / `budget_form_start_date` / `budget_form_apply_category` / `budget_form_all_expenses` / `budget_form_all_expenses_hint` / `error_budget_name_empty` / `error_amount_must_be_positive` / `common_cancel` / `common_save`。

確認 `common_name` 已存在（既有 NameField section header `common_name`）。

## 8. 錯誤處理

- `nameError` / `amountError`：inline 紅字（`ErrorText` primitive）顯示在對應 field 下方
- `categoryId` validation：當前無 validation rule（可選欄位，nil 代表「全部支出」）
- save 失敗（`budgetClient.add/update` throws）：沿用既有 reducer 處理路徑 — 不在本次設計稿 scope

## 9. Testing

| Suite | 涵蓋 |
|---|---|
| 新增 `BudgetPeriodSuffixTests`（DomainTests）| `.weekly.suffix` / `.monthly.suffix` / `.yearly.suffix` 各回傳對應 key（用 `LocalizedStringKey` 比較或字串解析）|
| 新增 `DecimalPerPeriodBreakdownTests`（DomainTests）| 邊界 0 / 負值 / 正值；各 period 計算結果；rounding 對齊（30 / 4.33 / 7 / 12）|
| 既有 `BudgetFormFeatureTests` | 不需動 — actions/state 沒變。可加一個 smoke test 確認 `availableCategories.isEmpty` 時 category section 不存在的 reducer-side 邏輯仍正確（既有 categoryClient stub） |

## 10. 切片計畫（4 slice）

| Slice | 內容 | Commit prefix |
|---|---|---|
| 0 | Common primitives — `FormSection`、`ErrorText`、`BudgetCategoryListPicker` + i18n keys batch | `feat(common):` |
| 1 | Domain helpers — `BudgetPeriod.suffix` + `Decimal.perPeriodBreakdown(_:)` + tests | `feat(domain):` |
| 2 | View 重寫 — `BudgetFormView` 拆解 5 sections，整合 NameField / AmountField / PeriodSegmented / StartDatePill / BudgetCategoryListPicker | `feat(budget-form):` |
| 3 | Polish — accessibility identifiers、舊 `Form { Section { } }` 結構徹底移除、edit-mode 預填驗證、視覺微調 | `chore(budget-form):` |

## 11. 風險與緩解

| 風險 | 緩解 |
|---|---|
| `Picker(.segmented)` 在 iOS 26 Liquid Glass 下視覺與設計稿不完全一致 | 接受系統樣式；若需完全對齊，未來再做自訂 segmented |
| `DatePicker(.compact)` 顯示樣式無法完全 customize 至 pill 風格 | 接受系統樣式；右側對齊 + labelsHidden 已是最接近寫法 |
| Decimal rounding 在大金額時可能誤差（特別是 monthly `÷ 4.33`） | `NSDecimalRound` rule .plain，精度 0；測試覆蓋大金額（999999） |
| Category list 過長時影響可滾動性 | 整個 BudgetFormView 在外層 ScrollView 內，自動繼承滾動 |
| `availableCategories` 預設可能尚未載入即顯示空 list | 沿用既有 `.task` load 流程；section 因 `isEmpty` 不渲染 |

## 12. 完成定義

- [ ] BudgetManagementView 的 `+` 與 row tap 兩個進入點都正常開啟新版 form
- [ ] 5 個 sections 順序：名稱 → 預算金額 → 週期 → 起始日 → 套用分類
- [ ] Section header 為 uppercase mono 11pt textSecondary
- [ ] Section 內容包在 Glass card（14pt radius）
- [ ] AmountField 顯示 NT$ prefix + 32pt mono 大字 + ` / 月（週/年）` suffix
- [ ] Amount > 0 時顯示對應 period 的 breakdown helper 字串（en + zh-Hant 正確）
- [ ] amountError 顯示時 breakdown 隱藏
- [ ] PeriodSegmented 切換 → AmountField suffix + breakdown 跟著更新
- [ ] StartDatePill 用 `.compact` 樣式右對齊
- [ ] CategoryListPicker 首列固定為「全部支出 ∗」；後續為 availableCategories
- [ ] 點某分類 → active checkmark 顯示；點「全部支出」→ categoryId = nil
- [ ] `.add` 模式儲存：寫入 budget + delegate(.saved)；form 關閉
- [ ] `.edit` 模式儲存：原 budget 更新；form 關閉
- [ ] nameError / amountError 透過 `ErrorText` primitive 顯示
- [ ] 全部使用者可見字串走 i18n（en / zh-Hant 兩語）
- [ ] 新增的 Domain helpers 有對應 Swift Testing；`xcodebuild test -scheme FeaturesTests / DomainTests` 全綠
- [ ] 無 hardcoded `#000000` / `#FFFFFF`；色彩走 `Color.Design.*`
- [ ] Dark mode 對映正確
