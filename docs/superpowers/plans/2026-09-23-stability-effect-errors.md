# 穩定性 PR：effect 錯誤處理與刪除視窗 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Features 層 28 處沒有 catch 的 `.run` effect 全部接上錯誤出口（inline 顯示、不用 Alert），修掉「刪除交易後滑掉 sheet 其實沒刪」，並補上啟動 / Onboarding 卡死的 fallback；每個修復都有 TestStore 測試。

**Architecture:** 沿用 codebase 已存在的正確寫法（`AddEditCarrierFeature`：`isSaving` + `saveError` + `saveFailed(String)` + `.run(operation:catch:)`），以「慣例」而非 higher-order reducer 推廣到每個 Feature：寫入類 effect 用 `saveFailed` / `actionFailed`，載入類 effect 用 `loadFailed`，View 用既有的 `ErrorText` 與 `SectionFailureView` 顯示。刪除視窗保留在 `TransactionDetailFeature`，但 parent 在 `.detail(.dismiss)` 時若 `pendingDelete` 立即提交刪除，View 同時 `interactiveDismissDisabled(pendingDelete)`。

**Tech Stack:** Swift 6、TCA 1.23.2、Swift Testing、xcodebuild。

**Spec:** `docs/audits/2026-09-23-health-audit/README.md`（#2–#6、#36、Tier 2 的 #16、#18、#20）與 `docs/audits/2026-09-23-health-audit/01-features.md`（A1–A7、A9、A10、A12、B9、「其他較小的確認項」的 NotificationSettings / AccountManagement `.merge` 兩條）。

## Global Constraints

- iOS 26.0 minimum；不加 `#available`。
- Features **不得** `import SwiftData`，不得注入 Adapter / `SwiftDataStore`，只能用六個 Client。
- 驗證 / 儲存錯誤一律 **inline**（`ErrorText`），不用 `Alert`。載入失敗用 `SectionFailureView(message:retry:)`。
- **不新增 localization key。** 錯誤訊息用 `error.localizedDescription`（與 `AddEditCarrierFeature` 一致）；載入失敗的 retry 文案由 `SectionFailureView` 自帶。
- 所有 `Color` 走 `Color.Design`、`.font` 走 `Font.Design`。
- 測試用 Swift Testing；`@DependencyClient` 的 `testValue` 是 unimplemented stub，reducer 路徑碰到的每個 closure 都要在 `withDependencies` 覆寫。測試裡拋錯一律用同一個型別：
  ```swift
  struct StubError: LocalizedError, Equatable { var errorDescription: String? { "boom" } }
  ```
  （放在各測試檔內 `private struct`；`localizedDescription` 會是 `"boom"`。）
- `swift test` 不可用；一律 xcodebuild，永不並行。完整 scheme 前景跑、重導向到檔案，`; echo "exit=$?"` 取結果（zsh 沒有 `$PIPESTATUS`）。
- 機器全域 `xcode-select` 指向未授權的 Xcode：**每個** `xcodebuild` / `git` / `python3` 指令加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 前綴。
- Commit subject 一律加 `[ci skip]`；body 帶 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`。
- 分支 `fix/stability-effect-errors`，從最新 `origin/developer`（d5da84b 之後）開；PR title 不加 `[ci skip]`。
- **每個 Task 最後一步跑完整 `NeuLedger` test scheme**。
- 只改各 Task **Files** 列出的檔案；清單外的檔案編譯失敗一律回報 BLOCKED。

## 裁定（寫在這裡讓執行者不用再問）

- R1：共用形狀用慣例（三個成員 + 一個 action），不抽 higher-order reducer。九張表單的 Action 各自命名已久，抽 reducer 會動到所有測試，成本高於收益。
- R2：刪除視窗不搬到 parent。child 保留計時器，parent 在 `.detail(.dismiss)` 讀 `state.detail?.pendingDelete`（TCA 的 `ifLet` 對 `.dismiss` 是 base reducer 先跑、之後才把 state 設 nil，所以 parent 讀得到）並立即刪除；View 在 `pendingDelete` 期間禁用互動式關閉。
- R3：`AnalysisFeature` 的 A11（主 effect 無 cancellable、失敗謊報空狀態）**不在本 PR**，併入 PR B（該 PR 會整檔重寫 AnalysisFeature）；PR B 的 Task 7 必須加 `CancelID.load` + `loadError`。
- R4：`ledger.search` API 保留，本 PR 只讓 `TransactionsFeature` 改走 `listAll(effectiveFilter)`；刪 API 留給 PR C。
- R5：reducer 內既有的裸 `Date()` / `Calendar.current`（SyncSettings、NotificationSettings）本 PR 不動（B7 另開）。

## 指令速查

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# 單一 suite
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/<SuiteStructName> -quiet; echo "exit=$?"
# 完整 scheme（每個 Task 結尾）
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > /tmp/full.log 2>&1; echo "exit=$?"; grep -c 'passed on' /tmp/full.log; grep -c 'failed on' /tmp/full.log
```
通過條件：exit=0 且 `failed on` = 0。基準（developer@d5da84b）：814 passed。

---

