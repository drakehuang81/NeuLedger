# Spec: NeuLedger App Features & Business Logic

## Requirements

---

### Requirement: Currency
- **GIVEN** the first version of the app
- **THEN** only **TWD (New Taiwan Dollar)** is supported.
- **AND** all amounts are displayed with the "NT$" prefix and **zero decimal places** (整數).
- **AND** the `Currency` enum is kept in code for future extensibility but only `.TWD` is active.

---

### Requirement: Core User Stories

#### Feature: 記帳（Record Transaction）

##### Scenario: 快速新增支出
- **GIVEN** 使用者在 Dashboard 或 Transactions tab
- **WHEN** 點擊「支出」快速操作
- **THEN** 開啟新增交易 Sheet（類型預設為 `.expense`）
- **AND** 金額欄位為必填，預設為空
- **AND** 帳戶預設為使用者設定的預設帳戶
- **AND** 日期預設為今天
- **AND** 分類預設為空（需選擇或由 AI 建議）

##### Scenario: 快速新增收入
- **GIVEN** 使用者在 Dashboard 或 Transactions tab
- **WHEN** 點擊「收入」快速操作
- **THEN** 開啟新增交易 Sheet（類型預設為 `.income`）
- **AND** 分類選擇器僅顯示收入類型的分類

##### Scenario: 帳戶間轉帳
- **GIVEN** 使用者在 Dashboard
- **WHEN** 點擊「轉帳」快速操作
- **THEN** 開啟轉帳 Sheet
- **AND** 必須選擇來源帳戶和目標帳戶（不得相同）
- **AND** 轉帳不需要選擇分類
- **AND** 儲存後：來源帳戶餘額減少、目標帳戶餘額增加

##### Scenario: AI 輔助記帳
- **GIVEN** AI 功能可用且使用者已啟用自動分類
- **WHEN** 使用者在備註欄輸入文字（e.g., "午餐 麥當勞 200"）
- **THEN** AI 將自動建議：
    1. **金額**：從文字中提取（若偵測到）→ 自動填入金額欄
    2. **分類**：建議最可能的分類 → 在分類選擇器中高亮顯示
- **AND** 使用者可以接受或覆蓋 AI 建議
- **AND** 若 AI 不可用，備註欄正常運作（無 sparkle 圖示）

#### Feature: 交易管理（Transaction Management）

##### Scenario: 查看交易列表
- **GIVEN** 使用者在 Transactions tab
- **THEN** 顯示所有交易，按日期降序排列（最新在上）
- **AND** 以日期分組顯示（"Today", "Yesterday", "2026/2/10" 等）
- **AND** 每筆交易顯示：分類圖示、備註、金額（支出紅色、收入綠色）、日期

##### Scenario: 搜尋交易
- **WHEN** 使用者在搜尋列輸入文字
- **THEN** 即時篩選備註 (note) 包含該文字的交易（不區分大小寫）

##### Scenario: 篩選交易
- **WHEN** 使用者選擇篩選條件
- **THEN** 支援以下篩選（可組合）：
    - 分類（單選或多選）
    - 帳戶（單選或多選）
    - 日期區間（起始 ↔ 結束）
    - 標籤（單選或多選）
    - 類型（支出 / 收入 / 轉帳）

##### Scenario: 編輯交易
- **WHEN** 使用者點擊交易進入詳情頁後點擊「編輯」
- **THEN** 開啟新增交易 Sheet（預填現有資料）
- **AND** 儲存後更新交易並重新計算相關帳戶餘額
- **AND** `updatedAt` 自動更新

##### Scenario: 刪除交易
- **WHEN** 使用者在列表中左滑交易或在詳情頁點擊「刪除」
- **THEN** 顯示確認對話框（`.confirmationDialog`）
- **AND** 確認後永久刪除該交易
- **AND** 相關帳戶餘額自動重新計算

#### Feature: 帳戶管理（Account Management）

##### Scenario: 預設帳戶
- **WHEN** 使用者首次使用 App（Onboarding）
- **THEN** 建立一個預設帳戶：
    - 名稱：「現金」
    - 類型：`.cash`
    - 圖示：`banknote`
- **AND** 此帳戶設為預設帳戶

##### Scenario: 新增帳戶
- **WHEN** 使用者在設定 → 帳戶 → 新增
- **THEN** 必填：名稱、類型
- **AND** 可選：圖示（從 SF Symbol 清單選擇）、顏色
- **AND** 帳戶名稱不得重複

