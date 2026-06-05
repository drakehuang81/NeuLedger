# 拆出 AccessoryBarFeature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `MainTabFeature` 裡的 accessory bar(AI 輸入 + 錄音 + 模式)那段 state/action/邏輯抽成獨立的 `AccessoryBarFeature` child reducer,讓 `AccessoryView` 只依賴自己的 feature,跨 tab 副作用改用 delegate 由 parent 路由。

**Architecture:** 標準 TCA parent/child 拆分。新增 `AccessoryBarFeature`,由 `MainTabFeature` 透過 `Scope(state:\.accessory, action:\.accessory)` 掛載。child 用 `delegate(.contextActionRequested)` / `delegate(.transactionExtracted)` 往上拋,parent 依 `selectedTab` 派發給對應 child(dashboard/transactions)。可見性(`showAccessoryBar`/`isAccessoryVisible`)依賴 tab+nav,留在 parent。

**Tech Stack:** Swift / The Composable Architecture (TCA v1.23.1) / Swift Testing (`@Suite`/`@Test`/`TestStore`) / xcodebuild。

**行為不變(refactor)。** 既有測試是安全網;測試隨邏輯搬到新 suite。CLAUDE.md TDD 例外條款適用(behaviour-preserving 重構),但每個 commit 都須建置 + 測試綠燈。

---

## File Structure

| 檔案 | 動作 | 職責 |
|---|---|---|
| `Features/Sources/Features/MainTab/AccessoryBarFeature.swift` | **新增** | accessory bar reducer:AI 輸入、錄音、`accessoryMode`、AI 可用性;對外只暴露 `delegate` |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | 改寫 | tab 殼 + 可見性 + recurring + 掛載/路由 accessory |
| `Features/Sources/Features/MainTab/AccessoryView.swift` | 小改 | store 型別 `StoreOf<MainTabFeature>` → `StoreOf<AccessoryBarFeature>`;preview helper |
| `Features/Sources/Features/MainTab/MainTabView.swift` | 小改 | 兩處 `AccessoryView(store:)` 改傳 scoped store |
| `NeuLedgerTests/Tests/FeaturesTests/AccessoryBarFeatureTests.swift` | **新增** | AI 輸入 / 錄音 / 模式 / task 生命週期測試(由 MainTabFeatureTests 搬移調整) |
| `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift` | 改寫 | 只留 `.task` 編排、delegate 路由、recurring |

**不需動的檔案(已確認):** `AppFeature.swift`(用 `MainTabFeature.State()` 預設建構,加上 `var accessory = AccessoryBarFeature.State()` 預設值後仍相容)、`AppFeatureTests.swift`、`AccessoryMode.swift`、`UserSettingsRepository.swift`、`AppEnvironmentUseCase+Live.swift`(用的是 `.accessoryMode` SettingsKey,與本次無關)。

---

## Task 1: 建立 AccessoryBarFeature + 測試

**Files:**
- Create: `Features/Sources/Features/MainTab/AccessoryBarFeature.swift`
- Test: `NeuLedgerTests/Tests/FeaturesTests/AccessoryBarFeatureTests.swift`

> 此 task 結束時,`MainTabFeature` 仍保有舊的 accessory 邏輯(尚未移除),`AccessoryBarFeature` 為新增、暫未被引用 → 專案可編譯,新舊測試並存皆綠。

- [ ] **Step 1: 先寫測試(會失敗 — 型別尚不存在)**

Create `NeuLedgerTests/Tests/FeaturesTests/AccessoryBarFeatureTests.swift`:

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("AccessoryBarFeature — lifecycle")
struct AccessoryBarFeatureLifecycleTests {

    @Test("task loads availability and resolves saved mode when AI available")
    func taskAIAvailable() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { true }
            $0.userSettingsRepository.string = { _ in "ai" }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true))
        await store.receive(.accessoryModeLoaded(.ai)) {
            $0.accessoryMode = .ai
        }
    }

    @Test("task falls back to .add when AI unavailable")
    func taskAIUnavailable() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { false }
            $0.userSettingsRepository.string = { _ in "ai" }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: false)) {
            $0.aiUnavailable = true
        }
        await store.receive(.accessoryModeLoaded(.add))
    }
}

