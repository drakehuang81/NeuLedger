# Domain Category Localization — Design Spec

**Date:** 2026-05-15
**Branch:** `developer`

---

## 1. Goal

讓 NeuLedger 預設 seed 的 14 個分類在 zh-Hant 環境下顯示為「餐飲 / 交通 / …」而非 raw English seed name（"Food" / "Transport" / …）。

實作方式：在 `Domain.Category` 上加一個 `localizedName: String` computed property，根據 `isDefault` + 英文 seed 名比對來回傳 localized 字串；user-created 分類維持原 raw `name`。

不動 SwiftData schema、不做資料 migration、既有 DB 不需處理。

## 2. 範圍與非範圍

**範圍：**

- 新增 `Domain.Category.localizedName: String` computed property
- 新增 14 個 i18n keys（en + zh-Hant），key 前綴 `category_seed_*`
- 鏡像 keys 到 `Features/Sources/Domain/Resources/Localizable.xcstrings`（讓 DomainTests 能解析；同 `BudgetPeriod.localizedSuffix` 模式）
- 全 app 顯示分類名稱的 view 改用 `category.localizedName`
- `AnalysisFeature` 抽取分類字串時改用 `localizedName`
- `CategoryManagement` 編輯 default 分類：**顯示** 用 `localizedName`、**TextField 編輯** 用 raw `name`（避免 user 看不到實際儲存值）
- Swift Testing 覆蓋 `localizedName` 各路徑

**非範圍（YAGNI 標註）：**

- 新增 `localizationKey` 欄位到 `Domain.Category` / `SDCategory` — 需要 SwiftData migration，過度設計
- 重新編寫 seed 邏輯（依 locale 寫入對應語言）— 沒解決既有資料的問題
- 簡體中文 / 其他語系
- AccountType / TransactionType / BudgetPeriod 已是 localized（不在 scope）
- 全 app 字串國際化掃描 — 只處理 Category seed

## 3. 解法總覽

```swift
// Domain/Entities/Category.swift  — 加入 computed property
public extension Category {
    /// Returns a localized display name for default seed categories;
    /// user-created or renamed categories fall back to the raw `name`.
    var localizedName: String {
        guard isDefault, let key = Self.seedLocalizationKey(for: name) else {
            return name
        }
        return String(localized: String.LocalizationValue(key), bundle: .module)
    }

    /// English seed name → i18n key. Matches the SeedCategory entries
    /// in Core/Persistence/DatabaseClient.swift. Keep in sync if seeds change.
    private static func seedLocalizationKey(for englishName: String) -> String? {
        Self.seedLocalizationMap[englishName]
    }

    private static let seedLocalizationMap: [String: String] = [
        "Food": "category_seed_food",
        "Transport": "category_seed_transport",
        "Entertainment": "category_seed_entertainment",
        "Shopping": "category_seed_shopping",
        "Housing": "category_seed_housing",
        "Utilities": "category_seed_utilities",
        "Health": "category_seed_health",
        "Education": "category_seed_education",
        "Other Expense": "category_seed_other_expense",
        "Salary": "category_seed_salary",
        "Freelance": "category_seed_freelance",
        "Investment": "category_seed_investment",
        "Gift": "category_seed_gift",
        "Other Income": "category_seed_other_income",
    ]
}
```

行為：

| 情境 | `name` | `isDefault` | `localizedName` 回傳 |
|---|---|---|---|
| 預設 seed，未被 rename | `"Food"` | `true` | `"餐飲"`（zh-Hant）/ `"Food"`（en） |
| 預設 seed，user 改名為「我的吃喝」 | `"我的吃喝"` | `true` | `"我的吃喝"`（fallback） |
| user 自己新增的 | `"Coffee"` | `false` | `"Coffee"`（fallback） |
| Seed 表外的字串（理論不該發生） | `"Misc"` | `true` | `"Misc"`（fallback） |

## 4. View 變更點

依 grep 整理出實際 render `category.name` 的點（其他 `categoryName: String` 是 reducer 內部傳值，源頭抽取點改了就會跟著）：

| 檔案 | 行為 |
|---|---|
| `Features/Sources/Common/Components/BudgetCategoryListPicker.swift` | `Text(cat.name)` → `Text(cat.localizedName)` |
| `Features/Sources/Features/Transactions/Detail/AIInsightCard.swift`（categoryName fallback） | callers 已傳 `String?` — 改源頭抽取（見下） |
| `Features/Sources/Features/Transactions/Detail/TxHero.swift`（`categoryName` 參數） | callers 改源頭 |
| `Features/Sources/Features/Transactions/TransactionDetailFeature.swift`（`.task` 抽取 categoryName） | `c.first { $0.id == id }?.name` → `c.first { $0.id == id }?.localizedName` |
| `Features/Sources/Features/Dashboard/DashboardFeature.swift`（`categoryMap` 載入 + 使用） | `categoryMap[cat.id]` 是 `Domain.Category`；render 端 `category?.name` → `category?.localizedName` |
| `Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift` | 同上 |
| `Features/Sources/Features/Dashboard/AddTransactionView.swift`（categoryChip）| `CategoryChip(title: category.name, ...)` → `CategoryChip(title: category.localizedName, ...)` |
| `Features/Sources/Features/CategoryManagement/CategoryManagementView.swift` | **list row label** 用 `category.localizedName`；**TextField for editing** 用 raw `category.name` |
| `Features/Sources/Features/Analysis/AnalysisFeature.swift`（抽取 metric.categoryName / drilldown.categoryName 的源頭）| 抽取時若有 `Domain.Category` 在手，存 `localizedName`；若只有 raw string（從 SwiftData groupBy 來）則保留現況 — **見下 §5** |

