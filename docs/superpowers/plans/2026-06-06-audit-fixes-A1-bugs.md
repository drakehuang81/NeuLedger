# PR A1 — 審查修復：4 個行為級 bug Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修復 presentation layer 審查（`docs/audits/2026-06-06-presentation-layer-audit.md`）發現的 4 個行為級 bug：AIAssistant 永不顯示的 gating 死鎖、Transactions 重載丟失 activeFilter、AddEditAccount 預設值與 AccountType SSOT 分歧、RecurringForm transfer 缺轉入帳戶 picker 與驗證。

**Architecture:** 全部走 TCA 1.23.1 既有模式（`@Reducer` / `@ObservableState` / `@DependencyClient`）。每個 task 獨立 TDD：先寫 failing test（Swift Testing + `TestStore`）→ 跑紅 → 最小實作 → 跑綠 → commit。Task 4 同時動 Feature/View/Localizable.xcstrings 三處，以 `AddTransactionFeature` 的 transfer 驗證為對齊基準。

**Tech Stack:** Swift / TCA 1.23.1 / Swift Testing（`@Suite`、`@Test`）/ xcodebuild（iPhone 17 Pro 模擬器）

**分支：** `fix/audit-behavior-bugs`（自 `developer` 切出）。所有 commit 標題尾帶 `[ci skip]`。

**Module boundary 注意：** 所有改動都在 `Features` SPM target 內（`Features/Sources/Features/`）+ 測試 target `NeuLedgerTests` + app resource（`NeuLedger/Resources/Localizable.xcstrings`）。`AccountType.defaultIcon/.defaultColor` 位於 Domain 的 `public extension`（`Features/Sources/Domain/Enums/AccountType.swift:24-62`），跨 target 可直接使用，無需修改 Domain。

**測試指令（每個 task 的紅/綠驗證）：**

```bash
# 單一 suite
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/<SuiteName>

# 完整 scheme（PR 前最終驗證，必跑）
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

### Task 1: AIAssistant availability 死鎖修復

**問題：** `AnalysisView.swift:120` 以 `if store.aiAssistant.isAvailable` gate `AIAssistantCardView`，但 `isAvailable` 預設 `false`（`AIAssistantFeature.swift:32`），唯一寫 `true` 的地方是子 reducer 的 `.task`（`AIAssistantFeature.swift:54-55`），而 `.aiAssistant(.task)` 唯一的觸發點是 `AIAssistantCardView` 自身的 `.task` modifier —— View 被 gate 擋住永不掛載 → `.task` 永不觸發 → 死鎖，AI 助理區塊永遠不顯示。子 reducer 已正確掛載於 `Scope`（`AnalysisFeature.swift:287`），只缺 parent `.task` 的轉送。

**Files:**
- Modify: `Features/Sources/Features/Analysis/AnalysisFeature.swift:100-107`（`.task` 分支）
- Test: `NeuLedgerTests/Tests/FeaturesTests/AnalysisFeatureTests.swift`（新增一個 `@Test`）

- [ ] **Step 1: 寫 failing test**

在 `AnalysisFeatureTests.swift` 的 suite 內（仿 `testPeriodChanged` 的 stub 樣式，blood rule①：reducer 路徑碰到的每個 closure 都要 stub）加：

```swift
// MARK: - AI Assistant availability

@Test("task forwards aiAssistant.task so the availability gate can resolve")
func testTaskForwardsAIAssistantTask() async {
    let store = await TestStore(initialState: AnalysisFeature.State()) {
        AnalysisFeature()
    } withDependencies: {
        $0.ledgerClient.listActiveAccounts = { [] }
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.listCategories = { _ in [] }
        $0.planningClient.listActive = { [] }
        $0.insightsClient.isAIAvailable = { true }
    }
    await MainActor.run {
        store.exhaustivity = .off
    }

    await store.send(.task)
    // 修復前：.task 只 merge accounts 載入與 .loadData，永遠等不到這個 receive
    await store.receive(\.aiAssistant.task) {
        $0.aiAssistant.isAvailable = true
    }
    await store.skipInFlightEffects()
}
```

- [ ] **Step 2: 跑測試驗證失敗**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/AnalysisFeatureTests`
Expected: FAIL — `testTaskForwardsAIAssistantTask` 在 `store.receive(\.aiAssistant.task)` 逾時（收不到該 action）。其餘既有測試保持綠。

