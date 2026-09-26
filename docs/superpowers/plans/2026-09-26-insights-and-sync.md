# 假資料 / 同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把使用者在畫面上看到的東西變成真的——移除 Dashboard 三筆捏造的假金額並改用真實帳本資料、讓 Watch 記的帳不再靜默消失、讓 App 內的 Widget 載具選擇真的傳到 Widget、讓 Dashboard 與交易分頁互相同步、讓交易列顯示分類。

**Architecture:** 核心是 `generateInsights` 的**分層重切**。它現在回傳寫死的繁中字串，而承載它的 `Core` target（含 `Sources/Application`）**只依賴 `Domain`、碰不到 `Common`**，所以金額格式化（`Decimal.twdFormatted`）與 main bundle 的 `String(localized:)` 在那一層根本不可用——這正是當初把字串寫死在 Client 的結構性原因。修法是讓 Client 回傳**結構化描述子**（`InsightDescriptor`：種類 + 數字），挑選與算術落在純 Domain 函式裡（可用數字斷言測試、不必比對字串），本地化與金額格式化落在 Features 層（那裡本來就有 `twdFormatted` 與 `String(localized:)`）。其餘四條各自獨立：Watch 去重順序、App Group 多一個 key、MainTab 切 tab 重載、交易列多一個分類名 lookup。

**Tech Stack:** Swift 6、TCA 1.23.2、swift-dependencies、SwiftData、Swift Testing、WidgetKit / App Intents。

**Spec:** `docs/audits/2026-09-23-health-audit/README.md` 的 **#7、#14、#15、#17、#22 前半**，原始條目在 `02-application-core.md` 的 **B9、A8、A9** 與 `01-features.md` 的 **A8**。**這些是 binding spec，每個 Task 開工前先讀對應條目。**

## Global Constraints