@Suite("AccessoryBarFeature — AI input")
struct AccessoryBarAIInputTests {

    @Test("AI input button expands the input bar")
    func aiInputButtonExpands() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        }
        await store.send(.aiInputButtonTapped) {
            $0.isAIInputExpanded = true
        }
    }

    @Test("dismiss resets all AI input state")
    func dismissResetsState() async {
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.aiInputError = "some error"

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { }
        }
        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
        }
    }

    @Test("successful extraction resets input and emits transactionExtracted delegate")
    func successfulExtractionEmitsDelegate() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.aiInputText = "午餐150"
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        await store.send(.aiExtractionCompleted(.success(extracted))) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
        }
        await store.receive(.delegate(.transactionExtracted(extracted)))
    }

    @Test("failed extraction shows error and keeps input open")
    func failedExtractionShowsError() async {
        struct FakeError: Error {}
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.isAIInputLoading = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        await store.send(.aiExtractionCompleted(.failure(FakeError()))) {
            $0.isAIInputLoading = false
            $0.aiInputError = String(localized: "ai_extraction_error")
        }
    }

    @Test("contextActionTapped emits contextActionRequested delegate")
    func contextActionEmitsDelegate() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        }
        await store.send(.contextActionTapped)
        await store.receive(.delegate(.contextActionRequested))
    }
}

@Suite("AccessoryBarFeature — accessory mode")
struct AccessoryBarModeTests {

    @Test("accessoryModeLoaded sets mode when AI is available")
    func modeLoadedAIAvailable() async {
        var initial = AccessoryBarFeature.State()
        initial.aiUnavailable = false
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        await store.send(.accessoryModeLoaded(.ai)) {
            $0.accessoryMode = .ai
        }
    }

    @Test("accessoryModeLoaded falls back to .add when AI unavailable")
    func modeLoadedAIUnavailable() async {
        var initial = AccessoryBarFeature.State()
        initial.aiUnavailable = true
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        }
        // AI unavailable — reducer ignores the .ai value and keeps .add
        await store.send(.accessoryModeLoaded(.ai))
    }

    @Test("accessoryModeSwitched updates state and persists to settings")
    func modeSwitchedPersists() async {
        let savedKey = LockIsolated<String?>(nil)
        let savedValue = LockIsolated<String?>(nil)
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.userSettingsRepository.setString = { value, key in
                savedKey.setValue(key.rawValue)
                savedValue.setValue(value)
            }
        }
        await store.send(.accessoryModeSwitched(.ai)) {
            $0.accessoryMode = .ai
        }
        #expect(savedKey.value == "accessoryMode")
        #expect(savedValue.value == "ai")
    }

    @Test("accessoryModeSwitched to .add persists correctly")
    func modeSwitchedToAdd() async {
        var initial = AccessoryBarFeature.State()
        initial.accessoryMode = .ai
        let savedValue = LockIsolated<String?>(nil)
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.userSettingsRepository.setString = { value, _ in savedValue.setValue(value) }
        }
        await store.send(.accessoryModeSwitched(.add)) {
            $0.accessoryMode = .add
        }
        #expect(savedValue.value == "add")
    }
}

@Suite("AccessoryBarFeature — recording")
struct AccessoryBarRecordingTests {

    @Test("recordingTapped requests permission then starts recording")
    func recordingTappedStartsWhenPermitted() async {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.finish()   // empty stream so the effect completes immediately

        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.requestPermission = { true }
            $0.speechAdapter.startRecording = { stream }
            $0.speechAdapter.stopRecording = { }
        }