- [ ] **Step 3: 最小實作**

`AnalysisFeature.swift` `.task` 分支（line 100-107）改為三路 merge：

```swift
case .task:
    return .merge(
        .run { [ledger] send in
            let accounts = (try? await ledger.listActiveAccounts()) ?? []
            await send(.accountsLoaded(accounts))
        },
        .send(.loadData),
        .send(.aiAssistant(.task))
    )
```

- [ ] **Step 4: 跑測試驗證通過**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/AnalysisFeatureTests`
Expected: 全 suite PASS（含新測試）。注意：若既有 `.task`/`loadData` 相關測試因新增 `.aiAssistant(.task)` action 而 fail（exhaustivity 全開的測試會收到未預期 action），在該測試補上 `store.receive(\.aiAssistant.task)`（並視其 `insightsClient.isAIAvailable` stub 值斷言 `isAvailable`）；若該測試未 stub `isAIAvailable`，補 `$0.insightsClient.isAIAvailable = { false }`（此時 receive 的 state 變化為無，closure 可省）。

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Analysis/AnalysisFeature.swift NeuLedgerTests/Tests/FeaturesTests/AnalysisFeatureTests.swift
git commit -m "fix(analysis): forward aiAssistant.task from parent task to break availability gating deadlock [ci skip]"
```

---

### Task 2: Transactions 三條重載路徑保留 activeFilter

**問題：** `state.activeFilter` 是清單範圍的 source of truth，但只有 `.filter(.filterApplied)`（line 124-129）尊重它。`.task`（line 87）、清空搜尋（line 102）、`addTransaction(.delegate(.saved))` 重載（line 196）都硬編 `TransactionFilter()` —— 套用 filter 後新增交易或清空搜尋，filter badge 仍亮但清單回到全部。

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift:84-110, 193-198`
- Test: `NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift`（新增兩個 `@Test`）

- [ ] **Step 1: 寫 failing tests**

在 `TransactionsFeatureTests.swift` suite 內加（`TransactionFilter` 的 `types` 參數為 `Set<TransactionType>?`；若 suite 內已有 sample filter helper 則沿用）：

```swift
// MARK: - activeFilter preservation (audit A1)

@Test("addTransaction saved reload queries with activeFilter, not an empty filter")
func testSavedReloadUsesActiveFilter() async {
    let captured = LockIsolated<TransactionFilter?>(nil)
    let activeFilter = TransactionFilter(types: [.expense])

    var initialState = TransactionsFeature.State()
    initialState.activeFilter = activeFilter
    initialState.addTransaction = AddTransactionFeature.State(mode: .add(.expense))

    let store = await TestStore(initialState: initialState) {
        TransactionsFeature()
    } withDependencies: {
        $0.ledgerClient.listAll = { filter in
            captured.setValue(filter)
            return []
        }
    }

    await store.send(.addTransaction(.presented(.delegate(.saved)))) {
        $0.addTransaction = nil
    }
    await store.receive(\.transactionsLoaded)
    #expect(captured.value == activeFilter)
}