- Features 層**不得** `import SwiftData`；持久化一律經 Client / Adapter。
- **`Core` target = `Sources/Core` + `Sources/Application`，依賴只有 `Domain`**（`Features/Package.swift:73-87`）。`Common`（`twdFormatted`、`Color.Design`、`Font.Design`）與 main bundle 的 localization **在 Application 層不可用**。需要它們就把責任放到 Features 層，**不要**在 Application 層 inline 複製一份格式化邏輯。
- 顏色與字體一律走 `Color.Design` / `Font.Design` gateway。
- 金額一律用 `Decimal.twdFormatted`（`Features/Sources/Common/Extensions/Decimal+Currency.swift:5`），**不要**自建 `NumberFormatter`。
- 使用者可見字串一律 `String(localized:)`，並且**同時填 `en` 與 `zh-Hant`**（`NeuLedger/Resources/Localizable.xcstrings` 目前只有這兩個 locale）。
- 每顆 commit subject **結尾加 `[ci skip]`**；PR 標題不加。
- 新增 effect 一律 `.run(operation:catch:)`，沿用既有錯誤形狀（`loadError`/`loadFailed`、`actionError`/`actionFailed`、`sectionFailed`）。
- 不得 `git push`、不得 force push、**不得 `git stash`**（stash stack 跨 worktree 共用）。
- 環境：全域 `xcode-select` 指向未授權的 Xcode，所有 `xcodebuild` / `git` / `python3` 前面都要加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`；**不得** `sudo` 或 `xcode-select`。
- **完整 test scheme 由 controller 執行，implementer 只跑 `-only-testing:` 的聚焦 suite**（完整 scheme 超過單次指令 10 分鐘上限會被轉背景，subagent 收不到通知會卡死）。兩個 xcodebuild 不得重疊。
- 測試數以不重複測試名計算：`grep -oE "Test case '[^']+' passed" LOG | sort -u | wc -l`。**平行 clone 會把輸出行從行首截斷**，數字對不上時用逐 suite 的名稱 `comm` 比對，不要寫「浮動」。
- 分支起點的基準：**890 條**不重複測試（developer @ 23e8f0c）。

## Rulings（開工前已裁定，實作時不要重開）

- **R1（使用者裁定）#7 要算真實數字**，不是隱藏、也不是空狀態文案。使用者要在 Dashboard 看到自己的帳。
- **R2 #7 的分層**：`InsightsClient.generateInsights` 的回傳型別從 `[InsightData]` 改成 **`[InsightDescriptor]`**（新 Domain 值型別，帶種類 + `Decimal` / `Double` 數字，**不帶任何使用者可見字串**）。挑選與算術放在純 Domain 的 `InsightComposer`。Features 層把描述子映成 localized `InsightData`。理由：Application 層碰不到 `Common` 與 main bundle（見 Global Constraints），這是硬性的 module 邊界，不是偏好。`InsightData` 本身與 `InsightCard` / `InsightCarousel` **不動**。
- **R3 #7 的資料來源不新增 Client endpoint**。`SpendingSummary` 由 Features 層用**既有的** `insightsClient.todayStats`（給 week / savingsPercentage）與 `insightsClient.categoryProportions`（給 topCategoryName / topCategoryAmount、monthTotal）組出來。`generateInsights` 仍然吃 `SpendingSummary`，介面形狀不變，只改回傳型別。
- **R4 #14 只做順序修正**，`mark(_:)` 移到 `add` 成功之後；失敗時不 log。**不引入 OSLog**：全專案目前零 `os_log`／`Logger`（唯一痕跡是 `WatchSyncObserver.swift:69` 一句「future iteration」註解），引入 logging 基礎建設是另一張單，而順序才是資料遺失的根因。
- **R5 #15 的 App Group key 要同步兩處**：`Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift:18-24` 與 `Shared/WidgetAppGroup.swift:17-25` 各自硬編同一組常數（那是 audit #37 / PR C 的範圍）。本 PR **不統一**這兩處，但新 key 必須同時加在兩邊，並在兩邊的「keep in sync」註解裡列出來。
- **R6 #22 只做前半**（交易列顯示分類名）。Analysis 分類名未本地化屬 PR B。
- **R7 #17 採「切 tab 時重載」**，不是跨 tab 轉發 delegate。理由：重載同時涵蓋 CloudKit 背景同步（另一台裝置改動後切回來也會更新），轉發只涵蓋本機異動。**重載期間不得清空既有資料**——`isLoading` / phase 轉 loading 但 `transactions` / 既有 section 資料保留，避免每次切 tab 閃一下空白。
- **R8 假洞察的空狀態也是假的**。`InsightCarousel.swift:73-84` 的 `placeholder` 用 `dashboard_insight_loading_title`（「正在生成洞察…」）當 `.loaded && isEmpty` 的畫面。R1 之後資料不足時仍會是空陣列（例如全新使用者一筆帳都沒有），所以**必須**另給一個真正的空狀態文案，不能沿用載入中那兩個 key。

---

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `Features/Sources/Domain/Entities/InsightDescriptor.swift` | **新建** | 結構化洞察描述子（種類 + 數字，無字串） |
| `Features/Sources/Domain/Analysis/InsightComposer.swift` | **新建** | 純函式：`SpendingSummary` → `[InsightDescriptor]`，含挑選與門檻 |
| `Features/Sources/Domain/Clients/InsightsClient.swift` | 修改 | `generateInsights` 回傳型別改 `[InsightDescriptor]` |
| `Features/Sources/Application/Insights/InsightsClient+Live.swift` | 修改 | 刪掉三筆寫死假資料，改呼叫 `InsightComposer` |
| `Features/Sources/Features/Dashboard/DashboardFeature.swift` | 修改 | 組真實 `SpendingSummary`；描述子 → localized `InsightData` |
| `Features/Sources/Features/Dashboard/Sections/InsightCarousel.swift` | 修改 | `.loaded && isEmpty` 改用真正的空狀態文案（R8） |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | 修改 | `tabSelected` 觸發對應 child 重載（R7） |
| `Features/Sources/Features/Transactions/TransactionsFeature.swift` | 修改 | state 加 categories + 載入 effect |
| `Features/Sources/Features/Transactions/TransactionsView.swift` | 修改 | 列的 subtitle 改分類名 |
| `Features/Sources/Core/Adapters/Watch/WatchSessionDelegate.swift` | 修改 | `mark` 移到 `add` 成功之後（R4） |
| `Features/Sources/Application/Carrier/CarrierClient+Live.swift` | 修改 | `setActiveForWidget` 一併寫 App Group |
| `Features/Sources/Domain/Adapters/WidgetSyncAdapter.swift` | 修改 | 介面新增 `setActiveCarrierId` endpoint |
| `Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift` | 修改 | 新增 active id 的寫入端 + key |
| `Shared/WidgetAppGroup.swift` | 修改 | 新增 active id 的讀取端 + key（R5） |
| `NeuLedgerWidget/CarrierWidget.swift` | 修改 | `resolveState` fallback 改讀 active id |
| `NeuLedger/Resources/Localizable.xcstrings` | 修改 | 洞察模板 + 空狀態 + 交易列 fallback，en / zh-Hant 都填 |

測試檔：`NeuLedgerTests/Tests/DomainTests/Analysis/InsightComposerTests.swift`（**新建**）、`DomainTests/Clients/InsightsClientTests.swift`、`FeaturesTests/Dashboard/DashboardFeatureInsightTests.swift`、`FeaturesTests/MainTabFeatureTests.swift`、`FeaturesTests/TransactionsFeatureTests.swift`、`CoreTests/WatchSessionDelegateTests.swift`（既有）、`CoreTests/Clients/CarrierClientLiveTests.swift`（若不存在則**新建**）。

**Task 順序的理由**：Task 1–3 三條互不相干的小修先走（各自可獨立 review、風險低）；Task 4–6 是 #7 的三層，必須依序（Domain → Application → Features，後者消費前者的型別）；Task 7 的 #17 放最後，因為它會動 `MainTabFeature` 與兩個 child 的重載入口，而 Task 3 剛改過 `TransactionsFeature` 的載入路徑。

---

## Task 1: Watch 入站草稿不再靜默消失（audit #14）

**先讀**：`docs/audits/2026-09-23-health-audit/02-application-core.md` 的 **A8**。

**Files:**
- Modify: `Features/Sources/Core/Adapters/Watch/WatchSessionDelegate.swift:26-57`
- Test: `NeuLedgerTests/Tests/CoreTests/WatchSessionDelegateTests.swift`（**既有檔案**，已有三個案例與 in-memory container + `dedupStore` 注入的 harness；新案例加進同一個 suite，不要另建檔案——`CoreTests/` 底下所有 Watch 測試都是攤平的，沒有 `Adapters/` 子目錄）

**Interfaces:**
- Consumes: `dedupStore`（既有，注入）、`TransactionStore`（Core）
- Produces: 無新型別

現況（`WatchSessionDelegate.swift`）：`parse(_:)` 在**驗證階段**就 `dedupStore.mark(draft.id)`（行 47），然後才在 `start()` 的 `Task` 裡 `try? await store.add(transaction)`（行 31-34）。寫入失敗被 `try?` 吞掉，而該 id 已被永久標記成「已處理」，WatchConnectivity 重送會在行 46 的 `contains` 被擋掉——**這筆記帳靜默消失，兩端都不顯示錯誤**。

- [ ] **Step 1: 寫失敗的測試**

需要能讓 `store.add` 失敗的注入點。`start()` 內部 `let store = TransactionStore()` 是硬寫的，所以**先把它改成可注入**（建構子參數，預設值維持現行行為），這是這個 Task 的一部分而不是額外重構。

```swift
@Test("a draft whose write fails is not marked as processed, so WatchConnectivity can resend it")
func testFailedWriteLeavesTheDraftResendable() async throws {
    let dedup = DedupStoreSpy()
    let transport = TransportSpy()
    let sut = WatchSessionDelegate(transport: transport, dedupStore: dedup, add: { _ in
        throw CoreError.notFound("SDTransaction")
    })
    sut.start()

    await transport.deliver(Self.validAddTxPayload(id: Self.draftID))

    #expect(dedup.contains(Self.draftID) == false, "寫入失敗的 draft 不得被標記成已處理，否則 WC 重送會被擋掉")
}

