# AccessoryView 排版改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重新設計 `CustomAccessoryView`，修正 compact 狀態視覺失衡與 AI 輸入欄空間擁擠，補足 AI 處理中 / 有結果的 compact 狀態呈現，並新增 Settings 開關控制整個底部快捷列的顯示。

**Architecture:** `SettingsFeature` 管理 `showAccessoryBar` 的讀寫（循 `isAIEnabled` 的既有模式）。`MainTabFeature` 在 `.task` 讀取此設定存入 State，`MainTabView` 依 `store.showAccessoryBar` 條件掛載 `.tabViewBottomAccessory`。`CustomAccessoryView` 依 `isAIInputExpanded / isAIInputLoading / aiAnswer` 的優先序切換五種狀態。

**Tech Stack:** SwiftUI, TCA v1.23.1, UserSettingsClient, Swift Testing

---

## File Map

| 檔案 | 類型 | 變動 |
|------|------|------|
| `Features/Sources/Domain/Clients/UserSettingsClient.swift` | Modify | 新增 `showAccessoryBar` Bool key |
| `Features/Sources/Features/Settings/SettingsFeature.swift` | Modify | 新增 `showAccessoryBar` state + action |
| `Features/Sources/Features/Settings/SettingsView.swift` | Modify | 新增 toggle row |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | Modify | 新增 state、actions、更新 `.task` 和 `answerReceived` |
| `Features/Sources/Features/MainTab/MainTabView.swift` | Modify | 條件渲染 accessory + 重寫 `CustomAccessoryView` |
| `NeuLedger/Resources/Localizable.xcstrings` | Modify | 新增 7 個 localization keys |
| `Features/Tests/FeaturesTests/SettingsFeatureTests.swift` | Modify | 新增 accessory bar toggle 測試 |
| `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` | Modify | 新增 3 個新測試、更新 1 個既有測試 |

---

## Task 1: 新增 `showAccessoryBar` SettingsKey

**Files:**
- Modify: `Features/Sources/Domain/Clients/UserSettingsClient.swift`

- [ ] **Step 1: 在 Bool Keys section 加入新 key**

在 `UserSettingsClient.swift` 的 `// MARK: - Bool Keys` section（`aiEnabled` key 之後）加入：

```swift
/// Whether the bottom accessory bar (AI record + quick add) is visible.
static let showAccessoryBar = SettingsKey(
    rawValue: "showAccessoryBar",
    defaultValue: true
)
```

- [ ] **Step 2: Build 確認無錯誤**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded"
```

預期：`Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Domain/Clients/UserSettingsClient.swift
git commit -m "feat(settings): add showAccessoryBar UserSettings key"
```

---

## Task 2: `SettingsFeature` 加入 accessory bar 開關

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`

- [ ] **Step 1: 寫失敗測試**

在 `SettingsFeatureTests.swift` 末尾加入新 suite（在最後一個 `}` 之前加在文件末端）：

```swift
@Suite("SettingsFeature — accessory bar toggle")
struct SettingsAccessoryBarTests {

    @Test("task loads showAccessoryBar=false from UserSettings")
    func taskLoadsAccessoryBarFalse() async {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { key in
                key.rawValue == "showAccessoryBar" ? false : key.defaultValue
            }
            $0.userSettingsClient.string = { $0.defaultValue }
            $0.accountClient.fetchActive = { [] }
        }
        await store.send(.task)
        await store.receive(.accountsLoaded([]))
        await store.receive(.aiToggleChanged(true))
        await store.receive(.defaultAccountSelected(""))
        await store.receive(\.languageLoaded)
        await store.receive(.accessoryBarToggleChanged(false)) {
            $0.showAccessoryBar = false
        }
    }

    @Test("accessoryBarToggleChanged persists and updates state")
    func toggleChangedPersists() async {
        var persisted: Bool = true
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.setBool = { value, key in
                if key.rawValue == "showAccessoryBar" { persisted = value }
            }
        }
        await store.send(.accessoryBarToggleChanged(false)) {
            $0.showAccessoryBar = false
        }
        #expect(persisted == false)
    }
}
```

- [ ] **Step 2: 執行測試確認失敗（compile error 是預期的）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsAccessoryBarTests 2>&1 | tail -5
```

預期：compile error — `showAccessoryBar` / `accessoryBarToggleChanged` 不存在

- [ ] **Step 3: 更新 `SettingsFeature.State`**

在 `public var exportError: String? = nil` 之後加入：

```swift
public var showAccessoryBar: Bool = true
```

在 `public init(...)` 的參數列和初始化區塊中加入（跟 `isAIEnabled` 同樣模式）：

```swift
// 參數列
showAccessoryBar: Bool = true,

