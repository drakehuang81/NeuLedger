## ADDED Requirements

### Requirement: 交易記錄列表顯示
Transactions tab SHALL display all transactions grouped by date in descending order (newest first). Business logic (filtering, sorting) is defined in `feature-transactions.md`.

#### Scenario: 顯示交易列表
- **WHEN** 使用者切換至 Transactions tab
- **THEN** 畫面顯示所有交易，按日期分組
- **AND** 每個日期組別顯示標題（"今天"、"昨天"、"2026/2/10" 等格式）
- **AND** 每筆交易 row 顯示：分類圖示（SF Symbol）、備註（note）、金額（支出紅色 `expenseRed`、收入綠色 `incomeGreen`、轉帳為 `secondary`）、時間

#### Scenario: 無交易時顯示空白狀態
- **WHEN** 使用者在 Transactions tab 且目前無任何交易記錄（或搜尋/篩選結果為空）
- **THEN** 畫面顯示 `EmptyStateView`
- **AND** 空白狀態提示使用者可從 Dashboard 或右上角按鈕新增交易

### Requirement: 即時搜尋
Transactions tab SHALL provide a SearchBar that filters transactions by note text in real time.

#### Scenario: 開啟搜尋列
- **WHEN** 使用者點擊搜尋圖示或下拉列表觸發 SearchBar
- **THEN** SearchBar 出現並取得鍵盤焦點
- **AND** 交易列表切換為搜尋結果模式

#### Scenario: 輸入搜尋文字
- **WHEN** 使用者在 SearchBar 輸入文字
- **THEN** 列表即時（debounce 0.3 秒後）更新，只顯示 note 包含該文字的交易（不區分大小寫）
- **AND** 搜尋結果不分日期組別，改為平面列表顯示

#### Scenario: 清除搜尋
- **WHEN** 使用者清空 SearchBar 或點擊「取消」
- **THEN** SearchBar 收起，列表恢復完整交易（含已套用的篩選條件）

### Requirement: 多條件篩選 Sheet
Transactions tab SHALL provide a filter sheet allowing users to combine multiple filter criteria.

#### Scenario: 開啟篩選 Sheet
- **WHEN** 使用者點擊篩選按鈕（funnel 圖示）
- **THEN** 從底部滑出篩選 Sheet
- **AND** Sheet 顯示目前已選取的篩選狀態

#### Scenario: 設定篩選條件
- **WHEN** 使用者在篩選 Sheet 中選取條件
- **THEN** 支援以下多選篩選（各可獨立組合）：
    - 類型：支出 / 收入 / 轉帳（`TransactionType`）
    - 分類：顯示所有分類供多選
    - 帳戶：顯示所有帳戶供多選
    - 標籤：顯示所有標籤供多選
    - 日期區間：起始日與結束日（DatePicker）

#### Scenario: 套用篩選
- **WHEN** 使用者點擊「套用」
- **THEN** 篩選 Sheet 關閉，列表立即更新為符合條件的交易
- **AND** 篩選按鈕顯示 badge 標示目前有啟用的篩選條件

#### Scenario: 清除所有篩選
- **WHEN** 使用者點擊「清除全部」
- **THEN** 所有篩選條件重置為未選取
- **AND** 列表恢復顯示所有交易（僅保留搜尋文字若有）

### Requirement: 左滑刪除交易
Transactions tab SHALL allow users to delete a transaction by swiping left on a row.

#### Scenario: 左滑顯示刪除按鈕
- **WHEN** 使用者在交易 row 向左滑動
- **THEN** 顯示紅色「刪除」按鈕

#### Scenario: 確認刪除
- **WHEN** 使用者點擊刪除按鈕
- **THEN** 顯示 `.confirmationDialog` 詢問確認
- **AND** 使用者確認後永久刪除該交易並從列表移除

### Requirement: 點擊交易進入詳情
Transactions tab SHALL navigate to transaction detail when a row is tapped.

#### Scenario: 點擊交易 row
- **WHEN** 使用者點擊交易 row
- **THEN** 以 sheet 方式呈現 `TransactionDetailView`（詳見 `transaction-detail` spec）

### Requirement: AddTransactionFeature 新增與編輯模式
`AddTransactionFeature` SHALL support both create and edit modes via a `Mode` enum, providing a single reusable form.

#### Scenario: 新增模式（create）
- **WHEN** `AddTransactionFeature.State` 以 `.add(TransactionType)` 初始化
- **THEN** 表單欄位預設為空（金額為空、帳戶為預設帳戶、分類未選、備註空白、日期為今天）
- **AND** 儲存時呼叫 `transactionClient.add(_:)`

#### Scenario: 編輯模式（edit）
- **WHEN** `AddTransactionFeature.State` 以 `.edit(Transaction)` 初始化
- **THEN** 表單欄位預填該交易的現有資料
- **AND** 儲存時呼叫 `transactionClient.update(_:)` 並更新 `updatedAt`

#### Scenario: 表單欄位
- **WHEN** 使用者在新增/編輯 Sheet 中填寫資料
- **THEN** 以下欄位 SHALL 可供輸入：
    - 交易類型選擇器（支出 / 收入 / 轉帳）— 類型切換時分類清單同步更新
    - 金額（數字鍵盤，NT$ prefix，整數）
    - 帳戶選擇器（`.expense`/`.income` 單選；`.transfer` 選來源與目標帳戶，且兩者不得相同）
    - 分類選擇器（僅顯示符合當前類型的分類；`.transfer` 不顯示）
    - 備註文字欄位（選填）
    - 日期選擇器（DatePicker）

#### Scenario: 表單驗證
- **WHEN** 使用者嘗試儲存
- **THEN** 若驗證失敗，在相關欄位下方顯示 inline 錯誤提示（不使用 Alert）
- **AND** 驗證規則：金額必須 > 0、帳戶必須選擇、非轉帳類型必須選擇分類