### Task 1: 交易列表（TransactionsFeature）— 六條 effect 補 catch、搜尋尊重篩選、查詢互相取消

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionsView.swift:18`（`if store.isLoading {` 區塊）
- Test: `NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift`

**Interfaces:**
- Produces（Task 2 用）：`TransactionsFeature.Action.loadFailed(String)`、`State.loadError: String?`、`State.effectiveFilter: TransactionFilter`（activeFilter + searchText）。

- [ ] **Step 1: 寫失敗測試**

在 `TransactionsFeatureTests.swift` 的 struct 末尾（最後一個 `}` 前）加：

```swift
    // MARK: - Effect error handling（health-audit A6 / A7）

    private struct StubError: LocalizedError, Equatable { var errorDescription: String? { "boom" } }

    @Test(".task failure sets loadError and clears isLoading")
    func testTaskFailureSetsLoadError() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in throw StubError() }
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.loadFailed) {
            $0.isLoading = false
            $0.loadError = "boom"
        }
    }

    @Test("searchDebounced queries listAll with activeFilter + searchText (filters are not dropped)")
    func testSearchRespectsActiveFilter() async {
        let categoryId = UUID()
        var initial = TransactionsFeature.State()
        initial.activeFilter = TransactionFilter(categoryIds: [categoryId])
        initial.searchText = "sushi"
        let captured = LockIsolated<TransactionFilter?>(nil)
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                captured.setValue(filter)
                return []
            }
        }
        await store.send(.searchDebounced)
        await store.receive(\.transactionsLoaded) {
            $0.isLoading = false
            $0.transactions = []
        }
        #expect(captured.value?.categoryIds == Set([categoryId]))
        #expect(captured.value?.searchText == "sushi")
    }

    @Test("deleteConfirmed failure surfaces loadError and keeps the row")
    func testDeleteFailureKeepsRow() async {
        var initial = TransactionsFeature.State()
        initial.transactions = [Self.sampleTransaction]
        initial.deleteConfirmationId = Self.sampleTransaction.id
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.delete = { _ in throw StubError() }
        }
        await store.send(.deleteConfirmed) { $0.deleteConfirmationId = nil }
        await store.receive(\.loadFailed) { $0.loadError = "boom" }
        await MainActor.run { #expect(store.state.transactions.count == 1) }
    }

    @Test("loadFailed clears when a later load succeeds")
    func testLoadErrorClearsOnSuccess() async {
        var initial = TransactionsFeature.State()
        initial.loadError = "stale"
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.transactionsLoaded) {
            $0.isLoading = false
            $0.loadError = nil
            $0.transactions = [Self.sampleTransaction]
        }
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/TransactionsFeatureTests`
Expected: 編譯錯誤 `no member 'loadFailed'` / `'loadError'`。

- [ ] **Step 3: 實作 — State / Action / CancelID**

`State` 加：
```swift
        /// 最近一次載入或刪除失敗的訊息；成功載入後清空。View 用 SectionFailureView 顯示。
        public var loadError: String? = nil

        /// 列表查詢一律用這個：使用者的篩選條件 + 搜尋字串（health-audit A7：搜尋不再丟掉篩選）。
        var effectiveFilter: TransactionFilter {
            var filter = activeFilter
            filter.searchText = searchText.isEmpty ? nil : searchText
            return filter
        }
```
`Action` 加：`case loadFailed(String)`。
`CancelID` 改為：
```swift
    private enum CancelID {
        case load            // 所有列表查詢共用，cancelInFlight 避免舊查詢覆蓋新結果
        case searchDebounce  // 只給 debounce 用
    }
```
在 `body` 之前加一個 reducer 內的 helper：
```swift
    /// 所有列表載入共用：成功 → transactionsLoaded，失敗 → loadFailed。
    private func reload(_ filter: TransactionFilter) -> Effect<Action> {
        .run { send in
            let rows = try await ledger.listAll(filter: filter)
            await send(.transactionsLoaded(rows.map(\.transaction)))
        } catch: { error, send in
            await send(.loadFailed(error.localizedDescription))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }
```

- [ ] **Step 4: 實作 — 六個 case 改用 helper**

```swift
            case .task:
                state.isLoading = true
                state.loadError = nil
                return reload(state.effectiveFilter)

            case let .transactionsLoaded(transactions):
                state.isLoading = false
                state.loadError = nil
                state.transactions = transactions.sorted { $0.date > $1.date }
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none

            case let .searchTextChanged(text):
                state.searchText = text
                if text.isEmpty {
                    return reload(state.effectiveFilter)
                }
                return .run { send in
                    await send(.searchDebounced)
                }
                .debounce(id: CancelID.searchDebounce, for: 0.3, scheduler: RunLoop.main)

            case .searchDebounced:
                return reload(state.effectiveFilter)

            case let .filter(.presented(.delegate(.filterApplied(newFilter)))):
                state.activeFilter = newFilter
                return reload(state.effectiveFilter)

            case .deleteConfirmed:
                guard let id = state.deleteConfirmationId else { return .none }
                state.deleteConfirmationId = nil
                return .run { send in
                    try await ledger.delete(id)
                    await send(.transactionDeleted(id))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case .addTransaction(.presented(.delegate(.saved))):
                state.addTransaction = nil
                return reload(state.effectiveFilter)
```
`ledger.search` 在此檔不再有呼叫者（API 保留，R4）。

- [ ] **Step 5: 實作 — View**

`TransactionsView.swift:18` 的 `if store.isLoading { ... }` 之後（同一個 if/else 鏈）加：
```swift
                } else if let error = store.loadError {
                    SectionFailureView(message: error) { store.send(.task) }
                        .padding(.horizontal, 22)
```
（若原本是 `if store.isLoading { A } else { B }`，改為 `if isLoading { A } else if let error { C } else { B }`。）

- [ ] **Step 6: 跑測試確認通過**

Run: `-only-testing:NeuLedgerTests/TransactionsFeatureTests` → exit=0。既有測試若因 CancelID / helper 改動而需要 `receive` 順序調整，只允許調整 receive 的排列，不得放寬斷言。

- [ ] **Step 7: 完整 scheme + commit**

```bash
git add Features/Sources/Features/Transactions/TransactionsFeature.swift Features/Sources/Features/Transactions/TransactionsView.swift NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift
git commit -m "fix(transactions): surface load/delete failures inline, search keeps active filter, reloads cancel in flight [ci skip]"
```

---

### Task 2: 刪除視窗 — 關 sheet 不再吞掉刪除

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift:85`（`.presentationDetents(` 之後）
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift`（`case .detail(.dismiss)`）
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift`（`case .detail:` 之前加 case；`Action` 加一個 case）
- Test: `NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift`
- Test: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureMutationTests.swift`

**Interfaces:**
- Consumes：Task 1 的 `loadFailed`。`TransactionDetailFeature.State.pendingDelete: Bool`（public，既有）、`State.transaction: Transaction`（既有）。
- Produces：`DashboardFeature.Action.pendingDeleteCommitted`。

- [ ] **Step 1: 寫失敗測試**

`TransactionsFeatureTests.swift` 末尾加（`TransactionDetailFeature.State` 的建構方式以 `TransactionDetailFeatureDeleteWindowTests.swift` 既有寫法為準）：

```swift
    // MARK: - Delete window survives sheet dismissal（health-audit A2）

    @Test("dismissing the detail sheet during the undo window commits the delete")
    func testDismissDuringPendingDeleteCommits() async {
        var detail = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        detail.pendingDelete = true
        var initial = TransactionsFeature.State()
        initial.transactions = [Self.sampleTransaction]
        initial.detail = detail
        let deleted = LockIsolated<Transaction.ID?>(nil)
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.delete = { deleted.setValue($0) }
        }
        await store.send(.detail(.dismiss)) { $0.detail = nil }
        await store.receive(\.transactionDeleted) { $0.transactions = [] }
        #expect(deleted.value == Self.sampleTransaction.id)
    }

    @Test("dismissing the detail sheet without a pending delete does not delete")
    func testDismissWithoutPendingDeleteIsNoop() async {
        var initial = TransactionsFeature.State()
        initial.transactions = [Self.sampleTransaction]
        initial.detail = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        let deleted = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.delete = { _ in deleted.setValue(true) }
        }
        await store.send(.detail(.dismiss)) { $0.detail = nil }
        await store.finish()
        #expect(deleted.value == false)
    }
