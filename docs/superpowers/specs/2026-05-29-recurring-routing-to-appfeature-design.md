# 把 recurring 通知入站路由上移到 AppFeature(中央 router）

**日期:** 2026-05-29
**類型:** Refactor（行為保留，結構解耦）
**前置:** 接續 AccessoryBar 拆分（commits `aaa09d0`/`9f27f3d`/`e34d017`），同樣在 `refactor` 分支。

## 動機

App 目前有**兩套平行的「外部進入 → 導航」機制**：

- **Deep link（URL）** 走中央 router：`AppView.onOpenURL` → `AppFeature.deepLinkReceived` → `deeplinkClient.parseLinkTo(url)` → `RouteLinkDestination` → `AppFeature.route(...)`（會 `guard case .main` 後改寫 MainTab 巢狀 state，見既有 `.carrierManagement`）。
- **Recurring 通知點擊** 卻硬接在 `MainTabFeature.task`：自己訂閱 `notificationAdapter.pendingConfirmations()`、自己 fetch、自己路由。

兩者本質都是「外部 re-entry → 導航」。本案把 recurring 的**入站路由**收斂進中央 router，使其與 deep link 一致，並讓 `MainTabFeature` 更瘦（只剩 tab 切換、child delegate 轉發、與 recurring 的「存檔後」那半）。

## 範圍

**只搬「入站路由」那一半**：通知點擊 → 解析 template → 開 Dashboard 確認單 + 切 tab。

**不在範圍：**
- 「存檔後 reschedule」那半（`savedRecurringConfirmation` → 更新 `nextDueDate` + 重排提醒）**維持留在 MainTab**。
- 不接 `RecurringUseCase.tick()`（那是另一個目前未接的自動入帳功能）。
- 不改 `DeeplinkClient` 命名（雖然它將解析非-URL 輸入；改名另議）。

## 取法：B — DeeplinkClient 當解析器

依「解析放 client、router 保持 thin、state-driven」原則，由 `DeeplinkClient` 把 recurring id 解析成 `RouteLinkDestination`，`AppFeature` 只負責訂閱來源並套用 destination。

## 詳細設計

### 1. `RouteLinkDestination`（Domain/UseCases/DeeplinkClient.swift）
新增 case：
```swift
case recurringConfirmation(RecurringTransaction)
```
（`RecurringTransaction` 為 Domain 實體，已 `Equatable`/`Sendable`，符合 enum 既有約束。）

### 2. `DeeplinkClient`（Domain 介面 + Core/Application Live）
介面新增：
```swift
public var resolveRecurringConfirmation: @Sendable (_ id: RecurringTransaction.ID) async throws -> RouteLinkDestination
```
Live 實作（注入 `recurringTransactionClient`，沿用 MainTab 現行查法）：
```swift
resolveRecurringConfirmation: { id in
    let all = try await recurringTransactionClient.fetchAll()
    guard let template = all.first(where: { $0.id == id }) else { return .none }
    return .recurringConfirmation(template)
}
```
找不到（已刪）→ 回 `.none`。`testValue` 為 `@DependencyClient` 自動 stub。

### 3. `AppFeature`（Features/AppFeature.swift）
- 新增 `@Dependency(\.notificationAdapter)`（取得 stream；`deeplinkClient` 已有）。
- 新增 `case task` action 與 `private enum CancelID { case recurringSubscription }`。
- `task` effect 訂閱通知串流，逐筆解析後送 `.route`（解析失敗或 `.none` 皆安全 no-op）：
```swift
case .task:
    return .run { send in
        for await id in notificationAdapter.pendingConfirmations() {
            let dest = (try? await deeplinkClient.resolveRecurringConfirmation(id)) ?? .none
            await send(.route(dest))
        }
    }
    .cancellable(id: CancelID.recurringSubscription)
```
- `.route` switch 新增 case（比照既有 `.carrierManagement` 寫法）：
```swift
case let .recurringConfirmation(template):
    guard case .main(var mainState) = state else { return .none }
    mainState.selectedTab = .dashboard
    mainState.dashboard.addTransaction = AddTransactionFeature.State(
        mode: .addRecurringConfirmation(template)
    )
    state = .main(mainState)
    return .none
```

