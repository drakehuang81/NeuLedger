# PR A2 — Dashboard 死碼清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 依審查報告（`docs/audits/2026-06-06-presentation-layer-audit.md` Dashboard 組）與使用者「死碼一律刪除」裁定，刪除 `DashboardFeature` 的 5 個死 action、3 個無消費 stored property 與整條無 UI 出口的 AI insight effect 鏈，並同步刪改依附測試。

**Architecture:** 純刪除型重構（行為不變或移除無觀察行為），不適用紅綠 TDD —— 驗證標準改為：①刪後識別字全 repo grep 歸零 ②編譯通過 ③Dashboard 全部測試 suite 綠 ④完整 scheme 綠。兩個 task 都動同一對檔案（`DashboardFeature.swift` + 測試），必須串行。

**Tech Stack:** Swift / TCA 1.23.1 / Swift Testing / xcodebuild

**分支：** `fix/dashboard-dead-state`（**自 `developer` 切出** —— 與 PR A1 的檔案無交集，平行 PR 安全）。commit 帶 `[ci skip]` 與 Co-Authored-By trailer。

**保留邊界（不得誤刪）：**
- `pulledToRefresh` action 本身是活的（`DashboardScreen` 的 `.refreshable` 送出）—— 只刪它 merge 的 `fetchAIInsight` 與 `lastInsightTransactionCount = nil`
- Insight **carousel** 鏈是活的：`insights` / `insightIndex` / `insightPhase` / `insightsLoaded` / `insightIndexChanged` / `insightsEffect` / `CancelID.insights` 全部保留
- `analysisShortcutTapped` 保留（它取代 `accountTapped` 的導航職責）
- `addTransactionButtonTapped` 保留（quickAction 三兄弟才是死的）
- `AnalysisFeatureTests` 中的 `generateAIInsight` stub 屬 AnalysisFeature 自己的功能，**不在本 PR 範圍**

---

### Task 1: 刪除 5 個死 action 與 isLoading 殘留 property

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`
- Modify: `NeuLedgerTests/Tests/FeaturesTests/DashboardFeatureTests.swift`
- Modify（若編譯指出引用）: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureScopeTests.swift` 等 Dashboard 測試檔的 `isLoading` 斷言行

**審查依據：** `refreshCompleted`（無任何 send 源，isLoading=false 實際由 `transactionsUpdated` 做）、`accountTapped`（chip 走 `accountChipSelected`、header 導航走 `analysisShortcutTapped`，此 case 邏輯與後者完全重複且無 View 送出）、`quickActionExpense/Income/TransferTapped`（無 View 送出、無 parent 轉送）、`isLoading`（無任何 View 讀取 —— refreshable spinner 由 `.refreshable { await store.send(.pulledToRefresh).finish() }` 自管，骨架由 sectionPhase 驅動）。

- [ ] **Step 1: 刪 production 代碼（DashboardFeature.swift）**

逐項刪除（以識別字定位，行號會隨刪除推移）：

1. Action enum：刪 `case refreshCompleted`、`case quickActionExpenseTapped`、`case quickActionIncomeTapped`、`case quickActionTransferTapped`、`case accountTapped(Account.ID)`
2. Reducer body：刪以下 handler 整段 ——
   - `case .refreshCompleted:`（`state.isLoading = false; return .none`）
   - `case .quickActionExpenseTapped:` / `case .quickActionIncomeTapped:` / `case .quickActionTransferTapped:`（三段 `state.addTransaction = AddTransactionFeature.State(mode: .add(...), date: now)`）
   - `case let .accountTapped(id):`（`state.path.append(.analysis(...))`）
3. State：刪 `public var isLoading: Bool = false`（含 `// Loading & UI state` 註解行改為只留 `expandedTransactionID`，註解可同步修為 `// UI state`）
4. 刪 `isLoading` 的所有寫入點：`.task` handler 的 `state.isLoading = true`、`.pulledToRefresh` handler 的 `state.isLoading = true`、`.transactionsUpdated` handler 的 `state.isLoading = false`

刪後 `.task` handler 應為：

```swift
case .task:
    state.heroPhase = .loading
    state.statsPhase = .loading
    state.transactionsPhase = .loading
    state.insightPhase = .loading
    state.accountsPhase = .loading
    return loadAllSections(
        accountID: state.selectedAccountID,
        cancelInFlight: false
    )
```

（`.pulledToRefresh` 的 `state.isLoading = true` 此 task 先刪，其餘 AI 鏈部分留待 Task 2。）

- [ ] **Step 2: 同步刪改測試**

