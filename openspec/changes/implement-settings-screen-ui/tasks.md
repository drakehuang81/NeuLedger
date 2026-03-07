## 1. Domain 層準備

- [ ] 1.1 在 `Features/Sources/Domain/Clients/UserSettingsClient.swift` 的 `Bool` extension 新增 `SettingsKey<Bool>.aiEnabled`（rawValue: `"aiEnabled"`, defaultValue: `true`）

## 2. SettingsFeature Reducer

- [ ] 2.1 建立目錄 `Features/Sources/Features/Settings/`
- [ ] 2.2 建立 `SettingsFeature.swift`，定義 `@ObservableState State`，包含 `isAIEnabled: Bool`、`defaultAccountName: String`
- [ ] 2.3 定義 `Action`：`task`、`aiToggleChanged(Bool)`、`accountsLoaded([Account])`、`navigateToAccounts`、`navigateToCategories`、`navigateToBudgets`、`navigateToTags`、`exportCSVTapped`、`exportJSONTapped`、`privacyPolicyTapped` 及 `delegate(Delegate)` enum
- [ ] 2.4 實作 `.task` Effect：並發讀取 `userSettingsClient.bool(.aiEnabled)` 和 `accountClient.fetchActive()`，更新 State
- [ ] 2.5 實作 `aiToggleChanged` handler：呼叫 `userSettingsClient.setBool` 並更新 `state.isAIEnabled`
- [ ] 2.6 管理列 Actions（navigateTo*）送出對應 `delegate` Action
- [ ] 2.7 匯出 / 隱私 Actions 暫時回傳 `.none`（加上 `print` log）
- [ ] 2.8 注入 `@Dependency(\.userSettingsClient)`、`@Dependency(\.accountClient)`

## 3. SettingsView UI

- [ ] 3.1 建立 `SettingsView.swift`，接收 `StoreOf<SettingsFeature>`
- [ ] 3.2 實作 `ScrollView` + `VStack(spacing: 24)` 骨架，整體 padding `top: 60, horizontal: 20, bottom: 100`（100 確保內容不被 TabBar 遮蓋）
- [ ] 3.3 建立可複用的私有 `SettingsRow` view helper：`HStack(justifyContent: .spaceBetween)`, padding `v:14 h:16`，左側 `HStack(spacing: 12)` 含 icon + label，右側接受 trailing content
- [ ] 3.4 實作**管理分區**：section 標題 + Glass 卡片容器（`VStack(spacing: 0)` + `.glassEffect()` + `RoundedRectangle(cornerRadius: 16)`），四個導航列（`wallet.bifold`、`square.grid.2x2`、`banknote`、`tag`）各附 `chevron.right`
- [ ] 3.5 實作**偏好設定分區**：三列（`creditcard` 預設帳戶顯示 `store.defaultAccountName`、`globe` 語言靜態「繁體中文」、`sparkles` AI Toggle 綁定 `store.isAIEnabled` 並 `.tint(Color.Design.incomeGreen)`）
- [ ] 3.6 實作**資料分區**：兩列（`square.and.arrow.down` 匯出 CSV、`tablecells` 匯出 JSON）各附 `chevron.right`
- [ ] 3.7 實作**關於分區**：版本列（`info.circle`，右側顯示 `Bundle.main.infoDictionary["CFBundleShortVersionString"] ?? "—"`）、隱私權政策列（`doc.text`，附 `chevron.right`）
- [ ] 3.8 各 section 的圖示套用 `.symbolRenderingMode(.hierarchical)`，尺寸 22×22；chevron 尺寸 20×20，色 `Color.Design.textTertiary`
- [ ] 3.9 連結各列點擊 Action 至 store（`Button` 或 `.onTapGesture`）
- [ ] 3.10 加上 `.task { await store.send(.task).finish() }` 啟動資料載入

## 4. MainTab 整合

- [ ] 4.1 在 `MainTabFeature.swift` 的 `State` 新增 `var settings = SettingsFeature.State()`
- [ ] 4.2 在 `MainTabFeature.Action` 新增 `case settings(SettingsFeature.Action)`
- [ ] 4.3 在 `body` 的 `Scope` 區塊新增 `Scope(state: \.settings, action: \.settings) { SettingsFeature() }`
- [ ] 4.4 在 `Reduce` 的 switch 加入 `case .settings(.delegate(.navigateToAccounts)):` 等 delegate 處理（暫時 `.none`）
- [ ] 4.5 在 `MainTabView.swift` 將 Settings Tab 從 `PlaceholderView` 換成 `SettingsView(store: store.scope(state: \.settings, action: \.settings))`

## 5. Build 驗證

- [ ] 5.1 執行 `xcodebuild build` 確認無編譯錯誤
- [ ] 5.2 在模擬器手動切換至設定 Tab，確認四個分區完整渲染
- [ ] 5.3 切換 AI 智慧功能 Toggle，kill & relaunch App 確認 Toggle 狀態持久化
- [ ] 5.4 確認大標題、section 標題、row 文字字型和顏色符合設計稿
