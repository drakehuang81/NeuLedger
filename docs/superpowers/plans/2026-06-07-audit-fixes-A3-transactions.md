# PR A3 — Transactions/Detail/Filter 死碼清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 依審查報告（`docs/audits/2026-06-06-presentation-layer-audit.md` Transactions/TransactionDetail/Filter 組）與「死碼一律刪除」裁定，刪除交易區 7 項死碼：重複投影 property、不可達分支、死 action 鏈與僅測試引用的 derived property。

**Architecture:** 純刪除型重構。驗證標準：①識別字 grep 歸零 ②編譯通過 ③相關 suite 綠 ④完整 scheme 綠。兩個實作 task 動不同檔案組，但 Task 2 會動 `TransactionsFeature.swift`（與 Task 1 無重疊）—— 仍串行執行。

**分支：** `fix/transactions-detail-filter-dead-state`（自 developer `1b290bb` 切出，A1/A2 已 merge）。commit 帶 `[ci skip]` + Co-Authored-By trailer。

**⚠️ 同名識別字生死交叉表（最容易出錯的點）：**

| 識別字 | TransactionsFeature | FilterFeature |
|---|---|---|
| `activeFilterCount` | **死**（badge 由 FilterFeature 版負責）→ 刪 | **活**（FilterView:53-54 消費）→ 保留 |
| `hasActiveFilters` | **活**（TransactionsView:88,103 消費）→ 保留 | **死**（僅測試引用）→ 刪 |
| `isLoading` | 活（TransactionsView 消費）→ 保留 | **死**（FilterView 用 `categories.isEmpty` gate，非 loading 旗標）→ 刪 |
| `Delegate.dismissed` | —（`addTransaction` 的 dismissed 是 AddTransactionFeature 的活 delegate，**不得動**） | **死**（唯一發送者是死 action `.dismiss`）→ 連鎖刪 |

---

### Task 1: TransactionDetail 清理（3 項）

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift`（僅 preview 區的死寫入）
- Modify: `NeuLedgerTests/Tests/FeaturesTests/TransactionDetailFeatureTests.swift`

**審查依據：** ①`state.accountName` 是 `account.name` 的重複投影 —— production View 渲染帳戶名走 `store.account`（DetailFieldsCard 經 AccountChip），無任何 View 讀 `store.accountName`，唯一讀取者是測試與 preview 死寫入；②`toAccountName` 同構；③`editTransaction(.presented(.delegate(.saved)))` 分支不可達 —— 本畫面只以 `.edit` 模式開 AddTransaction，其儲存路徑只發 `.savedWithTransaction`，永遠不發 `.saved`（`.saved` 僅 `.add`/`.addPrefilled` 模式）。

- [ ] **Step 1: 刪 production 代碼**

`TransactionDetailFeature.swift`：
1. State：刪 `public var accountName: String?` 與 `public var toAccountName: String?`（`categoryName` 是活的——它沒有整包 Category 對應，保留）
2. `namesLoaded` action 簽名改為三參數：

```swift
case namesLoaded(
    categoryName: String?,
    account: Account?,
    toAccount: Account?
)
```

3. `.task` 的第一個 `.run` 內 `send(.namesLoaded(...))` 同步改為三參數（刪 `accountName: account?.name` 與 `toAccountName: toAccount?.name` 兩行）
4. `namesLoaded` handler 同步改：

```swift
case let .namesLoaded(categoryName, account, toAccount):
    state.categoryName = categoryName
    state.account = account
    state.toAccount = toAccount
    return .none
```

5. 刪除不可達分支整段：

```swift
case .editTransaction(.presented(.delegate(.saved))):
    state.editTransaction = nil
    return .none
```

（fallback `case .editTransaction: return .none` 已兜底，安全。）

`TransactionDetailView.swift`（preview 區，約 :206-222）：刪 4 行死寫入 `state.accountName = ...`（×3）與 `state.toAccountName = ...`（×1）。**View body 不得動。**

- [ ] **Step 2: 同步刪改測試**

`TransactionDetailFeatureTests.swift`：
- `.task loads accountName, toAccountName, categoryName via namesLoaded` 測試（約 :99）：`receive(\.namesLoaded)` 的 trailing closure 刪 `$0.accountName = "現金"`、`$0.toAccountName = "銀行"` 兩行（`$0.account`/`$0.toAccount`/`$0.categoryName` 斷言保留），@Test 標題同步改為 `".task loads category name and accounts via namesLoaded"`
- 其他三個 Detail 測試檔（DeleteWindow/Detent/Insight）若引用 `accountName`/`toAccountName`/`namesLoaded` 舊簽名，同步修（以編譯錯誤為清單）
- 若有測試 send `.editTransaction(.presented(.delegate(.saved)))`，刪該測試（grep 確認）

- [ ] **Step 3: 歸零驗證**

```bash
grep -rn 'accountName\|toAccountName' Features/Sources/Features/Transactions/ NeuLedgerTests/Tests/FeaturesTests/
# 預期：無輸出（其他 feature 若有同名屬性不在掃描範圍）
```

- [ ] **Step 4: 跑 suite（4 個 Detail suite）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/TransactionDetailFeatureTests \
  -only-testing:NeuLedgerTests/TransactionDetailFeatureDeleteWindowTests \
  -only-testing:NeuLedgerTests/TransactionDetailFeatureDetentTests \
  -only-testing:NeuLedgerTests/TransactionDetailFeatureInsightTests
```