@Test("a draft that was written successfully is marked so a resend is ignored")
func testSuccessfulWriteMarksTheDraft() async throws {
    // 反向斷言：成功時一定要標記，否則去重就沒了、同一個 transferUserInfo
    // 重送會被記成第二筆帳。
    let dedup = DedupStoreSpy()
    let transport = TransportSpy()
    let writes = WriteCounter()
    let sut = WatchSessionDelegate(transport: transport, dedupStore: dedup, add: { _ in
        writes.increment()
    })
    sut.start()

    await transport.deliver(Self.validAddTxPayload(id: Self.draftID))
    #expect(dedup.contains(Self.draftID), "寫入成功就必須標記")

    // 重送同一筆
    await transport.deliver(Self.validAddTxPayload(id: Self.draftID))
    #expect(writes.count == 1, "已處理的 draft 重送不得再寫一次")
}
```

三個 helper（放在同一個 suite 裡，全部 `@unchecked Sendable` + NSLock，比照其他 CoreTests 的 spy 寫法）：`DedupStoreSpy`（實作被注入的 dedup 介面，提供 `contains` / `mark`）、`TransportSpy`（把 `onReceiveUserInfo` 的 closure 存下來，`deliver(_:)` 呼叫它）、`WriteCounter`（計次）。`validAddTxPayload(id:)` 依 `parse` 讀的形狀組出 `["op": "addTx", "payload": <JSON-encoded TransactionDraft>]`。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/WatchSessionDelegateTests 2>&1 | tail -40
```
Expected: FAIL —— 第一條紅（目前 `mark` 在 parse 階段就發生）。

- [ ] **Step 3: 把 `mark` 移到 `add` 成功之後**

`parse(_:)` 只保留 `contains` 檢查（**不** `mark`），`mark` 移進 `Task` 裡 `add` 成功之後：

```swift
transport.onReceiveUserInfo { [weak self] payload in
    guard let self, let (draftID, transaction) = self.parse(payload) else { return }
    Task {
        do {
            try await self.add(transaction)
            // 標記必須在寫入成功之後：失敗時保留 id，讓 WatchConnectivity
            // 重送同一個 transferUserInfo 有機會補上（audit A8）。
            self.dedupStore.mark(draftID)
        } catch {
            // 刻意不 log：全專案目前沒有 logging 基礎建設，引入它是另一張單
            // （plan R4）。這裡的重點是不要 mark，讓重送能救回這筆帳。
        }
    }
}
```

`parse` 的回傳型別因此從 `Transaction?` 改成 `(Transaction.ID, Transaction)?`（或讓呼叫端從 `transaction.id` 取，兩者皆可，擇一並保持一致）。

- [ ] **Step 4: 跑測試確認通過**（同 Step 2 指令）

- [ ] **Step 5: 突變驗證**

把 `mark` 搬回 `parse` 內，確認**只有**第一條測試變紅、第二條仍綠。回報改了哪一行、失敗訊息是什麼。驗證完改回來。

- [ ] **Step 6: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git add -A && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -m "fix(watch): mark an inbound draft as processed only after the write succeeds [ci skip]"
```

---

## Task 2: App 內的 Widget 載具選擇真的傳到 Widget（audit #15）

**先讀**：`docs/audits/2026-09-23-health-audit/02-application-core.md` 的 **A9**。

**Files:**
- Modify: `Features/Sources/Application/Carrier/CarrierClient+Live.swift:39-48`
- Modify: `Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift:18-24`（常數）與 `liveValue`
- Modify: `Shared/WidgetAppGroup.swift:17-25`（Key）+ 新增讀取
- Modify: `NeuLedgerWidget/CarrierWidget.swift:52-66`（`resolveState` fallback）
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/CarrierClientLiveTests.swift`（不存在則新建）

**Interfaces:**
- Produces: App Group 新 key `carrierActiveId`（String），寫入端在 `WidgetSyncAdapter`，讀取端在 `WidgetAppGroup`

現況：`setActiveForWidget` 把選擇寫進 `.widgetCarrierId`，但 `UserSettingsAdapter.liveValue` 寫的是 `UserDefaults.standard`（`UserSettingsAdapter+Live.swift:16,22,31`），**不是 App Group suite**。`syncAllCarriers` 只把整份 `carrierList` 寫進 App Group、不含「哪一張是 active」。Widget 的 `resolveState(for:)` 只看自己的 `CarrierSelectionIntent.carrier`，找不到就 fallback `all.first`。所以 App 內切換載具，Widget 畫面**不會變**，除非長按 Widget 編輯。

**Module boundary 提醒**：`Shared/WidgetAppGroup.swift` 與 `NeuLedgerWidget/` 是 **Xcode target membership 的檔案，不在 Features SPM package 裡**。它們看不到 `Domain` / `Common` 的任何型別。新 key 只傳 `String`（載具 id），不要試圖在那邊引用 `Carrier`。

**注入的縫已經存在**：`CarrierClient+Live.swift:18` 已有 `@Dependency(\.widgetSyncAdapter) var widgetSyncAdapter`，`create` / `update` / `delete` / `setActiveForWidget` 都已經在用它（`:27,32,37,42`）。所以這個 Task 不需要新增注入點，只需要在 `WidgetSyncAdapter` 介面加一個 endpoint。

- [ ] **Step 1: 介面加 endpoint**

`Features/Sources/Domain/Adapters/WidgetSyncAdapter.swift`，跟既有三個 `public var` 同形（全部是 `async -> Void`、不 throw）：

