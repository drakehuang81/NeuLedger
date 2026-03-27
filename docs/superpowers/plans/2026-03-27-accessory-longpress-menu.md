# AccessoryView 長按 Menu 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 AccessoryView 從雙按鈕並排改為單一按鈕，長按開啟 contextMenu 切換模式（新增 / AI 記帳），模式持久保存，AI 不可用時禁用長按。

**Architecture:** 新增 `AccessoryMode` enum 加入 `MainTabFeature.State`；新增兩個 Action（`accessoryModeLoaded` / `accessoryModeSwitched`）；`.task` Effect 讀取保存的模式並在 AI 不可用時自動 fallback；View 改為單一按鈕搭配條件性 `.contextMenu`。

**Tech Stack:** TCA v1.23.1、SwiftUI `.contextMenu`、`UserSettingsClient`（`SettingsKey<String>`）

---

## 受影響的檔案

| 檔案 | 操作 |
|------|------|
| `Features/Sources/Domain/Clients/UserSettingsClient.swift` | 新增 `SettingsKey<String>.accessoryMode` |
| `Features/Sources/Features/MainTab/MainTabFeature.swift` | 新增 `AccessoryMode` enum；更新 State / Action / Reducer |
| `Features/Sources/Features/MainTab/MainTabView.swift` | 替換 `compactPillContent` 與 `inline` case |
| `Features/Tests/FeaturesTests/MainTabFeatureTests.swift` | 新增新行為測試；修正既有 `.task` 測試 |

---

## Task 1: 新增基礎型別

**Files:**
- Modify: `Features/Sources/Domain/Clients/UserSettingsClient.swift`
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`

- [ ] **Step 1: 在 `UserSettingsClient.swift` 的 String Keys section 新增 `accessoryMode` key**

在 `// MARK: - String Keys` 的 extension 內，`defaultAccountId` 之後加入：

```swift
/// The user's preferred accessory bar mode ("add" or "ai"). Default: "add".
static let accessoryMode = SettingsKey(
    rawValue: "accessoryMode",
    defaultValue: "add"
)
```

- [ ] **Step 2: 在 `MainTabFeature.swift` 頂部（`InputPurpose` 之後）新增 `AccessoryMode` enum**

```swift
enum AccessoryMode: String, Equatable, Sendable {
    case add
    case ai
}
```

- [ ] **Step 3: Build 確認沒有 compile error**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Domain/Clients/UserSettingsClient.swift \
        Features/Sources/Features/MainTab/MainTabFeature.swift
git commit -m "feat(accessory): add AccessoryMode enum and SettingsKey"
```

---

## Task 2: 寫失敗測試（RED）

**Files:**
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

- [ ] **Step 1: 在測試檔案末尾新增新的 test suite**

在 `MainTabFeatureTests.swift` 檔案末尾加入：

```swift
@Suite("MainTabFeature — accessory mode")
struct MainTabAccessoryModeTests {

    @Test("accessoryModeLoaded sets mode when AI is available")
    func modeLoadedAIAvailable() async {
        var initial = MainTabFeature.State()
        initial.aiUnavailable = false
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
        }
        await store.send(.accessoryModeLoaded(.ai)) {
            $0.accessoryMode = .ai
        }
    }

    @Test("accessoryModeLoaded falls back to .add when AI unavailable")
    func modeLoadedAIUnavailable() async {
        var initial = MainTabFeature.State()
        initial.aiUnavailable = true
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { false }
        }
        // AI unavailable — reducer ignores the .ai value and keeps .add
        await store.send(.accessoryModeLoaded(.ai))
        // state.accessoryMode remains .add (default)
    }

    @Test("accessoryModeSwitched updates state and persists to settings")
    func modeSwitchedPersists() async {
        var savedKey: String?
        var savedValue: String?
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.setString = { value, key in
                savedKey = key.rawValue
                savedValue = value
            }
        }
        await store.send(.accessoryModeSwitched(.ai)) {
            $0.accessoryMode = .ai
        }
        #expect(savedKey == "accessoryMode")
        #expect(savedValue == "ai")
    }

    @Test("accessoryModeSwitched to .add persists correctly")
    func modeSwitchedToAdd() async {
        var initial = MainTabFeature.State()
        initial.accessoryMode = .ai
        var savedValue: String?
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.userSettingsClient.setString = { value, _ in savedValue = value }
        }
        await store.send(.accessoryModeSwitched(.add)) {
            $0.accessoryMode = .add
        }
        #expect(savedValue == "add")
    }
}
```

- [ ] **Step 2: 執行新測試，確認因缺少 Action 而 compile 失敗（RED）**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep "error:"
```