```

`DashboardFeatureMutationTests.swift` 末尾加（Dashboard 的 State / 依賴 setup 沿用該檔既有 helper；`refreshAfterMutation` 會觸發多條 effect，所以關 exhaustivity）：

```swift
    @Test("dismissing the detail sheet during the undo window commits the delete and refreshes")
    func testDashboardDismissDuringPendingDeleteCommits() async {
        let tx = Transaction(amount: 100, date: Date(), accountId: UUID().uuidString, type: .expense)
        var detail = TransactionDetailFeature.State(transaction: tx)
        detail.pendingDelete = true
        var initial = DashboardFeature.State()
        initial.detail = detail
        let deleted = LockIsolated<Transaction.ID?>(nil)
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.delete = { deleted.setValue($0) }
            // refreshAfterMutation 會碰到的 closure，全部給空值
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.weeklySparkline = { _ in Array(repeating: 0, count: 7) }
            $0.insightsClient.generateInsights = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.detail(.dismiss)) { $0.detail = nil }
        await store.receive(\.pendingDeleteCommitted)
        await store.finish()
        #expect(deleted.value == tx.id)
    }
```
（若 `refreshAfterMutation` 還碰到其他 closure，依 `DashboardFeatureMutationTests` 既有測試的 `withDependencies` 補齊。）

- [ ] **Step 2: 跑測試確認失敗**

Run: `-only-testing:NeuLedgerTests/TransactionsFeatureTests`、`-only-testing:NeuLedgerTests/DashboardFeatureMutationTests`
Expected: 第一條 FAIL（`transactionDeleted` 從未收到）；Dashboard 編譯錯誤 `no member 'pendingDeleteCommitted'`。

- [ ] **Step 3: 實作 — TransactionDetailView**

`.presentationDetents(...)` 那個修飾子之後加：
```swift
        .interactiveDismissDisabled(store.pendingDelete)
```

- [ ] **Step 4: 實作 — TransactionsFeature**

```swift
            case .detail(.dismiss):
                guard let detail = state.detail, detail.pendingDelete else {
                    state.detail = nil
                    return .none
                }
                // 使用者在 5 秒 Undo 視窗內關掉 sheet：child 的計時器會隨 ifLet 被取消，
                // 由 parent 立即提交刪除，避免「看起來刪了其實沒刪」（health-audit A2）。
                let id = detail.transaction.id
                state.detail = nil
                return .run { send in
                    try await ledger.delete(id)
                    await send(.transactionDeleted(id))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }
```

- [ ] **Step 5: 實作 — DashboardFeature**

`Action` 加 `case pendingDeleteCommitted`。在 `case .detail:` 之前加：
```swift
            case .detail(.dismiss):
                guard let detail = state.detail, detail.pendingDelete else { return .none }
                // 同 TransactionsFeature：Undo 視窗內關 sheet 由 parent 提交刪除。
                let id = detail.transaction.id
                return .run { send in
                    try await ledger.delete(id)
                    await send(.pendingDeleteCommitted)
                } catch: { _, send in
                    await send(.sectionFailed(.transactions, String(localized: "dashboard_section_load_failed", bundle: .main)))
                }

            case .pendingDeleteCommitted:
                return refreshAfterMutation(accountID: state.selectedAccountID)
```
（`state.detail` 由 `ifLet` 在 base reducer 之後設 nil，parent 不需自己清。）

- [ ] **Step 6: 跑測試確認通過**

Run: 兩個 suite + `-only-testing:NeuLedgerTests/TransactionDetailFeatureDeleteWindowTests` → exit=0。

- [ ] **Step 7: 完整 scheme + commit**

```bash
git add Features/Sources/Features/Transactions/TransactionDetailView.swift Features/Sources/Features/Transactions/TransactionsFeature.swift Features/Sources/Features/Dashboard/DashboardFeature.swift NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureMutationTests.swift
git commit -m "fix(detail): commit pending delete when the sheet is dismissed during the undo window [ci skip]"
```

---

### Task 3: App 啟動與 Onboarding 不再卡死

**Files:**
- Modify: `Features/Sources/Features/AppFeature.swift:60-69`
- Modify: `Features/Sources/Features/Onboarding/OnboardingFeature.swift`（State、Action、`finishOnboarding`）
- Modify: `Features/Sources/Features/Onboarding/OnboardingView.swift:70-72`
- Test: `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift`
- Test: `NeuLedgerTests/Tests/FeaturesTests/OnboardingFeatureTests.swift`

**Interfaces:**
- Produces：`OnboardingFeature.Action.setupFailed(String)`、`State.setupError: String?`。

- [ ] **Step 1: 寫失敗測試**

`AppFeatureTests.swift` 末尾加（State / route 的建構方式沿用該檔前兩條測試）：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("splashCompleted falls back to onboarding when canSkipOnboarding throws")
    func testSplashFallsBackToOnboarding() async {
        let store = await TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.canSkipOnboarding = { throw StubError() }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.splashCompleted)
        await store.receive(\.route) {
            #expect($0.destination != nil)   // 不再停在 splash
        }
    }

    @Test("deepLinkReceived ignores a link that fails to parse")
    func testDeepLinkParseFailureIsIgnored() async {
        let store = await TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.parseLink = { _ in throw StubError() }
        }
        await store.send(.deepLinkReceived(URL(string: "neuledger://nope")!))
        await store.finish()
    }
```
（`$0.destination` 的實際欄位名依 `AppFeature.State` 為準；若 `route(.onboarding)` 的 receive 可以精確比對就直接 `await store.receive(.route(.onboarding))`。）

