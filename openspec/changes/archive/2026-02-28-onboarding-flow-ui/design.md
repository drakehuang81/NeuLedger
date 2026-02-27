## Context

NeuLedger 目前 `RootView` 直接顯示一個佔位 `Text("app_greeting")`，沒有任何 Onboarding 引導。Design System（`.pen`）已完成 3 步驟的 Onboarding Flow 視覺設計，`app-features.md` spec 也已定義了首次啟動的行為需求。

現有模組化架構：
- **Features** target（依賴 TCA + Domain + Common）：放置所有 Feature Reducer + View
- **Domain** target：包含 `AccountType` enum、`Account` entity 等純領域物件
- **Core** target：包含 Live Client 實作與 Persistence
- `RootView.swift` 中 `NeuLedgerApp`（`@main`）負責 `WindowGroup` + `ModelContainer`

## Goals / Non-Goals

**Goals:**
- 建立 `OnboardingFeature`（TCA `@Reducer`）管理 3 步驟的狀態機
- 建立 `OnboardingView`（SwiftUI），視覺對齊 `.pen` 設計稿
- 修改 `RootView` 根據 `hasCompletedOnboarding` 判斷是否顯示 Onboarding
- UI 殼可獨立編譯與運行，不依賴真實的資料層寫入

**Non-Goals:**
- 不在本次實作真實的帳戶 seeding（`AccountClient.add`）— 表單 UI 先呈現，submit 動作後續接線
- 不實作「跳過 Onboarding」邏輯 — 先完成正常的 3 步流程
- 不處理動畫細節（轉場動畫、頁面切換動效）— 先確保結構正確
- 不在 Step 2 做欄位驗證 — 本次僅 UI 殼

## Decisions

### Decision 1: 使用 TCA `@Reducer` + `enum Step` 管理步驟狀態

**選擇**：在 `OnboardingFeature.State` 中用 `enum Step` (`welcome`, `accountSetup`, `ready`) 搭配 `TabView(selection:)` 或條件 `switch` 來切換畫面。

**替代方案**：
- StackNavigation（`NavigationPath`）— 但 Onboarding 不是典型的 push/pop 導覽，且步驟固定，使用 enum 更直觀。
- 用 `@Presents` sheet — Onboarding 是全畫面體驗，不適合 sheet 模式。

**理由**：enum 步驟機結構清晰、易於測試，且 TCA 的 `Reduce` body 可以直觀地 `switch` 每個 Action 來推進步驟。

### Decision 2: `hasCompletedOnboarding` 使用 `@AppStorage`

**選擇**：在 `RootView` 層級使用 `@AppStorage("hasCompletedOnboarding")` 來持久化是否已完成 Onboarding 的 flag。

**替代方案**：
- 存入 SwiftData — 過於重量級，單純的 Boolean flag 不需要。
- TCA `@Shared(.appStorage(...))` — 可行，但 `RootView` 層級不經過 Store，用 `@AppStorage` 最直接。

**理由**：`@AppStorage` 足以應付單一 Boolean，且無需在 TCA Store 初始化前就取得此值（因為決定要不要顯示 Onboarding 發生在 View 最上層）。

### Decision 3: Onboarding 完成後透過回呼通知 RootView

**選擇**：`OnboardingView` 接收一個 `onComplete: () -> Void` closure，或 `RootView` 觀察 `@AppStorage` 的值變化來自動切換畫面。

**理由**：保持 `OnboardingFeature` 不需要知道 Root 層的實作細節，僅負責將 `hasCompletedOnboarding` 設為 `true` 並呼叫 `onComplete`。`RootView` 的 `@AppStorage` 綁定會自動觸發 SwiftUI re-render。

### Decision 4: Step 2 表單欄位綁定在 OnboardingFeature.State

**選擇**：
```swift
@ObservableState
struct State: Equatable {
    var currentStep: Step = .welcome
    var accountName: String = "現金"
    var accountType: AccountType = .cash
}
```

**理由**：帳戶名稱和類型是 Onboarding 流程的核心輸入，直接放在 `State` 中管理，未來接線時可直接取值傳給 `AccountClient.add`。

### Decision 5: 檔案位置遵循現有結構

**選擇**：
```
Features/Sources/Features/Onboarding/
├── OnboardingFeature.swift
└── OnboardingView.swift
```

**理由**：與現有的 `Dashboard/`、`Analysis/` 資料夾結構一致。

## Risks / Trade-offs

- **[Risk] `@AppStorage` 與 TCA Store 分離** → 由於 `hasCompletedOnboarding` 只在 `RootView` 使用（TCA Store 外層），實際上沒有衝突。若未來需要在 Reducer 裡讀取，可改用 `@Shared(.appStorage(...))` 遷移。
- **[Risk] UI 殼先行，表單 submit 無實際效果** → 明確標記為 Non-Goal，後續 task 補上。Button action 先 send TCA action 但 Reducer 僅推進步驟。
- **[Trade-off] 不做動畫** → 優先確保結構正確，動畫可以獨立加入不影響架構。