### 4. `AppView`（Features/AppView.swift）
contentView 加上根層生命週期掛點（app analog，平行於 MainTabView 的 `.task`）：
```swift
.task { Self.store.send(.task) }
```

### 5. `MainTabFeature`（Features/MainTab/MainTabFeature.swift）— 清理
- `.task`：移除訂閱 `pendingConfirmations` 的 `group.addTask { ... }` 子任務（保留 `.send(.accessory(.task))` 與載入 `showAccessoryBar`）。
- 移除 `case pendingRecurringConfirmationReceived` 與 `case recurringTemplateFetched`（含其 Action enum case）。
- 移除 `var pendingRecurringConfirmationId`（vestigial：全 repo 無人讀，僅測試斷言）。
- **保留** `dashboard(.delegate(.savedRecurringConfirmation(...)))` 的 reschedule 邏輯，只刪掉其中 `state.pendingRecurringConfirmationId = nil` 那一行。
- 依賴：保留 `recurringTransactionClient` 與 `notificationAdapter`（reschedule 仍需）。

### 行為等價說明
- 仍是**通知點擊驅動**（OS 由 `UNUserNotificationCenterDelegate` 投遞，非 URL；故串流來源不變，只是訂閱者從 MainTab 改為 AppFeature）。
- 通知在 splash/onboarding 期間到達 → `route(.recurringConfirmation)` 的 `guard case .main` 會忽略 → 與現況「MainTab 未掛載故不處理」實質相同（且更明確）。
- 開啟確認單 → 使用者存檔 → `savedRecurringConfirmation` 仍由 MainTab 處理 reschedule（不變）。

## 測試計畫（TDD）

- **`AppFeatureTests`（新增 recurring 路由測試）**：
  - `route(.recurringConfirmation(template))` 於 `.main` → 斷言 `selectedTab == .dashboard` 且 `dashboard.addTransaction?.mode == .addRecurringConfirmation(template)`。
  - 同上但 state 為 `.onboarding` → no-op（state 不變）。
  - `.task` 訂閱：覆寫 `deeplinkClient.resolveRecurringConfirmation = { _ in .recurringConfirmation(template) }` 與 `notificationAdapter.pendingConfirmations = { AsyncStream { $0.yield(id); $0.finish() } }`，送 `.task` → 收到 `.route(.recurringConfirmation(template))` 並完成路由（`exhaustivity = .off` + `finish()`，因串流非同步）。
  - 失敗路徑：覆寫 `resolveRecurringConfirmation = { _ in .none }` → `.task` → `route(.none)` 為 no-op。
- **`MainTabFeatureTests`**：移除 `MainTabRecurringConfirmationTests`（`pendingRecurringConfirmationReceived` 已搬走）；其餘（`task & accessory routing`）不受影響。
- **（選配）Core `DeeplinkClient+Live` 解析測試**：以 in-memory `recurringTransactionClient` 驗證命中 → `.recurringConfirmation`、查無 → `.none`。低優先（live 實作僅 `fetchAll().first`）；不做則由上述 AppFeature 的 resolver 覆寫涵蓋兩條路由分支。
- 全套件須維持綠燈（現為 522 passed）。

## 影響檔案

| 檔案 | 動作 |
|---|---|
| `Domain/UseCases/DeeplinkClient.swift` | `RouteLinkDestination` +case；`DeeplinkClient` +method |
| `Core/Adapters/DeeplinkClient+Live.swift` | +`resolveRecurringConfirmation` 實作（注入 `recurringTransactionClient`） |
| `Features/AppFeature.swift` | +`task`/`CancelID`/`notificationAdapter`；`.route` +case；訂閱 |
| `Features/AppView.swift` | +`.task { store.send(.task) }` |
| `Features/MainTab/MainTabFeature.swift` | 移除入站路由 + vestigial state；保留 reschedule |
| `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift` | +recurring 路由 + 訂閱測試 |
| `NeuLedgerTests/Tests/CoreTests/Adapters/DeeplinkClientTests.swift`（選配） | +解析命中/查無測試 |
| `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift` | 移除 recurring 入站測試 |
