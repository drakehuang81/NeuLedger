# Presentation Layer 審查修復 Roadmap（Master Plan）

> **For agentic workers:** 本文件是批次結構總覽，不是 task-level plan。每個 PR 動工前須先依 `superpowers:writing-plans` 寫出該 PR 的詳細 plan（`docs/superpowers/plans/2026-06-06-audit-fixes-<PR編號>.md`），再以 `superpowers:subagent-driven-development` 執行。

**Spec 來源：** `docs/audits/2026-06-06-presentation-layer-audit.md`（31 組 Screen/Feature 審查，91 項 confirmed + 38 項 reviewer 補漏）

**使用者裁定（2026-06-06）：**
1. 死碼一律刪除 — git 歷史可找回；既有 TODO 註解保留原位標記未來功能
2. 129 項全修 — 先代碼修復（Wave A）再補測試（Wave B），避免補完測試又因刪碼返工
3. 每個 PR：subagent 實作 → 派另一 subagent 交叉 review → 跑完整 test scheme

**通用規則（每個 PR 都適用）：**
- 分支 `fix/<name>`，commit 預設帶 `[ci skip]`，走 PR 進 `developer`
- 刪除死 action/property 時，依附它的測試一併刪除（否則編譯失敗）
- 驗證 = `xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 全綠（watch 改動另需 watch target 編譯通過）
- 修復涉及行為變更時依 TDD：先寫 failing test

---

## Wave A：代碼修復（39 項）

### PR A1 — `fix/audit-behavior-bugs`：4 個真 bug（行為錯誤）
1. **[Analysis/high]** AIAssistant `isAvailable` gating 死鎖 — `AnalysisFeature.task` 不轉送 `.aiAssistant(.task)`，而 `AIAssistantCardView` 被 `if store.aiAssistant.isAvailable` 擋住永不掛載 → AI 助理區塊永遠不顯示（`AnalysisView.swift:120`、`AIAssistantFeature.swift:32,54-55`）
2. **[Transactions/medium]** 三條重載路徑（`.task` / 清空搜尋 / `addTransaction.saved`）硬編 `TransactionFilter()` 忽略 `state.activeFilter`（`TransactionsFeature.swift:87,102,196`）
3. **[AddEditAccount/medium]** `.add` init 硬寫 `icon="creditcard"` / `colorHex="#3478F6"`，與 `AccountType.cash` 的 SSOT 預設（`banknote` / `#8E8E93`）不一致（`AddEditAccountFeature.swift:38-40`）
4. **[RecurringForm/medium]** transfer 可存出 `toAccountId == nil` 的殘缺範本 + 死 action `toAccountChanged` + View :250-252 錯誤註解（`RecurringTransactionFormFeature.swift:23,68,139-140`）— **裁定（2026-06-06）：補齊 toAccount picker**（`toAccountChanged` 變活、saveTapped 驗證 nil 與 same-account、對齊 AddTransactionFeature 模式），非刪除

### PR A2 — `fix/dashboard-dead-state`：Dashboard 組 6 項死碼
- 死 action：`refreshCompleted`（:124,214）、`accountTapped`（:154,405-407，導航統一走 `analysisShortcutTapped`）、`quickActionExpenseTapped/IncomeTapped/TransferTapped`（:148-150,380-396）
- 殘留 property：`aiInsight`（:67）、`isLoadingInsight`（:68）— 連同整條 `fetchAIInsight → generateAIInsight → aiInsightResponse` 死鏈；`isLoading`（:81）
- 同步刪除依附測試（`testAccountTappedOpensAnalysis`、quickAction 三條等）

### PR A3 — `fix/transactions-detail-filter-dead-state`：交易區 7 項
- Transactions：`State.activeFilterCount`（:33-41，badge 已由 FilterFeature 同名 property 負責）
- TransactionDetail：`accountName`/`toAccountName` 重複投影（:22-23，`namesLoaded` 簽名同步改）、`editTransaction(.delegate(.saved))` 不可達分支（:204-206）
- Filter：`isLoading`（:23）、死 action `dismiss`（:70,182-186）、`hasActiveFilters`（:38-42）— 含對應測試刪除

