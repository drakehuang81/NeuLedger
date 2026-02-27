## ADDED Requirements

### Requirement: Onboarding 步驟狀態管理
系統 SHALL 使用 TCA `@Reducer`（`OnboardingFeature`）管理 3 個步驟的狀態，步驟以 `enum Step` 表示：`.welcome`、`.accountSetup`、`.ready`。

#### Scenario: 初始狀態為 Welcome
- **WHEN** `OnboardingFeature.State` 被初始化
- **THEN** `currentStep` SHALL 為 `.welcome`
- **AND** `accountName` SHALL 為 `"現金"`
- **AND** `accountType` SHALL 為 `.cash`

#### Scenario: 從 Welcome 前進至 Account Setup
- **WHEN** 使用者在 Welcome 頁點擊「開始使用」按鈕
- **THEN** `OnboardingFeature` SHALL 收到 `.startButtonTapped` action
- **AND** `currentStep` SHALL 變為 `.accountSetup`

#### Scenario: 從 Account Setup 前進至 Ready
- **WHEN** 使用者在 Account Setup 頁點擊「下一步」按鈕
- **THEN** `OnboardingFeature` SHALL 收到 `.nextButtonTapped` action
- **AND** `currentStep` SHALL 變為 `.ready`

#### Scenario: 從 Ready 完成 Onboarding
- **WHEN** 使用者在 Ready 頁點擊「前往主畫面」按鈕
- **THEN** `OnboardingFeature` SHALL 收到 `.finishButtonTapped` action
- **AND** 系統 SHALL 將 `hasCompletedOnboarding` 設為 `true`
- **AND** 系統 SHALL 透過 `onComplete` delegate action 通知上層

---

### Requirement: Welcome 頁面 UI 結構
Welcome 頁 SHALL 對齊 Design System `.pen` 檔的 Step 1 設計。

#### Scenario: Welcome 頁面元素呈現
- **WHEN** `currentStep` 為 `.welcome`
- **THEN** 畫面 SHALL 顯示以下元素（由上至下）：
  1. App Icon 佔位圖（120×120，品牌漸層 `brand-primary` → `brand-secondary`，圓角 28）
  2. 主標題文字 `"NeuLedger"`（字型大小 34，粗體 700）
  3. 副標題文字 `"AI 驅動的極簡記帳體驗"`（字型大小 17）
  4. 底部主要按鈕 `"開始使用"` 附帶向右箭頭圖示
- **AND** 內容區塊 SHALL 置中對齊
- **AND** 按鈕 SHALL 使用 `brand-primary` 填色、`radius-pill` 圓角、高度 56、寬度填滿

---

### Requirement: Account Setup 頁面 UI 結構
Account Setup 頁 SHALL 對齊 Design System `.pen` 檔的 Step 2 設計。

#### Scenario: Account Setup 頁面元素呈現
- **WHEN** `currentStep` 為 `.accountSetup`
- **THEN** 畫面 SHALL 顯示以下元素（由上至下）：
  1. 標題 `"第一個帳戶"`（字型大小 28，粗體 700）
  2. 副標題 `"為你的主要錢包命名"`（字型大小 17）
  3. 帳戶名稱輸入欄位（綁定至 `State.accountName`，預設值 `"現金"`）
  4. 帳戶類型選擇器（綁定至 `State.accountType`，選項為 `AccountType.allCases`）
  5. 底部主要按鈕 `"下一步"`
- **AND** 按鈕 SHALL 使用與 Welcome 頁相同的樣式

#### Scenario: 帳戶名稱即時綁定
- **WHEN** 使用者在帳戶名稱欄位輸入文字
- **THEN** `OnboardingFeature` SHALL 收到 `.accountNameChanged(String)` action
- **AND** `State.accountName` SHALL 即時更新為輸入值

