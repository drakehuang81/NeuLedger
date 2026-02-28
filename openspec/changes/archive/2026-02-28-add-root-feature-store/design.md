## Context

目前 `RootView` 直接持有 `@Dependency` 和 `@State` 來判斷是否顯示 Onboarding 或主畫面，`OnboardingFeature` 的 Store 在 View 層手動建立。這導致：

1. 路由邏輯散落在 View 層，無法透過 TCA 測試
2. `OnboardingFeature` 的 delegate action（`onboardingCompleted`）無處消費，目前 Onboarding 完成後需靠 View `onAppear` 重讀 UserDefaults
3. 未來要整合 NavigationStack/Path、TabView 或 Deep Link 時沒有統一的狀態入口

`architecture-blueprint.md` 已規劃 `AppFeature` 作為 Root Reducer，負責組合子 Feature 並管理 TabView 選擇。本次先建立 `AppFeature` 最小可行版本，聚焦在 Onboarding ↔ Main 路由。

## Goals / Non-Goals

**Goals:**
- 建立 `AppFeature` Reducer 管理 App 層級路由狀態（Onboarding vs Main）
- 將 `OnboardingFeature` 作為 child feature 透過 TCA `Scope` 組合
- 處理 `OnboardingFeature.Delegate.onboardingCompleted`，在 Reducer 層完成路由切換
- 將 `RootView.swift` 重新命名為 `AppView.swift`，改為 Store-driven
- 確保路由邏輯可透過 TCA `TestStore` 測試

**Non-Goals:**
- 本次不建立完整的 TabView composition（Dashboard/Transactions/Analysis/Settings）
- 本次不實作 NavigationStack/Path 導航
- 本次不處理 Deep Link
- 本次不改動 `OnboardingFeature` 內部邏輯

## Decisions

### Decision 1: AppFeature 使用 enum Destination 管理路由

使用 enum 而非 boolean 來表達應用程式的路由目的地。

```swift
@Reducer
struct AppFeature {
    enum Destination: Equatable {
        case onboarding(OnboardingFeature.State)
        case main
    }

    @ObservableState
    struct State: Equatable {
        var destination: Destination = .onboarding(OnboardingFeature.State())
    }
}
```

**Why**: enum 比 `Bool hasCompletedOnboarding` 更具表達力，未來擴展（如 `.main(TabFeature.State)`）只需加 case，符合 Open-Closed Principle。

**Alternatives considered**:
- `@Presents var onboarding: OnboardingFeature.State?` + `ifLet`：適合 sheet/modal，但 Onboarding→Main 是全畫面替換，不是 presentation。用 optional 語意上不夠清楚（nil 代表"主畫面"不直觀）。
- `Bool` + `if/else`：目前做法，已論述為何不妥。

### Decision 2: 在 Reducer 層讀取 UserSettings 判斷初始路由

`AppFeature.State` 的初始值由 `NeuLedgerApp`（`@main`）建立時決定，透過 `userSettingsClient` 讀取 `hasCompletedOnboarding`：

```swift
// NeuLedgerApp.swift
@Dependency(\.userSettingsClient) var userSettingsClient

var body: some Scene {
    WindowGroup {
        AppView(
            store: Store(
                initialState: AppFeature.State(
                    destination: userSettingsClient.bool(.hasCompletedOnboarding)
                        ? .main
                        : .onboarding(OnboardingFeature.State())
                )
            ) {
                AppFeature()
            }
        )
    }
}
```

**Why**: 啟動時只需讀一次，之後由 Reducer 管理狀態流。把判斷放在 Store 初始化時，Reducer 不需關心"初次讀取"邏輯，更乾淨。

**Alternatives considered**:
- 在 Reducer 的 `.onAppear` action 中讀取：多一個非同步步驟，且造成畫面初始時會有短暫的不確定狀態。

### Decision 3: OnboardingFeature 透過 inline Scope 組合

在 `body` 中使用 pattern-match 在 `.onboarding` case 上 scope 出 `OnboardingFeature`：

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onboarding(.delegate(.onboardingCompleted)):
            state.destination = .main
            return .none
        case .onboarding:
            return .none
        }
    }
    .ifCaseLet(\.destination.onboarding, action: \.onboarding) {
        OnboardingFeature()
    }
}
```

**Why**: `ifCaseLet` 是 TCA 推薦的 enum-based child feature 組合模式，當 destination 不是 `.onboarding` 時自動停止 child reducer 執行，效能和語意都正確。

### Decision 4: AppView 使用 switch + store.scope 渲染

```swift
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        switch store.destination {
        case .onboarding:
            if let onboardingStore = store.scope(
                state: \.destination.onboarding,
                action: \.onboarding
            ) {
                OnboardingView(store: onboardingStore)
            }
        case .main:
            Text("app_greeting") // placeholder for future TabView
        }
    }
}
```

**Why**: 透過 `store.scope` 從父 Store 衍生子 Store 傳給 `OnboardingView`，確保子 Feature 的 action 能正確回傳到父層 Reducer 處理 delegate。

### Decision 5: 檔案命名與擺放

| 檔案 | 路徑 |
|------|------|
| `AppFeature.swift` | `Features/Sources/Features/AppFeature.swift` |
| `AppView.swift`（原 `RootView.swift` 重新命名） | `Features/Sources/Features/AppView.swift` |

**Why**: 與 `architecture-blueprint.md` 規劃一致。App 層級的 Feature 和 View 放在 Features 根目錄，不另建子資料夾，因為它是唯一的根入口。

## Risks / Trade-offs

- **[Destination enum 不用 `@Presents`]** → 無法使用 SwiftUI 的 `sheet(item:)` 等 navigation modifier 來驅動。但 Onboarding→Main 的切換是全畫面替換，不是 modal/sheet，所以不需要。未來有 sheet 需求時再用 `@Presents`。

- **[初始路由在 Store 建立時決定]** → 如果 `userSettingsClient` 日後改為 async，需調整初始化方式。目前是同步讀取 UserDefaults，風險極低。

- **[`OnboardingFeature.State` 保存在 enum associated value 中]** → 切換到 `.main` 後 Onboarding 狀態會被丟棄。這是預期行為，因為 Onboarding 完成後不會再回到此流程。