##### Scenario: 封存帳戶
- **WHEN** 使用者封存一個帳戶
- **THEN** 該帳戶從新增交易的帳戶選擇器中隱藏
- **AND** 歷史交易仍可查看
- **AND** 帳戶餘額仍在 Dashboard 中可見（標記為已封存）

##### Scenario: 不可刪除帳戶
- **GIVEN** 帳戶有關聯的交易記錄
- **WHEN** 使用者嘗試刪除
- **THEN** 只能封存，不能永久刪除（保護資料完整性）

#### Feature: 分類管理（Category Management）

##### Scenario: 預設分類清單
- **WHEN** App 首次啟動
- **THEN** 自動建立以下預設分類：

**支出分類：**

| 名稱 | SF Symbol | 備註 |
|------|-----------|------|
| 飲食 | `fork.knife` | 餐飲、飲料、零食 |
| 交通 | `car.fill` | 捷運、公車、計程車、油錢 |
| 娛樂 | `gamecontroller.fill` | 電影、遊戲、訂閱 |
| 購物 | `bag.fill` | 服飾、3C、日用品 |
| 居住 | `house.fill` | 房租、房貸、管理費 |
| 生活繳費 | `bolt.fill` | 水電瓦斯、電信、網路 |
| 醫療 | `cross.case.fill` | 看診、藥品、保險 |
| 教育 | `book.fill` | 課程、書籍、學費 |
| 社交 | `person.2.fill` | 聚餐、送禮、紅包 |
| 其他支出 | `ellipsis.circle.fill` | 未分類支出 |

**收入分類：**

| 名稱 | SF Symbol | 備註 |
|------|-----------|------|
| 薪資 | `briefcase.fill` | 定期薪水 |
| 獎金 | `star.fill` | 年終、績效獎金 |
| 副業 | `laptopcomputer` | 接案、兼差 |
| 投資 | `chart.line.uptrend.xyaxis` | 股票、基金收益 |
| 收禮 | `gift.fill` | 紅包、禮金 |
| 其他收入 | `ellipsis.circle.fill` | 未分類收入 |

- **AND** 預設分類的 `isDefault = true`，不可刪除但可編輯名稱/圖示/顏色
- **AND** 使用者可新增自訂分類

##### Scenario: 分類排序
- **WHEN** 使用者在分類管理中拖動分類
- **THEN** 更新 `sortOrder`，影響分類選擇器的顯示順序

#### Feature: 標籤管理（Tag Management）

##### Scenario: 建立與使用標籤
- **WHEN** 使用者在新增交易時輸入標籤
- **THEN** 自動完成現有標籤
- **AND** 若輸入的標籤不存在，自動建立新標籤
- **AND** 每筆交易可有 0 個或多個標籤

##### Scenario: 管理標籤
- **WHEN** 使用者在設定 → 標籤
- **THEN** 可以查看所有標籤、編輯名稱/顏色、刪除標籤
- **AND** 刪除標籤時，從所有交易中移除該標籤（不影響交易本身）

#### Feature: 預算管理（Budget Management）

##### Scenario: 建立預算
- **WHEN** 使用者在設定 → 預算 → 新增
- **THEN** 設定：
    - 名稱（必填）
    - 金額上限（必填）
    - 週期：每週 / 每月 / 每年
    - 分類（可選）：不指定 = 總支出預算；指定 = 該分類預算
- **AND** 預算在指定週期結束後自動重置（重新開始計算）

##### Scenario: 預算進度顯示
- **WHEN** 使用者在 Analysis 頁查看預算
- **THEN** 顯示：已花費 / 預算金額、百分比進度條
- **AND** 進度條顏色規則：
    - < 80%：系統綠色
    - 80% ~ 100%：`warningAmber`
    - > 100%：`expenseRed`

##### Scenario: 預算停用
- **WHEN** 使用者停用一個預算
- **THEN** 預算不再出現在 Analysis 頁
- **AND** 可以在設定中重新啟用

---

### Requirement: 資料分析（Analysis）

#### Scenario: 期間選擇
- **WHEN** 使用者在 Analysis tab 選擇期間
- **THEN** 支援：本週 / 本月 / 今年 / 自訂日期範圍
- **AND** 預設為「本月」