@Test("clearing search restores the activeFilter-scoped list, not the full list")
func testClearSearchUsesActiveFilter() async {
    let captured = LockIsolated<TransactionFilter?>(nil)
    let activeFilter = TransactionFilter(types: [.expense])

    var initialState = TransactionsFeature.State()
    initialState.activeFilter = activeFilter
    initialState.searchText = "abc"

    let store = await TestStore(initialState: initialState) {
        TransactionsFeature()
    } withDependencies: {
        $0.ledgerClient.listAll = { filter in
            captured.setValue(filter)
            return []
        }
    }

    await store.send(.searchTextChanged("")) {
        $0.searchText = ""
    }
    await store.receive(\.transactionsLoaded)
    #expect(captured.value == activeFilter)
}
```

注意：`ledger.listAll` stub 的回傳元素型別依既有測試（回傳值經 `.map(\.transaction)` 取交易），回傳 `[]` 即可由型別推斷。

- [ ] **Step 2: 跑測試驗證失敗**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/TransactionsFeatureTests`
Expected: 兩個新測試 FAIL 於 `#expect(captured.value == activeFilter)`（captured 為空 `TransactionFilter()`）。

- [ ] **Step 3: 最小實作**

`TransactionsFeature.swift` 三處改為 capture `state.activeFilter`：

```swift
// line 84-90 (.task)
case .task:
    state.isLoading = true
    return .run { [filter = state.activeFilter] send in
        let transactions = try await ledger.listAll(filter: filter)
        await send(.transactionsLoaded(transactions.map(\.transaction)))
    }
    .cancellable(id: CancelID.task)
```

```swift
// line 98-106 (searchTextChanged 的 text.isEmpty 分支)
case let .searchTextChanged(text):
    state.searchText = text
    if text.isEmpty {
        return .run { [filter = state.activeFilter] send in
            let transactions = try await ledger.listAll(filter: filter)
            await send(.transactionsLoaded(transactions.map(\.transaction)))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
```

```swift
// line 193-198 (addTransaction saved)
case .addTransaction(.presented(.delegate(.saved))):
    state.addTransaction = nil
    return .run { [filter = state.activeFilter] send in
        let transactions = try await ledger.listAll(filter: filter)
        await send(.transactionsLoaded(transactions.map(\.transaction)))
    }
```

- [ ] **Step 4: 跑測試驗證通過**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/TransactionsFeatureTests`
Expected: 全 suite PASS（既有測試的 `activeFilter` 預設為空 `TransactionFilter()`，行為等價，不應受影響）。

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Transactions/TransactionsFeature.swift NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift
git commit -m "fix(transactions): preserve activeFilter across task/clear-search/saved reload paths [ci skip]"
```

---

### Task 3: AddEditAccount 預設值對齊 AccountType SSOT

**問題：** `AddEditAccountFeature.State.init` 的 `.add` 分支（line 36-40）預選 `type = .cash` 卻硬寫 `icon = "creditcard"`、`colorHex = "#3478F6"`，與 SSOT（`AccountType.cash.defaultIcon == "banknote"`、`AccountType.cash.defaultColor == "#8E8E93"`，見 `Features/Sources/Domain/Enums/AccountType.swift:45-62`）不一致 —— 新增帳戶表單預設顯示信用卡圖示與品牌藍。

**Files:**
- Modify: `Features/Sources/Features/AccountManagement/AddEditAccountFeature.swift:36-40`
- Create: `NeuLedgerTests/Tests/FeaturesTests/AddEditAccountFeatureTests.swift`（此 feature 目前零測試；本 task 建檔起步，PR B1 再補滿整套）

- [ ] **Step 1: 寫 failing test（建新測試檔）**

Create `NeuLedgerTests/Tests/FeaturesTests/AddEditAccountFeatureTests.swift`：