```swift
/// 把「App 內選了哪一張載具給 Widget 顯示」寫進 App Group，讓 Widget
/// 在使用者沒有長按編輯小工具時也能跟著變（audit A9）。
public var setActiveCarrierId: @Sendable (_ id: String) async -> Void
```

- [ ] **Step 2: 寫失敗的測試**

```swift
import Testing
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("CarrierClient Live — widget hand-off")
struct CarrierClientLiveTests {
    private final class WidgetSyncSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var ids: [String] = []
        func record(_ id: String) { lock.lock(); ids.append(id); lock.unlock() }
        var recorded: [String] { lock.lock(); defer { lock.unlock() }; return ids }
    }

    @Test("choosing a carrier for the widget writes the active id into the App Group")
    func testSetActiveForWidgetWritesTheActiveId() async throws {
        let spy = WidgetSyncSpy()
        let chosen = UUID()
        let container = try freshContainer()

        try await withDependencies {
            $0.modelContainer = container
            $0.userSettingsAdapter = .init(
                string: { _ in "" },
                setString: { _, _ in }
            )
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
            $0.widgetSyncAdapter.setActiveCarrierId = { spy.record($0) }
        } operation: {
            try await CarrierClient.liveValue.setActiveForWidget(chosen)
        }

        #expect(spy.recorded == [chosen.uuidString],
                "App 內選了載具就必須把 active id 交給 App Group，否則 Widget 不會跟著變")
    }
}
```

**注意**：`userSettingsAdapter` 的覆寫要照該型別實際的成員來寫（`UserSettingsAdapter` 的簽章見 `Features/Sources/Domain/Adapters/UserSettingsAdapter.swift`）；上面是形狀示意，成員名以原始碼為準。`freshContainer()` 若該 suite 沒有就照其他 CoreTests 的寫法建一顆 `isStoredInMemoryOnly: true` 的容器——**絕對不要**用預設 configuration（測試 host 繼承 App Group 權限，會動到真實資料庫）。

- [ ] **Step 3: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/CarrierClientLiveTests 2>&1 | tail -40
```

- [ ] **Step 4: 寫入端**

`WidgetSyncAdapter+Live.swift`：常數加 `private static let keyActiveId = "carrierActiveId"`，並在檔頭那段「Keep in sync with Shared/WidgetAppGroup.swift」的註解裡把它列進去（R5）。新增 endpoint：

```swift
setActiveCarrierId: { id in
    guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
    defaults.set(id, forKey: keyActiveId)
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
}
```

`CarrierClient+Live.swift` 的 `setActiveForWidget`：保留既有寫 `.widgetCarrierId` 的行為（App 內的 UI 讀它），**額外**呼叫 `widgetSyncAdapter.setActiveCarrierId(id)`。

- [ ] **Step 5: 讀取端**

`Shared/WidgetAppGroup.swift`：`Key` 加 `case carrierActiveId`，新增

```swift
/// The carrier the user picked in-app for the widget to show.
/// `nil` when the user has never chosen one.
static func readActiveCarrierId() -> String? {
    guard let defaults, let id = defaults.string(forKey: Key.carrierActiveId.rawValue), !id.isEmpty else { return nil }
    return id
}
```

`NeuLedgerWidget/CarrierWidget.swift` 的 `resolveState(for:)`：fallback 鏈從「intent 選的 → `all.first`」改成「intent 選的 → **App 內選的 active id** → `all.first`」。

- [ ] **Step 6: 跑測試確認通過**（同 Step 3 指令），並確認 `NeuLedgerWidget` target 有編譯成功

- [ ] **Step 7: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -am "fix(widget): carry the in-app carrier choice into the App Group so the widget follows it [ci skip]"
```

---

## Task 3: 交易列顯示分類（audit #22 前半）

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionsFeature.swift:13-23`（state）與載入路徑
- Modify: `Features/Sources/Features/Transactions/TransactionsView.swift:246-258`
- Test: `NeuLedgerTests/Tests/FeaturesTests/TransactionsFeatureTests.swift`

現況：`transactionRow` 傳 `title: transaction.note ?? transaction.type.displayName`、`subtitle: transaction.type.displayName`（`TransactionsView.swift:252-253`），**分類名從不出現**。`TransactionsFeature.State` 裡沒有 categories。

- [ ] **Step 1: 寫失敗的測試**

新增 action `case categoriesLoaded([Domain.Category])`，state 加 `categoryNames`。

```swift
@Test("loading the list also loads the category names the rows need")
func testTaskLoadsCategoryNames() async throws {
    let foodId = UUID()
    let food = Domain.Category(
        id: foodId, name: "餐飲", icon: "fork.knife", color: "#FF6B6B",
        type: .expense, isDefault: false
    )
    let store = await TestStore(initialState: TransactionsFeature.State()) {
        TransactionsFeature()
    } withDependencies: {
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.listCategories = { _ in [food] }
    }
    await MainActor.run { store.exhaustivity = .off }

    await store.send(.task)
    await store.receive(\.categoriesLoaded) {
        $0.categoryNames = [foodId: "餐飲"]
    }
    await store.skipReceivedActions()
    await store.finish()
}

