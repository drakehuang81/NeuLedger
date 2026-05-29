# 拆出 AccessoryBarFeature(從 MainTabFeature 解耦)

**日期:** 2026-05-29
**類型:** Refactor(行為不變,結構解耦)

## 動機

`AccessoryView` 目前直接吃整顆 `StoreOf<MainTabFeature>`,但實際只用到 AI 輸入列那一段 state/action。`MainTabFeature` 混了三組互不相干的職責:tab 殼、recurring 確認路由、accessory bar(AI 輸入)。把第三組抽成獨立 child reducer,讓 `AccessoryView` 只依賴自己的 feature,符合單一職責與既有的 TCA delegate pattern。

確認過:這些 accessory/AI action(`aiInputButtonTapped`、`contextActionTapped`、`accessoryModeSwitched`、`recordingTapped`、`aiInputSubmitted`、`aiInputDismissed`、`aiExtractionCompleted` 等)**只有 `AccessoryView` 在送**——切點乾淨。

## 架構

新增 child reducer `AccessoryBarFeature`,由 `MainTabFeature` 透過 `Scope(state:\.accessory, action:\.accessory)` 掛載。跨 tab 的副作用用 `delegate` 往上拋,由 parent 依 `selectedTab` 決定路由。

```
MainTabFeature (parent: tab 殼 + 可見性 + recurring + 路由)
 ├─ Scope dashboard / transactions / settings
 └─ Scope accessory → AccessoryBarFeature (AI 輸入 + accessoryMode + 可用性)
```

### State / 職責歸屬

**移到 `AccessoryBarFeature.State`:**
`isAIInputExpanded`、`aiInputText`、`isAIInputLoading`、`aiInputError`、`aiUnavailable`、`isRecording`、`accessoryMode`

**留在 `MainTabFeature.State`:**
`selectedTab`、`dashboard`/`transactions`/`settings`、`showAccessoryBar`、`pendingRecurringConfirmationId`,新增 `var accessory = AccessoryBarFeature.State()`。

**關鍵邊界:可見性留在 parent。** `isAccessoryVisible` 由 `showAccessoryBar` + `selectedTab` + child 的 `path.isEmpty` 計算得出,本質是 tab 殼職責,child 不該知道 tab 存在。`MainTabView` 仍讀 parent 的 `store.isAccessoryVisible` 當 `isEnabled`。

### Action / body 歸屬

**`AccessoryBarFeature.Action`:**
- 生命週期:`onAppear`(查 AI 可用性 + 載入並解析 `accessoryMode`)、`aiAvailabilityLoaded(isAvailable:)`、`accessoryModeLoaded(AccessoryMode)`、`accessoryModeSwitched(AccessoryMode)`
- AI 輸入:`aiInputButtonTapped`、`aiInputTextChanged`、`aiInputSubmitted`、`aiInputDismissed`、`aiExtractionCompleted(TaskResult<ExtractedTransaction>)`
- 錄音:`recordingTapped`、`recordingStarted`、`permissionDenied`、`transcriptionUpdated`、`transcriptionFailed`
- 觸發點:`contextActionTapped`(`.add` 模式點擊)
- `delegate(Delegate)`,`@CasePathable enum Delegate { case contextActionRequested, transactionExtracted(ExtractedTransaction) }`
- Dependencies:`aiUseCase`、`speechAdapter`、`userSettingsRepository`;CancelID:`aiExtraction`、`speechRecording`

行為對應:
- `aiExtractionCompleted(.success)` → 重設輸入 state,然後 `.send(.delegate(.transactionExtracted(extracted)))`(不改 tab)
- `contextActionTapped` → `.send(.delegate(.contextActionRequested))`

**`MainTabFeature` 保留 / 變更:**
- `.task`:仍負責編排——載入 `showAccessoryBar`(parent 自己的 `accessoryBarVisibilityLoaded`)、訂閱 recurring 通知、並 `.send(.accessory(.onAppear))` 觸發 child 載入(因 accessory 可能隱藏,放 parent 觸發以保證啟動時必跑一次,維持現有行為)
- `.accessory(.delegate(.contextActionRequested))` → 依 `selectedTab` 派 `.transactions(.contextActionTapped)` 或 `.dashboard(.addTransactionButtonTapped)`
- `.accessory(.delegate(.transactionExtracted(extracted)))` → 依 `selectedTab` 派對應 child 的 `.addTransactionWithPrefilledData(extracted)`
- `.settings(.delegate(.accessoryBarVisibilityChanged))` → 仍設 `state.showAccessoryBar`
- recurring 全套不動

### View 變更

- `AccessoryView`:`store: StoreOf<MainTabFeature>` → `StoreOf<AccessoryBarFeature>`;內部 `store.send`/讀取對應到 child action(名稱不變);`#Preview` 改用 `AccessoryBarFeature`
- `MainTabView`:`AccessoryView(store: store.scope(state: \.accessory, action: \.accessory))`,`isEnabled`/條件仍用 parent 的 `store.isAccessoryVisible`

## 測試計畫(TDD)

拆分 `MainTabFeatureTests.swift`:
- **新增 `AccessoryBarFeatureTests.swift`**:`onAppear` 可用性、`aiInputButtonTapped`、`aiInputDismissed`(含停止錄音)、`aiExtractionCompleted` 成功(斷言 state 重設 + 發出 `.delegate(.transactionExtracted)`)/ 失敗、`accessoryModeLoaded`(available/unavailable)、`accessoryModeSwitched`(持久化)、錄音全套(start/stop/denied、transcription updated/failed、submit-while-recording)
- **`MainTabFeatureTests.swift` 保留**:recurring 確認、`.task` 編排(載 `showAccessoryBar` + 轉發 `accessory.onAppear`)、delegate 路由(`contextActionRequested` → tab+child action;`transactionExtracted` → 對應 child action)

先寫(或搬移後調整)測試使其失敗 → 實作 → 綠燈。

## 不在範圍

- 不動 recurring、tab 切換、settings 邏輯
- 不改 AI/錄音的實際行為,只搬位置 + 改用 delegate 路由
- 不動 `AccessoryMode` enum、`UserSettingsRepository`、`aiUseCase`/`speechAdapter` 介面
