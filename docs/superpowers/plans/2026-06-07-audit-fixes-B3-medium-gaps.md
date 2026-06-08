# PR B3 — Medium 級測試缺口補強 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development。

**Goal:** 補齊 audit 的 medium 級 test-gap 中仍存活的 ~26 項。已被處理的**不重複**：App route（B2）、SyncSettings 空驗證（B2）、Notification openSystemSettings（B2）、AddEditTag savedSuccessfully/cancel/colorHex（B1）、AddEditCarrier saveFailed/cancel（B1）、RecurringForm transfer 驗證（A1）、AccountManagement unarchive alert 鏈（A4 已刪）。MainTab 吞錯分支依 audit 自述「難以斷言」列為已知風險不補。

**Architecture:** 「補測試」型，慣例同 B1/B2。implementer 先讀 audit 對應組段落 + reducer 現狀（**A 波改動大，逐項核對 gap 是否仍存在，已消滅的記錄跳過**）。

**分支：** `fix/tests-medium-gaps`（自整合分支切出）。PR base = 整合分支。

### Task 1: 殼層 + 儀表板 + 交易（~10 項）

- MainTab：`settings.delegate.accessoryBarVisibilityChanged` 同步、`dashboard.delegate.seeAllTransactionsTapped` 跨 tab 導航
- AccessoryBar：語音串流 effect（`startVoiceSession` 產出 → `transcriptionUpdated`/`transcriptionFailed`）
- Dashboard：`analysisShortcutTapped` 導航、`retrySection(.accounts)`
- AddTransaction：`categorySuggestionsReceived` success/failure、note 防抖 AI 擷取 effect
- Transactions：filter/addTransaction 的 `dismissed` delegate 關 sheet（注意 A3 已刪 Filter 的 Delegate.dismissed — **核對現狀**，filter sheet 現靠 ifLet 自動 nil，只剩 addTransaction dismissed 可測）
- Filter：`applyTapped` dateRange 三分支、`.task` 錯誤路徑（throw → 空 section 靜默）
- Analysis：loadData 兩條並發 effect 協調與 cancellable 語義

### Task 2: 設定 + 管理（~12 項）

- Settings：`seedRandomData` 流程（guard 去重 + effect + 完成後鏈式重載）
- NotificationSettings：`budgetWarningToggled` authorized 啟/停 + 持久化、`reminderDateChanged` 在 disabled 時 guard（仍 persist 不排程）
- AccountManagement：addEdit delegate `.saved` 重載/`.dismissed` 清空（A5 已測 delegate 發送，此處補 parent 收端行為）
- CategoryManagement：`categoryTapped` 開 edit sheet
- TagManagement：addEdit `dismissed` 關 sheet
- BudgetManagement：add/edit 表單閉環 4 分支（含 `.delegate(.saved)` reload）
- BudgetForm：`categoryChanged` + categoryId 存檔路徑
- CarrierManagement：`editTapped`、`deleteConfirmed` catch 錯誤回復
- RecurringManagement：`deleteTapped` 委派、form saved 後 reload、alert 取消負向（不呼叫 deleteRecurring）

### Task 3: Watch（5 項）

- WatchApp：`isPagingLocked` 的 `draftSent` 解鎖、carrier 分支 4 個 nested action 的 App-level 轉送
- WatchRecord：`confirmTapped` 的 `activeAccountId == nil` guard、amount 上限 clamp 真實邊界（替換恆真斷言 — 若需修改既有恆真測試，允許）、`.task` NotificationCenter self-heal 重載

### Task 4: 收尾

雙 scheme 驗證 + ast-grep + PR 級交叉 review（含逐項對照表）→ PR → merge。

**跑紅 = 真 bug → 不修 production、記錄回報。**
