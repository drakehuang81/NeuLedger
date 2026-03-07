## 1. AddTransactionFeature — 完整實作（新增 & 編輯模式）

- [ ] 1.1 在 `AddTransactionFeature.State` 中定義 `enum Mode { case add(TransactionType); case edit(Transaction) }`，並以 mode 初始化所有表單欄位預設值
- [ ] 1.2 在 `AddTransactionFeature.State` 中加入完整表單欄位：`type`、`amount`（String 供輸入）、`accountId`、`toAccountId`（轉帳）、`categoryId`、`note`、`date`、`validationErrors`
- [ ] 1.3 在 `AddTransactionFeature` 載入時（`.task`）從 `accountClient.fetchActive()` 與 `categoryClient.fetchAll()` 取得選項並存入 state
- [ ] 1.4 實作表單驗證 action（`saveTapped`）：金額 > 0、accountId 必選、非轉帳需選分類；驗證失敗時更新 `validationErrors` 顯示 inline 錯誤
- [ ] 1.5 實作儲存邏輯：新增模式呼叫 `transactionClient.add(_:)`，編輯模式呼叫 `transactionClient.update(_:)` 並更新 `updatedAt`；成功後送出 `delegate(.saved)`
- [ ] 1.6 實作 `AddTransactionView`：金額輸入欄（數字鍵盤、NT$ prefix）、類型 Picker（切換時清除分類選擇）、帳戶 Picker、分類選擇器（依類型篩選、轉帳隱藏）、備註 TextField、DatePicker、inline 驗證錯誤提示

## 2. FilterFeature — 篩選 Sheet

- [ ] 2.1 建立 `FilterFeature` Reducer：State 持有 `selectedTypes: Set<TransactionType>`、`selectedCategoryIds`、`selectedAccountIds`、`selectedTagIds`、`dateRange: ClosedRange<Date>?`，以及載入用的 `categories`、`accounts`、`tags` 陣列
- [ ] 2.2 在 `FilterFeature.task` 中平行載入 `categoryClient.fetchAll()`、`accountClient.fetchAll()`、`tagClient.fetchAll()`
- [ ] 2.3 實作 `applyTapped` action：將目前選取狀態組合為 `TransactionFilter` 並透過 `delegate(.filterApplied(TransactionFilter))` 回傳
- [ ] 2.4 實作 `clearAllTapped` action：重置所有選取狀態為空
- [ ] 2.5 建立 `FilterView`：類型多選 chips、分類多選列表、帳戶多選列表、標籤多選列表、起始/結束日期 DatePicker、「清除全部」與「套用」按鈕

## 3. TransactionsFeature — 列表主邏輯

- [ ] 3.1 建立 `TransactionsFeature` Reducer：State 持有 `transactions: [Transaction]`、`searchText: String`、`activeFilter: TransactionFilter`、`isLoading: Bool`、`@Presents var detail: TransactionDetailFeature.State?`、`@Presents var filter: FilterFeature.State?`、`@Presents var addTransaction: AddTransactionFeature.State?`
- [ ] 3.2 實作 `.task` action：呼叫 `transactionClient.fetchAll()` 並存入 state
- [ ] 3.3 實作 `searchTextChanged(_:)` action：以 `.debounce(id: CancelID.search, for: 0.3)` 觸發 `transactionClient.search(text)` 或在 client 回傳時過濾結果
- [ ] 3.4 實作 `filterApplied(TransactionFilter)` delegate handler：儲存 `activeFilter`，重新呼叫 `transactionClient.fetch(filter)` 取得結果
- [ ] 3.5 實作 `deleteTransaction(Transaction.ID)` action：呼叫 `transactionClient.delete(_:)` 並從 state 移除該筆
- [ ] 3.6 實作 `transactionTapped(Transaction)` action：設定 `detail` 為 `TransactionDetailFeature.State(transaction:)`
- [ ] 3.7 實作 `filterButtonTapped` action：設定 `filter` 為 `FilterFeature.State()`，並傳入現有 `activeFilter` 作為初始選取狀態
- [ ] 3.8 實作 `contextActionTapped` action（來自 MainTab 轉發）：設定 `addTransaction` 為 `AddTransactionFeature.State(mode: .add(.expense))`
- [ ] 3.9 處理 `addTransaction` delegate `.saved`：重新載入交易列表