#### Scenario: 帳戶類型即時綁定
- **WHEN** 使用者選擇帳戶類型
- **THEN** `OnboardingFeature` SHALL 收到 `.accountTypeChanged(AccountType)` action
- **AND** `State.accountType` SHALL 即時更新為選擇值

---

### Requirement: Ready 頁面 UI 結構
Ready 頁 SHALL 對齊 Design System `.pen` 檔的 Step 3 設計。

#### Scenario: Ready 頁面元素呈現
- **WHEN** `currentStep` 為 `.ready`
- **THEN** 畫面 SHALL 顯示以下元素（由上至下）：
  1. 成功圖示（`checkmark.circle.fill`，100×100，`income-green` 背景，圓形）
  2. 主標題文字 `"準備就緒"`（字型大小 34，粗體 700）
  3. 副標題文字 `"你的個人財務助手已設定完成"`（字型大小 17）
  4. 預覽卡片：顯示 `"目前資產"` 標籤與 `"$0"` 金額（毛玻璃效果、圓角 `radius-xl`）
  5. 底部主要按鈕 `"前往主畫面"`
- **AND** 按鈕 SHALL 使用與 Welcome 頁相同的樣式

---

### Requirement: RootView 條件顯示
`RootView` SHALL 根據 `hasCompletedOnboarding` flag 決定顯示 Onboarding 或主畫面。

#### Scenario: 首次啟動顯示 Onboarding
- **WHEN** App 啟動且 `@AppStorage("hasCompletedOnboarding")` 為 `false`（預設值）
- **THEN** `RootView` SHALL 顯示 `OnboardingView`
- **AND** SHALL 不顯示主畫面內容

#### Scenario: Onboarding 完成後顯示主畫面
- **WHEN** `hasCompletedOnboarding` 變為 `true`
- **THEN** `RootView` SHALL 自動切換至主畫面
- **AND** SHALL 不再顯示 `OnboardingView`

#### Scenario: 非首次啟動直接進入主畫面
- **WHEN** App 啟動且 `@AppStorage("hasCompletedOnboarding")` 已為 `true`
- **THEN** `RootView` SHALL 直接顯示主畫面
- **AND** SHALL 不顯示 `OnboardingView`

---

### Requirement: Onboarding 在地化字串
所有 Onboarding 頁面的使用者可見文字 SHALL 使用 `Localizable.xcstrings` 中的在地化 key，遵循 `onboarding_[element]` 命名慣例，並同時提供 `en` 與 `zh-Hant` 翻譯。

#### Scenario: 在地化 Key 定義
- **WHEN** Onboarding UI 被實作
- **THEN** 以下 key SHALL 被新增至 `Localizable.xcstrings`：

| Key | en | zh-Hant |
|-----|-----|---------|
| `onboarding_welcome_title` | NeuLedger | NeuLedger |
| `onboarding_welcome_subtitle` | AI-Powered Minimal Bookkeeping | AI 驅動的極簡記帳體驗 |
| `onboarding_welcome_button` | Get Started | 開始使用 |
| `onboarding_setup_title` | First Account | 第一個帳戶 |
| `onboarding_setup_subtitle` | Name your primary wallet | 為你的主要錢包命名 |
| `onboarding_setup_name_label` | Account Name | 帳戶名稱 |
| `onboarding_setup_name_placeholder` | Cash | 現金 |
| `onboarding_setup_type_label` | Account Type | 帳戶類型 |
| `onboarding_setup_button` | Next | 下一步 |
| `onboarding_ready_title` | All Set | 準備就緒 |
| `onboarding_ready_subtitle` | Your personal finance assistant is ready | 你的個人財務助手已設定完成 |
| `onboarding_ready_balance_label` | Current Balance | 目前資產 |
| `onboarding_ready_button` | Go to Home | 前往主畫面 |

- **AND** 每個 key 的 `extractionState` SHALL 為 `"manual"`
- **AND** View 中 SHALL 使用 `Text("onboarding_welcome_title")` 等 key 引用，不得使用硬編碼字串