Expected: 出現 `error: ... accessoryModeLoaded ... is not a member` 或 `accessoryMode` 找不到等 compile error。

---

## Task 3: 實作 State + Actions + Reducer（GREEN）

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabFeature.swift`

- [ ] **Step 1: 在 `State` 中新增 `accessoryMode` 欄位**

在 `var showAccessoryBar: Bool = true` 這行之後加入：

```swift
var accessoryMode: AccessoryMode = .add
```

- [ ] **Step 2: 在 `Action` enum 新增兩個 case**

在 `case accessoryBarVisibilityLoaded(Bool)` 之後加入：

```swift
case accessoryModeLoaded(AccessoryMode)
case accessoryModeSwitched(AccessoryMode)
```

- [ ] **Step 3: 在 `.task` effect 中讀取並傳送 `accessoryModeLoaded`**

找到現有的 `.task` case 內的 `group.addTask` 區塊（讀取 AI 可用性的那個），在 `await send(.accessoryBarVisibilityLoaded(showAccessoryBar))` 之後加入：

```swift
let rawMode = userSettingsClient.string(.accessoryMode)
let savedMode = AccessoryMode(rawValue: rawMode) ?? .add
// Resolve AI fallback at load time so the reducer doesn't need to coordinate timing
let resolvedMode = await aiServiceClient.isAvailable() ? savedMode : .add
await send(.accessoryModeLoaded(resolvedMode))
```

> 注意：`isAvailable()` 在這裡再呼叫一次（同一個 task group 內），確保 fallback 邏輯與 AI 狀態一致，避免 task group 的並發順序問題。

- [ ] **Step 4: 在 Reducer 的 `switch action` 新增兩個 case 的處理**

在 `case let .accessoryBarVisibilityLoaded(visible):` case 之後加入：

```swift
case let .accessoryModeLoaded(mode):
    state.accessoryMode = mode
    return .none

case let .accessoryModeSwitched(mode):
    state.accessoryMode = mode
    userSettingsClient.setString(mode.rawValue, .accessoryMode)
    return .none
```

- [ ] **Step 5: 執行新測試，確認全部通過（GREEN）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \
  | grep -E "(accessory mode|accessoryMode|✔|✘)" | head -20
```

Expected: 四個新測試全部顯示 `✔`。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabFeature.swift \
        Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "feat(accessory): add accessoryMode state, actions, and reducer logic"
```

---

## Task 4: 修正既有 `.task` 測試

**Files:**
- Modify: `Features/Tests/FeaturesTests/MainTabFeatureTests.swift`

既有的 `taskStoresAvailability` 和 `taskMarksUnavailable` 測試現在少了 `accessoryModeLoaded` 的 `receive`，會導致 test store 抱怨有未預期的 action。

- [ ] **Step 1: 更新 `taskStoresAvailability` 測試**

找到現有測試並替換：

```swift
@Test("task stores AI availability")
func taskStoresAvailability() async {
    let store = await TestStore(initialState: MainTabFeature.State()) {
        MainTabFeature()
    } withDependencies: {
        $0.aiServiceClient.isAvailable = { true }
        $0.userSettingsClient.string = { _ in "add" }
    }
    await store.send(.task)
    await store.receive(.aiAvailabilityLoaded(isAvailable: true))
    await store.receive(.accessoryBarVisibilityLoaded(true))
    await store.receive(.accessoryModeLoaded(.add))
}
```

- [ ] **Step 2: 更新 `taskMarksUnavailable` 測試**

```swift
@Test("task marks AI unavailable when not available")
func taskMarksUnavailable() async {
    let store = await TestStore(initialState: MainTabFeature.State()) {
        MainTabFeature()
    } withDependencies: {
        $0.aiServiceClient.isAvailable = { false }
        $0.userSettingsClient.string = { _ in "ai" }
    }
    await store.send(.task)
    await store.receive(.aiAvailabilityLoaded(isAvailable: false)) {
        $0.aiUnavailable = true
    }
    await store.receive(.accessoryBarVisibilityLoaded(true))
    // AI is unavailable → mode falls back to .add even though "ai" was stored
    await store.receive(.accessoryModeLoaded(.add))
}
```

- [ ] **Step 3: 執行所有 Features 測試，確認無紅燈**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \
  | grep -E "(✔|✘|passed|failed)" | tail -5
```

