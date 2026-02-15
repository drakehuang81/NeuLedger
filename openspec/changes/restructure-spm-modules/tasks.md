## 1. Xcode Project 清理

- [ ] 1.1 Git commit 當前狀態作為備份（確保可回滾）
- [ ] 1.2 從 `project.pbxproj` 移除 `NeuLedgerUI` 的 `PBXBuildFile` 引用（`A249D8C92F419BCC00CBA03D`）
- [ ] 1.3 從 `project.pbxproj` 移除 `NeuLedgerUI` 的 `PBXFrameworksBuildPhase` files 條目
- [ ] 1.4 從 `project.pbxproj` 移除 `NeuLedgerUI` 的 `XCSwiftPackageProductDependency`（`A2CF1C2F2F40ABE000BDE292`）
- [ ] 1.5 從 `project.pbxproj` 移除 `NeuLedgerUI` 的 `packageProductDependencies` 條目
- [ ] 1.6 驗證 Xcode 可正常開啟專案，無 package resolution 錯誤

## 2. 建立 DesignTokens 套件（Base 層）

- [ ] 2.1 在專案根目錄建立 `DesignTokens/` 目錄結構：`Package.swift`、`Sources/DesignTokens/`
- [ ] 2.2 撰寫 `Package.swift`：swift-tools-version 6.2、iOS 26、library product `DesignTokens`、零外部依賴
- [ ] 2.3 建立 `ColorTokens.swift`：定義 `Color.Design` namespace，包含 `incomeGreen`、`expenseRed`、`warningAmber` 品牌色（使用 `Color(light:dark:)` Pure Code）
- [ ] 2.4 在 `ColorTokens.swift` 中定義語義色：`textPrimary`、`textSecondary`、`background`、`groupedBackground`、`cardSurface`、`separator`
- [ ] 2.5 建立 `FontTokens.swift`：定義 `Font.Design` namespace，包含 `largeTitle`、`title2`、`headline`、`body`、`callout`、`subheadline`、`caption`、`amount`
- [ ] 2.6 確認所有 public API 已標記 `public`
- [ ] 2.7 切換 Scheme 至 `DesignTokens`，驗證獨立編譯通過

## 3. 搬遷 Glass 元件至 Features 套件

- [ ] 3.1 在 `Features/Sources/Features/` 下建立 `Components/` 目錄
- [ ] 3.2 將 `NeuLedger/GlassCard.swift` 搬移至 `Features/Sources/Features/Components/GlassCard.swift`
- [ ] 3.3 將 `NeuLedger/GlassHeader.swift` 搬移至 `Features/Sources/Features/Components/GlassHeader.swift`
- [ ] 3.4 將 `NeuLedger/GlassButton.swift` 搬移至 `Features/Sources/Features/Components/GlassButton.swift`
- [ ] 3.5 建立 `Features/Sources/Features/Components/GlassButtonStyle.swift`：實作 `ButtonStyle` 協議 + `.glass()` static extension
- [ ] 3.6 從 `NeuLedger/` 目錄中刪除已搬遷的三個原始 `.swift` 檔案

## 4. 更新 Features 套件依賴

- [ ] 4.1 在 `Features/Package.swift` 中新增 `DesignTokens` 本地套件依賴：`.package(path: "../DesignTokens")`
- [ ] 4.2 在 Features target 的 `dependencies` 中加入 `.product(name: "DesignTokens", package: "DesignTokens")`
- [ ] 4.3 在 Glass 元件原始檔中加入 `import DesignTokens`
- [ ] 4.4 確認 `GlassCard.swift` 中的 `Color.Design.background` 引用可正確解析
- [ ] 4.5 確認 `GlassHeader.swift` 中的 `Font.Design.title2`、`Font.Design.subheadline`、`Color.Design.textPrimary`、`Color.Design.textSecondary` 引用可正確解析
- [ ] 4.6 確認 `GlassButton.swift` 中的 `GlassButtonStyle` 引用可正確解析
- [ ] 4.7 切換 Scheme 至 `Features`，驗證獨立編譯通過

## 5. 更新 Xcode App Target 依賴

- [ ] 5.1 透過 Xcode UI 將 `DesignTokens` 本地套件加入 App Target 的 packageProductDependencies
- [ ] 5.2 確認 App Target 的 `packageProductDependencies` 包含 `Features` 和 `DesignTokens`
- [ ] 5.3 選擇 App Target Scheme，驗證完整 build 通過

## 6. 清理主 App Target

- [ ] 6.1 確認 `NeuLedger/NeuLedgerApp.swift` 為空殼（無 `@main`，無業務邏輯）
- [ ] 6.2 確認 `Assets.xcassets` 僅保留 `AppIcon` 和 `AccentColor`（可選擇移除 `incomeGreen`、`expenseRed`、`warningAmber` Color Set，因已用 Pure Code 取代）
- [ ] 6.3 確認 `Info.plist` 和 `NeuLedger.entitlements` 維持不動

## 7. 驗收與規格確認

- [ ] 7.1 驗證依賴方向：`DesignTokens` 無外部依賴 → `Features` 依賴 `DesignTokens` + TCA → App Target 依賴兩者
- [ ] 7.2 驗證 `DesignTokens` Scheme 可獨立編譯（聚焦編譯）
- [ ] 7.3 驗證 `Features` Scheme 可獨立編譯（聚焦編譯）
- [ ] 7.4 驗證 App Target 完整 build 通過
- [ ] 7.5 執行 `NeuLedgerTests` 和 `NeuLedgerUITests`，確認無回歸