### 4.1 Analysis 特殊處理

`AnalysisFeature` 把 `categoryName: String` 當作 metric / drilldown 的 stable identifier 傳遞（line 10: `public var id: String { categoryName }`）。若 raw stored name 與 localized name 不同，會破壞 identity（同一個 category 載入時 stored "Food"，顯示時 "餐飲"，雙語環境會混亂）。

**處理：** 把 `id` 與「顯示」分離。`metric.categoryName` 維持 raw stored name（作為 ID），加 `metric.localizedCategoryName: String` 用於顯示。View 顯示用後者。

不在這個 spec 大改 `AnalysisFeature` — 只在抽取點呼叫 `Domain.Category.localizedName` 寫入新的 display field。具體變更在 plan 階段細化。

## 5. Tests

DomainTests 新增 `CategoryLocalizedNameTests`：

| @Test case | 涵蓋 |
|---|---|
| `default seed matches → localized` | name="Food", isDefault=true → 「餐飲」/「Food」 |
| `default seed user-renamed → fallback raw` | name="My Food", isDefault=true → 「My Food」 |
| `user-created → fallback raw` | name="Coffee", isDefault=false → 「Coffee」 |
| `all 14 seeds map to non-empty localized values` | 14 個 seed name 各跑一輪，回傳非空、非原字串（zh-Hant locale 下）|

FeaturesTests 不動 — 既有 reducer / view 測試不依賴 category name 的 localization。

## 6. i18n keys（14 個）

| Key | en | zh-Hant |
|---|---|---|
| `category_seed_food` | Food | 餐飲 |
| `category_seed_transport` | Transport | 交通 |
| `category_seed_entertainment` | Entertainment | 娛樂 |
| `category_seed_shopping` | Shopping | 購物 |
| `category_seed_housing` | Housing | 居家 |
| `category_seed_utilities` | Utilities | 水電費 |
| `category_seed_health` | Health | 健康醫療 |
| `category_seed_education` | Education | 教育 |
| `category_seed_other_expense` | Other Expense | 其他支出 |
| `category_seed_salary` | Salary | 薪資 |
| `category_seed_freelance` | Freelance | 接案 |
| `category_seed_investment` | Investment | 投資 |
| `category_seed_gift` | Gift | 禮金 |
| `category_seed_other_income` | Other Income | 其他收入 |

新增至：
- `NeuLedger/Resources/Localizable.xcstrings`（app bundle）
- `Features/Sources/Domain/Resources/Localizable.xcstrings`（Domain SPM bundle，給 DomainTests 解析）

兩處保持同步 — 在 `Domain/Entities/Category.swift` 加 sync 警告 comment（同 `Decimal+Budget.swift` 模式）。

## 7. 風險與緩解

| 風險 | 緩解 |
|---|---|
| 未來 seed 改名（例如把 "Food" 改成 "Dining"）→ mapping 失效 | mapping table 集中在 Domain/Category.swift；改 seed 時順手改 mapping。加 comment 提醒「Keep in sync with DatabaseClient seeds」 |
| user rename 預設分類後，顯示變回 raw user 字串（不再 localize）| 設計如此 — user 主動命名應尊重 |
| `AnalysisFeature.categoryName` 同時被當 id 與 display 使用 | 拆出 `localizedCategoryName` 作為 display；id 仍用 raw stored name |
| dual-bundle xcstrings drift | 同 `Decimal+Budget.swift` 加 sync 警告 comment |
| 既有 user 已 rename 過 default 的，升 app 後不會被 localize | 設計如此 — `isDefault` 守不住所有情境，但 mapping 比對 raw name fail 時自然 fallback |

## 8. Slice 規劃（2 slice）

| Slice | 內容 | Commit prefix |
|---|---|---|
| 0 | Domain — `Category.localizedName` + 14 i18n keys（app + Domain bundle 雙寫）+ `CategoryLocalizedNameTests`（4 tests） | `feat(domain):` |
| 1 | View call-site sweep — 9 個檔案改 `category.name` → `category.localizedName`，含 `AnalysisFeature` 抽取 + `CategoryManagement` 顯示/編輯分離；smoke + sanity test sweep | `refactor(features):` |

## 9. 完成定義

- [ ] `Domain.Category.localizedName` 對 14 個 seed name + `isDefault=true` 回傳 zh-Hant 翻譯（en locale 回傳英文原字）
- [ ] User-rename 後的 default 與 user-created 分類 fallback 到 raw `name`
- [ ] 14 個 i18n keys 同時存在於 app + Domain xcstrings 兩處
- [ ] 9 個顯示點全部改用 `localizedName`（除 `CategoryManagement` 的 TextField 編輯場景 + `AnalysisFeature.id`）
- [ ] DomainTests `CategoryLocalizedNameTests` 4 個 case 全綠
- [ ] `xcodebuild test -scheme FeaturesTests` 270/270 維持綠（沒有 regression）
- [ ] `xcodebuild build -scheme NeuLedger` BUILD SUCCEEDED
- [ ] sync 警告 comment 已加在 `Domain/Entities/Category.swift`