`DashboardFeatureTests.swift`：
- **整個刪除**：`testAccountTappedOpensAnalysis`（@Test "accountTapped opens analysis with selectedAccountId set"）、`testQuickActionExpenseTapped`、`testQuickActionIncomeTapped`、`testQuickActionTransferTapped`（三個 @Test "quickAction*Tapped presents AddTransaction..."）
- **修改**：所有對 `$0.isLoading = true/false` 的 trailing-closure 斷言行刪除（以編譯錯誤為完整清單 —— `State.isLoading` 刪除後所有引用點都會編譯失敗，逐一清掉）

其他 Dashboard 測試檔（`Dashboard/DashboardFeature*Tests.swift`、`SectionPhaseTests.swift`）若也斷言 `isLoading`，同樣刪該斷言行（只刪斷言，不刪測試本體）。

- [ ] **Step 3: 識別字歸零驗證**

```bash
grep -rn 'refreshCompleted\|quickActionExpenseTapped\|quickActionIncomeTapped\|quickActionTransferTapped' Features/Sources/ NeuLedgerTests/ NeuLedgerWatchTests/ Shared/ NeuLedger/ NeuLedgerWidget/
# 預期：無輸出
grep -rn '\.accountTapped' Features/Sources/Features/Dashboard/ NeuLedgerTests/Tests/FeaturesTests/DashboardFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/Dashboard/
# 預期：無輸出（AccountManagement 的同名 case 不在掃描範圍，屬另一 feature）
grep -rn 'isLoading' Features/Sources/Features/Dashboard/
# 預期：無輸出
```

- [ ] **Step 4: 跑 Dashboard 測試 suite**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/DashboardFeatureTests \
  -only-testing:NeuLedgerTests/DashboardFeatureChipTests \
  -only-testing:NeuLedgerTests/DashboardFeatureExpansionTests \
  -only-testing:NeuLedgerTests/DashboardFeatureInsightTests \
  -only-testing:NeuLedgerTests/DashboardFeatureScopeTests \
  -only-testing:NeuLedgerTests/DashboardFeatureSectionPhaseTests \
  -only-testing:NeuLedgerTests/DashboardFeatureStatsTests
```

預期：全 PASS。

- [ ] **Step 5: 跑完整 test scheme**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

預期：全 PASS。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Dashboard/DashboardFeature.swift NeuLedgerTests/
git commit -m "refactor(dashboard): remove dead actions (refreshCompleted/quickAction*/accountTapped) and unused isLoading [ci skip]

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 刪除 AI insight 死鏈（整條）

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`
- Modify: `NeuLedgerTests/Tests/FeaturesTests/DashboardFeatureTests.swift`
- Modify: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureScopeTests.swift`
- Modify（清多餘 stub）: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureInsightTests.swift` 等

**審查依據：** `state.aiInsight` 與 `state.isLoadingInsight` 被 reducer 寫入但無任何 View 讀取（InsightCarousel 渲染的是 `insights: [InsightData]`，與 `aiInsight: String?` 是不同資料）—— 整條 `fetchAIInsight → insightsClient.generateAIInsight → aiInsightResponse` 產出的字串無處顯示，effect 白打 on-device 模型。`lastInsightTransactionCount` 只服務此鏈的失效判斷，連帶成為孤兒，一併刪除。

- [ ] **Step 1: 刪 production 代碼（DashboardFeature.swift）**

1. State：刪 `// AI Insight` 註解塊與三個 property —— `aiInsight`、`isLoadingInsight`、`lastInsightTransactionCount`
2. Action enum：刪 `// AI Insight` 註解與 `case fetchAIInsight`、`case aiInsightResponse(TaskResult<String>)`
3. CancelID：刪 `case aiInsightFetch`
4. Reducer body：刪 `// MARK: AI Insight` 區塊整段（`case .fetchAIInsight:`、`case let .aiInsightResponse(.success(insight)):`、`case .aiInsightResponse(.failure):` 三個 handler，含 SpendingSummary 組裝邏輯）
5. `.pulledToRefresh` handler 簡化為：

```swift
// Task 2.5: Pull-to-refresh — reload data
case .pulledToRefresh:
    return loadAllSections(
        accountID: state.selectedAccountID,
        cancelInFlight: true
    )
```

6. `.transactionsUpdated` handler 刪除 count-diff 觸發段（含「AI insight 失效判斷」整段註解），簡化為：

```swift
case let .transactionsUpdated(recent, earliestDate):
    state.recentTransactions = recent
    state.earliestTransactionDate = earliestDate
    state.transactionsPhase = .loaded
    return .none
```

