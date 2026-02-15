## Why

專案已開始導入 SPM 本地套件進行模組化拆分（`Features` 套件已建立），但目前存在幾個結構問題阻礙了進一步開發：

1. **`NeuLedgerUI` 幽靈引用**：Xcode `project.pbxproj` 引用了一個 `NeuLedgerUI` 套件依賴，但該套件目錄實際不存在，導致建構設定不一致。
2. **Glass 元件滯留主 Target**：`GlassButton`、`GlassCard`、`GlassHeader` 三個 Design System 元件仍停留在 `NeuLedger/` 主 Target 資料夾中，尚未遷移至模組化套件。這些元件依賴了未定義的 `GlassButtonStyle` 和 `.Design.*` Color/Font extension，無法獨立編譯。
3. **架構規範未反映 SPM 模組化**：現有的 `architecture-blueprint` spec 仍描述單體式（Monolithic）資料夾結構，與 Rules.md 三層架構（Base → Infrastructure → Features）的策略不一致。
4. **Design System 顏色依賴 Asset Catalog**：現有 `design-system` spec 要求顏色定義在 `Assets.xcassets` 中，但模組化後套件無法直接存取主 Target 的 Asset Catalog，需改用 Pure Code 方式定義 Color Token。

現在是重構的最佳時機：專案處於早期階段，技術債尚未累積，且 Rules.md 已經明確定義了三層架構方向。

## What Changes

- **BREAKING**: 移除 `NeuLedgerUI` 套件的所有 pbxproj 引用（該套件從未實際建立）
- **BREAKING**: 重新定義 SPM 模組架構，遵循 Rules.md 三層體系：
  - **Base 層**：建立基礎套件（如 `DesignTokens`），包含 Pure Code 的 Color/Font Design Token 定義，零外部依賴
  - **Infrastructure 層**：在 `Features` 套件內或建立獨立套件，放置 Design System 元件（GlassButton、GlassCard、GlassHeader、GlassButtonStyle）
  - **Features 層**：現有 `Features` 套件維持不變，依賴 Base 層
- 搬遷 `GlassButton.swift`、`GlassCard.swift`、`GlassHeader.swift` 至對應的 SPM 套件
- 補齊缺失的 `GlassButtonStyle` 定義和 `.Design.*` Color/Font extension
- 修正現有 spec 文件以反映 SPM 模組化架構
- 主 App Target (`NeuLedger/`) 精簡為 Composer 角色：僅負責 `@main` 入口組裝、`Info.plist`、`Entitlements`

## Capabilities

### New Capabilities
- `design-tokens`: Pure Code 的 Design Token 模組 — 定義全部 Color、Font extension（以代碼方式取代 Asset Catalog 的顏色定義），作為三層架構的 Base 層，零外部依賴

### Modified Capabilities
- `architecture-blueprint`: 資料夾結構從單體式改為 SPM 三層模組化架構（Base → Infrastructure → Features），主 App Target 轉型為 Composer
- `design-system`: 移除 Asset Catalog 顏色依賴，改用 Pure Code Design Token；Glass 元件遷移至 SPM 套件；補齊 GlassButtonStyle 和 Design extension 定義

## Impact

- **Xcode Project (`project.pbxproj`)**：移除 `NeuLedgerUI` productDependency 引用，新增 Base 層套件依賴
- **主 App Target (`NeuLedger/`)**：三個 Glass `.swift` 檔案將被移走，`NeuLedgerApp.swift` 保留為空殼或移除（`@main` 在 Features 套件中）
- **`Features` 套件 (`Features/Package.swift`)**：新增對 Base 層套件的依賴宣告
- **Asset Catalog (`Assets.xcassets`)**：Color Set（`incomeGreen`、`expenseRed`、`warningAmber`）將不再是 Design Token 的來源，改由 Pure Code 取代
- **存取控制 (Access Control)**：搬遷至套件後，所有對外介面需顯式標記 `public`
- **Spec 文件**：`architecture-blueprint.md` 和 `design-system.md` 的 requirements 需要更新
