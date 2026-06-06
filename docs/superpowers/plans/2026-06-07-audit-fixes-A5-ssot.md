# PR A5 — SSOT 結構修復 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 修復審查確認的 SSOT 違規：Watch 載具的整包複本投影、Watch 預設帳戶規則雙寫、Settings 與子畫面的清單 desync、餘額查詢雙路徑、預設色 magic literal。

**Architecture:** 行為保持重構 + 新增 delegate 行為，**適用 TDD**（新行為先寫 failing test）。三個實作 task 檔案互不重疊，串行。

**分支：** `fix/ssot-refactors`（自 `integration/presentation-audit` d14cb7d 切出）。PR base = 整合分支。

**範圍調整紀錄：** roadmap 原列的「Dashboard/Analysis income/expense 投影收進 insightsClient」**作廢** —— Dashboard 端的手刻 fold 已隨 A2 的 AI insight 死鏈刪除，重複已不存在（只剩 Analysis 一處使用者，DRY 違規消失）。AddEditAccount 的 `#3478F6` 已在 A1 修復，本批只剩 AddEditTag。

---

### Task 1: Watch 預設帳戶規則統一（Domain 純函式）

**Files:**
- Modify: `Features/Sources/Domain/Entities/Account.swift`（加 static 純函式）
- Modify: `Features/Sources/Core/Adapters/Watch/WatchDefaultAccountResolver.swift`（改呼叫純函式）
- Modify: `Features/Sources/Features/Settings/Watch/WatchSettingsFeature.swift`（`loaded` 的 fallback 改呼叫純函式）
- Test: 新建 `NeuLedgerTests/Tests/DomainTests/Entities/AccountResolveDefaultTests.swift`；既有 `WatchSettingsFeatureTests` / `WatchDefaultAccountResolverTests` 行為持平

**問題：** `WatchDefaultAccountResolver` docstring 自稱規則的 single source of truth，但 `WatchSettingsFeature.loaded`（:64-66）逐行重寫同一規則（「stored 指向活帳戶則用之，否則 fallback 第一個活帳戶」），兩處規則並存有 drift 風險。

**TDD 步驟：**
1. 新建 Domain 測試（failing —— 函式不存在即編譯紅）：

```swift
import Testing
import Foundation
import Domain

@Suite("Account.resolveDefaultId Tests")
struct AccountResolveDefaultTests {
    private static func account(_ id: String, sortOrder: Int = 0) -> Account {
        Account(id: id, name: id, type: .cash, icon: "banknote", color: "#8E8E93",
                sortOrder: sortOrder, isArchived: false, createdAt: Date())
    }

    @Test("stored id pointing at a live account is honored")
    func storedHonored() {
        let accounts = [Self.account("a"), Self.account("b", sortOrder: 1)]
        #expect(Account.resolveDefaultId(stored: "b", in: accounts) == "b")
    }

    @Test("stale stored id falls back to the first account")
    func staleFallsBack() {
        let accounts = [Self.account("a"), Self.account("b", sortOrder: 1)]
        #expect(Account.resolveDefaultId(stored: "ghost", in: accounts) == "a")
    }

    @Test("nil stored id falls back to the first account")
    func nilFallsBack() {
        #expect(Account.resolveDefaultId(stored: nil, in: [Self.account("a")]) == "a")
    }

    @Test("empty account list resolves to nil")
    func emptyResolvesNil() {
        #expect(Account.resolveDefaultId(stored: "a", in: []) == nil)
    }
}
```

2. `Account.swift` 加（public extension，純函式，呼叫端保證傳入已排序的活帳戶清單）：

```swift
public extension Account {
    /// Single source of truth for the Watch default-account rule, shared by
    /// `WatchDefaultAccountResolver` (Core) and `WatchSettingsFeature` (Features):
    /// honor the stored override only while it still points at an account in
    /// `activeAccounts`; otherwise fall back to the first one (callers pass
    /// sortOrder-sorted, non-archived accounts). `nil` when the list is empty.
    static func resolveDefaultId(stored: Account.ID?, in activeAccounts: [Account]) -> Account.ID? {
        if let stored, activeAccounts.contains(where: { $0.id == stored }) {
            return stored
        }
        return activeAccounts.first?.id
    }
}
```

3. `WatchDefaultAccountResolver.resolve` 改為 fetch 後委派：

```swift
public static func resolve(stored: Account.ID?) async throws -> Account.ID? {
    let activeAccounts = try await AccountStore()
        .fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
        .filter { !$0.isArchived }
    return Account.resolveDefaultId(stored: stored, in: activeAccounts)
}
```

（docstring 的 SSOT 宣告同步改為指向 `Account.resolveDefaultId`。）

4. `WatchSettingsFeature` `loaded` handler 的 :58-66 註解+三行 fallback 改為：

