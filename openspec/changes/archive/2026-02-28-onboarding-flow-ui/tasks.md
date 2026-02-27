## 1. Localization 在地化字串

- [x] 1.1 在 `Localizable.xcstrings` 新增 13 個 `onboarding_*` key（`extractionState: "manual"`），同時提供 `en` 與 `zh-Hant` 翻譯（詳見 spec 在地化 Key 定義表）

## 2. OnboardingFeature (TCA Reducer)

- [x] 2.1 建立 `Features/Sources/Features/Onboarding/OnboardingFeature.swift`
- [x] 2.2 定義 `enum Step: Equatable { case welcome, accountSetup, ready }`
- [x] 2.3 定義 `@ObservableState struct State: Equatable`，包含 `currentStep: Step = .welcome`、`accountName: String = "現金"`、`accountType: AccountType = .cash`
- [x] 2.4 定義 `enum Action`：`startButtonTapped`、`nextButtonTapped`、`finishButtonTapped`、`accountNameChanged(String)`、`accountTypeChanged(AccountType)`、`delegate(Delegate)`
- [x] 2.5 定義 `enum Delegate` action：`onboardingCompleted`（通知上層 Onboarding 已結束）
- [x] 2.6 實作 `Reduce` body：各 action 推進 `currentStep`，`finishButtonTapped` 時 send `.delegate(.onboardingCompleted)`

## 3. OnboardingView (SwiftUI)

- [x] 3.1 建立 `Features/Sources/Features/Onboarding/OnboardingView.swift`
- [x] 3.2 實作 Welcome 頁：App Icon 佔位圖（120×120 漸層圓角框）、標題 `Text("onboarding_welcome_title")`、副標題 `Text("onboarding_welcome_subtitle")`、底部按鈕 `Text("onboarding_welcome_button")` + 箭頭圖示
- [x] 3.3 實作 Account Setup 頁：標題 `Text("onboarding_setup_title")`、副標題 `Text("onboarding_setup_subtitle")`、帳戶名稱 `TextField`（綁定 `store.accountName`）、帳戶類型 `Picker`（綁定 `store.accountType`，使用 `AccountType.allCases`）、底部按鈕 `Text("onboarding_setup_button")`
- [x] 3.4 實作 Ready 頁：成功圖示（`checkmark.circle.fill` + 綠色背景）、標題 `Text("onboarding_ready_title")`、副標題 `Text("onboarding_ready_subtitle")`、預覽卡片（`Text("onboarding_ready_balance_label")` + `"$0"` 金額、毛玻璃效果）、底部按鈕 `Text("onboarding_ready_button")`
- [x] 3.5 使用 `switch store.currentStep` 條件切換 3 個頁面
- [x] 3.6 所有使用者可見文字 SHALL 使用 `Localizable.xcstrings` key，不得硬編碼

## 4. 共用按鈕樣式

- [x] 4.1 抽取 Onboarding 主要按鈕為可複用的 ViewModifier 或 private subview（`brand-primary` 填色、`Capsule` 圓角、高度 56、寬度填滿）

## 5. RootView 條件顯示

- [x] 5.1 在 `RootView.swift` 加入 `@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false`
- [x] 5.2 根據 `hasCompletedOnboarding` 條件：`false` 時顯示 `OnboardingView`，`true` 時顯示主畫面（原有內容）
- [x] 5.3 `OnboardingView` 的 `.delegate(.onboardingCompleted)` 觸發時，將 `hasCompletedOnboarding` 設為 `true`

## 6. 驗證

- [x] 6.1 確認專案編譯通過（`swift build` 或 Xcode Build）
- [x] 6.2 確認首次啟動顯示 Onboarding，走完 3 步後進入主畫面
- [x] 6.3 確認再次啟動直接進入主畫面（不再顯示 Onboarding）