// 初始化區塊
self.showAccessoryBar = showAccessoryBar
```

- [ ] **Step 4: 更新 `SettingsFeature.Action`**

在 `case privacyPolicyTapped` 之前加入：

```swift
case accessoryBarToggleChanged(Bool)
```

- [ ] **Step 5: 更新 `.task` 讀取設定**

在 `.task` 的 `.run { send in` 區塊中，`let isAIEnabled = ...` 那行之後加入讀取，並在 `await send(.languageLoaded(...))` 之後加入 send：

```swift
let showAccessoryBar = userSettingsClient.bool(.showAccessoryBar)
```

以及：

```swift
await send(.accessoryBarToggleChanged(showAccessoryBar))
```

- [ ] **Step 6: 處理 `accessoryBarToggleChanged` action**

在 `case .privacyPolicyTapped:` 之前加入：

```swift
case let .accessoryBarToggleChanged(value):
    state.showAccessoryBar = value
    userSettingsClient.setBool(value, .showAccessoryBar)
    return .none
```

- [ ] **Step 7: 執行測試確認通過**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SettingsAccessoryBarTests 2>&1 | tail -5
```

預期：`Test Suite 'SettingsAccessoryBarTests' passed`

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsFeature.swift
git add Features/Tests/FeaturesTests/SettingsFeatureTests.swift
git commit -m "feat(settings): add showAccessoryBar toggle to SettingsFeature"
```

---

## Task 3: `SettingsView` 加入開關 UI + localization

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: 加入 localization keys**

在 `Localizable.xcstrings` 的 strings 物件中（找一個合適的位置，例如 `settings_` 開頭的 key 附近）加入：

```json
"settings_show_accessory_bar": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": { "state": "translated", "value": "Show Quick Bar" }
    },
    "zh-Hant": {
      "stringUnit": { "state": "translated", "value": "顯示底部快捷列" }
    }
  }
},
"settings_show_accessory_bar_description": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": { "state": "translated", "value": "AI record and quick add buttons" }
    },
    "zh-Hant": {
      "stringUnit": { "state": "translated", "value": "AI 記帳與快速新增按鈕" }
    }
  }
},
```

- [ ] **Step 2: 在 `sectionPreferences` 加入 toggle row**

在 `SettingsView.swift` 的 `sectionPreferences` 中，AI features toggle (`sparkles`) 那個 `settingsRow` 之後加入：

```swift
settingsRow(
    icon: "dock.rectangle",
    iconColor: Color.Design.textSecondary,
    label: String(localized: "settings_show_accessory_bar"),
    trailing: Toggle("", isOn: $store.showAccessoryBar.sending(\.accessoryBarToggleChanged))
        .labelsHidden()
        .tint(Color.Design.incomeGreen)
)
```

- [ ] **Step 3: Build 確認無錯誤**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsView.swift
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(settings): add accessory bar toggle UI in SettingsView"
```

---

## Task 4: `MainTabFeature` — showAccessoryBar + resultPillTapped + answerReceived 修正

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: 寫失敗測試**

在 `MainTabFeatureTests.swift` 末尾加入：

```swift
@Suite("MainTabFeature — accessory bar & result pill")
struct MainTabAccessoryBarTests {

    @Test("task reads showAccessoryBar=false and stores it")
    func taskReadsAccessoryBarFalse() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.bool = { key in
                key.rawValue == "showAccessoryBar" ? false : key.defaultValue
            }
        }
        await store.send(.task)
        await store.receive(.aiAvailabilityLoaded(isAvailable: true))
        await store.receive(.accessoryBarVisibilityLoaded(false)) {
            $0.showAccessoryBar = false
        }
    }

    @Test("resultPillTapped clears aiAnswer and expands input")
    func resultPillTappedClearsAndExpands() async {
        var initial = MainTabFeature.State()
        initial.aiAnswer = "上個月餐費 NT$8,500"
        initial.isAIInputExpanded = false

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.resultPillTapped) {
            $0.aiAnswer = nil
            $0.isAIInputExpanded = true
            $0.aiInputError = nil
        }
    }

    @Test("answerReceived collapses input bar so compact pill appears")
    func answerReceivedCollapsesInputBar() async {
        var initial = MainTabFeature.State()
        initial.isAIInputExpanded = true
        initial.inputPurpose = .ask
        initial.isAIInputLoading = true
        initial.aiInputText = "上個月餐費多少？"

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.answerReceived("上個月餐費 NT$8,500")) {
            $0.aiAnswer = "上個月餐費 NT$8,500"
            $0.isAIInputLoading = false
            $0.aiInputText = ""
            $0.isAIInputExpanded = false   // 新增這行
        }
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MainTabAccessoryBarTests 2>&1 | tail -5
```

預期：compile error

- [ ] **Step 3: 更新 `MainTabFeature.State`**

在 `var aiAnswer: String? = nil` 之後加入：

```swift
var showAccessoryBar: Bool = true
```