```swift
import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("AddEditAccountFeature Tests")
struct AddEditAccountFeatureTests {

    // MARK: - State init defaults (audit A1)

    @Test("add mode defaults follow AccountType.cash SSOT (defaultIcon/defaultColor)")
    func testAddModeDefaultsFollowAccountTypeSSOT() async {
        let state = AddEditAccountFeature.State(mode: .add)
        #expect(state.type == .cash)
        #expect(state.icon == AccountType.cash.defaultIcon)
        #expect(state.colorHex == AccountType.cash.defaultColor)
    }

    @Test("edit mode init copies the account's own icon and color")
    func testEditModeCopiesAccountValues() async {
        let account = Account(
            id: "acc-1", name: "玉山銀行", type: .bank,
            icon: "building.columns", color: "#0A84FF",
            sortOrder: 0, isArchived: false, createdAt: Date()
        )
        let state = AddEditAccountFeature.State(mode: .edit(account))
        #expect(state.icon == "building.columns")
        #expect(state.colorHex == "#0A84FF")
    }
}
```

注意：新測試檔需確認被 `NeuLedgerTests` target 收錄 —— 先檢查 `NeuLedger.xcodeproj` 是否對 `NeuLedgerTests/Tests/` 使用 folder reference / `PBXFileSystemSynchronizedRootGroup`（若是，落檔即收錄）；若是逐檔列舉的舊式 project，需把檔案加進 target（可用 `ruby -e` + xcodeproj gem 或回報 BLOCKED）。

- [ ] **Step 2: 跑測試驗證失敗**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/AddEditAccountFeatureTests`
Expected: `testAddModeDefaultsFollowAccountTypeSSOT` FAIL（`icon == "creditcard"`、`colorHex == "#3478F6"`）；`testEditModeCopiesAccountValues` PASS。

- [ ] **Step 3: 最小實作**

`AddEditAccountFeature.swift` line 36-40 改為：

```swift
case .add:
    self.name = ""
    self.type = .cash
    self.icon = AccountType.cash.defaultIcon
    self.colorHex = AccountType.cash.defaultColor
```

- [ ] **Step 4: 跑測試驗證通過**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/AddEditAccountFeatureTests`
Expected: 兩個測試 PASS。

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/AccountManagement/AddEditAccountFeature.swift NeuLedgerTests/Tests/FeaturesTests/AddEditAccountFeatureTests.swift
git commit -m "fix(account): align add-mode defaults with AccountType SSOT (banknote/#8E8E93) [ci skip]"
```

---

### Task 4: RecurringForm 補齊 transfer 轉入帳戶 picker 與驗證

**問題：** `RecurringTransactionFormView` 有 transfer 類型 pill（line 70-72）可選，但無轉入帳戶 picker；`toAccountChanged` action（Feature line 68, 139-141）無任何送出點（死 action）；View line 248-252 的 TODO 註解錯誤宣稱 toAccountId 會被「靜默設定」（實際無任何代碼這麼做）→ 可存出 `toAccountId == nil` 的殘缺轉帳範本。**裁定（2026-06-06）：補齊 picker**，對齊 `AddTransactionFeature` 的驗證（same-account 檢查見 `AddTransactionFeature.swift:262-263`），並加 nil 檢查。

**Files:**
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift`（State 加 `transferError`、saveTapped 驗證、toAccountId 組裝 transfer-only、typeChanged/toAccountChanged 清錯）
- Modify: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormView.swift`（account picker 後加 transfer-only 的 toAccount row，替換錯誤 TODO 註解）
- Modify: `NeuLedger/Resources/Localizable.xcstrings`（新增 2 個 key）
- Test: `NeuLedgerTests/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift`（新增 5 個 `@Test`）

- [ ] **Step 1: 寫 failing tests**

在 `RecurringTransactionFormFeatureTests.swift` suite 內加（沿用既有 `Self.sampleAccount`；新增第二個帳戶常數）：

```swift
static let sampleAccount2 = Account(
    id: "00000000-0000-0000-0000-000000000002",
    name: "銀行", type: .bank, icon: "building.columns", color: "#0A84FF",
    sortOrder: 1, isArchived: false, createdAt: Date()
)

// MARK: - Transfer support (audit A1)