- [ ] **Step 2: 同步刪改測試**

`DashboardFeatureTests.swift`：
- **整個刪除**：`testAICacheInvalidationOnNewTransaction`（@Test "AI insight cache is invalidated..."）、`testPullToRefreshForcesAIUpdate`（@Test "pulledToRefresh forces AI insight update"）、`testAIInsightFailure`（@Test "AI insight failure falls back gracefully"）
- **修改**：其餘測試（如 `testTaskUpdatesState`、`testTaskFetchesCategoriesAndPopulatesCategoryMap`）中的 `$0.insightsClient.generateAIInsight = ...` stub 行、`receive(\.fetchAIInsight)` / `receive(\.aiInsightResponse)` 行、`$0.aiInsight = ...` / `$0.isLoadingInsight = ...` / `$0.lastInsightTransactionCount = ...` 斷言行 —— 全部刪除（編譯錯誤 + TestStore exhaustivity 失敗訊息為完整清單）

`Dashboard/DashboardFeatureScopeTests.swift`：
- **整個刪除**：`testAIInsightSkippedWhenCountUnchanged`（@Test "transactionsUpdated with unchanged count does not refetch AI insight"）、`testAIInsightCountConsistency`（@Test "AI insight response stores the same count the trigger compared against"）
- **修改**：其餘測試中與死鏈相關的 stub/receive/斷言（同上原則）

`Dashboard/DashboardFeatureInsightTests.swift` 等其他 Dashboard 測試檔：
- 測試本體保留（carousel 是活的），僅刪除 `generateAIInsight` stub 行與任何 `fetchAIInsight`/`aiInsightResponse` receive（若有）

- [ ] **Step 3: 識別字歸零驗證**

```bash
grep -rn 'aiInsight\|isLoadingInsight\|lastInsightTransactionCount\|fetchAIInsight\|aiInsightResponse\|aiInsightFetch' Features/Sources/Features/Dashboard/ NeuLedgerTests/Tests/FeaturesTests/DashboardFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/Dashboard/
# 預期：無輸出
grep -rn 'generateAIInsight' Features/Sources/Features/Dashboard/
# 預期：無輸出（AnalysisFeature 與 TransactionDetail 的使用不受影響，不在掃描範圍）
```

- [ ] **Step 4: 跑 Dashboard 測試 suite**（同 Task 1 Step 4 指令）

預期：全 PASS。

- [ ] **Step 5: 跑完整 test scheme**

預期：全 PASS（特別確認 `AnalysisFeatureTests` 與 `TransactionDetailFeatureInsightTests` 不受影響 —— 它們用的 `generateAIInsight`/`generateTransactionInsight` 是各自 feature 的活功能）。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Dashboard/DashboardFeature.swift NeuLedgerTests/
git commit -m "refactor(dashboard): remove dead AI-insight chain (no view consumes aiInsight) [ci skip]

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 完整驗證 + 交叉 review + PR

- [ ] **Step 1: 完整 test scheme**（Task 2 已跑過，若 Task 2 後無其他改動可引用其結果）
- [ ] **Step 2: ast-grep PR 前審計**（CLAUDE.md 四條，預期全乾淨）
- [ ] **Step 3: 派獨立 subagent 交叉 review 整個 PR diff** —— 重點：①保留邊界是否被誤刪（pulledToRefresh、insights carousel、analysisShortcutTapped）②刪除是否徹底（無新孤兒：例如刪 fetchAIInsight 後 `SpendingSummary` 在 Dashboard 的 import/使用是否還有殘留）③測試刪改是否過度（誤刪了活測試）
- [ ] **Step 4: 開 PR**（`fix/dashboard-dead-state` → `developer`，PR 標題不帶 `[ci skip]`，body 引用審查報告 Dashboard 組條目）

---

## Self-Review 紀錄

- Spec coverage：審查 Dashboard 組 confirmed 8 項中，6 項死碼在本 plan（F1 refreshCompleted、F2 accountTapped、F3 quickAction×3、F4 aiInsight、F5 isLoadingInsight、F6 isLoading）；其餘 2 項為 test-gap（refreshAfterMutation 未測 → B2）✅
- 保留邊界已明列（carousel 鏈、pulledToRefresh、analysisShortcutTapped）✅
- 刪除型任務不適用紅綠 TDD，已改為 grep 歸零 + 編譯 + 雙層測試驗證 ✅
- `lastInsightTransactionCount` 為審查未單列但邏輯上連帶的孤兒，已標注依據 ✅