```swift
// Single source of truth: Account.resolveDefaultId (shared with
// WatchDefaultAccountResolver / the Watch sync pipeline).
state.selectedAccountId = Account.resolveDefaultId(stored: selectedAccountId, in: accounts)
```

5. 驗證：新 Domain suite 綠；`WatchSettingsFeatureTests`、`WatchDefaultAccountResolverTests`（CoreTests）行為持平全綠；完整 scheme 綠。
6. Commit：`refactor(watch): unify default-account fallback rule into Account.resolveDefaultId [ci skip]`

---

### Task 2: WatchCarrier presentedCarrier 改 ID + computed

**Files:**
- Modify: `Features/Sources/WatchFeatures/Carrier/WatchCarrierFeature.swift`
- Test: `NeuLedgerWatchTests/WatchCarrierFeatureTests.swift`

**問題：** State 同時持有 `carriers: [Carrier]?` 與 `presentedCarrier: Carrier?`（同一筆 entity 的整包複本），靠 `carriersUpdated` 的 re-resolve 膠水（:63-67）手動同步。View 只讀 `presentedCarrier`（`navigationDestination` 的 get + `if let`）且 dismiss 走 `barcodeDismissed` action —— computed 替代完全相容。

**實作：**

```swift
@ObservableState
public struct State: Equatable, Sendable {
    public var carriers: [Carrier]?

    /// ID of the carrier pushed full-screen from the 2+ list.
    /// The presented carrier itself is derived from `carriers` — renames /
    /// barcode edits flow through automatically, and deletion on iPhone
    /// dismisses the screen (derivation returns nil).
    public var presentedCarrierID: Carrier.ID?

    /// Derived: single source of truth stays in `carriers`.
    public var presentedCarrier: Carrier? {
        presentedCarrierID.flatMap { id in carriers?.first { $0.id == id } }
    }

    public init(carriers: [Carrier]? = nil, presentedCarrierID: Carrier.ID? = nil) {
        self.carriers = carriers
        self.presentedCarrierID = presentedCarrierID
    }
}
```

- `carriersUpdated` handler 刪 re-resolve 膠水，只剩 `state.carriers = carriers`。**注意**：carrier 被刪後 `presentedCarrierID` 會殘留為 stale id（computed 回 nil → View dismiss）— 在 `barcodeDismissed` 清掉即可；另在 `carriersUpdated` 加一行防衛（`if state.presentedCarrier == nil { state.presentedCarrierID = nil }` 之類）**或不加**——二選一由實作判斷哪個讓測試語義最乾淨，回報選擇與理由
- `carrierTapped`：`state.presentedCarrierID = id`（保持「id 不存在則 computed 為 nil」的語義 — 原版 first{} 找不到也是 nil presented）
- `barcodeDismissed`：`state.presentedCarrierID = nil`
- 測試改寫：`updateReresolvesPresented`（改斷言 computed 在 rename 後回新值 — state 變化斷言改為只有 `carriers` 更新，另 `#expect(store.state.presentedCarrier == renamed)`）、`updateDismissesDeletedPresented`（同構：carriers 更新後 `presentedCarrier == nil`）、`carrierTapped` 測試改斷言 `presentedCarrierID`
- **驗證（watch target 不在 iOS scheme 內）：** ①`xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'generic/platform=watchOS Simulator'` 編譯過 ②watch 測試：用 `xcodebuild test -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'`（裝置名以 `xcrun simctl list devices available | grep Watch` 實際輸出為準）；若該 scheme 無 test action，回報 BLOCKED 並附 scheme 清單 ③iOS 完整 scheme 也跑（確認無連帶影響）
- Commit：`refactor(watch): derive presentedCarrier from carriers via ID (drop re-resolve glue) [ci skip]`

---

### Task 3: Settings↔子畫面 delegate 回拋 + balances() 統一 + AddEditTag 常數

**Files:**
- Modify: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift`
- Modify: `Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift`
- Modify: `Features/Sources/Common/DesignSystem/DesignConstants.swift`
- Test: `AccountManagementFeatureTests` / `CarrierManagementFeatureTests` / `SettingsFeatureTests`（新增 delegate 測試）

**問題①（desync）：** Settings 持有 `accounts`/`defaultAccountName` 與 `carriers`/`widgetCarrierName`，只在 `.task`（`.cancellable(id: CancelID.task)`，pop 回來不重跑）載入一次；push 的 AccountManagement/CarrierManagement 各自寫入（archive/unarchive/delete/save）後只 reload 自己 —— pop 回 Settings 顯示舊值。

**修法（delegate 回拋）：**

1. `AccountManagementFeature` 加：

```swift
case delegate(Delegate)