        await store.send(.recordingTapped)
        await store.receive(.recordingStarted) {
            $0.isRecording = true
            $0.aiInputError = nil
        }
    }

    @Test("recordingTapped stops recording when already recording")
    func recordingTappedStopsWhenRecording() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { stopCalled.setValue(true) }
        }

        await store.send(.recordingTapped) {
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }

    @Test("recordingTapped shows permission error when denied")
    func recordingTappedDeniedPermission() async {
        let store = await TestStore(initialState: AccessoryBarFeature.State()) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.requestPermission = { false }
        }

        await store.send(.recordingTapped)
        await store.receive(.permissionDenied) {
            $0.aiInputError = String(localized: "speech_permission_denied_error")
        }
    }

    @Test("transcriptionUpdated sets aiInputText")
    func transcriptionUpdatedSetsText() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { }
        }

        await store.send(.transcriptionUpdated("早餐五十五元")) {
            $0.aiInputText = "早餐五十五元"
        }
    }

    @Test("transcriptionUpdated overwrites previous partial result")
    func transcriptionUpdatedOverwrites() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { }
        }

        await store.send(.transcriptionUpdated("早餐五十五元")) {
            $0.aiInputText = "早餐五十五元"
        }
    }

    @Test("transcriptionFailed clears recording state and shows error")
    func transcriptionFailedShowsError() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { }
        }

        await store.send(.transcriptionFailed) {
            $0.isRecording = false
            $0.aiInputError = String(localized: "speech_recognition_failed_error")
        }
    }

    @Test("aiInputSubmitted is ignored while recording is active")
    func submitIgnoredWhileRecording() async {
        var initial = AccessoryBarFeature.State()
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { }
        }

        // Should be a no-op — isRecording guard prevents extraction
        await store.send(.aiInputSubmitted)
    }

    @Test("aiInputDismissed stops active recording")
    func dismissStopsActiveRecording() async {
        var initial = AccessoryBarFeature.State()
        initial.isAIInputExpanded = true
        initial.isRecording = true
        initial.aiInputText = "早餐"

        let stopCalled = LockIsolated(false)
        let store = await TestStore(initialState: initial) {
            AccessoryBarFeature()
        } withDependencies: {
            $0.speechAdapter.stopRecording = { stopCalled.setValue(true) }
        }

        await store.send(.aiInputDismissed) {
            $0.isAIInputExpanded = false
            $0.aiInputText = ""
            $0.isAIInputLoading = false
            $0.aiInputError = nil
            $0.isRecording = false
        }
        #expect(stopCalled.value)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗(編譯失敗 — `AccessoryBarFeature` 未定義)**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AccessoryBarFeatureLifecycleTests
```
Expected: BUILD FAILED — `cannot find 'AccessoryBarFeature' in scope`。

- [ ] **Step 3: 建立 `AccessoryBarFeature.swift`(最小實作 — 從 MainTabFeature 平移邏輯)**

Create `Features/Sources/Features/MainTab/AccessoryBarFeature.swift`:

```swift
import Foundation
import ComposableArchitecture
import Domain

@Reducer
struct AccessoryBarFeature {
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var isAIInputExpanded: Bool = false
        var aiInputText: String = ""
        var isAIInputLoading: Bool = false
        var aiInputError: String? = nil      // shown inline below the text field
        var aiUnavailable: Bool = false      // set by aiAvailabilityLoaded; drives all AI UI
        var isRecording: Bool = false
        var accessoryMode: AccessoryMode = .add
    }

    // MARK: - Action
    enum Action: Equatable {
        // Lifecycle
        case task
        case aiAvailabilityLoaded(isAvailable: Bool)   // true means AI IS available
        case accessoryModeLoaded(AccessoryMode)
        case accessoryModeSwitched(AccessoryMode)

        // AI input bar
        case aiInputButtonTapped
        case aiInputTextChanged(String)
        case aiInputSubmitted
        case aiInputDismissed
        case aiExtractionCompleted(TaskResult<ExtractedTransaction>)

        // Recording
        case recordingTapped
        case recordingStarted
        case permissionDenied
        case transcriptionUpdated(String)
        case transcriptionFailed

        // Quick-add (.add mode) tap
        case contextActionTapped

        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            /// `.add` 模式點擊 — 由 parent 依 selectedTab 決定要新增到哪個 tab。
            case contextActionRequested
            /// AI 擷取成功 — 由 parent 依 selectedTab 派給對應 child。
            case transactionExtracted(ExtractedTransaction)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.aiUseCase) var aiUseCase
    @Dependency(\.userSettingsRepository) var userSettingsRepository
    @Dependency(\.speechAdapter) var speechAdapter

    private enum CancelID {
        case aiExtraction
        case speechRecording
        case task
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let isAvailable = aiUseCase.isAvailable()
                    await send(.aiAvailabilityLoaded(isAvailable: isAvailable))
                    let rawMode = userSettingsRepository.string(.accessoryMode)
                    let savedMode = AccessoryMode(rawValue: rawMode) ?? .add
                    let resolvedMode = isAvailable ? savedMode : .add
                    await send(.accessoryModeLoaded(resolvedMode))
                }
                .cancellable(id: CancelID.task, cancelInFlight: true)

            case let .aiAvailabilityLoaded(isAvailable):
                state.aiUnavailable = !isAvailable
                return .none

            case .aiInputButtonTapped:
                state.isAIInputExpanded = true
                state.aiInputError = nil
                return .none

            case let .aiInputTextChanged(text):
                state.aiInputText = text
                return .none

            case .aiInputDismissed:
                let wasRecording = state.isRecording
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                state.aiInputError = nil
                state.isRecording = false
                if wasRecording {
                    return .merge(
                        .cancel(id: CancelID.speechRecording),
                        .run { _ in speechAdapter.stopRecording() }
                    )
                }
                return .none

            case .aiInputSubmitted:
                guard !state.aiInputText.isEmpty, !state.isRecording else { return .none }
                state.isAIInputLoading = true
                state.aiInputError = nil
                let text = state.aiInputText
                return .run { send in
                    await send(.aiExtractionCompleted(
                        TaskResult { try await aiUseCase.extractFromText(text) }
                    ))
                }
                .cancellable(id: CancelID.aiExtraction, cancelInFlight: true)

            case let .aiExtractionCompleted(.success(extracted)):
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                return .send(.delegate(.transactionExtracted(extracted)))

            case .aiExtractionCompleted(.failure):
                state.isAIInputLoading = false
                state.aiInputError = String(localized: "ai_extraction_error")
                return .none

            case .recordingTapped:
                if state.isRecording {
                    state.isRecording = false
                    return .merge(
                        .cancel(id: CancelID.speechRecording),
                        .run { _ in speechAdapter.stopRecording() }
                    )
                } else {
                    return .run { send in
                        let granted = await speechAdapter.requestPermission()
                        guard granted else {
                            await send(.permissionDenied)
                            return
                        }
                        await send(.recordingStarted)
                        do {
                            for try await text in speechAdapter.startRecording() {
                                await send(.transcriptionUpdated(text))
                            }
                        } catch {
                            await send(.transcriptionFailed)
                        }
                    }
                    .cancellable(id: CancelID.speechRecording)
                }

            case .recordingStarted:
                state.isRecording = true
                state.aiInputError = nil
                return .none

            case .permissionDenied:
                state.aiInputError = String(localized: "speech_permission_denied_error")
                return .none

            case let .transcriptionUpdated(text):
                state.aiInputText = text
                return .none

            case .transcriptionFailed:
                state.isRecording = false
                state.aiInputError = String(localized: "speech_recognition_failed_error")
                return .none

            case let .accessoryModeLoaded(mode):
                state.accessoryMode = state.aiUnavailable ? .add : mode
                return .none

            case let .accessoryModeSwitched(mode):
                state.accessoryMode = mode
                userSettingsRepository.setString(mode.rawValue, .accessoryMode)
                return .none

            case .contextActionTapped:
                return .send(.delegate(.contextActionRequested))

            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/AccessoryBarFeatureLifecycleTests \
  -only-testing:NeuLedgerTests/AccessoryBarAIInputTests \
  -only-testing:NeuLedgerTests/AccessoryBarModeTests \
  -only-testing:NeuLedgerTests/AccessoryBarRecordingTests
```
Expected: TEST SUCCEEDED(全部綠燈)。

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/MainTab/AccessoryBarFeature.swift \
        NeuLedgerTests/Tests/FeaturesTests/AccessoryBarFeatureTests.swift
git commit -m "refactor(maintab): add AccessoryBarFeature reducer + tests [ci skip]"
```

---

## Task 2: Cutover — 接線 parent / views,並收斂 parent 測試

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`(改寫)
- Modify: `Features/Sources/Features/MainTab/AccessoryView.swift`(store 型別 + preview helper)
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`(兩處 scope)
- Modify: `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift`(改寫)

> 這是原子性切換:parent 移除舊 accessory slice 的同時,view 改吃 scoped store、測試改用新 action 路徑。過程中專案會短暫無法編譯,但此 task 完成的 commit 必須綠燈。屬 behaviour-preserving 重構,搬移後的測試 + 既有全測試套件為安全網。

- [ ] **Step 1: 改寫 `MainTabFeature.swift`(移除 accessory slice,掛載 + 路由 AccessoryBarFeature)**

以下列內容**整檔取代** `Features/Sources/Features/MainTab/MainTabFeature.swift`:

```swift
import Foundation
import ComposableArchitecture
import Domain

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case dashboard
        case settings
        case transactions
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var dashboard = DashboardFeature.State()
        var transactions = TransactionsFeature.State()
        var settings = SettingsFeature.State()

        // Floating accessory bar (AI input / quick-add)
        var accessory = AccessoryBarFeature.State()

        // Accessory bar visibility — depends on tab + child nav, so it stays here.
        var showAccessoryBar: Bool = true

        // Recurring transaction confirmation routing
        var pendingRecurringConfirmationId: RecurringTransaction.ID? = nil

        var isAccessoryVisible: Bool {
            guard showAccessoryBar else { return false }
            switch selectedTab {
            case .settings:     return settings.path.isEmpty
            case .dashboard:    return dashboard.path.isEmpty
            case .transactions: return true
            }
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)

        // Lifecycle
        case task
        case accessoryBarVisibilityLoaded(Bool)

        // Recurring transaction confirmation routing
        case pendingRecurringConfirmationReceived(RecurringTransaction.ID)
        case recurringTemplateFetched(RecurringTransaction)

        case accessory(AccessoryBarFeature.Action)
        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Dependencies
    @Dependency(\.userSettingsRepository) var userSettingsRepository
    @Dependency(\.notificationAdapter) var notificationAdapter
    @Dependency(\.recurringTransactionClient) var recurringTransactionClient

    private enum CancelID {
        case task
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.accessory, action: \.accessory) {
            AccessoryBarFeature()
        }
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    // Trigger the accessory bar's own load (availability + mode) once at launch,
                    // regardless of whether it is currently visible.
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

            case let .accessoryBarVisibilityLoaded(visible):
                state.showAccessoryBar = visible
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            // MARK: Accessory routing (depends on selectedTab — a tab-shell concern)
            case .accessory(.delegate(.contextActionRequested)):
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.contextActionTapped))
                default:
                    return .send(.dashboard(.addTransactionButtonTapped))
                }

            case let .accessory(.delegate(.transactionExtracted(extracted))):
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.addTransactionWithPrefilledData(extracted)))
                default:
                    return .send(.dashboard(.addTransactionWithPrefilledData(extracted)))
                }

            case .accessory:
                return .none

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
            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):
                state.pendingRecurringConfirmationId = nil
                return .run { send in
                    do {
                        let all = try await recurringTransactionClient.fetchAll()
                        if var template = all.first(where: { $0.id == id }) {
                            template.nextDueDate = newNextDueDate
                            try await recurringTransactionClient.update(template)
                            try await notificationAdapter.scheduleRecurringReminder(
                                template.id,
                                newNextDueDate,
                                String(localized: "recurring_transaction_notification_title"),
                                String(localized: "recurring_transaction_notification_body")
                            )
                        }
                    } catch {
                        // silently ignore
                    }
                }

            case .dashboard:
                return .none

            case .transactions:
                return .none

            case let .settings(.delegate(.accessoryBarVisibilityChanged(visible))):
                state.showAccessoryBar = visible
                return .none

            case .settings:
                return .none
            }
        }
    }
}
```

- [ ] **Step 2: 改 `AccessoryView.swift` 的 store 型別**

`AccessoryView.swift:6`,改 struct 的 store 屬性型別:

```swift
// 改前
struct AccessoryView: View {
    let store: StoreOf<MainTabFeature>
```
```swift
// 改後
struct AccessoryView: View {
    let store: StoreOf<AccessoryBarFeature>
```
(其餘 body / `store.send(...)` / `store.xxx` 讀取皆不變 — AccessoryBarFeature 上有同名的 state 與 action。)

- [ ] **Step 3: 改 `AccessoryView.swift` 的 preview helper**

檔尾 `previewStore` helper,把 `MainTabFeature` 換成 `AccessoryBarFeature`(三處):

```swift
// 改前
@MainActor
private func previewStore(_ mutate: (inout MainTabFeature.State) -> Void) -> StoreOf<MainTabFeature> {
    var state = MainTabFeature.State()
    mutate(&state)
    return Store(initialState: state) {
        MainTabFeature()
    }
}
```
```swift
// 改後
@MainActor
private func previewStore(_ mutate: (inout AccessoryBarFeature.State) -> Void) -> StoreOf<AccessoryBarFeature> {
    var state = AccessoryBarFeature.State()
    mutate(&state)
    return Store(initialState: state) {
        AccessoryBarFeature()
    }
}
```
(各 `#Preview` 內的 `previewStore { state in state.accessoryMode = ... }` 不變。)

- [ ] **Step 4: 改 `MainTabView.swift` 兩處傳 scoped store**

`MainTabView.swift` body,兩個 `AccessoryView(store: store)` 都改成 scoped store:

```swift
// 改前
        if #available(iOS 26.1, *) {
            tabViewBase
                .tabViewBottomAccessory(isEnabled: store.isAccessoryVisible) {
                    AccessoryView(store: store)
                }
        } else {
            tabViewBase
                .tabViewBottomAccessory {
                    if store.isAccessoryVisible {
                        AccessoryView(store: store)
                    }
                }
        }
```
```swift
// 改後
        if #available(iOS 26.1, *) {
            tabViewBase
                .tabViewBottomAccessory(isEnabled: store.isAccessoryVisible) {
                    AccessoryView(store: store.scope(state: \.accessory, action: \.accessory))
                }
        } else {
            tabViewBase
                .tabViewBottomAccessory {
                    if store.isAccessoryVisible {
                        AccessoryView(store: store.scope(state: \.accessory, action: \.accessory))
                    }
                }
        }
```
(`store.isAccessoryVisible` 仍讀 parent 的 computed property — 不變。)

- [ ] **Step 5: 改寫 `MainTabFeatureTests.swift`(移除已搬走的測試,新增 `.task` 編排 + delegate 路由)**

以下列內容**整檔取代** `NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift`:

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("MainTabFeature — task & accessory routing")
struct MainTabFeatureTests {

    @Test("task forwards lifecycle to accessory and loads showAccessoryBar")
    func taskForwardsLifecycleAndLoadsAccessoryBar() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { true }
            $0.userSettingsRepository.string = { _ in "add" }
            $0.userSettingsRepository.bool = { key in
                key.rawValue == SettingsKey.showAccessoryBar.rawValue ? false : key.defaultValue
            }
            $0.notificationAdapter.pendingConfirmations = {
                AsyncStream { $0.finish() }
            }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        await store.receive(\.accessory.task)
        await store.receive(\.accessoryBarVisibilityLoaded) {
            $0.showAccessoryBar = false
        }
        await store.finish()
    }

    @Test("contextActionRequested on dashboard routes to dashboard add")
    func contextActionRoutesDashboard() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.accessory(.delegate(.contextActionRequested)))
        await store.receive(\.dashboard.addTransactionButtonTapped) { state in
            #expect(state.dashboard.addTransaction?.mode == .add(.expense))
        }
    }

    @Test("contextActionRequested on transactions routes to transactions add")
    func contextActionRoutesTransactions() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .transactions
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.accessory(.delegate(.contextActionRequested)))
        await store.receive(\.transactions.contextActionTapped) { state in
            #expect(state.transactions.addTransaction?.mode == .add(.expense))
        }
    }

    @Test("transactionExtracted delegate on dashboard opens AddTransaction")
    func transactionExtractedRoutesDashboard() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
        let fixedDate = Date(timeIntervalSince1970: 0)
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }
            $0.date = .constant(fixedDate)
        }
        await store.send(.accessory(.delegate(.transactionExtracted(extracted)))) 
        await store.receive(\.dashboard.addTransactionWithPrefilledData) {
            $0.dashboard.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: fixedDate)
        }
    }
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
            $0.aiUseCase.isAvailable = { false }
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