#### Scenario: 支出摘要
- **WHEN** 顯示摘要卡片
- **THEN** 計算選定期間內的：
    - 總收入 (所有 `.income` 交易的金額總和)
    - 總支出 (所有 `.expense` 交易的金額總和)
    - 淨額 (總收入 - 總支出)
- **AND** 轉帳不計入收入/支出

#### Scenario: 圓餅圖（支出分類佔比）
- **WHEN** 顯示圓餅圖
- **THEN** 按分類分組計算支出金額
- **AND** 點擊某一塊可查看該分類的交易明細

#### Scenario: 長條圖（每日/每週趨勢）
- **WHEN** 顯示長條圖
- **THEN** 按日（本週/本月）或按週（今年）顯示支出金額
- **AND** 使用 Swift Charts

#### Scenario: AI 支出洞察
- **GIVEN** AI 功能可用且使用者已啟用 AI 洞察
- **WHEN** 使用者在 Analysis tab
- **THEN** 顯示 AI 生成的自然語言摘要，例如：
    - "本月飲食支出 NT$8,500，較上月增加 15%。"
    - "本週交通支出較平均值低 30%，做得好！"
- **AND** 洞察使用 `LanguageModelSession` + `QueryTransactionsTool` 生成
- **AND** 可被使用者關閉/dismiss

---

### Requirement: Onboarding 流程

#### Scenario: 首次啟動
- **WHEN** App 首次啟動（無任何資料）
- **THEN** 顯示 3 步驟 Onboarding：
    1. **歡迎頁**：App 名稱 + 價值主張（"AI 智慧記帳"）
    2. **帳戶設定**：建立第一個帳戶（預填名稱「現金」、類型 `.cash`）
    3. **完成頁**：「開始使用」按鈕
- **AND** 完成後 seed 預設分類
- **AND** 設定 flag（`hasCompletedOnboarding`）避免再次顯示

#### Scenario: 跳過 Onboarding
- **WHEN** 使用者在任何步驟點擊「跳過」
- **THEN** 用預設值建立帳戶和分類
- **AND** 直接進入 Dashboard

---

### Requirement: 資料匯出（Data Export）

#### Scenario: 匯出為 CSV
- **WHEN** 使用者在設定 → 資料 → 匯出 CSV
- **THEN** 匯出所有交易為 CSV 檔案
- **AND** 欄位順序：日期, 類型, 分類, 備註, 金額, 帳戶, 標籤
- **AND** 日期格式：`yyyy/MM/dd`
- **AND** 金額：支出為負數、收入為正數
- **AND** 標籤以逗號分隔
- **AND** 使用系統 Share Sheet 分享檔案

#### Scenario: 匯出為 JSON
- **WHEN** 使用者在設定 → 資料 → 匯出 JSON
- **THEN** 匯出所有交易為 JSON 檔案
- **AND** 包含完整資料結構（ID、所有欄位、關聯 ID）
- **AND** 使用系統 Share Sheet 分享檔案

---

### Requirement: 驗證規則（Validation Rules）

#### Scenario: 新增交易驗證
- **WHEN** 使用者嘗試儲存交易
- **THEN** 以下欄位為必填：
    - `amount`：必須 > 0
    - `accountId`：必須選擇帳戶
    - `categoryId`：必須選擇分類（轉帳除外）
    - `date`：必須有值（預設今天）
- **AND** 若驗證失敗，在相關欄位顯示提示（不使用 alert，用 inline 錯誤提示）

#### Scenario: 帳戶驗證
- **WHEN** 使用者新增帳戶
- **THEN** 名稱不得為空、不得與現有帳戶重複

#### Scenario: 預算驗證
- **WHEN** 使用者新增預算
- **THEN** 金額必須 > 0
- **AND** 名稱不得為空

---

### Requirement: 設定偏好（Preferences）

#### Scenario: 可設定項目
- **WHEN** 使用者前往設定
- **THEN** 提供以下偏好設定：
    - **預設帳戶**：新增交易時的預設帳戶（Picker）
    - **語言**：zh-Hant / en（Picker — 影響 AI 輸出語言）
    - **AI 自動分類**：開/關（Toggle）
    - **AI 支出洞察**：開/關（Toggle）

#### Scenario: 偏好儲存
- **WHEN** 使用者更改偏好
- **THEN** 立即持久化（使用 `@AppStorage` 或 SwiftData）
- **AND** 下次 App 啟動時保持不變