@Test("a failure loading the categories does not block the list itself")
func testCategoryLoadFailureDoesNotSetLoadError() async throws {
    let store = await TestStore(initialState: TransactionsFeature.State()) {
        TransactionsFeature()
    } withDependencies: {
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.listCategories = { _ in throw CoreError.notFound("SDCategory") }
    }
    await MainActor.run { store.exhaustivity = .off }

    await store.send(.task)
    await store.skipReceivedActions()
    // 分類名只是標記，載不到就退回 fallback 文案；loadError 留給交易本身的失敗。
    await MainActor.run {
        #expect(store.state.loadError == nil, "分類載入失敗不得擋住整張列表")
    }
    await store.finish()
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/TransactionsFeatureTests 2>&1 | tail -40
```

- [ ] **Step 3: state 加 lookup 與載入**

state 加 `public var categoryNames: [Category.ID: String] = [:]`（**存名字而不是整個 `Category`**——view 只需要名字，存 lookup 讓 view 端零查找成本）。`.task` 的 `.merge` 裡加一條 `listCategories(nil)` 的 effect，沿用既有錯誤形狀（失敗**不**擋列表：分類名只是標記，`loadError` 留給交易本身的失敗）。

- [ ] **Step 4: view 用它**

```swift
TransactionRow(
    title: transaction.note ?? transaction.type.displayName,
    subtitle: store.categoryNames[transaction.categoryId ?? UUID()]
        ?? String(localized: "transactions_row_uncategorized", bundle: .main),
    ...
)
```

`transaction.categoryId` 是 optional，且「無分類」是合法狀態（上一個 PR 的刪除連鎖就會產生），所以 fallback 文案是必要的、要新增 localization key（en + zh-Hant）。**不要**用 `transaction.type.displayName` 當 fallback——那會讓「無分類」和「有分類但還沒載入」看起來一樣。

- [ ] **Step 5: 跑測試確認通過**

- [ ] **Step 6: 突變驗證**

把 `subtitle` 改回 `transaction.type.displayName`，確認有測試變紅。若沒有，表示測試只驗了 state 沒驗 view 的接線——那就補一條斷言 `subtitle` 來源的測試。

- [ ] **Step 7: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -am "fix(transactions): show the category on each row instead of repeating the type [ci skip]"
```

---

## Task 4: Domain — 結構化洞察描述子與純挑選函式（#7 第一層）

**先讀**：`docs/audits/2026-09-23-health-audit/02-application-core.md` 的 **B9**。

**Files:**
- Create: `Features/Sources/Domain/Entities/InsightDescriptor.swift`
- Create: `Features/Sources/Domain/Analysis/InsightComposer.swift`
- Modify: `Features/Sources/Domain/Clients/InsightsClient.swift:55`
- Test: `NeuLedgerTests/Tests/DomainTests/Analysis/InsightComposerTests.swift`（新建）
- Test: `NeuLedgerTests/Tests/DomainTests/Clients/InsightsClientTests.swift:117`（既有，要跟著改型別）

**Interfaces:**
- Produces: `InsightDescriptor`、`InsightComposer.compose(from:)`、`InsightsClient.generateInsights` 的新簽章 `@Sendable (_ summary: SpendingSummary) async throws -> [InsightDescriptor]`
- Consumes: `SpendingSummary`（既有，`Features/Sources/Domain/.../SpendingSummary.swift`）

**`InsightDescriptor` 不得帶任何使用者可見字串**。它帶的是「哪一種洞察 + 算出來的數字」，字串由 Features 層組。

- [ ] **Step 1: 寫失敗的測試**

```swift
@Suite("InsightComposer")
struct InsightComposerTests {
    @Test("the top spending category becomes a descriptor carrying its real share")
    func testTopCategoryDescriptor() {
        let summary = SpendingSummary(
            monthTotal: 20_000, weekTotal: 3_000,
            topCategoryName: "餐飲", topCategoryAmount: 8_400,
            savingsPercentage: 0.28
        )
        let out = InsightComposer.compose(from: summary)
        let top = out.compactMap { if case let .topCategory(name, amount, share) = $0.kind { return (name, amount, share) } else { return nil } }.first
        #expect(top?.0 == "餐飲")
        #expect(top?.1 == 8_400)
        // 8400 / 20000 = 0.42 —— 這個比例必須是算出來的，不是傳進來的
        #expect(top.map { abs($0.2 - 0.42) < 0.0001 } == true)
    }

    @Test("a summary with no activity produces no descriptors")
    func testEmptySummaryProducesNothing() {
        let out = InsightComposer.compose(from: SpendingSummary(monthTotal: 0, weekTotal: 0))
        #expect(out.isEmpty, "一筆帳都沒有時不得憑空產生洞察——那正是本 PR 要移除的行為")
    }

    @Test("monthTotal of zero never divides by zero")
    func testZeroMonthTotalDoesNotProduceAShare() {
        let summary = SpendingSummary(
            monthTotal: 0, weekTotal: 0,
            topCategoryName: "餐飲", topCategoryAmount: 500
        )
        let out = InsightComposer.compose(from: summary)
        let shares = out.compactMap { if case let .topCategory(_, _, share) = $0.kind { return share } else { return nil } }
        #expect(shares.isEmpty, "monthTotal 為 0 時沒有比例可言，不得產生 topCategory 描述子")
        #expect(shares.allSatisfy { $0.isFinite }, "不得出現 inf / nan")
    }

    @Test("the savings descriptor carries the real percentage, negative included")
    func testSavingsDescriptor() {
        let positive = InsightComposer.compose(from: SpendingSummary(
            monthTotal: 10_000, weekTotal: 1_000, savingsPercentage: 0.28
        ))
        let rate = positive.compactMap { if case let .savingsRate(r) = $0.kind { return r } else { return nil } }.first
        #expect(rate.map { abs($0 - 0.28) < 0.0001 } == true)

        // 負儲蓄率（花得比賺得多）必須照樣產生描述子，不得被門檻吃掉——
        // 那正是使用者最需要看到的一則。
        let negative = InsightComposer.compose(from: SpendingSummary(
            monthTotal: 10_000, weekTotal: 1_000, savingsPercentage: -0.15
        ))
        let negRate = negative.compactMap { if case let .savingsRate(r) = $0.kind { return r } else { return nil } }.first
        #expect(negRate.map { abs($0 + 0.15) < 0.0001 } == true, "負儲蓄率不得被過濾掉")
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/InsightComposer 2>&1 | tail -40
```
Expected: 編譯失敗（型別不存在）。

- [ ] **Step 3: 實作 `InsightDescriptor`**

```swift
import Foundation

/// 一則洞察的**結構化**內容：種類 + 算好的數字，不含任何使用者可見字串。
///
/// 字串與金額格式化刻意留在 Features 層：承載 `InsightsClient` 實作的
/// `Core` target 只依賴 `Domain`，碰不到 `Common` 的 `twdFormatted`
/// 也碰不到 main bundle 的 localization（`Features/Package.swift:73-87`）。
/// 把字串寫死在 Application 層正是 audit B9 的結構性成因。
public struct InsightDescriptor: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// 本月支出最高的分類：名稱、金額、占本月總支出的比例（0...1）。
        case topCategory(name: String, amount: Decimal, share: Double)
        /// 本月儲蓄率（可為負）。
        case savingsRate(Double)
        /// 本週支出總額。
        case weekSpending(Decimal)
    }

    public let id: UUID
    public let kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }
}
```

- [ ] **Step 4: 實作 `InsightComposer`**

純 `enum` + `static func compose(from:) -> [InsightDescriptor]`。規則：

- `topCategory`：只在 `topCategoryName` 非 nil、`topCategoryAmount` > 0 **且** `monthTotal` > 0 時產生（`monthTotal == 0` 就沒有比例可言，直接不產生——避免除以零）。
- `savingsRate`：只在 `savingsPercentage != 0` 時產生。
- `weekSpending`：只在 `weekTotal` > 0 時產生。
- 全部都不成立時回傳 `[]`。**沒有資料就沒有洞察**，不得補任何預設卡片。
- 順序固定：`topCategory`、`savingsRate`、`weekSpending`（讓測試與畫面都可預期）。

`share` 用 `Double` 計算：`(topCategoryAmount as NSDecimalNumber).doubleValue / (monthTotal as NSDecimalNumber).doubleValue`，並在 `monthTotal > 0` 的 guard 之後才算。

- [ ] **Step 5: 改 `InsightsClient` 的簽章**

```swift
/// Carousel-style list of insights for the Dashboard.
/// 回傳**結構化**描述子；字串與金額格式化由 Features 層負責（見
/// `InsightDescriptor` 的註解說明為什麼不能在這一層做）。
public var generateInsights: @Sendable (_ summary: SpendingSummary) async throws -> [InsightDescriptor] = { _ in [] }
```

`InsightsClientTests.swift:117` 會編譯失敗，跟著改成 `InsightDescriptor`。

- [ ] **Step 6: 跑測試確認通過**

- [ ] **Step 7: 突變驗證**

把 `share` 改成直接回傳傳進來的某個值（而不是算出來的比例），確認 `testTopCategoryDescriptor` 變紅——這條測試存在的意義就是釘住「比例是算的」。

- [ ] **Step 8: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -am "feat(domain): compose insights as structured descriptors instead of prebuilt strings [ci skip]"
```

---

## Task 5: Application — 刪掉三筆寫死的假資料（#7 第二層）

**Files:**
- Modify: `Features/Sources/Application/Insights/InsightsClient+Live.swift:193-220`
- Test: `NeuLedgerTests/Tests/DomainTests/Clients/InsightsClientTests.swift`

**Interfaces:**
- Consumes: `InsightComposer.compose(from:)`（Task 4）

- [ ] **Step 1: 寫失敗的測試**

```swift
@Test("generateInsights derives everything from the summary and invents nothing")
func testGenerateInsightsInventsNothing() async throws {
    let live = InsightsClient.liveValue
    let out = try await live.generateInsights(SpendingSummary(monthTotal: 0, weekTotal: 0))
    #expect(out.isEmpty, "全 0 的 summary 不得產生任何洞察——寫死的假資料就是這樣被看見的")
}
```

- [ ] **Step 2: 跑測試確認失敗**（目前回三筆硬編，所以 `isEmpty` 為 false）

- [ ] **Step 3: 換成一行**

```swift
generateInsights: { summary in
    // 真實數字一律由 Domain 的純函式算；這一層不組字串也不格式化金額
    // （`Core` target 碰不到 `Common` 與 main bundle，見 InsightDescriptor 註解）。
    InsightComposer.compose(from: summary)
},
```

把行 193-196 那段「TODO: replace with FoundationModels output」的註解一併刪掉——它描述的是已經不存在的做法。

- [ ] **Step 4: 跑測試確認通過**

- [ ] **Step 5: 確認假字串真的消失**

```bash
grep -rn "3,200\|8,400\|儲蓄率達標\|本週支出減少" Features/Sources/ ; echo "exit=$? (1 = 乾淨)"
```

- [ ] **Step 6: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -am "fix(insights): stop returning three invented amounts and derive insights from the ledger [ci skip]"
```

---

## Task 6: Features — 組真實 summary 並本地化（#7 第三層）

**Files:**
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift:471-483`（`insightsEffect`）+ 新的映射函式
- Modify: `Features/Sources/Features/Dashboard/Sections/InsightCarousel.swift:73-84`（R8 空狀態）
- Modify: `NeuLedger/Resources/Localizable.xcstrings`
- Test: `NeuLedgerTests/Tests/FeaturesTests/Dashboard/DashboardFeatureInsightTests.swift`

**Interfaces:**
- Consumes: `InsightDescriptor`（Task 4）、`insightsClient.generateInsights`（Task 5）、既有的 `insightsClient.todayStats` / `categoryProportions`（R3）

現況：`insightsEffect` 傳的是 `SpendingSummary(monthTotal: 0, weekTotal: 0)`——**全 0**（`DashboardFeature.swift:475`）。那正是為什麼 Client 端必須寫死假資料才看起來有內容。

- [ ] **Step 1: 寫失敗的測試**

```swift
/// 捕捉 `generateInsights` 實際收到的 summary。`@unchecked Sendable` + NSLock
/// 是這個 suite 既有 spy 的寫法。
private final class SummaryCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var value: SpendingSummary?
    func record(_ s: SpendingSummary) { lock.lock(); value = s; lock.unlock() }
    var captured: SpendingSummary? { lock.lock(); defer { lock.unlock() }; return value }
}

