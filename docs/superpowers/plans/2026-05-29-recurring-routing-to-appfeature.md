# recurring 通知入站路由上移到 AppFeature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「recurring 通知點擊 → 開 Dashboard 確認單 + 切 tab」這段入站路由,從 `MainTabFeature` 上移到中央 router `AppFeature`,與既有 deep-link 路由一致;reschedule 那半維持留在 MainTab。

**Architecture:** `DeeplinkClient` 新增 `resolveRecurringConfirmation(id)` 把 recurring id 解析成 `RouteLinkDestination.recurringConfirmation(template)`(取法 B,解析放 client)。`AppFeature` 新增 `.task` 訂閱 `notificationAdapter.pendingConfirmations()`,逐筆解析後送 `.route(...)`,於 `.route` handler `guard case .main` 後改寫 MainTab 巢狀 state(比照既有 `.carrierManagement`)。`MainTabFeature` 移除自己的訂閱/入站 case/vestigial state。行為保留(仍是通知點擊驅動)。

**Tech Stack:** Swift / TCA v1.23.1（`@Reducer`、`@ObservableState`、`@Dependency`、`@DependencyClient`、enum State + `.ifCaseLet`、`RouteLinkDestination` 路由）/ Swift Testing（`@Suite`/`@Test`/`TestStore`）/ xcodebuild。

**行為保留（refactor）。** 每個 commit 須建置 + 測試綠燈。全套件目前 522 passed。

---

## File Structure

| 檔案 | 動作 | 職責 |
|---|---|---|
| `Features/Sources/Domain/UseCases/DeeplinkClient.swift` | 改 | `RouteLinkDestination` +`recurringConfirmation`；`DeeplinkClient` +`resolveRecurringConfirmation` |
| `Features/Sources/Core/Adapters/DeeplinkClient+Live.swift` | 改 | `resolveRecurringConfirmation` live 實作（注入 `recurringTransactionClient`） |
| `Features/Sources/Features/AppFeature.swift` | 改 | +`task` action/`CancelID`/`notificationAdapter`；`.route` +`recurringConfirmation` handler；訂閱 |
| `Features/Sources/Features/AppView.swift` | 改 | contentView +`.task { … .send(.task) }` |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | 改 | 移除入站路由 + vestigial `pendingRecurringConfirmationId`；保留 reschedule |
| `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift` | 改 | +recurring 路由 + 訂閱測試 |
| `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift` | 改 | 移除 `MainTabRecurringConfirmationTests` |

---

## Task 1: RouteLinkDestination case + AppFeature route handler（additive）

把「目的地 + 套用」先加好並測通。此 task **不動** MainTab 的現有 recurring 流程,也不加訂閱 —— 純粹新增一個目前 production 尚未觸發、但已被測試覆蓋的路由分支(production 仍由 MainTab 走舊路)。專案保持可編譯、可測。

**Files:**
- Modify: `Features/Sources/Domain/UseCases/DeeplinkClient.swift`
- Modify: `Features/Sources/Features/AppFeature.swift`
- Test: `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift`

- [ ] **Step 1: 先寫失敗測試（route handler 行為）**

在 `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift`：把第一行 import 區塊改為加入 `import Foundation`（測試用到 `UUID`/`Date`）：
```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features
```
並在 `struct AppFeatureTests {` 內,`onboardingCompletedRoutesToMain` 之後加入兩個測試：
```swift
    @Test("recurringConfirmation route opens dashboard confirmation when in main")
    func recurringConfirmationRoutesInMain() async {
        let template = RecurringTransaction(
            id: UUID(), amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.route(.recurringConfirmation(template))) { state in
            guard case let .main(main) = state else {
                Issue.record("expected .main state")
                return
            }
            #expect(main.selectedTab == .dashboard)
            #expect(main.dashboard.addTransaction?.mode == .addRecurringConfirmation(template))
        }
    }

    @Test("recurringConfirmation route is ignored when not in main")
    func recurringConfirmationIgnoredOutsideMain() async {
        let template = RecurringTransaction(
            id: UUID(), amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: .onboarding(OnboardingFeature.State())) {
            AppFeature()
        }
        // guard case .main fails → no-op, no state change
        await store.send(.route(.recurringConfirmation(template)))
    }
```