- [ ] **Step 5: 完整 test scheme**（全綠）

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Transactions/ NeuLedgerTests/
git commit -m "refactor(detail): remove accountName/toAccountName duplicate projections and unreachable saved branch [ci skip]

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Filter 清理（3 項）+ Transactions activeFilterCount

**Files:**
- Modify: `Features/Sources/Features/Transactions/FilterFeature.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift`
- Modify: `NeuLedgerTests/Tests/FeaturesTests/FilterFeatureTests.swift`
- Modify（若有引用）: `NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift`

**審查依據：** ①Filter `isLoading` 在 View 與 reducer 路徑上無消費者（FilterView 用 `categories.isEmpty` gate section）；②Filter `.dismiss` action 永不被送出（FilterView 無 Cancel 鈕——toolbar cancellationAction 送的是 `.clearAllTapped`；sheet 由系統下滑回收，`ifLet` 自動 nil）——其唯一產物 `Delegate.dismissed` 與 parent 的對應 handler 連鎖死；③Filter `hasActiveFilters` 僅測試引用；④Transactions `activeFilterCount` 為重構殘留（badge 計數已搬到 FilterFeature 的同名 property）。

- [ ] **Step 1: 刪 production 代碼**

`FilterFeature.swift`：
1. State：刪 `public var isLoading: Bool` 宣告與 init 的 `self.isLoading = false`
2. `.task` handler：刪 `state.isLoading = true`
3. `optionsLoaded` handler：刪 `state.isLoading = false`
4. State：刪 `hasActiveFilters` computed property 整段（:38-42）
5. Action：刪 `case dismiss` 與其 handler 整段（`.run { send in await send(.delegate(.dismissed)); await dismiss() }`）
6. `Delegate`：刪 `case dismissed`（唯一發送者已刪；`@Dependency(\.dismiss)` 保留——`applyTapped` 仍用）

`TransactionsFeature.swift`：
7. 刪 parent 的連鎖死 handler 整段：

```swift
case .filter(.presented(.delegate(.dismissed))):
    state.filter = nil
    return .none
```

（sheet 系統下滑由 `ifLet` 對 `PresentationAction.dismiss` 自動置 nil，此 handler 本就冗餘；**注意 :200 的 `addTransaction(.presented(.delegate(.dismissed)))` 是 AddTransactionFeature 的活 delegate，不得動**）
8. State：刪 `activeFilterCount` computed property 整段（:33-41；**`hasActiveFilters`（:25-31）是活的，保留**）

- [ ] **Step 2: 同步刪改測試**

`FilterFeatureTests.swift`：
- **整個刪除** 3 個測試：`dismiss action emits dismissed delegate`（:304）、`hasActiveFilters is false when nothing is selected`（:317）、`hasActiveFilters is true when types are selected`（:323）+ 其 `// MARK: - hasActiveFilters computed property` 標頭
- **修改**：`testTaskLoadsOptions` 等對 `$0.isLoading` 的斷言行刪（:45,:48 一帶，以編譯錯誤為清單）
- `TransactionsFeatureTests.swift`：若有 send `.filter(.presented(.delegate(.dismissed)))` 或引用 `activeFilterCount` 的測試，刪除（grep 確認）

- [ ] **Step 3: 歸零驗證**

```bash
grep -rn 'isLoading\|hasActiveFilters' Features/Sources/Features/Transactions/FilterFeature.swift
# 預期：無輸出
grep -rn 'activeFilterCount' Features/Sources/Features/Transactions/TransactionsFeature.swift NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift
# 預期：無輸出
grep -rn 'dismissed' Features/Sources/Features/Transactions/FilterFeature.swift Features/Sources/Features/Transactions/FilterView.swift
# 預期：無輸出
grep -n 'hasActiveFilters' Features/Sources/Features/Transactions/TransactionsFeature.swift
# 預期：有輸出（活的，必須還在）
grep -n 'activeFilterCount' Features/Sources/Features/Transactions/FilterFeature.swift
# 預期：有輸出（活的，必須還在）
```

- [ ] **Step 4: 跑 suite**

```bash
xcodebuild test ... -only-testing:NeuLedgerTests/FilterFeatureTests -only-testing:NeuLedgerTests/TransactionsFeatureTests
```

- [ ] **Step 5: 完整 test scheme**（全綠）

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Transactions/ NeuLedgerTests/
git commit -m "refactor(transactions): remove dead filter dismiss chain, test-only derived props and stale activeFilterCount [ci skip]

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 完整驗證 + 交叉 review + PR

- [ ] ast-grep 四條閘門審計
- [ ] 完整 test scheme
- [ ] 派獨立 subagent 交叉 review 整個 PR diff —— 重點：①生死交叉表四格是否刪對邊（最高風險）②namesLoaded 簽名改動的漣漪是否全收斂 ③Filter sheet 系統下滑回收在刪掉 dismissed handler 後行為不變（ifLet 自動 nil）④AddTransaction 的 dismissed delegate 未被誤動
- [ ] 開 PR（`fix/transactions-detail-filter-dead-state` → `developer`）

---

## Self-Review 紀錄

- 審查 7 項全對應：Transactions F4(activeFilterCount)、Detail F1/F2(accountName/toAccountName)、Detail F5(saved 分支)、Filter F1(isLoading)、F2(dismiss)、F4(hasActiveFilters) ✅
- 生死交叉表已置頂強調 ✅
- `Delegate.dismissed` 連鎖刪除（審查未單列但邏輯連帶）已標注依據 ✅
- categoryName 保留判斷已寫明 ✅