@Test("toAccountChanged updates toAccountId and clears transferError")
func testToAccountChanged() async {
    var initialState = RecurringTransactionFormFeature.State(mode: .add)
    initialState.transferError = "stale"
    let store = await TestStore(initialState: initialState) {
        RecurringTransactionFormFeature()
    }
    await store.send(.toAccountChanged(Self.sampleAccount2.id)) {
        $0.toAccountId = Self.sampleAccount2.id
        $0.transferError = nil
    }
}

@Test("saveTapped transfer without toAccount sets transferError")
func testSaveTransferWithoutToAccountSetsError() async {
    let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
        RecurringTransactionFormFeature()
    }
    await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
    await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
    await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
    await store.send(.saveTapped) {
        $0.transferError = String(localized: "recurring_transaction_error_to_account")
    }
}

@Test("saveTapped transfer to the same account sets transferError")
func testSaveTransferSameAccountSetsError() async {
    let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
        RecurringTransactionFormFeature()
    }
    await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
    await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
    await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
    await store.send(.toAccountChanged(Self.sampleAccount.id)) { $0.toAccountId = Self.sampleAccount.id }
    await store.send(.saveTapped) {
        $0.transferError = String(localized: "add_transaction_error_same_account")
    }
}

@Test("saveTapped valid transfer persists toAccountId on the created template")
func testSaveTransferValidPersistsToAccountId() async {
    let added = LockIsolated<RecurringTransaction?>(nil)
    let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
    let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
        RecurringTransactionFormFeature()
    } withDependencies: {
        $0.date = .constant(fixedNow)
        $0.ledgerClient.createRecurring = { template in added.setValue(template) }
        $0.dismiss = DismissEffect {}
    }
    await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
    await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
    await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
    await store.send(.toAccountChanged(Self.sampleAccount2.id)) { $0.toAccountId = Self.sampleAccount2.id }
    await store.send(.saveTapped)
    await store.receive(\.delegate.saved)
    #expect(added.value?.type == .transfer)
    #expect(added.value?.toAccountId == Self.sampleAccount2.id)
}

@Test("non-transfer save nils out a previously picked toAccountId")
func testNonTransferSaveNilsToAccountId() async {
    let added = LockIsolated<RecurringTransaction?>(nil)
    let fixedNow = Date(timeIntervalSinceReferenceDate: 771_638_400)
    let store = await TestStore(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
        RecurringTransactionFormFeature()
    } withDependencies: {
        $0.date = .constant(fixedNow)
        $0.ledgerClient.createRecurring = { template in added.setValue(template) }
        $0.dismiss = DismissEffect {}
    }
    await store.send(.amountChanged("1000")) { $0.amountText = "1000" }
    await store.send(.typeChanged(.transfer)) { $0.type = .transfer }
    await store.send(.toAccountChanged(Self.sampleAccount2.id)) { $0.toAccountId = Self.sampleAccount2.id }
    await store.send(.typeChanged(.expense)) { $0.type = .expense }
    await store.send(.accountChanged(Self.sampleAccount.id)) { $0.accountId = Self.sampleAccount.id }
    await store.send(.saveTapped)
    await store.receive(\.delegate.saved)
    #expect(added.value?.toAccountId == nil)
}
```

注意：①既有 `testSaveTappedValid` 等用了 `$0.ledgerClient.listActiveAccounts` 等 stub 是因為它們 send `.task`；上面的新測試不送 `.task`，不需要那些 stub。②若 `transferError` 對測試 target 不可見（`State` 內需與 `amountError` 同層宣告為 `public var`），實作時保持一致。③ `categoryId` 驗證：現行 `saveTapped` 不要求 category（無 categoryError 驗證），transfer 測試無需設 category。

- [ ] **Step 2: 跑測試驗證失敗**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/RecurringTransactionFormFeatureTests`
Expected: 新增 5 個測試中，`testToAccountChanged` 因 `transferError` property 不存在而**編譯失敗** —— 編譯錯誤即紅燈。先補 State property（僅宣告 `public var transferError: String?` 與 init 設 nil）讓編譯過，再跑一次：4 個行為測試 FAIL（驗證不存在、toAccountId 未 nil-out）。