`OnboardingFeatureTests.swift` 末尾加：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("finishOnboarding failure returns to .ready with an inline error instead of hanging on .done")
    func testFinishOnboardingFailureReturnsToReady() async {
        let store = await TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.ledgerClient.setupAccounts = { _ in throw StubError() }
            $0.platformClient.markOnboardingComplete = { }
        }
        await store.send(.finishOnboarding) { $0.setupError = nil }
        await store.receive(\.setupFailed) {
            $0.setupError = "boom"
            $0.currentStep = .ready
        }
    }
```
（若 `send(.finishOnboarding)` 的 state 沒變化，TestStore 會要求拿掉 closure；依實際行為調整為 `await store.send(.finishOnboarding)`。）

- [ ] **Step 2: 跑測試確認失敗**

Run: 兩個 suite → App 第一條 FAIL（沒有 route 到達）；Onboarding 編譯錯誤 `no member 'setupFailed'`。

- [ ] **Step 3: 實作 — AppFeature**

```swift
            case .splashCompleted:
                return .run { send in
                    let canSkipOnboarding = try await platformClient.canSkipOnboarding()
                    await send(.route(canSkipOnboarding ? .main : .onboarding))
                } catch: { _, send in
                    // 讀不到 onboarding 狀態時寧可多問一次，也不要永遠停在 splash（health-audit A4）。
                    await send(.route(.onboarding))
                }

            case let .deepLinkReceived(url):
                return .run { send in
                    let destination = try await platformClient.parseLink(url)
                    await send(.route(destination))
                } catch: { _, _ in
                    // 無法解析的連結直接忽略；此時沒有畫面能承接錯誤。
                }