Expected: 只有原本就存在的既有失敗（無關本次修改的），無新增失敗。

- [ ] **Step 4: Commit**

```bash
git add Features/Tests/FeaturesTests/MainTabFeatureTests.swift
git commit -m "test(accessory): fix task tests to receive accessoryModeLoaded"
```

---

## Task 5: 更新 View

**Files:**
- Modify: `Features/Sources/Features/MainTab/MainTabView.swift`

- [ ] **Step 1: 替換 `inline` case 為單一 icon（反映目前模式）**

找到現有的 `case .inline:` 區塊：

```swift
case .inline:
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
```

整個替換成：

```swift
case .inline:
    Button {
        if store.accessoryMode == .ai {
            withAnimation(.spring()) {
                _ = store.send(.aiInputButtonTapped)
            }
        } else {
            store.send(.contextActionTapped)
        }
    } label: {
        Image(systemName: store.accessoryMode == .ai ? "wand.and.sparkles" : "plus.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(store.accessoryMode == .ai ? Color.accentColor : Color.primary)
    }
    .contextMenu(if: !store.aiUnavailable) {
        Button {
            store.send(.accessoryModeSwitched(.add))
        } label: {
            Label(String(localized: "accessory_add"), systemImage: "plus")
        }
        Button {
            store.send(.accessoryModeSwitched(.ai))
        } label: {
            Label(String(localized: "accessory_ai_record"), systemImage: "wand.and.sparkles")
        }
    }
```

> 注意：SwiftUI 沒有內建 `contextMenu(if:)`，需要在 Step 3 加入 helper extension。

- [ ] **Step 2: 替換 `compactPillContent`**

找到整個 `private var compactPillContent: some View` property 並全部替換：

```swift
private var compactPillContent: some View {
    let isAI = store.accessoryMode == .ai

    return Button {
        if isAI {
            withAnimation(.spring()) {
                _ = store.send(.aiInputButtonTapped)
            }
        } else {
            store.send(.contextActionTapped)
        }
    } label: {
        HStack(spacing: 6) {
            Image(systemName: isAI ? "wand.and.sparkles" : "plus.circle.fill")
                .symbolRenderingMode(.hierarchical)
            Text(isAI
                 ? String(localized: "accessory_ai_record")
                 : String(localized: "accessory_add"))
                .font(Font.Design.callout)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .foregroundStyle(isAI ? Color.accentColor : Color.primary)
    }
    .background(.regularMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(
        isAI ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1),
        lineWidth: 1
    ))
    .padding(.vertical, 8)
    .contextMenu(if: !store.aiUnavailable) {
        Button {
            store.send(.accessoryModeSwitched(.add))
        } label: {
            Label(String(localized: "accessory_add"), systemImage: "plus")
        }
        Button {
            store.send(.accessoryModeSwitched(.ai))
        } label: {
            Label(String(localized: "accessory_ai_record"), systemImage: "wand.and.sparkles")
        }
    }
}
```

- [ ] **Step 3: 在 `MainTabView.swift` 末尾加入 `contextMenu(if:)` helper extension**

在檔案最末尾（`#Preview` 之前）加入：

```swift
// MARK: - Conditional contextMenu helper

private extension View {
    @ViewBuilder
    func contextMenu(if condition: Bool, @ViewBuilder menuItems: () -> some View) -> some View {
        if condition {
            self.contextMenu(menuItems: menuItems)
        } else {
            self
        }
    }
}
```

- [ ] **Step 4: Build 確認沒有 compile error**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/MainTab/MainTabView.swift
git commit -m "feat(accessory): replace dual-button pill with single long-press menu button"
```

---

## Task 6: 最終驗證

- [ ] **Step 1: 執行完整測試套件**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \
  | grep -E "(✔|✘|passed|failed)" | tail -10
```

Expected: 無新增失敗。

- [ ] **Step 2: 手動在模擬器上確認以下行為**
  - 短按 → 新增模式開 AddTransaction Sheet
  - 長按 → 選單出現，有「新增」和「AI 記帳」
  - 選 AI 記帳 → 按鈕變橘色「AI 記帳」
  - 短按 AI 模式按鈕 → 展開 AI 輸入框
  - 重啟 App → 模式保持 AI
  - 模擬器關閉 Foundation Models（系統設定）→ 按鈕不可長按
