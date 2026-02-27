## Context

NeuLedger 專案遵循 Clean Architecture 分層：

- **Domain**（`Features/Sources/Domain/`）：定義介面（`@DependencyClient`）、Entities 與 Enums
- **Core**（`Features/Sources/Core/`）：提供 Live 實作（`DependencyKey.liveValue`）
- **Features**（`Features/Sources/Features/`）：SwiftUI Views 與 TCA Reducers

現有的 Client 模式（如 `AccountClient`）統一以 `@DependencyClient` 定義在 Domain，Live 實作在 Core 的 extension 中提供 `liveValue`，並透過 `DependencyValues` extension 註冊為 `\.accountClient`。

目前 `RootView` 使用 `@AppStorage("hasCompletedOnboarding")` 直接讀取 UserDefaults，`OnboardingFeature` 使用 `UserDefaults.standard.set` 直接寫入。這繞過了既有的分層架構，且 `OnboardingFeature` 沒有單元測試。

## Goals / Non-Goals

**Goals:**

- 建立泛型 `UserSettingsClient`，對齊既有 Client 架構慣例
- 使用 `SettingsKey<Value>` 提供型別安全的 key 定義，集中管理所有 UserDefaults keys
- 重構 `RootView` 與 `OnboardingFeature`，移除對 UserDefaults 的直接依賴
- 為 `OnboardingFeature` Reducer 建立完整的單元測試

**Non-Goals:**

- 不遷移現有已存在 UserDefaults 中的資料（key 名稱保持不變，無需 migration）
- 不在本次 change 中支援 Bool 以外的型別（String、Int 等留待未來需求時擴充）
- 不重構 `RootView` 的整體架構（例如改為 TCA Reducer 驅動），只抽換 UserDefaults 存取方式
- 不建立 `OnboardingView`（UI）的單元測試

## Decisions

### Decision 1：`SettingsKey<Value>` 使用泛型 struct + constrained extension

```swift
public struct SettingsKey<Value>: Sendable {
    public let rawValue: String
    public let defaultValue: Value
    public init(rawValue: String, defaultValue: Value) { ... }
}

extension SettingsKey where Value == Bool {
    public static let hasCompletedOnboarding = SettingsKey(
        rawValue: "hasCompletedOnboarding",
        defaultValue: false
    )
}
```

**為什麼**：使用泛型 struct 搭配 constrained extension 而非 enum，因為 enum 無法支援泛型 associated values 的靜態定義。struct + constrained extension 允許根據 `Value` 型別分組定義 keys，且能自然擴充。

**替代方案考量**：
- **使用 raw string key**：失去型別安全與 default value 保證，容易拼錯 key
- **使用 protocol + 各型別 struct**：過度設計，struct + constrained extension 已足夠

### Decision 2：`UserSettingsClient` 初始僅支援 Bool

```swift
@DependencyClient
public struct UserSettingsClient: Sendable {
    public var bool: @Sendable (SettingsKey<Bool>) -> Bool = { $0.defaultValue }
    public var setBool: @Sendable (Bool, SettingsKey<Bool>) -> Void
}
```

**為什麼**：目前唯一的使用場景是 `hasCompletedOnboarding`（Bool）。遵循 YAGNI 原則，先提供 Bool 支援，未來有需求時再擴充 `string`、`int` 等方法。介面設計已為擴充預留空間。

**替代方案考量**：
- **一次支援所有型別**：增加初始工作量且當前無需求
- **使用 `Any` + 強轉**：失去型別安全，與設計目標矛盾

### Decision 3：`bool` 方法使用同步介面

**為什麼**：UserDefaults 的讀寫本質上是同步的記憶體操作（UserDefaults 會 cache 到記憶體）。使用同步介面簡化呼叫端程式碼，避免不必要的 async 開銷。與既有 `@AppStorage` 的用法對齊。

**替代方案考量**：
- **使用 async 介面**：增加使用複雜度，且 UserDefaults 本身為同步，沒有 async 的實際需求

### Decision 4：`SettingsKey` 定義在 `UserSettingsClient.swift` 同一檔案

**為什麼**：`SettingsKey` 與 `UserSettingsClient` 高度耦合，放在同一檔案減少檔案數量。當 keys 數量增長到顯著程度時，可考慮拆分到 `SettingsKey.swift`。

### Decision 5：`RootView` 使用 `@State` + `.onAppear` 取代 `@AppStorage`

```swift
struct RootView: View {
    @Dependency(\.userSettingsClient) var userSettingsClient
    @State private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding { ... }
            else { OnboardingView(...) }
        }
        .onAppear {
            hasCompletedOnboarding = userSettingsClient.bool(.hasCompletedOnboarding)
        }
    }
}
```

**為什麼**：`@AppStorage` 直接耦合 UserDefaults，無法注入測試替身。改用 `@State` + `onAppear` 從 `userSettingsClient` 讀取，保持 SwiftUI 的響應式更新，同時解耦底層儲存。

**替代方案考量**：
- **將 RootView 改為 TCA Store 驅動**：工作量較大，本次 Non-Goal 已明確排除
- **自訂 property wrapper**：過度設計，`@State` + `onAppear` 已足夠

### Decision 6：`OnboardingFeature.finishButtonTapped` 改為同步 Effect

現有實作使用 `.run` 只因為需要呼叫 `UserDefaults.standard.set`。改用 `UserSettingsClient`（同步）後，可簡化為：

```swift
case .finishButtonTapped:
    userSettingsClient.setBool(true, .hasCompletedOnboarding)
    return .send(.delegate(.onboardingCompleted))
```

**為什麼**：既然 `setBool` 是同步的，就不需要 `.run` async Effect。直接同步呼叫後 send delegate，邏輯更清晰且更易測試。

### Decision 7：測試檔案放置位置

- `OnboardingFeatureTests.swift` → `Features/Tests/FeaturesTests/FeaturesTests/`（與 Feature 對齊）
- `UserSettingsClientTests.swift` → `Features/Tests/FeaturesTests/CoreTests/`（與 Core live impl 對齊）

**為什麼**：遵循既有測試目錄結構，`FeaturesTests/` 下已有 `CoreTests/` 和 `DomainTests/` 子目錄。

## Risks / Trade-offs

- **`@State` + `onAppear` 的時序**：`onAppear` 在首幀渲染前可能有短暫的初始狀態（`false`），但因為 default value 也是 `false`（顯示 onboarding），不會造成畫面閃爍。 → **風險低，無需額外處理**
- **`SettingsKey` 散落各處**：如果未來多個模組都定義自己的 extension，可能導致 key 重複。 → **Mitigation**：所有 `SettingsKey` extension 統一定義在 Domain 層的同一檔案中，code review 時確保無重複
- **同步介面限制**：若未來需要從 iCloud KVS 等非同步儲存讀取，需要改介面。 → **Mitigation**：屆時可新增 async 變體方法，不影響既有同步方法