- [ ] **Step 4: 更新 `MainTabFeature.Action`**

在 `case answerFailed` 之後加入：

```swift
case resultPillTapped
case accessoryBarVisibilityLoaded(Bool)
```

- [ ] **Step 5: 注入 userSettingsClient**

在 `MainTabFeature` 的 dependencies 區塊（`@Dependency(\.aiServiceClient)` 那行之後）加入：

```swift
@Dependency(\.userSettingsClient) var userSettingsClient
```

- [ ] **Step 6: 更新 `.task` 讀取設定**

在 `.task` 的 `.run { send in` 中，`await send(.aiAvailabilityLoaded(...))` 之後加入：

```swift
let showAccessoryBar = userSettingsClient.bool(.showAccessoryBar)
await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
```

- [ ] **Step 7: 處理兩個新 actions**

在 `case .answerFailed:` 之後加入：

```swift
case .resultPillTapped:
    state.aiAnswer = nil
    state.isAIInputExpanded = true
    state.aiInputError = nil
    return .none

case let .accessoryBarVisibilityLoaded(visible):
    state.showAccessoryBar = visible
    return .none
```

- [ ] **Step 8: 更新 `answerReceived` — 加入 isAIInputExpanded = false**

找到現有的：

```swift
case let .answerReceived(text):
    guard state.inputPurpose == .ask else { return .none }
    state.aiAnswer = text
    state.isAIInputLoading = false
    state.aiInputText = ""
    return .none
```

改為：

```swift
case let .answerReceived(text):
    guard state.inputPurpose == .ask else { return .none }
    state.aiAnswer = text
    state.isAIInputLoading = false
    state.aiInputText = ""
    state.isAIInputExpanded = false
    return .none
```

- [ ] **Step 9: 更新 `MainTabAskModeTests` 中的既有測試**

`askSubmittedReceivesAnswer` 測試的 `store.receive(\.answerReceived)` 區塊需加上 `$0.isAIInputExpanded = false`：

```swift
await store.receive(\.answerReceived) {
    $0.aiAnswer = "上個月餐費 NT$8,500"
    $0.isAIInputLoading = false
    $0.aiInputText = ""
    $0.isAIInputExpanded = false   // ← 新增
}
```

- [ ] **Step 10: 執行所有 MainTab 測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MainTabFeatureTests \
  -only-testing:FeaturesTests/MainTabAskModeTests \
  -only-testing:FeaturesTests/MainTabAccessoryBarTests 2>&1 | tail -10
```

預期：所有測試通過

- [ ] **Step 11: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift
git add Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "feat(maintab): add showAccessoryBar state, resultPillTapped, collapse input on answer"
```

---

## Task 5: 重寫 `CustomAccessoryView` 並條件渲染 accessory

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: 加入剩餘 localization keys**

在 `Localizable.xcstrings` 加入（`accessory_` 開頭的 key 群）：

```json
"accessory_ai_record": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "AI Record" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "AI 記帳" } }
  }
},
"accessory_add": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Add" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "新增" } }
  }
},
"accessory_ai_processing": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "AI is analyzing…" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "AI 正在分析你的交易…" } }
  }
},
"accessory_mode_record_short": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Rec" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "記" } }
  }
},
"accessory_mode_ask_short": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Ask" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "問" } }
  }
},
```

- [ ] **Step 2: 更新 `MainTabView.body` — 條件渲染 accessory**

目前 `body` 在 `#if os(iOS)` 區塊中無條件掛載 `.tabViewBottomAccessory`。改為抽出 tabView 本體，條件加上 modifier：

把現有的 `body` 改寫如下：

```swift
var body: some View {
    tabViewContent
        .task {
            await store.send(.task).finish()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
}

@ViewBuilder
private var tabViewContent: some View {
    let base = TabView(selection: Binding(
        get: { store.selectedTab },
        set: { store.send(.tabSelected($0)) }
    )) {
        Tab("Ledger", systemImage: "chart.pie.fill", value: MainTabFeature.Tab.dashboard) {
            DashboardScreen(store: store.scope(state: \.dashboard, action: \.dashboard))
        }
        Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis) {
            AnalysisView(store: store.scope(state: \.analysis, action: \.analysis))
        }
        Tab("Settings", systemImage: "gearshape.fill", value: MainTabFeature.Tab.settings) {
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
        }
        Tab(value: MainTabFeature.Tab.transactions, role: .search) {
            TransactionsView(store: store.scope(state: \.transactions, action: \.transactions))
        }
    }

    if store.showAccessoryBar {
        base.tabViewBottomAccessory {
            CustomAccessoryView(store: store)
        }
    } else {
        base
    }
}
```

- [ ] **Step 3: 重寫 `CustomAccessoryView.body`**

取代 `body` 的整個 `switch placement` 區塊：