```

- [ ] **Step 4: 實作 — OnboardingFeature + View**

`State` 加 `public var setupError: String? = nil`；`Action` 加 `case setupFailed(String)`。
```swift
            case .finishOnboarding:
                state.setupError = nil
                let types = state.selectedTypes.sorted(by: { $0.rawValue < $1.rawValue })
                let customs = state.customAccounts
                return .run { send in
                    let accounts = types.map(\.new) + customs.map(\.new)
                    try await ledger.setupAccounts(accounts)
                    platformClient.markOnboardingComplete()
                    try await clock.sleep(for: .milliseconds(1600))
                    await send(.delegate(.onboardingCompleted))
                } catch: { error, send in
                    await send(.setupFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.create)

            case let .setupFailed(message):
                // 退回「準備好了」那一步，讓使用者看得到錯誤並能再按一次（health-audit A3）。
                state.setupError = message
                state.currentStep = .ready
                return .none
```
`OnboardingView.swift` 的 `case .ready:` 改為：
```swift
        case .ready:
            VStack(spacing: 8) {
                if let error = store.setupError {
                    ErrorText(error)
                }
                PrimaryButton("onboarding_ready_button") { store.send(.nextButtonTapped) }
                    .disabled(store.currentStep == .done)
            }
```

- [ ] **Step 5: 跑測試確認通過** — 兩個 suite exit=0。

- [ ] **Step 6: 完整 scheme + commit**

```bash
git add Features/Sources/Features/AppFeature.swift Features/Sources/Features/Onboarding/OnboardingFeature.swift Features/Sources/Features/Onboarding/OnboardingView.swift NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/OnboardingFeatureTests.swift
git commit -m "fix(app,onboarding): splash falls back to onboarding on failure; account setup failure is retryable [ci skip]"
```

---

### Task 4: 記帳表單（AddTransactionFeature）— 儲存失敗可見、防連按、選項載入失敗可見

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`（State、Action、`.task`、`.saveTapped`、`.savedSuccessfully*`）
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift:115`（儲存按鈕）、`:213`（`amountError` 區塊之後）、`:255`（`accountError` 區塊之後）
- Test: `NeuLedgerTests/Tests/FeaturesTests/AddTransactionFeatureTests.swift`

**Interfaces:**
- Produces：`State.isSaving: Bool`、`State.saveError: String?`、`State.optionsError: String?`、`Action.saveFailed(String)`、`Action.optionsLoadFailed(String)`。

- [ ] **Step 1: 寫失敗測試**

在 `@Suite("AddTransactionFeature — recurring template")` 這個 struct 末尾加（沿用該 suite 的 `Self.account` / `Self.category` 與既有測試的 `withDependencies` 形狀）：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("saveTapped: record failure sets saveError, resets isSaving, and does not dismiss")
    func testSaveFailureIsVisible() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense), date: Date(timeIntervalSince1970: 1_000_000))
        initial.amountText = "500"
        initial.accountId  = Self.account.id
        initial.categoryId = Self.category.id
        let dismissed = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [Self.account] }
            $0.ledgerClient.listCategories     = { _ in [Self.category] }
            $0.ledgerClient.defaultAccountId   = { nil }
            $0.captureClient.isAvailable       = { false }
            $0.ledgerClient.record             = { _ in throw StubError() }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }
        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.saveError = "boom"
        }
        #expect(dismissed.value == false)
    }

    @Test("saveTapped while isSaving is ignored (no double write)")
    func testSaveWhileSavingIsIgnored() async {
        var initial = AddTransactionFeature.State(mode: .add(.expense), date: Date())
        initial.amountText = "500"
        initial.accountId  = Self.account.id
        initial.categoryId = Self.category.id
        initial.isSaving   = true
        let records = LockIsolated(0)
        let store = await TestStore(initialState: initial) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.record = { _ in records.withValue { $0 += 1 } }
        }
        await store.send(.saveTapped)
        await store.finish()
        #expect(records.value == 0)
    }

    @Test(".task failure sets optionsError and clears isLoading")
    func testOptionsLoadFailure() async {
        let store = await TestStore(initialState: AddTransactionFeature.State(mode: .add(.expense), date: Date())) {
            AddTransactionFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { throw StubError() }
            $0.ledgerClient.listCategories     = { _ in [] }
            $0.ledgerClient.defaultAccountId   = { nil }
            $0.captureClient.isAvailable       = { false }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.optionsLoadFailed) {
            $0.isLoading = false
            $0.optionsError = "boom"
        }
    }
```

- [ ] **Step 2: 跑測試確認失敗** — 編譯錯誤 `no member 'isSaving'`。

- [ ] **Step 3: 實作 — State / Action**

`State` 加：
```swift
        /// 儲存進行中；View 停用儲存鈕、reducer 忽略重複的 saveTapped。
        public var isSaving: Bool = false
        /// 最近一次儲存失敗的訊息（inline 顯示）。
        public var saveError: String? = nil
        /// 帳戶 / 分類選項載入失敗的訊息。
        public var optionsError: String? = nil
```
`Action` 加：`case saveFailed(String)`、`case optionsLoadFailed(String)`。

- [ ] **Step 4: 實作 — effects**

`.task`：
```swift
            case .task:
                state.isLoading = true
                state.optionsError = nil
                return .run { send in
                    async let accounts = ledger.listActiveAccounts()
                    async let categories = ledger.listCategories(nil)
                    let (a, c) = try await (accounts, categories)
                    await send(.optionsLoaded(accounts: a, categories: c))
                } catch: { error, send in
                    await send(.optionsLoadFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoadFailed(message):
                state.isLoading = false
                state.optionsError = message
                return .none
```
`.saveTapped`：在所有驗證 `guard` 之後、`return .run { send in`（目前的 `:281`）之前插入：
```swift
                guard !state.isSaving else { return .none }
                state.isSaving = true
                state.saveError = nil
```
並把那個 `.run { send in ... }` 的結尾（`await send(.savedSuccessfully)` 後的 `}`）改成：
```swift
                } catch: { error, send in
                    await send(.saveFailed(error.localizedDescription))
                }
```
新增：
```swift
            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none
```
`.savedSuccessfully` 與 `.savedSuccessfullyWithTransaction` 的 case 開頭各加 `state.isSaving = false`。（recurring confirmation 路徑走 `delegate(.savedRecurringConfirmation)` 後 `return`，sheet 由 parent 收掉，`isSaving` 留 true 無害。）

- [ ] **Step 5: 實作 — View**

`:115` 儲存按鈕：`Button(String(localized: "common_save")) { store.send(.saveTapped) }.disabled(store.isSaving)`。
`:213` `if let error = store.amountError { ... }` 區塊之後加：
```swift
                if let error = store.saveError {
                    ErrorText(error)
                }
```
`:255` `if let error = store.accountError { ... }` 區塊之後加：
```swift
                if let error = store.optionsError {
                    ErrorText(error)
                }
```

- [ ] **Step 6: 跑測試確認通過** — `AddTransactionFeatureTests` exit=0（兩個 suite 都在同一檔）。

- [ ] **Step 7: 完整 scheme + commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift Features/Sources/Features/Dashboard/AddTransactionView.swift NeuLedgerTests/Tests/FeaturesTests/AddTransactionFeatureTests.swift
git commit -m "fix(add-transaction): inline save/options errors, guard against double save [ci skip]"
```

---

### Task 5: 四張表單 + 篩選頁 — 同一形狀套齊（AddEditAccount / AddEditCategory / AddEditTag / BudgetForm / FilterFeature.task）

**Files:**
- Modify: `Features/Sources/Features/AccountManagement/AddEditAccountFeature.swift`、`AddEditAccountView.swift:56,134`
- Modify: `Features/Sources/Features/CategoryManagement/AddEditCategoryFeature.swift`、`AddEditCategoryView.swift:51,166`
- Modify: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift`、`AddEditTagView.swift:47,99`
- Modify: `Features/Sources/Features/BudgetManagement/BudgetFormFeature.swift`、`BudgetFormView.swift:42-45,119`
- Modify: `Features/Sources/Features/Transactions/FilterFeature.swift`（`.task`）、`FilterView.swift`（表單最上方）
- Test: `AddEditAccountFeatureTests.swift`、`AddEditCategoryFeatureTests.swift`、`AddEditTagFeatureTests.swift`、`BudgetFormFeatureTests.swift`、`FilterFeatureTests.swift`（皆在 `NeuLedgerTests/Tests/FeaturesTests/`）

**Interfaces:**
- Produces（每張表單相同）：`State.isSaving: Bool`、`State.saveError: String?`、`Action.saveFailed(String)`；FilterFeature：`State.optionsError: String?`、`Action.optionsLoadFailed(String)`。

- [ ] **Step 1: 寫失敗測試（每檔一條）**

四張表單各加一條，**複製該檔既有的 happy-path 儲存測試 setup**（它已經把驗證需要的 state 與 closure 準備好），只把寫入 closure 改成 throw，斷言改成下列形狀（以 Account 為例，其他三張把 `createAccount` 換成 `createCategory` / `createTag` / `planningClient.create`）：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("saveTapped: create failure sets saveError, resets isSaving, does not dismiss")
    func testSaveFailureIsVisible() async {
        // <複製既有 happy-path 測試的 initialState 與 withDependencies>
        //   ...其中 $0.ledgerClient.createAccount = { _ in throw StubError() }
        //   $0.dismiss = DismissEffect { dismissed.setValue(true) }
        await store.send(.saveTapped) {
            $0.nameError = nil          // 既有行為：驗證通過會先清 nameError（若該表單沒有這行就拿掉）
            $0.isSaving = true
        }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.saveError = "boom"
        }
        #expect(dismissed.value == false)
    }
```
`FilterFeatureTests.swift` 加：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test(".task failure sets optionsError instead of hanging")
    func testTaskFailureSetsOptionsError() async {
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in throw StubError() }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
        }
        await store.send(.task)
        await store.receive(\.optionsLoadFailed) { $0.optionsError = "boom" }
    }
```

