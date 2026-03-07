## Why

Transactions tab 目前是空白 placeholder（`Tab.search`），使用者無法查看、搜尋、篩選、編輯或刪除交易記錄，缺少記帳 app 的核心體驗。現在 Dashboard 的新增交易功能已完成，是補齊完整 CRUD 流程的最佳時機。

## What Changes

- 新增 `TransactionsFeature` Reducer 與 `TransactionsView`，作為 Transactions tab 的主畫面
- 新增 `TransactionDetailFeature` Reducer 與 `TransactionDetailView`，用於查看單筆交易並支援跳轉至編輯（重用 `AddTransactionFeature`）及刪除
- 新增篩選 Sheet（`FilterFeature`），支援多選分類、帳戶、標籤、類型、日期區間
- **BREAKING**：將 `MainTabFeature` 的 `Tab.search` 改名為 `Tab.transactions`，並整合 `TransactionsFeature` 到 tab scope
- 更新 `MainTabView`，將 Transactions tab 的 `contextCapsule` 全域動作改為開啟新增交易 Sheet

## Capabilities

### New Capabilities

- `screen-transactions`: 交易記錄主畫面 — 按日期分組列表、SearchBar 即時搜尋、篩選 Sheet 入口、左滑刪除、點擊進入詳情
- `transaction-detail`: 交易詳情畫面 — 顯示單筆交易完整資訊、提供「編輯」（push `AddTransactionFeature` 預填模式）與「刪除」（confirmationDialog）操作

### Modified Capabilities

- `screen-main-navigation`: `Tab.search` 改為 `Tab.transactions`；`MainTabFeature` 新增 `transactions: TransactionsFeature.State` scope；Transactions tab 的 `contextCapsule` 全域動作定義為開啟新增交易

## Impact

- **Features layer**：新增 `Features/Transactions/TransactionsFeature.swift`、`TransactionsView.swift`、`TransactionDetailFeature.swift`、`TransactionDetailView.swift`
- **MainTabFeature**：enum `Tab` 改名、新增 `TransactionsFeature` scope 及對應 delegate 處理
- **MainTabView**：新增 Transactions tab view 綁定及 context action 路由
- **AddTransactionFeature**：需支援「編輯模式」（預填現有 `Transaction` 資料）— 檢查現有 state 是否已有此能力
- **Dependencies**：`transactionClient`、`categoryClient`、`accountClient`、`tagClient` 均已存在，無需新增
