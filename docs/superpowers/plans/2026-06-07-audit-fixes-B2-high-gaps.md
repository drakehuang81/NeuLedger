# PR B2 — High 級測試缺口補強 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development。

**Goal:** 補齊審查確認的 21 項 high 級 test-gap（A 波刪碼後全部存活，已核對）。每項的證據與 suggestedFix 在 `docs/audits/2026-06-06-presentation-layer-audit.md` 各組段落 —— implementer 須先讀對應組的 findings 與 untestedCriticalPaths，再讀 reducer 現狀（A 波後行號已漂移，以識別字定位）。

**Architecture:** 「補測試」型 —— 寫測試 → 跑 → 預期綠；跑紅 = 發現真 bug → 不修 production、記錄回報。慣例同 B1（LockIsolated spy 逐欄斷言、負斷言、血淚規則①②、`String(localized:)` 對齊 reducer）。

**分支：** `fix/tests-high-gaps`（自 `integration/presentation-audit` 最新 HEAD 切出）。PR base = 整合分支。

### Task 1: 核心殼層（App + MainTab + AccessoryBar）

- **AppFeatureTests**：①`deepLinkReceived` 三分支（stub `platformClient.parseLink` 回 `.carrierManagement` / `.none`，斷言 receive `\.route` 與後續導航）②`route(.carrierManagement)` 在 `.main`（selectedTab 切 .settings + settings.path 尾端 .carrierManagement）與非 `.main`（guard 早退，state 不變）③`main(.settings(.delegate(.allDataWiped)))` → receive `\.route.onboarding` → destination 重置
- **MainTabFeatureTests**：`savedRecurringConfirmation` 編排 —— stub `listRecurring` 回含目標 id 的 template、`updateRecurring` spy 斷言 nextDueDate 被覆寫；負例：id 不存在時 updateRecurring 不被呼叫
- **AccessoryBarFeatureTests**：`aiInputSubmitted` 成功路徑 —— stub `captureClient.extractFromText` 回 ExtractedTransaction，斷言整鏈（含 `aiInputError` 清除、delegate/轉送行為以 reducer 實際為準）

### Task 2: 交易流（Dashboard + AddTransaction + Transactions）

- **Dashboard**（放 `Dashboard/DashboardFeatureMutationTests.swift` 新檔）：`refreshAfterMutation` 三入口 —— ①`addTransaction(.presented(.delegate(.saved)))`（與 `.savedWithTransaction`）②`savedRecurringConfirmation`（同時斷言 delegate 轉送給 parent）③`detail(.presented(.delegate(.deleted/.updated)))`。斷言四個 effect 齊發（accountsUpdated/transactionsUpdated/statsComputed/weeklySpendingComputed 各 receive；exhaustivity 策略以可讀為準）
- **AddTransactionFeatureTests**：saveTapped 在 `.add` 模式 + `recurringFrequency != nil` 時建立 RecurringTransaction 範本（spy `createRecurring` 斷言 frequency/amount/nextDueDate）；負例 frequency == nil 不建立
- **TransactionsFeatureTests**：①`searchDebounced`（stub `ledger.search` spy 斷言查詢字串 + transactionsLoaded 回流）②detail delegate 三分支（deleted 移除列、updated 替換列、dismiss 清 state）③`addTransaction.saved` 重載已在 A1 測過 —— 不重複

### Task 3: 設定群（Settings + SyncSettings + NotificationSettings）

- **SettingsFeatureTests**：`wipeAllData` 全流程 —— tapped（旗標）、confirmed（stub 抹除 client 成功 → receive completed → receive `\.delegate.allDataWiped`）、failed（stub throw → wipeAllDataError 寫入）、dismissed
- **SyncSettingsFeatureTests**：`syncNowTapped`（stub `platformClient.syncNow` + `lastSyncedAt`）→ receive `\.syncNowFinished` 斷言 lastSynced 更新與 syncing 旗標復位；並修復 audit 點名的「taskLoadsState 空驗證」（補 trailing closure 斷言）
- **NotificationSettingsFeatureTests**：dailyReminder 未授權→`requestPermission` granted=true→自動重試開啟（斷言 `setReminderTime`/`scheduleDailyReminder` spy 被呼叫）；budgetWarning 同構

### Task 4: 管理群（Account/Category/Tag 管理 + RecurringForm）

- **AccountManagementFeatureTests**：`accountTapped`（未封存）進 edit 模式（addEdit state 含 existingNames 過濾自身）
- **CategoryManagementFeatureTests**：①alert 確認刪除（`.alert(.presented(.deleteConfirmed))` → spy deleteCategory + 重載）②addEdit saved/dismissed delegate 回流（saved 觸發重載、dismissed 清 sheet）
- **TagManagementFeatureTests**：`addEdit(.presented(.delegate(.saved)))` 關 sheet + listTags 重載
- **RecurringTransactionFormFeatureTests**：①edit 模式 saveTapped 整條（spy updateRecurring 斷言欄位 + nextDueDate 重組）②edit 模式 transfer 範本載入後切 expense 存檔 → toAccountId nil-out（A1 follow-up）③task/cancel 路徑

### Task 5: WatchRecord（watch 測試）

- **NeuLedgerWatchTests/WatchRecordFeatureTests**：`amountConfirmed` 兩分支 —— amount > 0 推進流程、amount == 0 被攔截（讀 reducer 確認實際守門邏輯）。驗證用 watch scheme（具名模擬器，如 Apple Watch Series 11 (46mm)）

### Task 6: 收尾

- 完整 iOS scheme + watch scheme 測試 + ast-grep 閘門
- PR 級交叉 review（誠實度抽查 + audit 21 項對照表）→ PR（base = 整合分支）→ merge

**若任何測試跑紅：** 真 bug → 記錄回報不修 production，PR body 列出待裁定。