## 4. TransactionsView — 列表 UI

- [ ] 4.1 建立 `TransactionsView`：`ScrollView` 包含以日期分組的 `LazyVStack`，日期 section header 顯示「今天」/「昨天」/「yyyy/M/d」格式
- [ ] 4.2 實作 `TransactionRow`（或重用 Common 層的 `TransactionRow`）：顯示分類圖示（SF Symbol）、備註、時間、金額（支出 `expenseRed`、收入 `incomeGreen`、轉帳 `.secondary`）
- [ ] 4.3 加入 SearchBar：使用 `.searchable()` modifier 或自訂 SearchBar View；輸入時送出 `searchTextChanged(_:)` action
- [ ] 4.4 加入篩選按鈕（funnel 圖示）於導航列右側；若 `activeFilter` 非空則顯示 badge 標示已啟用篩選
- [ ] 4.5 在 row 上加入 `.swipeActions(edge: .trailing)`：顯示紅色「刪除」按鈕，點擊後送出 `deleteTransaction(_:)` 並觸發 `.confirmationDialog`
- [ ] 4.6 實作空白狀態：當 `transactions` 為空時顯示 `EmptyStateView`，依搜尋/篩選狀態顯示不同說明文字
- [ ] 4.7 綁定 `detail` sheet（`TransactionDetailView`）與 `filter` sheet（`FilterView`）與 `addTransaction` sheet（`AddTransactionView`）

## 5. TransactionDetailFeature & TransactionDetailView

- [ ] 5.1 建立 `TransactionDetailFeature` Reducer：State 持有 `transaction: Transaction`、`@Presents var editTransaction: AddTransactionFeature.State?`、`@Presents var deleteConfirmation: ConfirmationDialogState<Action>?`
- [ ] 5.2 實作 `editTapped` action：設定 `editTransaction` 為 `AddTransactionFeature.State(mode: .edit(transaction))`
- [ ] 5.3 實作 `deleteTapped` action：顯示 `.confirmationDialog`；`deleteConfirmed` action 呼叫 `transactionClient.delete(_:)` 並送出 `delegate(.deleted(transaction.id))`
- [ ] 5.4 處理 `editTransaction` delegate `.saved`：更新 `state.transaction` 為最新值並關閉編輯 sheet
- [ ] 5.5 建立 `TransactionDetailView`：顯示類型 badge、大字金額（DM Mono）、帳戶、分類、備註、日期、標籤 pills；右上角「編輯」按鈕、底部紅色「刪除」按鈕；綁定 `editTransaction` sheet

## 6. MainTabFeature & MainTabView — 整合

- [ ] 6.1 將 `MainTabFeature.Tab` enum 中的 `.search` 改名為 `.transactions`（BREAKING）；更新所有引用（`MainTabFeature`、`MainTabView` 及相關測試）
- [ ] 6.2 在 `MainTabFeature.State` 中加入 `transactions: TransactionsFeature.State`，並建立對應的 `Scope` reducer
- [ ] 6.3 在 `MainTabFeature` 中處理 `transactions(.delegate(.deleted(_:)))`：確保列表重新載入（若需要跨 tab 同步）
- [ ] 6.4 在 `MainTabFeature.contextActionTapped` 中，依 `selectedTab` 路由：`.transactions` tab → 送出 `transactions(.contextActionTapped)`；`.dashboard` tab → 維持現有行為
- [ ] 6.5 在 `MainTabView` 中為 `.transactions` tab 加入 `TransactionsView` 綁定；更新 `contextCapsule` 圖示：Transactions tab 顯示 `plus`，Dashboard tab 維持現有圖示