### PR A4 — `fix/management-screens-dead-code`：管理畫面群 ~13 項
- AccessoryBar：死 action `aiInputTextChanged`（:29,88-90）；`AccessoryView.swift:100` 被覆蓋的 `.font(.title)` 殘留修飾子
- AccountManagement：死 action `accountMoved` + `CancelID.reorder`（:204）；`accountTapped` 的 `isArchived` 死分支 + `unarchiveConfirmed` alert + 孤兒 localization key（:105，archived row 無 tap 入口）
- CategoryManagement：死 action `categoriesMoved`（:95-124 整段 reorder 邏輯）
- BudgetManagement：死 action `toggleActive`（:29,73-80）+ **整檔刪除** `Components/BudgetRow.swift`（從未被實例化）+ `testToggleActive`
- CustomAccountForm：死 action `cancelTapped` + `Delegate.dismissed`（:36,55）+ OnboardingFeature 的 `.dismissed` handler + 兩條測試
- Settings：死 action `seedRandomDataDismissed`（:469）；殘留 property `widgetCarrierId`（:46，含 init 參數與兩處測試斷言）
- Analysis：死 action `dismissInsight`（:232）；`AnalysisData.budgetMetrics` 死欄位（:81,213）；`hasMonthlyTrendData` 永 false 分支 + **整檔刪除** `MonthlyTrendCard.swift`；空轉 `BindingReducer` + `binding` case + 兩處 `@Bindable` 改回 `let store`
- AIAssistant：`submitTapped` 的 `cancelInFlight: true` 不可達（保留 `.cancellable(id:)`，移除 `cancelInFlight`）

### PR A5 — `fix/ssot-refactors`：SSOT 結構修復 7 項
- WatchCarrier：`presentedCarrier: Carrier?` → `presentedCarrierID: Carrier.ID?` + computed 推導，刪 `carriersUpdated` 的 re-resolve 膠水（:63-67），測試改斷言推導結果
- Settings ↔ AccountManagement：子畫面補 `delegate(.accountsChanged)` 回拋（pop 後 `accounts`/`defaultAccountName` desync）
- Settings ↔ CarrierManagement：子畫面補 `delegate(.carriersChanged)` 回拋（同構 desync）
- WatchSettings：`loaded` 的 fallback 規則（:64-66）與 `WatchDefaultAccountResolver` 統一為單一純函式
- AccountManagement：逐筆 `ledger.balance(id)` task group → 單呼叫 `ledger.balances()`（與 Dashboard 統一）
- Dashboard/Analysis：income/expense 手刻 filter+reduce 收進 `insightsClient` 投影（牽動 Domain/Application，風險最高，置於 A5 最後可獨立切出）
- AddEditTag/AddEditAccount：`"#3478F6"` magic literal 抽具名常數

**Follow-up（本輪不做，另開單）：** Settings.State（20 props）與 Dashboard.State（22 props）肥大拆解 — 屬建議性重構非缺陷；Dashboard stats 未隨 selectedAccountID 連動為已知 TODO（stats-follow-up）。

---

## Wave B：測試補強（90 項 test-gap；Wave A 全 merge 後動工）

### PR B1 — `fix/tests-addedit-suites`：4 個零測試 AddEdit feature 建套件
- `AddEditAccountFeatureTests`（A1 已建檔含 init 測試，此處補滿：saveTapped create/update、驗證失敗 inline error、cancel/delegate）
- `AddEditCategoryFeatureTests`（0/9 覆蓋）
- `AddEditTagFeatureTests`（save happy-path、colorHex 端到端、delegate+dismiss）
- `AddEditCarrierFeatureTests`（saveFailed 錯誤路徑、cancelTapped 發端）

### PR B2 — `fix/tests-high-gaps`：21 項 high 級缺口（A 波刪碼後存活者）
重點：App 深連結三分支 + `route(.carrierManagement)` + `allDataWiped` 重置；MainTab `savedRecurringConfirmation` 編排（含 id 不存在負例）；AccessoryBar `aiInputSubmitted` 成功路徑；Dashboard `refreshAfterMutation` 三入口；AddTransaction recurring 範本建立；Transactions `searchDebounced` + detail delegate 三分支；Settings `wipeAllData` 全流程；SyncSettings `syncNowTapped/Finished`；NotificationSettings 授權重試；AccountManagement `accountTapped` 分支；CategoryManagement alert 刪除 + delegate 回流；TagManagement saved 重載；RecurringForm edit 模式 save；WatchRecord `amountConfirmed`

### PR B3 — `fix/tests-medium-gaps`：medium 級（~27 項 confirmed + 補漏）
### PR B4 — `fix/tests-low-gaps`：low 級（~14 項 confirmed + 補漏）

> B2-B4 的逐項清單以 `docs/audits/2026-06-06-presentation-layer-audit.md` 各組「未覆蓋關鍵路徑」與 test-gap findings 為準；寫各 PR plan 時須先核對 Wave A 後的實際代碼（部分 gap 所屬 action 已在 A 波刪除）。

---

## 進度追蹤

- [ ] PR A1 — fix/audit-behavior-bugs
- [ ] PR A2 — fix/dashboard-dead-state
- [ ] PR A3 — fix/transactions-detail-filter-dead-state
- [ ] PR A4 — fix/management-screens-dead-code
- [ ] PR A5 — fix/ssot-refactors
- [ ] PR B1 — fix/tests-addedit-suites
- [ ] PR B2 — fix/tests-high-gaps
- [ ] PR B3 — fix/tests-medium-gaps
- [ ] PR B4 — fix/tests-low-gaps