- [ ] **Step 2: 跑測試確認失敗** — 五個 suite 各自編譯錯誤（`isSaving` / `optionsLoadFailed` 不存在）。

- [ ] **Step 3: 實作 — 四張表單（每張都做同樣五件事）**

1. `State` 加 `public var isSaving: Bool = false` 與 `public var saveError: String? = nil`。
2. `Action` 加 `case saveFailed(String)`。
3. `case .saveTapped:` 在驗證全部通過後、`return .run` 之前加：
   ```swift
                guard !state.isSaving else { return .none }
                state.isSaving = true
                state.saveError = nil
   ```
   並把 `.run { send in ... await send(.savedSuccessfully) }` 改成 `.run { ... } catch: { error, send in await send(.saveFailed(error.localizedDescription)) }`。
4. 新增：
   ```swift
            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none
   ```
   `case .savedSuccessfully:` 開頭加 `state.isSaving = false`。
5. View：儲存按鈕加 `.disabled(store.isSaving)`（Budget 是 `.disabled(!isSaveEnabled || store.isSaving)`）；在 `if let error = store.nameError { ErrorText(error) }`（Budget 用 `amountError` 那塊）之後加 `if let error = store.saveError { ErrorText(error) }`。

- [ ] **Step 4: 實作 — FilterFeature**

`State` 加 `public var optionsError: String? = nil`；`Action` 加 `case optionsLoadFailed(String)`；
```swift
            case .task:
                state.optionsError = nil
                return .run { send in
                    async let categories = ledger.listCategories(nil)
                    async let accounts = ledger.listAccounts()
                    async let tags = ledger.listTags()
                    let (c, a, t) = try await (categories, accounts, tags)
                    await send(.optionsLoaded(categories: c, accounts: a, tags: t))
                } catch: { error, send in
                    await send(.optionsLoadFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoadFailed(message):
                state.optionsError = message
                return .none
```
`FilterView`：表單內容最上方（第一個 section 之前）加 `if let error = store.optionsError { ErrorText(error).padding(.horizontal, 22) }`。

- [ ] **Step 5: 跑測試確認通過** — 五個 suite exit=0。

- [ ] **Step 6: 完整 scheme + commit**

```bash
git add Features/Sources/Features/AccountManagement/AddEditAccount*.swift Features/Sources/Features/CategoryManagement/AddEditCategory*.swift Features/Sources/Features/TagManagement/AddEditTag*.swift Features/Sources/Features/BudgetManagement/BudgetForm*.swift Features/Sources/Features/Transactions/FilterFeature.swift Features/Sources/Features/Transactions/FilterView.swift NeuLedgerTests/Tests/FeaturesTests/AddEdit*FeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/BudgetFormFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/FilterFeatureTests.swift
git commit -m "fix(forms): isSaving/saveError shape on account, category, tag, budget forms; filter options load failure inline [ci skip]"
```

---

### Task 6: 五個管理清單頁 — 載入 / 刪除 / 封存失敗可見，delegate 改在寫入完成後才送

**Files:**
- Modify: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift`、`AccountManagementView.swift:19`
- Modify: `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift`、`CategoryManagementView.swift:25`
- Modify: `Features/Sources/Features/TagManagement/TagManagementFeature.swift`、`TagManagementView.swift:19`
- Modify: `Features/Sources/Features/BudgetManagement/BudgetManagementFeature.swift`、`BudgetManagementView.swift:19`
- Modify: `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`、`CarrierManagementView.swift:23`
- Test: `AccountManagementFeatureTests.swift`、`CategoryManagementFeatureTests.swift`、`TagManagementFeatureTests.swift`、`BudgetManagementFeatureTests.swift`、`CarrierManagementFeatureTests.swift`

**Interfaces:**
- Produces（每個 Feature 相同）：`State.loadError: String?`、`State.actionError: String?`、`Action.loadFailed(String)`、`Action.actionFailed(String)`。

- [ ] **Step 1: 寫失敗測試**

每檔加 `private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }`，然後：

`CategoryManagementFeatureTests`（刪除預設分類被 client 拒絕是真實情境）：
```swift
    @Test("deleteConfirmed failure sets actionError and keeps the list")
    func testDeleteFailureKeepsList() async {
        let category = Domain.Category(name: "Food", icon: "fork.knife", color: "#FF6B6B", type: .expense, isDefault: true)
        var initial = CategoryManagementFeature.State()
        initial.categories = [category]
        let store = await TestStore(initialState: initial) {
            CategoryManagementFeature()
        } withDependencies: {
            $0.ledgerClient.deleteCategory = { _ in throw StubError() }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.alert(.presented(.deleteConfirmed(category.id))))
        await store.receive(\.actionFailed) { $0.actionError = "boom" }
        await MainActor.run { #expect(store.state.categories.count == 1) }
    }
```
（`alert(.presented(.deleteConfirmed(_:)))` 的路徑名依該 Feature 的 `Action.Alert` 為準；若 alert state 必須先存在才能 present，依既有刪除測試的作法先 `send(.deleteRequested(id))`。）

`AccountManagementFeatureTests`（`.concatenate` 之後順序固定）：
```swift
    @Test("archiveConfirmed reloads accounts before notifying the delegate")
    func testArchiveNotifiesAfterReload() async {
        let account = Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759")
        var initial = AccountManagementFeature.State()
        initial.accounts = [account]
        var archived = account; archived.isArchived = true
        let store = await TestStore(initialState: initial) {
            AccountManagementFeature()
        } withDependencies: {
            $0.ledgerClient.archiveAccount = { _ in }
            $0.ledgerClient.listAccounts = { [archived] }
            $0.ledgerClient.balances = { [:] }
        }
        await store.send(.alert(.presented(.archiveConfirmed(account.id))))
        await store.receive(\.accountsLoaded) {
            $0.isLoading = false
            $0.accounts = [archived]
        }
        await store.receive(\.balancesLoaded)
        await store.receive(\.delegate.accountsChanged)
    }

    @Test("deleteRequested failure sets actionError instead of a dead button")
    func testDeleteRequestedFailure() async {
        let store = await TestStore(initialState: AccountManagementFeature.State()) {
            AccountManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in throw StubError() }
        }
        await store.send(.deleteRequested(UUID().uuidString))
        await store.receive(\.actionFailed) { $0.actionError = "boom" }
    }