- [ ] **Step 6: 建置 + 跑全套測試確認綠燈**

Run:
```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: TEST SUCCEEDED。重點檢查 suites:`AccessoryBarFeature*`、`MainTabFeature — task & accessory routing`、`MainTabFeature — recurring confirmation`、以及 `AppFeatureTests`、`TransactionsFeatureTests`、`DashboardFeatureTests` 不受影響全綠。

> 依 CLAUDE.md,此 build/test 可委派給 Haiku subAgent,只回報 pass/fail 與錯誤行。

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift \
        Features/Sources/Features/MainTab/AccessoryView.swift \
        Features/Sources/Features/MainTab/MainTabView.swift \
        NeuLedgerTests/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "refactor(maintab): wire AccessoryBarFeature into MainTab + split tests [ci skip]"
```

---

## Self-Review

**1. Spec coverage:**
- 抽出 `AccessoryBarFeature`(AI 輸入 + accessoryMode + aiUnavailable)→ Task 1 ✓
- parent 保留可見性 / recurring / tab / 路由 → Task 2 Step 1 ✓
- delegate `.contextActionRequested` / `.transactionExtracted` → Task 1(child 發出)+ Task 2(parent 路由)✓
- 生命週期 parent `.task` 觸發 `.accessory(.task)` → Task 2 Step 1 ✓
- 測試拆分(錄音/AI/mode 到新 suite;parent 留 recurring/task/路由)→ Task 1 + Task 2 Step 5 ✓
- View 改 scoped store → Task 2 Steps 2-4 ✓