@Test("the summary handed to generateInsights carries real totals, not zeros")
func testInsightsEffectBuildsARealSummary() async throws {
    let capture = SummaryCapture()
    let foodId = UUID()
    let store = await TestStore(initialState: DashboardFeature.State()) {
        DashboardFeature()
    } withDependencies: {
        $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        $0.insightsClient.todayStats = { _ in
            StatsSnapshot(today: 500, week: 3_000, savingsPercentage: 0.28)
        }
        $0.insightsClient.categoryProportions = { _ in
            [
                CategoryProportion(categoryId: foodId, categoryName: "餐飲", amount: 8_400),
                CategoryProportion(categoryId: UUID(), categoryName: "交通", amount: 11_600)
            ]
        }
        $0.insightsClient.generateInsights = { summary in
            capture.record(summary)
            return []
        }
        $0.insightsClient.weeklySparkline = { _ in [] }
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.balances = { [:] }
        $0.ledgerClient.listActiveAccounts = { [] }
        $0.ledgerClient.listCategories = { _ in [] }
    }
    await MainActor.run { store.exhaustivity = .off }

    await store.send(.task)
    await store.skipReceivedActions()
    await store.finish()

    let summary = try #require(capture.captured)
    #expect(summary.weekTotal == 3_000, "weekTotal 必須來自 todayStats，不是 0")
    #expect(summary.monthTotal == 20_000, "monthTotal 必須是 categoryProportions 的總和，不是 0")
    #expect(summary.topCategoryName == "餐飲" || summary.topCategoryName == "交通",
            "top category 必須來自真實資料")
    #expect(abs(summary.savingsPercentage - 0.28) < 0.0001)
}