```swift
var body: some View {
    switch placement {
    case .inline:
        // 不改 — 保留現有 inline 邏輯
        HStack(spacing: 20) {
            Button {
                withAnimation(.spring()) {
                    _ = store.send(.aiInputButtonTapped)
                }
            } label: {
                Image(systemName: "wand.and.sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(store.aiUnavailable ? Color.Design.textTertiary : Color.primary)
            }
            .disabled(store.aiUnavailable)

            Button {
                store.send(.contextActionTapped)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
        }
    case .expanded, _:
        if store.isAIInputExpanded {
            expandedAIInputContent
        } else if store.isAIInputLoading {
            processingPillContent
        } else if let answer = store.aiAnswer {
            resultPillContent(answer)
        } else {
            compactPillContent
        }
    }
}
```

- [ ] **Step 4: 加入 `compactPillContent` computed var**

```swift
private var compactPillContent: some View {
    HStack(spacing: 0) {
        Button {
            withAnimation(.spring()) {
                _ = store.send(.aiInputButtonTapped)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.sparkles")
                    .symbolRenderingMode(.hierarchical)
                Text(String(localized: "accessory_ai_record"))
                    .font(Font.Design.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .disabled(store.aiUnavailable)
        .foregroundStyle(store.aiUnavailable ? Color.Design.textTertiary : Color.primary)

        Divider().frame(height: 20)

        Button {
            store.send(.contextActionTapped)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                Text(String(localized: "accessory_add"))
                    .font(Font.Design.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .foregroundStyle(Color.accentColor)
    }
    .glassEffect(Glass.clear.interactive().tint(Color.Design.background), in: Capsule())
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}
```

- [ ] **Step 5: 加入 `processingPillContent` + `AccessoryShimmerPill`**

```swift
private var processingPillContent: some View {
    AccessoryShimmerPill(text: String(localized: "accessory_ai_processing"))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
}

private struct AccessoryShimmerPill: View {
    let text: String
    @State private var shimmerPhase: CGFloat = -1.0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.sparkles")
                .symbolRenderingMode(.hierarchical)
            Text(text)
                .font(Font.Design.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: shimmerPhase * geo.size.width)
            }
            .clipped()
        )
        .glassEffect(Glass.clear.tint(Color.Design.background), in: Capsule())
        .disabled(true)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.4
            }
        }
    }
}
```

- [ ] **Step 6: 加入 `resultPillContent` method**

```swift
private func resultPillContent(_ answer: String) -> some View {
    Button {
        store.send(.resultPillTapped)
    } label: {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.sparkles")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            Text(answer)
                .font(Font.Design.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 3) {
                Text(String(localized: "accessory_expand"))
                    .font(Font.Design.caption)
                Image(systemName: "chevron.up")
                    .font(Font.Design.caption)
            }
            .foregroundStyle(Color.Design.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    .glassEffect(Glass.clear.interactive().tint(Color.Design.background), in: Capsule())
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}
```

別忘了在 Localizable.xcstrings 補上：

```json
"accessory_expand": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Expand" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "展開" } }
  }
},
```

- [ ] **Step 7: 重寫 `expandedPlacementContent` — mode toggle 改為 badge**

找到現有的 `expandedPlacementContent` 中「Mode toggle — record vs ask」的 `HStack(spacing: 2) { ... }` 區塊（約 `MainTabView.swift:97-147`），取代為單一 badge button：

```swift
// Mode badge — 點擊切換，icon + 短標題
Button {
    store.send(.inputPurposeSwitched(
        store.inputPurpose == .record ? .ask : .record
    ))
} label: {
    HStack(spacing: 4) {
        Image(systemName: store.inputPurpose == .record ? "pencil" : "bubble.left")
            .font(.caption)
        Text(store.inputPurpose == .record
            ? String(localized: "accessory_mode_record_short")
            : String(localized: "accessory_mode_ask_short"))
            .font(Font.Design.caption)
            .fontWeight(.semibold)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.accentColor.opacity(0.2), in: Capsule())
    .foregroundStyle(Color.accentColor)
}
.buttonStyle(.plain)
.fixedSize()
```

- [ ] **Step 8: Build 確認無錯誤**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 9: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabView.swift
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(ui): redesign CustomAccessoryView with centered pill, shimmer, result pill, mode badge"
```

---

## Task 6: 完整 regression test

- [ ] **Step 1: 執行所有 Features 測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

預期：所有測試通過，無 regression

- [ ] **Step 2: 若有失敗，檢查錯誤並修正後重跑**

- [ ] **Step 3: Final commit（若 step 2 有任何修正）**

```bash
# 只 add 實際修改的檔案，例如：
git add Features/Sources/Features/MainTab/MainTabFeature.swift
git add Features/Sources/Features/MainTab/MainTabView.swift
git commit -m "fix: address regression from AccessoryView redesign"
```