```
`TagManagementFeatureTests` / `BudgetManagementFeatureTests` / `CarrierManagementFeatureTests` 各加：
```swift
    @Test(".task failure sets loadError and clears isLoading")
    func testTaskFailure() async {
        let store = await TestStore(initialState: <Feature>.State()) {
            <Feature>()
        } withDependencies: {
            $0.<client>.<listMethod> = { throw StubError() }   // Tag: ledgerClient.listTags；Budget: planningClient.listAll；Carrier: carrierClient.listAll
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.loadFailed) {
            $0.isLoading = false
            $0.loadError = "boom"
        }
    }
```

- [ ] **Step 2: 跑測試確認失敗** — 各 suite 編譯錯誤。

- [ ] **Step 3: 實作 — 共同形狀（五個 Feature 都做）**

1. `State` 加 `public var loadError: String? = nil`、`public var actionError: String? = nil`。
2. `Action` 加 `case loadFailed(String)`、`case actionFailed(String)`。
3. `.task` 的 `.run` 補 `catch: { error, send in await send(.loadFailed(error.localizedDescription)) }`；`xLoaded` case 開頭加 `state.loadError = nil; state.actionError = nil`（Account 的 `accountsLoaded` 已有 `isLoading = false`）。
4. 每條「寫入後重載」的 `.run`（刪除 / 封存 / 解封存 / addEdit saved 後重載）補 `catch: { error, send in await send(.actionFailed(error.localizedDescription)) }`。Carrier 的 `deleteConfirmed` 已有 catch（重載清單），在其 catch 內**多送一個** `.actionFailed(error.localizedDescription)`（要把 `catch: { _, send in` 改成 `catch: { error, send in`）。
5. 新增：
   ```swift
            case let .loadFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none

            case let .actionFailed(message):
                state.actionError = message
                return .none
   ```

- [ ] **Step 4: 實作 — AccountManagement 專屬**

四處 `.merge(.run { 寫入 + 重載 }, .send(.delegate(.accountsChanged)))`（`archiveConfirmed`、`deleteConfirmed`、`unarchiveTapped`、`addEdit(.presented(.delegate(.saved)))`）全部改成 `.concatenate(...)`，讓 Settings 收到 delegate 時資料已落地。`deleteRequested`：
```swift
            case let .deleteRequested(id):
                return .run { send in
                    let transactions = try await ledger.listAll(TransactionFilter(accountIds: [id]))
                    if transactions.isEmpty {
                        await send(.showDeleteConfirmation(id))
                    } else {
                        await send(.showArchiveConfirmation(id))
                    }
                } catch: { error, send in
                    await send(.actionFailed(error.localizedDescription))
                }
```

- [ ] **Step 5: 實作 — Views（五個相同）**

在 `if store.isLoading {` 那個 if/else 鏈加一段 `else if let error = store.loadError { SectionFailureView(message: error) { store.send(.task) } }`；在清單內容最上方（`ScrollView` 的第一個子 view 之前）加 `if let error = store.actionError { ErrorText(error).padding(.horizontal, 16) }`。

- [ ] **Step 6: 跑測試確認通過** — 五個 suite exit=0；若 Account 既有測試因 `.merge`→`.concatenate` 改了 receive 順序，只調整順序不放寬斷言。

- [ ] **Step 7: 完整 scheme + commit**

```bash
git add Features/Sources/Features/AccountManagement/AccountManagement*.swift Features/Sources/Features/CategoryManagement/CategoryManagement*.swift Features/Sources/Features/TagManagement/TagManagement*.swift Features/Sources/Features/BudgetManagement/BudgetManagement*.swift Features/Sources/Features/CarrierManagement/CarrierManagement*.swift NeuLedgerTests/Tests/FeaturesTests/*ManagementFeatureTests.swift
git commit -m "fix(management): inline load/action errors on all five list screens; account delegate fires after write completes [ci skip]"
```

---

### Task 7: 其他 effect 缺口 — 手動同步、每日提醒、AI 擷取取消

**Files:**
- Modify: `Features/Sources/Features/Settings/SyncSettings/SyncSettingsFeature.swift:98-109`、`SyncSettingsView.swift:308-336`
- Modify: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift:115,134`、`NotificationSettingsView.swift:119`
- Modify: `Features/Sources/Features/MainTab/AccessoryBarFeature.swift:87-100`
- Test: `SyncSettingsFeatureTests.swift`、`NotificationSettingsFeatureTests.swift`、`AccessoryBarFeatureTests.swift`

**Interfaces:**
- Produces：`SyncSettingsFeature.Action.syncNowFailed(String)` / `State.syncNowError`；`NotificationSettingsFeature.Action.reminderScheduleFailed(String)` / `State.reminderError`。

- [ ] **Step 1: 寫失敗測試**

`SyncSettingsFeatureTests`：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("syncNowTapped failure shows syncNowError and does not touch lastSyncedAt")
    func testSyncNowFailure() async {
        let before = Date(timeIntervalSince1970: 1_000)
        var initial = SyncSettingsFeature.State()
        initial.lastSyncedAt = before
        let store = await TestStore(initialState: initial) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.platformClient.requestSyncNow = { throw StubError() }
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.syncNowTapped) {
            $0.isManualSyncing = true
            $0.syncNowError = nil
        }
        await store.receive(\.syncNowFailed) {
            $0.isManualSyncing = false
            $0.syncNowError = "boom"
        }
        await MainActor.run { #expect(store.state.lastSyncedAt == before) }
    }
```
`NotificationSettingsFeatureTests`：
```swift
    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("dailyReminderToggled(true): schedule failure reverts the toggle and shows reminderError")
    func testScheduleFailureRevertsToggle() async {
        var initial = NotificationSettingsFeature.State()
        initial.isAuthorized = true
        let enabledLog = LockIsolated<[Bool]>([])
        let store = await TestStore(initialState: initial) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.platformClient.setDailyReminderEnabled = { enabledLog.withValue { $0.append($1) } }   // 若簽章是 (Bool) -> Void，寫成 { enabledLog.withValue { log in log.append($0) } }
            $0.platformClient.setReminderTime = { _ in }
            $0.platformClient.scheduleDailyReminder = { throw StubError() }
        }
        await store.send(.dailyReminderToggled(true)) { $0.dailyReminderEnabled = true }
        await store.receive(\.reminderScheduleFailed) {
            $0.dailyReminderEnabled = false
            $0.reminderError = "boom"
        }
        #expect(enabledLog.value.last == false)
    }
```
`AccessoryBarFeatureTests`（沿用該檔既有 submit 測試的 setup；擷取 closure 換成會被取消的長睡眠）：
```swift
    @Test("aiInputDismissed cancels an in-flight extraction so no late sheet pops up")
    func testDismissCancelsExtraction() async {
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐 120"
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.captureClient.isAvailable = { true }
            $0.captureClient.extractFromText = { _ in
                try await Task.sleep(for: .seconds(60))   // 若沒被取消，store.finish 會逾時失敗
                return ExtractedTransaction(amount: 120, category: nil, note: nil, type: nil)
            }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.aiInputSubmitted)
        await store.send(.aiInputDismissed)
        await store.finish(timeout: .seconds(2))
    }
```
（`ExtractedTransaction` 的 init 參數與 `aiInputSubmitted` 的實際名稱以既有測試為準。）

- [ ] **Step 2: 跑測試確認失敗** — Sync / Notification 編譯錯誤；AccessoryBar 的 `finish` 逾時 FAIL。

- [ ] **Step 3: 實作 — SyncSettings**

`State` 加 `public var syncNowError: String? = nil`；`Action` 加 `case syncNowFailed(String)`；
```swift
            case .syncNowTapped:
                guard !state.isManualSyncing else { return .none }
                state.isManualSyncing = true
                state.syncNowError = nil
                return .run { [clock] send in
                    let start = Date()
                    try await platformClient.requestSyncNow()
                    let remaining = 1.0 - Date().timeIntervalSince(start)
                    if remaining > 0 {
                        try? await clock.sleep(for: .seconds(remaining))
                    }
                    await send(.syncNowFinished(platformClient.lastSyncedAt() ?? Date()))
                } catch: { error, send in
                    await send(.syncNowFailed(error.localizedDescription))
                }

            case let .syncNowFailed(message):
                state.isManualSyncing = false
                state.syncNowError = message
                return .none
```
`SyncSettingsView`：立即同步按鈕（`:308-336`）下方加 `if let error = store.syncNowError { ErrorText(error) }`。

- [ ] **Step 4: 實作 — NotificationSettings**

`State` 加 `public var reminderError: String? = nil`；`Action` 加 `case reminderScheduleFailed(String)`；兩處 `return .run { _ in try await platformClient.scheduleDailyReminder() }` 改成：
```swift
                    return .run { _ in
                        try await platformClient.scheduleDailyReminder()
                    } catch: { error, send in
                        await send(.reminderScheduleFailed(error.localizedDescription))
                    }
```
新增：
```swift
            case let .reminderScheduleFailed(message):
                // 排程失敗就把開關關回去，否則使用者以為提醒已設好（health-audit「其他確認項」）。
                state.dailyReminderEnabled = false
                platformClient.setDailyReminderEnabled(false)
                state.reminderError = message
                return .none
```
`NotificationSettingsView`：每日提醒 Toggle 那一列（`:119`）下方加 `if let error = store.reminderError { ErrorText(error) }`。

- [ ] **Step 5: 實作 — AccessoryBar**

```swift
            case .aiInputDismissed:
                let wasRecording = state.isRecording
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                state.aiInputError = nil
                state.isRecording = false
                // 關掉輸入列就一併取消擷取，避免遲到的結果彈出新增頁（health-audit A9）。
                var effects: [Effect<Action>] = [.cancel(id: CancelID.aiExtraction)]
                if wasRecording {
                    effects.append(.cancel(id: CancelID.speechRecording))
                    effects.append(.run { _ in captureClient.stopVoiceSession() })
                }
                return .merge(effects)
```

- [ ] **Step 6: 跑測試確認通過** — 三個 suite exit=0。

- [ ] **Step 7: 完整 scheme + commit**

```bash
git add Features/Sources/Features/Settings/SyncSettings/SyncSettings*.swift Features/Sources/Features/NotificationSettings/NotificationSettings*.swift Features/Sources/Features/MainTab/AccessoryBarFeature.swift NeuLedgerTests/Tests/FeaturesTests/SyncSettingsFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/NotificationSettingsFeatureTests.swift NeuLedgerTests/Tests/FeaturesTests/AccessoryBarFeatureTests.swift
git commit -m "fix(settings,accessory): manual sync and reminder scheduling report failures; dismissing AI input cancels extraction [ci skip]"
```

---

## 完成後

- 跑 CLAUDE.md 的五條 ast-grep audit。
- `grep -rn 'catch:' Features/Sources/Features | wc -l` 應 ≥ 28 + 原有的 4。
- 開 PR：`fix: surface effect failures inline and commit pending deletes on dismiss`（不帶 `[ci skip]`），body 列行為變更：搜尋現在尊重篩選；帳戶管理的 delegate 在寫入完成後才送；Undo 視窗內關 sheet 會直接刪除。
- 記入 PR B 的待辦：AnalysisFeature 加 `CancelID.load` 與 `loadError`（R3）。

## Self-review

- Spec coverage：A1→T4、A2→T2、A3/A4/A5(啟動部分)→T3、A6/A7→T1、A9→T7、A10→T5+T6、A12→T7、B9→T4+T5、Notification/Account merge→T7/T6、known FilterFeature.task 與 BudgetForm→T5。A8（tab 同步）、A11（Analysis）刻意不在本 PR（A8 另開；A11 併 PR B）。
- 型別一致：`loadFailed(String)` / `actionFailed(String)` / `saveFailed(String)` / `optionsLoadFailed(String)` 四個名字在各 Task 內一致；`StubError` 每檔 private 各自宣告，`errorDescription` 固定 `"boom"`。
- Placeholder 掃描：測試中「複製既有 happy-path setup」與「以既有測試為準」的地方是刻意交由實作者對照該檔既有內容，不是待填空；其餘皆給完整程式碼。