**2. Placeholder scan:** 無 TBD/TODO;每個 code step 皆含完整程式碼與指令。✓

**3. Type consistency:**
- `AccessoryBarFeature.Action.Delegate`:`contextActionRequested` / `transactionExtracted(ExtractedTransaction)` — Task 1 定義、Task 2 parent 比對、測試使用,三處一致。✓
- parent 新增 `accessory(AccessoryBarFeature.Action)`、`accessoryBarVisibilityLoaded(Bool)`;移除 `aiAvailabilityLoaded`/`aiInput*`/`recording*`/`transcription*`/`accessoryMode*`/`contextActionTapped`/`aiExtractionCompleted` — 與 AccessoryView(改吃 child)、MainTabFeatureTests(改用 `.accessory(...)`)一致。✓
- parent 移除 `@Dependency aiUseCase`/`speechAdapter` 與 `CancelID.aiExtraction`/`.speechRecording`;child 接收這些。parent 保留 `userSettingsRepository`/`notificationAdapter`/`recurringTransactionClient` 與 `CancelID.task`。✓
- 路由目標 action 名稱核對原始碼:`DashboardFeature.addTransactionButtonTapped`(set `addTransaction = .init(mode: .add(.expense), date: now)`)、`TransactionsFeature.contextActionTapped`(set `.init(mode: .add(.expense))`)、雙方 `addTransactionWithPrefilledData(_:)` 皆存在。✓

**測試注意事項:**
- parent `.task` 測試用 `exhaustivity = .off` + `store.finish()`,因 `.send(.accessory(.task))` 與 task group 的 `accessoryBarVisibilityLoaded` 並行,順序非決定性。
- transactions 路由只斷言 `mode`(其 `AddTransactionFeature.State` 用預設 `date: Date()`,非決定性);dashboard 路由注入 `$0.date = .constant(...)` 故可完整斷言。