- [ ] **Step 3: 實作 — Feature**

`RecurringTransactionFormFeature.swift`：

1. State 宣告（line 33 `saveError` 旁）加：

```swift
// Audit A1: transfer destination validation surfaces inline
public var transferError: String?
```

`init` 兩個分支的 `saveError = nil` 旁各加 `transferError = nil`。

2. `typeChanged`（line 116-118）改為：

```swift
case let .typeChanged(type):
    state.type = type
    state.transferError = nil
    return .none
```

3. `toAccountChanged`（line 139-141）改為：

```swift
case let .toAccountChanged(id):
    state.toAccountId = id
    state.transferError = nil
    return .none
```

4. `saveTapped` 在 accountId guard（line 166-169）之後、錯誤清理（line 170-172）之前插入 transfer 驗證（沿用既有逐條 early-return 風格）：

```swift
if state.type == .transfer {
    guard let toId = state.toAccountId else {
        state.transferError = String(localized: "recurring_transaction_error_to_account")
        return .none
    }
    guard toId != accountId else {
        state.transferError = String(localized: "add_transaction_error_same_account")
        return .none
    }
}
```

5. 錯誤清理區（line 170-172）加 `state.transferError = nil`。

6. toAccountId 組裝改為 transfer-only（line 178）：

```swift
let toAccountId = state.type == .transfer ? state.toAccountId : nil
```

（`.edit` 分支 line 201 的 `updated.toAccountId = toAccountId` 與 `.add` 分支 line 214 共用此值，無需另改。）

- [ ] **Step 4: 實作 — Localizable.xcstrings**

`NeuLedger/Resources/Localizable.xcstrings`（JSON，sourceLanguage `en`，雙語系 `en`/`zh-Hant`，仿 `recurring_transaction_error_account` 結構）在 `strings` 物件中新增兩個 key（用 python3 json 寫回或手動編輯，保持字典序位置不重要）：

```json
"recurring_transaction_to_account_label": {
 "extractionState": "manual",
 "localizations": {
  "en":      { "stringUnit": { "state": "translated", "value": "To account" } },
  "zh-Hant": { "stringUnit": { "state": "translated", "value": "轉入帳戶" } }
 }
},
"recurring_transaction_error_to_account": {
 "extractionState": "manual",
 "localizations": {
  "en":      { "stringUnit": { "state": "translated", "value": "Please select a destination account" } },
  "zh-Hant": { "stringUnit": { "state": "translated", "value": "請選擇轉入帳戶" } }
 }
}
```

- [ ] **Step 5: 跑測試驗證通過**

Run: `xcodebuild test ... -only-testing:NeuLedgerTests/RecurringTransactionFormFeatureTests`
Expected: 全 suite PASS（含既有測試 —— `testSaveTappedValid` 的 expense 路徑經 nil-out 後 `toAccountId` 仍為 nil，不受影響）。

- [ ] **Step 6: 實作 — View（toAccount picker row）**

`RecurringTransactionFormView.swift`：刪除 line 248-252 的錯誤 TODO 註解，原位置（account picker 的 `VStack` 之後、同一容器內）加 transfer-only 的 toAccount row，仿 account picker 的 `Menu` + `formRow` 寫法：