- [ ] **Step 2: 跑測試確認失敗（編譯失敗 — RouteLinkDestination 無 .recurringConfirmation）**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AppFeatureTests
```
Expected: BUILD FAILED — `type 'RouteLinkDestination' has no member 'recurringConfirmation'`。

- [ ] **Step 3: RouteLinkDestination 加 case**

在 `Features/Sources/Domain/UseCases/DeeplinkClient.swift`，把 enum 改為：
```swift
@CasePathable
public enum RouteLinkDestination: Sendable, Equatable {
    case carrierManagement
    case recurringConfirmation(RecurringTransaction)
    case main
    case onboarding
    case none
}
```

- [ ] **Step 4: AppFeature 的 .route 加 handler**

在 `Features/Sources/Features/AppFeature.swift` 的 `case .route(let action):` 內層 `switch action {` 中,於 `case .onboarding:` 之後、`default:` 之前插入：
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

- [ ] **Step 5: 跑測試確認通過**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AppFeatureTests
```
Expected: TEST SUCCEEDED（含兩個新測試）。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Domain/UseCases/DeeplinkClient.swift \
        Features/Sources/Features/AppFeature.swift \
        NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift
git commit -m "$(cat <<'EOF'
feat(routing): add RouteLinkDestination.recurringConfirmation + AppFeature route handler [ci skip]

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Cutover — AppFeature 訂閱 + MainTab 清理

把訂閱從 MainTab 上移到 AppFeature,並補上 `DeeplinkClient` 解析器。訂閱「移入 AppFeature」與「移出 MainTab」在同一個 commit 完成,避免出現兩邊同時訂閱的重複路由窗口。

**Files:**
- Modify: `Features/Sources/Domain/UseCases/DeeplinkClient.swift`
- Modify: `Features/Sources/Core/Adapters/DeeplinkClient+Live.swift`
- Modify: `Features/Sources/Features/AppFeature.swift`
- Modify: `Features/Sources/Features/AppView.swift`
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Test: `NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift`、`NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: 先寫失敗測試（AppFeature 訂閱）**

在 `AppFeatureTests.swift` 的 `struct AppFeatureTests {` 內,接續 Task 1 的兩個測試之後加入：
```swift
    @Test("task routes a tapped recurring confirmation")
    func taskRoutesRecurringConfirmation() async {
        let template = RecurringTransaction(
            id: UUID(), amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.notificationAdapter.pendingConfirmations = {
                AsyncStream { continuation in
                    continuation.yield(template.id)
                    continuation.finish()
                }
            }
            $0.deeplinkClient.resolveRecurringConfirmation = { _ in .recurringConfirmation(template) }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        await store.receive(\.route) { state in
            guard case let .main(main) = state else {
                Issue.record("expected .main state")
                return
            }
            #expect(main.dashboard.addTransaction?.mode == .addRecurringConfirmation(template))
        }
        await store.finish()
    }

    @Test("task ignores a confirmation that resolves to none")
    func taskIgnoresUnresolvedConfirmation() async {
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.notificationAdapter.pendingConfirmations = {
                AsyncStream { continuation in
                    continuation.yield(UUID())
                    continuation.finish()
                }
            }
            $0.deeplinkClient.resolveRecurringConfirmation = { _ in .none }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        await store.receive(\.route) { state in
            guard case let .main(main) = state else {
                Issue.record("expected .main state")
                return
            }
            #expect(main.dashboard.addTransaction == nil)
        }
        await store.finish()
    }
```

- [ ] **Step 2: 跑測試確認失敗（無 .task action / 無 resolveRecurringConfirmation）**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AppFeatureTests
```
Expected: BUILD FAILED — `type 'AppFeature.Action' has no member 'task'` 及 `value of type 'DeeplinkClient' has no member 'resolveRecurringConfirmation'`。

- [ ] **Step 3: DeeplinkClient 介面加 resolveRecurringConfirmation**

在 `Features/Sources/Domain/UseCases/DeeplinkClient.swift` 的 `DeeplinkClient` struct 內,於 `canSkipOnboarding` 之後加入：
```swift
    public var resolveRecurringConfirmation: @Sendable (_ id: RecurringTransaction.ID) async throws -> RouteLinkDestination
```
（結果 struct 為：`parseLinkTo`、`canSkipOnboarding`、`resolveRecurringConfirmation` 三個成員。）

- [ ] **Step 4: DeeplinkClient live 實作**

在 `Features/Sources/Core/Adapters/DeeplinkClient+Live.swift` 把 `liveValue` 改為：
```swift
extension DeeplinkClient: DependencyKey {
    public static var liveValue: DeeplinkClient {
        @Dependency(\.userSettingsRepository) var userSettingsRepository
        @Dependency(\.recurringTransactionClient) var recurringTransactionClient
        return .init(
            parseLinkTo: { url in
                guard url.scheme == "neuledger" else { return .none }
                switch url.host {
                case "carrier-management":
                    return .carrierManagement
                default:
                    return .none
                }
            },
            canSkipOnboarding: {
                return userSettingsRepository.bool(.hasCompletedOnboarding)
            },
            resolveRecurringConfirmation: { id in
                let all = try await recurringTransactionClient.fetchAll()
                guard let template = all.first(where: { $0.id == id }) else { return .none }
                return .recurringConfirmation(template)
            }
        )
    }
}
```

- [ ] **Step 5: AppFeature 加 .task action + 依賴 + 訂閱**

在 `Features/Sources/Features/AppFeature.swift`：

(a) Action enum 加 `case task`（放在 `case route(RouteLinkDestination)` 之後）：
```swift
        case route(RouteLinkDestination)
        case task
```
(b) 依賴區塊加 notificationAdapter：
```swift
    @Dependency(\.deeplinkClient) var deeplinkClient
    @Dependency(\.notificationAdapter) var notificationAdapter

    private enum CancelID { case recurringSubscription }
```
(c) 在 `Reduce { state, action in switch action {` 內,於 `case .splashCompleted:` 之前(或任一處)加入 `.task` handler：
```swift
            case .task:
                return .run { send in
                    for await id in notificationAdapter.pendingConfirmations() {
                        let destination = (try? await deeplinkClient.resolveRecurringConfirmation(id)) ?? .none
                        await send(.route(destination))
                    }
                }
                .cancellable(id: CancelID.recurringSubscription)
```

- [ ] **Step 6: AppView 加根層 .task 掛點**

在 `Features/Sources/Features/AppView.swift` 的 `contentView` 末端(於 `.onOpenURL { … }` 之後)加入：
```swift
        .task {
            await Self.store.send(.task).finish()
        }
```

- [ ] **Step 7: 跑 AppFeature 測試確認通過**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AppFeatureTests
```
Expected: TEST SUCCEEDED（含 4 個 recurring 相關測試）。

- [ ] **Step 8: MainTabFeature 移除入站路由(5 處)**

在 `Features/Sources/Features/MainTab/MainTabFeature.swift`：

(8a) State 移除 vestigial 欄位 ——
old:
```swift
        // Recurring transaction confirmation routing
        var pendingRecurringConfirmationId: RecurringTransaction.ID? = nil

        var isAccessoryVisible: Bool {
```
new:
```swift
        var isAccessoryVisible: Bool {
```

(8b) Action 移除兩個 case ——
old:
```swift
        // Recurring transaction confirmation routing
        case pendingRecurringConfirmationReceived(RecurringTransaction.ID)
        case recurringTemplateFetched(RecurringTransaction)

        case accessory(AccessoryBarFeature.Action)
```
new:
```swift
        case accessory(AccessoryBarFeature.Action)
```

(8c) `.task` 簡化(移除 recurring 訂閱子任務,單一載入不需 task group)——
old:
```swift
            case .task:
                return .run { send in
                    // Forward to the accessory bar's own load (availability + mode) when MainTabView appears,
                    // so it runs regardless of whether the accessory is currently visible.
                    await send(.accessory(.task))
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            let showAccessoryBar = userSettingsRepository.bool(.showAccessoryBar)
                            await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                        }
                        // Subscribe to recurring notification taps
                        group.addTask {
                            for await recurringId in notificationAdapter.pendingConfirmations() {
                                await send(.pendingRecurringConfirmationReceived(recurringId))
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.task)
```
new:
```swift
            case .task:
                // Forward to the accessory bar's own load (availability + mode) when MainTabView appears,
                // so it runs regardless of whether the accessory is currently visible.
                return .run { send in
                    await send(.accessory(.task))
                    let showAccessoryBar = userSettingsRepository.bool(.showAccessoryBar)
                    await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                }
                .cancellable(id: CancelID.task)
```

(8d) 移除 Recurring 區塊兩個 case ——
old:
```swift
            // MARK: Recurring
            case let .pendingRecurringConfirmationReceived(id):
                return .run { send in
                    do {
                        let all = try await recurringTransactionClient.fetchAll()
                        guard let template = all.first(where: { $0.id == id }) else { return }
                        await send(.recurringTemplateFetched(template))
                    } catch {
                        // silently ignore — template may have been deleted
                    }
                }

            case let .recurringTemplateFetched(template):
                state.pendingRecurringConfirmationId = template.id
                state.dashboard.addTransaction = AddTransactionFeature.State(
                    mode: .addRecurringConfirmation(template)
                )
                state.selectedTab = .dashboard
                return .none

            // MARK: Child delegates
```
new:
```swift
            // MARK: Child delegates
```

(8e) `savedRecurringConfirmation` 移除 vestigial 清除行 + 未用的 `send` 參數 ——
old:
```swift
            case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):
                state.pendingRecurringConfirmationId = nil
                return .run { send in
```
new:
```swift
            case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):
                return .run { _ in
```

> 依賴不動：`recurringTransactionClient`(savedRecurringConfirmation 仍用 fetchAll/update)、`notificationAdapter`(scheduleRecurringReminder)、`userSettingsRepository`(showAccessoryBar)皆保留;`CancelID.task` 保留。

- [ ] **Step 9: 移除 MainTabFeatureTests 的 recurring suite**

在 `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift` 刪除整個 `MainTabRecurringConfirmationTests`：
old（從 `MainTabFeatureTests` 收尾大括號開始,到檔尾）:
```swift
}

@Suite("MainTabFeature — recurring confirmation")
struct MainTabRecurringConfirmationTests {

    @Test("pendingRecurringConfirmationReceived pre-fills dashboard and switches tab")
    func testPendingRecurringConfirmationReceived() async {
        let recurringId = UUID()
        let template = RecurringTransaction(
            id: recurringId, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [template] }
            $0.userSettingsRepository.bool = { _ in false }
            $0.notificationAdapter.pendingConfirmations = {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.pendingRecurringConfirmationReceived(recurringId))
        await store.receive(\.recurringTemplateFetched) { state in
            #expect(state.dashboard.addTransaction != nil)
            #expect(state.selectedTab == .dashboard)
            #expect(state.pendingRecurringConfirmationId == recurringId)
        }
    }
}
```
new:
```swift
}
```

- [ ] **Step 10: 建置 + 全套件測試確認綠燈**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: TEST SUCCEEDED。重點:`AppFeatureTests`(含 4 個 recurring 測試)、`MainTabFeatureTests`(task & accessory routing,無 recurring suite)、`AccessoryBarFeature*`、`DashboardFeatureTests`、`TransactionsFeatureTests` 全綠。

> 可委派 Haiku subAgent 跑,只回報 pass/fail + 錯誤行。

- [ ] **Step 11: Commit**

```bash
git add Features/Sources/Domain/UseCases/DeeplinkClient.swift \
        Features/Sources/Core/Adapters/DeeplinkClient+Live.swift \
        Features/Sources/Features/AppFeature.swift \
        Features/Sources/Features/AppView.swift \
        Features/Sources/Features/MainTab/MainTabFeature.swift \
        NeuLedgerTests/Tests/FeaturesTests/AppFeatureTests.swift \
        NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "$(cat <<'EOF'
refactor(routing): move recurring notification routing from MainTab to AppFeature [ci skip]

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**1. Spec coverage:**
- `RouteLinkDestination` +`recurringConfirmation` → Task 1 Step 3 ✓
- `DeeplinkClient.resolveRecurringConfirmation` + Live → Task 2 Steps 3-4 ✓
- `AppFeature` `.task` 訂閱 + `.route` handler + notificationAdapter → Task 1 Step 4 + Task 2 Step 5 ✓
- `AppView` 根層 `.task` → Task 2 Step 6 ✓
- MainTab 移除入站路由 + vestigial state、保留 reschedule → Task 2 Step 8 ✓
- 測試:AppFeature 路由+訂閱、MainTab 移除入站 → Task 1 Step 1 + Task 2 Steps 1/9 ✓
- 選配 Core 解析測試:刻意略過(spec 標選配;live 僅 `fetchAll().first`,由 AppFeature resolver 覆寫涵蓋兩分支)→ 已於 spec 說明 ✓

**2. Placeholder scan:** 無 TBD/TODO;每個 code step 皆含完整程式碼與指令。✓

**3. Type consistency:**
- `RouteLinkDestination.recurringConfirmation(RecurringTransaction)` — Task 1 定義、Task 2 live 回傳、AppFeature handler 解構、測試建構,四處一致。✓
- `resolveRecurringConfirmation: (RecurringTransaction.ID) async throws -> RouteLinkDestination` — 介面(Task 2 S3)、live(S4)、AppFeature 呼叫(S5)、測試覆寫(S1)簽章一致。✓
- `AppFeature.Action.task` + `CancelID.recurringSubscription` — S5 定義、AppView(S6)/測試(S1)使用一致。✓
- AppFeature `.route` handler 使用 `AddTransactionFeature.State(mode: .addRecurringConfirmation(template))` 與 `mainState.dashboard.addTransaction` / `mainState.selectedTab` — 與既有 `.carrierManagement` 同模式,型別存在。✓
- MainTab 移除後 `recurringTransactionClient`/`notificationAdapter`/`userSettingsRepository`/`CancelID.task` 仍被 reschedule/`.task` 使用,無孤兒依賴。✓

**測試注意事項:**
- AppFeature 路由/訂閱測試用 `exhaustivity = .off` + 必要時 `store.finish()`：enum State 帶非決定性 `Date()`(AddTransactionFeature.State 預設),故以「case path + `.mode` 斷言」取代整體相等;訂閱經非同步串流故 `.off` + `finish()`。
- `recurringConfirmationIgnoredOutsideMain` 為 exhaustive(`.onboarding` 下 `guard .main` 失敗 → 無 state 變更,無需 closure)。