@CasePathable
public enum Delegate: Sendable, Equatable {
    /// 任何帳戶寫入（新增/編輯/封存/解封存/刪除）完成後通知 parent 重載。
    case accountsChanged
}
```

在四個寫入完成點（`archiveConfirmed` / `deleteConfirmed` / `unarchiveTapped` 的 effect 完成、`addEdit(.presented(.delegate(.saved)))`）的 reload effect 上 merge `.send(.delegate(.accountsChanged))`（統一模式：原 `return .run { ... reload ... }` → `return .merge(.run { ... }, .send(.delegate(.accountsChanged)))`）。`case .delegate: return .none` 兜底。

2. `CarrierManagementFeature` 同構加 `Delegate.carriersChanged`，在兩個寫入完成點（`alert(.presented(.deleteConfirmed))`、`addEdit(.presented(.delegate(.saved)))`）merge 發送。

3. `SettingsFeature` 接收（path element delegate）：

```swift
case .path(.element(id: _, action: .accountManagement(.delegate(.accountsChanged)))):
    return .run { [ledger] send in
        let accounts = (try? await ledger.listActiveAccounts()) ?? []
        await send(.accountsLoaded(accounts))
    }

case .path(.element(id: _, action: .carrierManagement(.delegate(.carriersChanged)))):
    return .run { [carrierClient] send in
        let carriers = (try? await carrierClient.listAll()) ?? []
        await send(.widgetCarriersLoaded(carriers))
    }
```

放在既有 `case .path: return .none` 之前。（`accountsLoaded`/`widgetCarriersLoaded` 既有 handler 會更新 `defaultAccountName`/`widgetCarrierName` —— 重用既有回流。）

**TDD：** 先寫 4 個 failing test —— ①AccountManagement：unarchive 完成後 receive `\.delegate.accountsChanged`②addEdit saved 後同上（或 archive/delete 擇一補強）③Settings：send `.path(.element(id:action:.accountManagement(.delegate(.accountsChanged))))` 後 receive `\.accountsLoaded` 且 `defaultAccountName` 更新（stub `listActiveAccounts` 回新名單）④Settings：carrier 同構。Settings 測試需 stub reducer 路徑會碰到的 closure（血淚規則①；`Scope`/`forEach` child 依賴注意血淚規則②）。

**問題②（餘額雙路徑）：** `accountsLoaded` 用 `withTaskGroup` 逐帳戶 `ledger.balance(id)`（N 次 round-trip）自組 dict；Dashboard 用單呼叫 `ledger.balances()`。統一：

```swift
case let .accountsLoaded(accounts):
    state.isLoading = false
    state.accounts = accounts
    return .run { send in
        let balances = (try? await ledger.balances()) ?? [:]
        await send(.balancesLoaded(balances))
    }
```

（`balances()` 回傳全帳本 fold 的 `[Account.ID: Decimal]`，與 Dashboard 同一投影入口；View 對缺 key 的帳戶本就 fallback 顯示 —— 先讀 View 確認 fallback 寫法後再動，若 View 對 archived 帳戶顯示餘額且 `balances()` 不含 archived，回報 BLOCKED 討論。）既有 balances 測試的 stub 從 `$0.ledgerClient.balance` 改為 `$0.ledgerClient.balances`。

**問題③（magic literal）：** `DesignConstants` 加：

```swift
/// Default color hex for newly created tags (brand blue, also present in tagColorOptions).
public static let defaultTagColorHex: String = "#3478F6"
```

`AddEditTagFeature` init 的兩處 `"#3478F6"`（:30 add 分支、:33 edit fallback）改引用 `DesignConstants.defaultTagColorHex`（確認 AddEditTagFeature 可見 Common —— Features target 依賴 Common）。

驗證：三個 suite + 完整 scheme 綠。
Commit：`refactor(settings): sync accounts/carriers via child delegates, unify balance projection, extract tag default color [ci skip]`

---

### Task 4: 驗證 + 交叉 review + PR + merge

- ast-grep 四條閘門 + iOS 完整 scheme + watch app build
- 派獨立 subagent 交叉 review 整個 PR diff —— 重點：①delegate 回拋的發送點是否涵蓋「全部」寫入路徑（漏一條 = desync 殘留）②presentedCarrierID 重構的 stale-id 處置 ③balances() 對 archived 帳戶的語義差異 ④Domain 純函式與 Resolver 行為等價（含空清單/nil 邊界）
- 開 PR（base = `integration/presentation-audit`）→ merge

---

## Self-Review 紀錄

- Global audit confirmed 6 項對應：G1/G2（Settings↔子畫面 desync）→ Task 3①；G4（balances 雙路徑）→ Task 3②；WatchCarrier（組內 confirmed）→ Task 2；WatchSettings resolver 補漏 → Task 1；AddEditTag 補漏 → Task 3③ ✅
- G3（income/expense 投影）作廢已記錄依據；G5/G6（State 肥大）為 follow-up 不在本輪 ✅
- watch 測試跑法的不確定性已寫入 Task 2（BLOCKED 路徑）✅
