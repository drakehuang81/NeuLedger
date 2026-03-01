# Spec: Screen - Onboarding & Launch
**Purpose**: Define the Launch Experience and Onboarding flow UI and Routing for first-time setup.

## Requirements

### Requirement: 啟動畫面視覺呈現 (Splash View)
啟動畫面 (Launch Screen) 必須展現 NeuLedger 的品牌形象，並提供平滑的視覺體驗。透過 `SplashView` 實作品牌動畫。

#### Scenario: 應用程式冷啟動 (Cold Launch)
- **WHEN** 使用者首次打開 App 或從完全關閉狀態啟動
- **THEN** 顯示包含 App Logo 與品牌名稱的 `SplashView`
- **AND** 顯示品牌 Logo 的縮放與透明度脈動動畫 (Scale & Pulsing)
- **AND** 背景色應與系統主題 (System Theme) 一致
- **AND** 經過由 Reducer 控制的非同步路由判斷後，過渡到 Onboarding 或主畫面。

### Requirement: Onboarding 流程與條件顯示
`AppView`（原 `RootView`）SHALL 根據 `AppFeature.State.destination` 決定顯示 Onboarding 或主畫面，不再直接讀取 `userSettingsClient`。

#### Scenario: 首次啟動
- **WHEN** App 啟動且 `AppFeature.State.destination` 為 `.onboarding` (因從未完成)
- **THEN** 顯示 3 步驟 Onboarding (`OnboardingView`)：
    1. **Welcome**：App 名稱 + 價值主張
    2. **Account Setup**：建立第一個帳戶
    3. **Ready**：「開始使用」按鈕

#### Scenario: 跳過 Onboarding
- **WHEN** 使用者在任何步驟點擊「跳過」
- **THEN** 用預設值建立帳戶和分類
- **AND** 直接進入 Dashboard

#### Scenario: Onboarding 完成後顯示主畫面
- **WHEN** `AppFeature` 收到 `.onboarding(.delegate(.onboardingCompleted))` action
- **THEN** `destination` SHALL 變為 `.main`
- **AND** 系統 SHALL 將 `hasCompletedOnboarding` 設為 `true`
- **AND** 系統 SHALL 透過 `onComplete` delegate action 通知上層，自動切換至主畫面

### Requirement: Onboarding UI 結構

#### Scenario: Welcome 頁面元素呈現
- **WHEN** `currentStep` 為 `.welcome`
- **THEN** 畫面 SHALL 顯示以下元素（由上至下）：
  1. App Icon 佔位圖（120×120，品牌漸層 `brand-primary` → `brand-secondary`，圓角 28）
  2. 主標題文字 `"NeuLedger"`（字型大小 34，粗體 700）
  3. 副標題文字 `"AI 驅陪的極簡記帳體驗"`（字型大小 17）
  4. 底部主要按鈕 `"開始使用"` 附帶向右箭頭圖示

#### Scenario: Account Setup 頁面元素呈現
- **WHEN** `currentStep` 為 `.accountSetup`
- **THEN** 畫面 SHALL 顯示以下元素（由上至下）：
  1. 標題 `"第一個帳戶"`（字型大小 28，粗體 700）
  2. 副標題 `"為你的主要錢包命名"`（字型大小 17）
  3. 帳戶名稱輸入欄位（預設值 `"現金"`）
  4. 帳戶類型選擇器（選項為 `AccountType.allCases`）
  5. 底部主要按鈕 `"下一步"`

#### Scenario: Ready 頁面元素呈現
- **WHEN** `currentStep` 為 `.ready`
- **THEN** 畫面 SHALL 顯示以下元素（由上至下）：
  1. 成功圖示（`checkmark.circle.fill`，100×100，`income-green` 背景，圓形）
  2. 主標題文字 `"準備就緒"`（字型大小 34，粗體 700）
  3. 副標題文字 `"你的個人財務助手已設定完成"`（字型大小 17）
  4. 預覽卡片：顯示 `"目前資產"` 標籤與 `"$0"` 金額（毛玻璃效果、圓角 `radius-xl`）
  5. 底部主要按鈕 `"前往主畫面"`
