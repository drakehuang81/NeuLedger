## ADDED Requirements

### Requirement: 交易詳情顯示
The system SHALL provide a `TransactionDetailView` presented as a sheet, showing the complete information of a single transaction.

#### Scenario: 查看交易詳情
- **WHEN** `TransactionDetailView` 以特定 `Transaction` 呈現
- **THEN** 畫面顯示以下欄位：
    - 交易類型 badge（支出 / 收入 / 轉帳）
    - 金額（大字體、DM Mono、支出紅色、收入綠色）
    - 帳戶名稱（支出/收入）或來源帳戶 → 目標帳戶（轉帳）
    - 分類名稱與圖示（轉帳不顯示）
    - 備註（若有）
    - 日期與時間
    - 標籤列表（TagPill，若有）
- **AND** 畫面右上角顯示「編輯」按鈕，左上角顯示「關閉」按鈕

### Requirement: 從詳情頁編輯交易
The system SHALL allow users to navigate from the detail view to an edit form pre-filled with the transaction's current data.

#### Scenario: 點擊編輯按鈕
- **WHEN** 使用者在 `TransactionDetailView` 點擊「編輯」
- **THEN** 以 sheet 方式呈現 `AddTransactionFeature`，以 `.edit(transaction)` 模式初始化
- **AND** 所有欄位預填現有交易資料

#### Scenario: 編輯完成後同步詳情頁
- **WHEN** 使用者在編輯 Sheet 中儲存變更
- **THEN** 編輯 Sheet 關閉，`TransactionDetailView` 的資料更新為最新值
- **AND** 交易列表同步反映變更

### Requirement: 從詳情頁刪除交易
The system SHALL allow users to permanently delete a transaction from the detail view.

#### Scenario: 點擊刪除按鈕
- **WHEN** 使用者在 `TransactionDetailView` 點擊「刪除」（破壞性操作，以紅色顯示）
- **THEN** 顯示 `.confirmationDialog` 詢問確認

#### Scenario: 確認刪除
- **WHEN** 使用者在確認對話框中確認刪除
- **THEN** 呼叫 `transactionClient.delete(_:)` 永久刪除該交易
- **AND** `TransactionDetailView` 關閉
- **AND** 交易列表移除該筆交易
