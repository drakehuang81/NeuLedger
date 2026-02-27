## Why

目前 App 啟動後直接顯示佔位 `Text("app_greeting")`，尚無 Onboarding 流程。Spec（`app-features.md`）與 Design System（`.pen` 檔 Onboarding Flow）已經定義了首次使用者的 3 步驟引導，需要將 UI 殼實作出來，讓後續的功能邏輯（帳戶建立、分類 seeding、Navigation）能有對應的 View 容器可以掛載。

## What Changes

- 新增 `OnboardingFeature.swift`：使用 TCA `@Reducer` 管理 Onboarding 的步驟狀態（Step 1 → 2 → 3）、帳戶名稱欄位輸入、帳戶類型選擇、完成 flag。
- 新增 `OnboardingView.swift`：3 頁 SwiftUI 畫面（Welcome → Account Setup → Ready），對應 Design System `.pen` 檔的設計。
- 修改 `RootView.swift`：依據 `hasCompletedOnboarding` flag 決定顯示 Onboarding 或正式主畫面。
- UI 殼先行：本次僅實作 **畫面結構與導覽**，不包含實際的資料寫入（帳戶 seeding、分類 seeding 等由後續 task 處理）。

## Capabilities

### New Capabilities
- `onboarding-flow`: 首次啟動時的 3 步驟引導 UI 殼——包含 Welcome 頁、Account Setup 表單頁、Ready 完成頁，以及步驟間的導覽邏輯與 `hasCompletedOnboarding` 控制。

### Modified Capabilities
_（無）— 本次不改動既有 spec 的 requirements，僅新增 UI 實作。_

## Impact

- **Features/Sources/Features/Onboarding/**：新增 `OnboardingFeature.swift`、`OnboardingView.swift`。
- **Features/Sources/Features/RootView.swift**：增加條件判斷顯示 Onboarding 或 Dashboard。
- **依賴**：TCA (`ComposableArchitecture`)、`Domain` 模組中的 `AccountType` enum（供帳戶類型選擇器使用）。
- **設計參照**：`openspec/designs/neuledger-design-system.pen` → Onboarding Flow（fa4Sn）。