@Test("a descriptor becomes a card carrying the formatted amount and percentage")
func testDescriptorIsLocalisedWithTheFormattedAmount() async throws {
    let descriptors = [
        InsightDescriptor(kind: .topCategory(name: "餐飲", amount: 8_400, share: 0.42))
    ]
    let store = await TestStore(initialState: DashboardFeature.State()) {
        DashboardFeature()
    } withDependencies: {
        $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        $0.insightsClient.generateInsights = { _ in descriptors }
        $0.insightsClient.todayStats = { _ in .zero }
        $0.insightsClient.categoryProportions = { _ in [] }
        $0.insightsClient.weeklySparkline = { _ in [] }
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.balances = { [:] }
        $0.ledgerClient.listActiveAccounts = { [] }
        $0.ledgerClient.listCategories = { _ in [] }
    }
    await MainActor.run { store.exhaustivity = .off }

    await store.send(.task)
    await store.skipReceivedActions()
    await store.finish()

    let card = try #require(await MainActor.run { store.state.insights.first })
    // 不比對整句文案（那會把測試綁死在文字上），只釘住「真實數字有出現」。
    #expect(card.metric == "42%")
    #expect(card.body.contains(Decimal(8_400).twdFormatted),
            "卡片內文必須帶格式化後的真實金額")
    #expect(card.body.contains("餐飲"))
    #expect(card.metricColor == .expense)
}
```

**注意**：`CategoryProportion` 的成員名以 `Features/Sources/Domain/` 下的定義為準（上面是形狀示意）。`StatsSnapshot(today:week:savingsPercentage:)` 的簽章見 `Features/Sources/Domain/.../StatsSnapshot.swift:8`。

**既有測試會編譯失敗，必須一起改**：`DashboardFeatureInsightTests.swift:12-14`、`:45-47`、`:65` 三處 `generateInsights = { _ in mock }` 的 `mock` 現在必須是 `[InsightDescriptor]`。`insightsLoaded` 的 payload **仍然是 `[InsightData]`**（Feature 負責映射），所以 `$0.insights = mock` 不再成立——要改成斷言映射後的結果，或把那幾條測試的 mock 換成描述子並相應調整期望值。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/DashboardFeatureInsightTests 2>&1 | tail -40
```

- [ ] **Step 3: 組真實 summary**

`insightsEffect` 改成先取真實數字再組 summary。`monthTotal` 與 top category 由 `categoryProportions(當月 DateInterval)` 得到（總和 = monthTotal，第一筆 = top category，該 endpoint 已依金額降冪排序）；`weekTotal` 與 `savingsPercentage` 由 `todayStats(now)` 得到。當月區間用 `BudgetPeriod.monthly.dateInterval(containing:)`（**不要**自己寫 `calendar.dateInterval(of: .month,...)`——spec §5 只允許一處）。時間一律走 `@Dependency(\.date.now)`，不得裸 `Date()`。

- [ ] **Step 4: 描述子 → localized `InsightData`**

在 Features 層加一個私有映射（`Transaction+Presentation.swift` 旁邊或 `DashboardFeature` 內），每個 `Kind` 對一組 localization key：

| Kind | title key | body key | metric | metricColor |
|---|---|---|---|---|
| `topCategory` | `dashboard_insight_top_category_title` | `dashboard_insight_top_category_body` | `"\(Int(share * 100))%"` | `.expense` |
| `savingsRate` | `dashboard_insight_savings_title` | `dashboard_insight_savings_body` | `"\(Int(rate * 100))%"` | rate >= 0 ? `.income` : `.expense` |
| `weekSpending` | `dashboard_insight_week_title` | `dashboard_insight_week_body` | `amount.twdCompact` | `.neutral` |

body 的模板帶參數（分類名、`amount.twdFormatted`、百分比）。**en 與 zh-Hant 都要填**。`cta` 沿用既有的三個字串或設 `nil`——不要為了填滿而發明新的 CTA。

- [ ] **Step 5: 真正的空狀態（R8）**

`InsightCarousel.swift` 的 `.loaded && isEmpty` 分支不得再用 `dashboard_insight_loading_*`。新增 `dashboard_insight_empty_title` / `dashboard_insight_empty_body`（例如「還沒有足夠的資料」／「記幾筆帳之後這裡會出現你的支出洞察」），`.idle`/`.loading` 繼續用載入中那兩個 key。

- [ ] **Step 6: 跑測試確認通過**