```swift
// Transfer destination picker — only rendered for transfer templates (audit A1)
if store.type == .transfer {
    VStack(alignment: .leading, spacing: 4) {
        Menu {
            Button(String(localized: "add_transaction_select_account")) {
                store.send(.toAccountChanged(nil))
            }
            ForEach(store.accounts.filter { $0.id != store.accountId }) { acc in
                Button {
                    store.send(.toAccountChanged(acc.id))
                } label: {
                    Label(acc.name, systemImage: acc.icon)
                }
            }
        } label: {
            formRow(label: String(localized: "recurring_transaction_to_account_label")) {
                if let toId = store.toAccountId,
                   let acc = store.accounts.first(where: { $0.id == toId }) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.Design.fromHex(acc.color))
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: acc.icon)
                                    .font(Font.Design.size11Semibold)
                                    .foregroundStyle(.white)
                            }
                        Text(acc.name)
                            .font(Font.Design.body)
                            .foregroundStyle(Color.Design.textPrimary)
                    }
                } else {
                    Text(String(localized: "add_transaction_select_account"))
                        .font(Font.Design.body)
                        .foregroundStyle(Color.Design.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(Font.Design.size12Medium)
                    .foregroundStyle(Color.Design.textTertiary)
            }
        }
        if let err = store.transferError {
            ErrorText(err)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
}
```

設計系統合規：字體一律 `Font.Design.*` token、顏色走 `Color.Design.*`（含 `fromHex`）、SF Symbols —— 與既有 account row 完全同款，不引入新樣式。

- [ ] **Step 7: 編譯 + 跑完整 suite 驗證**

Run: `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED（View 改動無測試直接覆蓋，以編譯 + 後續完整 scheme 驗證）。

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/RecurringTransactions/ NeuLedger/Resources/Localizable.xcstrings NeuLedgerTests/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift
git commit -m "fix(recurring): add transfer destination picker with inline validation [ci skip]"
```

---

### Task 5: 完整驗證 + 交叉 review + PR

- [ ] **Step 1: 跑完整 test scheme（不可只憑單 suite 結果宣告完成）**

Run: `xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: 全部 PASS。

- [ ] **Step 2: ast-grep PR 前審計（CLAUDE.md 規定）**

```bash
ast-grep --lang swift -p 'Font.system(size: $$$)' Features/Sources/ | cut -d: -f1 | sort -u   # 預期：只有 Font+extension.swift
ast-grep --lang swift -p '$X.font(.system($$$))' Features/Sources/ | cut -d: -f1 | sort -u    # 預期：只有 Font+extension.swift
ast-grep --lang swift -p 'Color(hexLiteral: $$$)' Features/Sources/ | cut -d: -f1 | sort -u   # 預期：只有 Color+extension.swift
ast-grep --lang swift -p 'import SwiftData' Features/Sources/Features/ Features/Sources/WatchFeatures/  # 預期：無輸出
```

- [ ] **Step 3: 派獨立 subagent 交叉 review 本 PR diff**（使用者要求每組處理完交叉 review）

審查重點：①四個修復是否與審查發現一一對應且無 scope creep；②TDD 測試是否真的驗到行為（非套套邏輯）；③transfer-only nil-out 是否破壞 edit 既有 transfer 範本的回寫（不應 —— edit transfer 時 type 仍是 .transfer）；④localization key 雙語齊備。

- [ ] **Step 4: 開 PR**

用 `commit-commands:commit-push-pr` 開 PR：`fix/audit-behavior-bugs` → `developer`。PR 標題**不得**帶 `[ci skip]`（CLAUDE.md：skip 標記只放 commit subject）。PR body 引用 `docs/audits/2026-06-06-presentation-layer-audit.md` 對應條目。

---

## Self-Review 紀錄

- Spec coverage：A1 範圍 4 個 bug 各對應 Task 1-4 ✅；roadmap 中 A1 的「刪 toAccountChanged」已被使用者後續裁定（補 picker）取代，roadmap 需同步更新 ✅（見 roadmap 修訂）
- Placeholder scan：所有代碼步驟均含完整代碼 ✅
- Type consistency：`transferError: String?` 在 Task 4 Step 1（測試）/Step 3（State）一致；`toAccountChanged(Account.ID?)` 與既有宣告一致；`AccountType.cash.defaultIcon/.defaultColor` 為 public extension 成員可跨 target 引用 ✅