- [ ] **Step 7: 突變驗證**

把 `insightsEffect` 的 summary 改回 `SpendingSummary(monthTotal: 0, weekTotal: 0)`，確認 `testInsightsEffectBuildsARealSummary` 變紅。這條是整個 Task 6 的存在理由。

- [ ] **Step 8: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -am "feat(dashboard): feed the insight carousel real spending data and localise it in the view layer [ci skip]"
```

---

## Task 7: Dashboard 與交易分頁互相同步（audit #17）

**先讀**：`docs/audits/2026-09-23-health-audit/01-features.md` 的 **A8**。

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift:131-134`（`tabSelected`）
- Test: `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift`

現況：`case let .tabSelected(tab): state.selectedTab = tab; return .none`。兩個 child 各自只重載自己，MainTab 不做跨 tab 轉發；而 `TransactionsView.swift:43` 的 `.task` 在 `TabView` 裡只會在該 tab 內容首次建立時觸發一次。所以 Dashboard 新增 → 切到交易分頁 → 新那筆不在列表上；反向亦然。

**R7：採「切 tab 時重載」**，並且**重載期間不得清空既有資料**。

- [ ] **Step 1: 寫失敗的測試**

```swift
@Test("switching to the transactions tab reloads it, so a dashboard change shows up")
func testSwitchingToTransactionsReloads() async throws {
    let store = await TestStore(initialState: MainTabFeature.State()) {
        MainTabFeature()
    } withDependencies: {
        $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.listCategories = { _ in [] }
        $0.ledgerClient.tick = { 0 }
    }
    await MainActor.run { store.exhaustivity = .off }

    // 起始就是 .dashboard，所以切到 .transactions 是真的換 tab
    await store.send(.tabSelected(.transactions)) {
        $0.selectedTab = .transactions
    }
    await store.receive(\.transactions.task)
    await store.skipReceivedActions()
    await store.finish()
}

@Test("switching back to the dashboard tab reloads it too")
func testSwitchingToDashboardReloads() async throws {
    var initial = MainTabFeature.State()
    initial.selectedTab = .transactions
    let store = await TestStore(initialState: initial) {
        MainTabFeature()
    } withDependencies: {
        $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        $0.ledgerClient.listAll = { _ in [] }
        $0.ledgerClient.balances = { [:] }
        $0.ledgerClient.listActiveAccounts = { [] }
        $0.ledgerClient.listCategories = { _ in [] }
        $0.insightsClient.todayStats = { _ in .zero }
        $0.insightsClient.categoryProportions = { _ in [] }
        $0.insightsClient.generateInsights = { _ in [] }
        $0.insightsClient.weeklySparkline = { _ in [] }
        $0.ledgerClient.tick = { 0 }
    }
    await MainActor.run { store.exhaustivity = .off }

    await store.send(.tabSelected(.dashboard)) {
        $0.selectedTab = .dashboard
    }
    await store.receive(\.dashboard.task)
    await store.skipReceivedActions()
    await store.finish()
}

@Test("re-tapping the tab you are already on does not reload")
func testReselectingTheSameTabDoesNotReload() async throws {
    let store = await TestStore(initialState: MainTabFeature.State()) {
        MainTabFeature()
    } withDependencies: {
        $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
    }
    // 這條要 exhaustive：它的全部意義就是「沒有任何 effect 被送出」。
    await store.send(.tabSelected(.dashboard))
    await store.finish()
}
```

**注意**：`.transactions` / `.dashboard` 這兩個 child 的 scope 名稱與 `MainTabFeature.Action` 的 case 名以原始碼為準；`Tab` 只有 `dashboard` / `settings` / `transactions` 三個 case（`MainTabFeature.swift:8-12`），所以實作的 `switch` 用 `default` 接 `.settings`。最後一條刻意**不**關 exhaustivity——它要證明的是「什麼都沒發生」。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/MainTabFeatureTests 2>&1 | tail -40
```

- [ ] **Step 3: 實作**

```swift
case let .tabSelected(tab):
    // 同一個 tab 再點一次不重載（否則每次點都打一輪查詢）。
    guard tab != state.selectedTab else {
        state.selectedTab = tab
        return .none
    }
    state.selectedTab = tab
    // 切 tab 就重載目標 tab：這同時涵蓋 CloudKit 背景同步——另一台裝置
    // 改動後切回來也會更新，而跨 tab 轉發 delegate 只涵蓋本機異動
    // （audit A8 的修法建議，plan R7）。
    switch tab {
    case .dashboard:    return .send(.dashboard(.task))
    case .transactions: return .send(.transactions(.task))
    default:            return .none
    }
```

確認兩個 child 的載入 action 在重載期間**保留既有資料**（`transactions` 不清空、section phase 轉 loading 但舊值留著）。若既有實作會清空，在此 Task 一併改掉並加測試釘住。

- [ ] **Step 4: 跑測試確認通過**

- [ ] **Step 5: 突變驗證**

把 `guard tab != state.selectedTab` 拿掉，確認 `testReselectingTheSameTabDoesNotReload` 變紅。

- [ ] **Step 6: Commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer git commit -am "fix(main-tab): reload the tab being switched to so the two tabs stop showing stale data [ci skip]"
```

---

## 收尾（controller 執行，不是 implementer）

- [ ] 每個 Task 後一次獨立 review；全部完成後一次全分支 review（**拆成兩位並行審查者**，各給源碼閱讀上限並要求增量寫報告——單一審查者在 180KB diff 上會 timeout，這在前一個 PR 發生過兩次）。
- [ ] 完整 scheme 在載入閘門後跑（等 1 分鐘 load average < 20），跑完等 `pgrep -f "xcodebuild test"` 歸零再讀數字。
- [ ] 測試數用逐 suite 名稱比對，不要只看總數（平行 clone 會截斷行首）。
- [ ] 寫 PR body，然後走 `superpowers:finishing-a-development-branch` 的選單，**由使用者決定**怎麼落地。
