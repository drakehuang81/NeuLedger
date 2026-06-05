# Client Layer Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Ultracode 編排模式**：本計畫設計為「步驟間序列、步驟內並行」。每個步驟是一個序列 gate（完整 test scheme 全綠才進下一步）；步驟內的「切換階段」可按 §B 檔案所有權分組 fan-out 並行 agent。每個 agent prompt 必須包含：①只能修改的檔案清單 ②目的地合約（§A 對應段）③驗證指令（§C）④越界編譯錯誤回報 `BLOCKED` 不自行修復。

**Goal:** 把 12 個 UseCase + 8 個 Repository 整併為 6 個領域 Client（UseCase == Client），溶解 Repository 層，Feature 端只准注入 Client。

**Architecture:** 依 `docs/superpowers/specs/2026-06-04-client-layer-consolidation-design.md`。擴張–收縮：每步驟新 Client 先就位 → Feature 注入點逐檔切換 → 刪舊檔，每 commit 全綠可獨立合入。

**Tech Stack:** Swift 6 / TCA 1.23.1（`@DependencyClient`）/ SwiftData（經 `SwiftDataStore<Domain, SD>`）/ Swift Testing / xcodebuild

**計畫哲學（為何沒有凍結 diff）：** 本計畫「合約完整、diff 輕量」。§A 合約與 §B 盤點是穩定的目的地；各步驟的實作 diff 由執行 agent 基於當時真實程式碼派生（舊 Live 的實作邏輯**搬運為主、重寫為輔**）。

---

## 進度狀態（2026-06-04 更新）

- [x] 步驟 0：`UserSettingsRepository` → `UserSettingsAdapter` 機械改名 — `af94202`
- [x] 步驟 1：Carrier 試點 — 1a `8addc18` / 1b `b24e5a6` / 1c `19053b2` / 1d `aa7ca8f`，完整 scheme 每 commit 全綠
- [x] 步驟 2：Planning — 2a `5f02332` / 2b `ec0a060` / 2c `0e59bb4`，全綠。偵察驅動 fan-out 模式驗證成功（額外呼叫端：WatchContextBuilder、AnalyticsUseCase+Live、NotificationSettings 預算警告偏好）。行為微調：evaluate/currentStatus 的交易讀取改 fetchAll + inline 過濾（語意等價）。已知 flaky（與本 refactor 無關，留待專項）：SyncSettingsFeatureTests 兩條 enableSync 測試建議補顯式 timeout
- [x] 步驟 3：AI 拆分 — 3a `3c3992e`+`ce34854` / 3b `37254ee`（含 MainTabFeatureTests scope 組合修復）/ 3c `6e0f1a6`，全綠 580 passed。CaptureClient 整檔包 `#if canImport(FoundationModels)`（簽名引用 ExtractedTransaction）；SyncSettings flaky 已加寬限 timeout 治理
- [x] 步驟 4：Platform — 4a `ec7cf44` / 4b `f494a18` / 4c `6c22427`，**新基準 603 passed / 0 failed**。RouteLinkDestination 搬至 `Domain/ValueObjects/`（AccessoryMode/ReminderTime 本就在獨立檔）；OnboardingUseCase 確認零呼叫端直接刪除；`Application/` 只剩 Ledger/Planning/Insights/Capture/Carrier/Platform 六個 context 資料夾
- [x] 步驟 5：Ledger — 5a1 `46af411` / 5a2 `3036e9c` / 5a3 `cbc811a` / 5b `8e3260a`+fix `9250580` / 5d `0a0c46a` / 5c-pre `2060db8` / 5c `4df1889`（33 檔退役）。最終 gate：iOS 全綠 + Watch 建置綠。`Domain/UseCases`、`Domain/Repositories`、`Core/Repositories`、`Application/Misc` 資料夾消失

### 步驟 5 教訓補錄（8–12）

8. **大型 agent 的 StructuredOutput 陣亡**是 context 耗盡的症狀：5a1（35 方法介面）與 5a3-verify 都死於此。對策已驗證有效：編輯/驗證 agent 分離 + context 紀律（grep 行號再讀區段、輸出 tail、修復限兩輪）。
9. **驗證 agent 禁用萬用字元讀 log**：5b 驗證 agent 用 `tail /tmp/verify_*.log` glob 讀到舊綠 log 假放行，54 行 keypath 回歸混進 commit。驗證 log 一律唯一檔名、只讀自己的。
10. **Scope parent 陷阱三度發作**：MainTab→AccessoryBar（步驟 3）、NotificationSettings→RecurringManagement（5b）、MainTab→Dashboard prefill（5c-pre）。切 child 依賴前必 grep「誰 Scope 了它」。
11. **模擬器衰竭**：一日多輪測試累積 805 個 CoreSimulator 進程，引發系統性 flake（假超時、ipc/mig 死亡、suite 假死 20 分鐘）。長 session 定期 `xcrun simctl --set testing delete all`。
13. **`test-without-building` 的假綠模式**：build 失敗時它不會跟著失敗，而是拿上一次成功建置的舊產物跑測試（舊碼全綠）。驗證鏈必須把測試步驟用 `&&` 鎖在 build 成功之後，且以 BUILD_OK sentinel 齊全為綠燈判準，不能只看測試 exit code。
12. **Subagent 不可把驗證丟背景就交棒**：背景任務生命週期綁定 agent，提前結束 = 驗證夭折。prompt 必須明令「等驗證完成才回報」。

**5 期行為微調紀錄**：①setupAccounts 不再寫 onboarding 旗標（雙寫入點解除）②鏡像推送 post-condition 顯式化 ③recurring 通知排程上收 ④exportCSV 寫入唯一子目錄（檔名不變）⑤Watch record 保留交易日期（原 Date() 預設）⑥**待裁定**：WatchSessionDelegate 入站記帳仍直寫 store（沿用原行為），是否應改走 ledgerClient.record 吃完整 invariant 鏈（預算警告+鏡像）留收網後與使用者討論
- [x] 步驟 6：收網 — 6A `2ce25d1`（watch 偏好歸 Platform）/ 6B `19335b7`（PersistenceBootstrap 改名）/ 文件三件套回寫。**最終 DoD 達成：Feature 層 adapter-free，注入面 = 6 Client + TCA 內建；全樹 DatabaseClient/UseCase/Repository 殘留歸零**

### 1e 食譜回顧（Carrier 試點教訓，步驟 2–5 必讀）

1. **驗證指令 pipe-masking bug（已修，見 §C）**：`xcodebuild ... | tail -40; echo "EXIT:$?"` 的 `$?` 取到的是 tail 的退出碼，會產生假綠燈。正確作法：xcodebuild 輸出導到 log 檔、`echo "EXIT:$?" >> log` 緊跟在 xcodebuild 之後，再 tail log 判讀。
2. **`@DependencyClient` 預設值 ≠ testValue stub**：介面宣告 `= { nil }` 只是 production fallback，testValue 仍是 unimplemented stub。切換 Feature 注入後，凡 reducer 路徑會碰到的 closure，測試的 `withDependencies` 都必須補 stub（1c 在 SettingsFeatureTests 補了 3 處 `activeForWidget`）。步驟 5 切 17 個 Feature 檔時這是最大雷區。
3. **Agent 中斷會留下 staged index**：workflow agent 失敗時可能留下 staged 變更；任何 commit 前必先 `git status` 確認 index 只含自己要的東西。
4. **Subagent 必須以 StructuredOutput 結尾 + xcodebuild 輸出必 tail 限縮**——否則長輸出撐爆 context 後 agent 無法回報，整條 workflow 失敗。
5. **上收 post-condition 時的語意微調要逐條記錄**（見下「行為微調」）。CoreTests 並非每個 repo 都有測試檔——以現場 grep 為準，別信計畫裡的檔案清單。
6. **TCA `Scope` 組合的 parent 測試是切換盲區**（步驟 3 教訓）：切 Feature X 的注入時，凡以 `Scope` 掛載 X 的 parent feature 測試也會走到 X 的新依賴（MainTabFeatureTests 因 AccessoryBar 切 captureClient 而紅）。切換前先 grep「誰 Scope 了這個 feature」，把 parent 測試檔納入允許清單。**步驟 5（17 檔）執行前必做此盤點**。
7. **環境級 flaky 的放行政策**（已實施）：完整 scheme 若有 ≤2 個失敗且伴隨 simulator IPC 噪音（`ipc/mig server died`），對失敗 suite 單獨 `-only-testing` 重跑；單跑綠即視為環境 flaky，記錄後放行。SyncSettingsFeatureTests 已加 `timeout: .seconds(5)` 寬限治理。

**1c 行為微調紀錄**（上收 widget reload 進 CarrierClient Live 的連帶）：
- read（`.task` 載入）不再觸發 widget reload（原 Feature 載入時手動 syncAllCarriers）——mutation 才 reload
- 刪除 active 載具：原行為「清空 widget」→ 新行為「重新指向第一個剩餘載具」（**已裁定 2026-06-04：保留新行為**。通則：上收 post-condition 遇語意分岔時允許合理微調，但必須逐條記錄於本區並於回報中標明，由使用者最終裁定）
- 編輯後的單筆 syncCarrier → Live 統一 syncAllCarriers（語意等價偏廣）

---

## §A 目的地合約（穩定——方法名稱/參數/回傳型別不得擅改；closure default 值可依 `@DependencyClient` macro 需求調整）

所有簽名以**現有程式碼實際簽名**為準推導（非 architecture.md 舊目錄）。每個 Client：介面檔在 `Domain/Clients/XxxClient.swift`（含 `DependencyValues` 註冊 + `testValue = Self()`），Live 在 `Application/<Context>/XxxClient+Live.swift`（conform `DependencyKey`）。

### A.1 `CarrierClient`（步驟 1）

```swift
@DependencyClient
public struct CarrierClient: Sendable {
    public var listAll: @Sendable () async throws -> [Carrier]
    public var create: @Sendable (_ carrier: Carrier) async throws -> Void
    public var update: @Sendable (_ carrier: Carrier) async throws -> Void
    public var delete: @Sendable (_ id: Carrier.ID) async throws -> Void
    public var setActiveForWidget: @Sendable (_ id: Carrier.ID) async -> Void
    public var activeForWidget: @Sendable () -> Carrier.ID? = { nil }
}
// keypath: \.carrierClient
```

**Live 組裝**：`SwiftDataStore<Carrier, SDCarrier>` + `userSettingsAdapter`（activeForWidget 設定）+ `widgetSyncAdapter`。
**內部 post-condition**：`create`/`update`/`delete`/`setActiveForWidget` 後 reload carrier widget（現由 CarrierManagementFeature 手動呼叫 `widgetSyncAdapter`——上收為 Client 內部不變量）。

### A.2 `PlanningClient`（步驟 2）

```swift
@DependencyClient
public struct PlanningClient: Sendable {
    public var listAll: @Sendable () async throws -> [Budget]
    public var listActive: @Sendable () async throws -> [Budget]
    public var create: @Sendable (_ budget: Budget) async throws -> Void
    public var update: @Sendable (_ budget: Budget) async throws -> Void
    public var delete: @Sendable (_ id: Budget.ID) async throws -> Void
    public var currentStatus: @Sendable (_ budget: Budget) async throws -> BudgetStatus
    /// INVARIANT 入口：由 LedgerClient.record/update 呼叫（§3.1）
    public var evaluateAfterTransaction: @Sendable (_ transaction: Transaction) async -> Void
    // 領域自有偏好（原 AppEnvironmentUseCase 持有）
    public var warningEnabled: @Sendable () -> Bool = { false }
    public var setWarningEnabled: @Sendable (_ enabled: Bool) -> Void
    public var warningThreshold: @Sendable () -> Int = { 80 }
    public var setWarningThreshold: @Sendable (_ percent: Int) -> Void
}
// keypath: \.planningClient
```

**Live 組裝**：`SwiftDataStore<Budget, SDBudget>` + `BudgetWarningPolicy` + `notificationAdapter`（sendBudgetWarning / lastWarnedPercent）+ `userSettingsAdapter`。
**注意**：`evaluateAfterTransaction` 需要讀交易聚合——現行 `BudgetUseCase+Live` 注入 transaction repo；溶解後改用 `SwiftDataStore<Transaction, SDTransaction>`（Application 層合法）。period bounds helper 隨實作搬入。

### A.3 `InsightsClient`（步驟 3）

```swift
@DependencyClient
public struct InsightsClient: Sendable {
    public var todayStats: @Sendable (_ referenceDate: Date) async throws -> StatsSnapshot = { _ in .zero }
    public var weeklySparkline: @Sendable (_ accountId: Account.ID?) async throws -> [Decimal] = { _ in Array(repeating: 0, count: 7) }
    public var dailyBars: @Sendable (_ range: DateInterval) async throws -> [DailyTrend] = { _ in [] }
    public var categoryProportions: @Sendable (_ range: DateInterval) async throws -> [CategoryProportion] = { _ in [] }
    public var budgetGauges: @Sendable (_ accountId: Account.ID?) async throws -> [BudgetGaugeMetrics] = { _ in [] }
    public var detailStats: @Sendable (_ transaction: Transaction) async throws -> TransactionInsight
    public var generateAIInsight: @Sendable (_ summary: SpendingSummary) async throws -> String
    public var generateInsights: @Sendable (_ summary: SpendingSummary) async throws -> [InsightData] = { _ in [] }
    /// 「用自然語言讀帳本」——自 AIUseCase 搬入（含 QueryTransactionsTool）
    public var answerFinancialQuestion: @Sendable (_ question: String) async throws -> String
    /// 洞察類 AI 功能可用性（AIAssistant/Analysis/Dashboard 的顯示判斷）
    public var isAIAvailable: @Sendable () -> Bool = { false }
}
// keypath: \.insightsClient
```

**步驟 3 前偵察情報（2026-06-04）**：
- `AnalyticsUseCase` 是幽靈——Feature 端零注入；Dashboard 的 stats 全走 `transactionClient.weeklySpending(id, 7)`×6 / `statsSnapshot()`×1，切換映射：→ `insightsClient.weeklySparkline(id)` / `todayStats(now)`（Dashboard 已注入 `\.date.now`）
- `generateInsight`（單數）呼叫端：AnalysisFeature、DashboardFeature → 映射到 `generateAIInsight`（簽名相同）；`generateInsights`（複數）：DashboardFeature → 原樣
- `isAvailable` 呼叫端按領域分流：AIAssistant（含 `AIAssistantCardView`）/Analysis/Dashboard → `insightsClient.isAIAvailable`；AddTransaction/AccessoryBar → `captureClient.isAvailable`
- `TransactionDetailView` 的 PreviewFixtures 也覆寫 `detailStats`，切換時別漏

**Live 組裝**：`TransactionAnalyticsKernel` + `AIAdapter` + `InsightCache`（檔案搬至 `Application/Insights/`）。
**去重裁定**：`AIUseCase.generateInsight`（單數，SpendingSummary→String）與 `AnalyticsUseCase.generateAIInsight` 是重複入口——合約只保留 `generateAIInsight`，執行時確認兩者呼叫端後統一。

### A.4 `CaptureClient`（步驟 3）

```swift
@DependencyClient
public struct CaptureClient: Sendable {
    public var extractFromText: @Sendable (_ text: String) async throws -> ExtractedTransaction
    public var extractFromVoice: @Sendable (_ transcript: String) async throws -> ExtractedTransaction
    public var suggestCategories: @Sendable (_ text: String, _ existing: [String]) async throws -> CategorySuggestions
    public var isAvailable: @Sendable () -> Bool = { false }
    // 語音 session 包裝（Feature 不再直接注入 speechAdapter）
    public var requestVoicePermission: @Sendable () async -> Bool = { false }
    public var startVoiceSession: @Sendable () -> AsyncThrowingStream<String, Error> = { .finished() }
    public var stopVoiceSession: @Sendable () -> Void = { }
}
// keypath: \.captureClient
```

**Live 組裝**：`AIAdapter` + `speechAdapter`（voice session 三方法是 1:1 轉發——這是「Feature 不准碰 Adapter」規則的代價，接受）。

### A.5 `PlatformClient`（步驟 4）

```swift
@DependencyClient
public struct PlatformClient: Sendable {
    // MARK: - Preferences（無主設定）
    public var accessoryMode: @Sendable () -> AccessoryMode = { .add }
    public var setAccessoryMode: @Sendable (_ mode: AccessoryMode) -> Void
    public var reminderTime: @Sendable () -> ReminderTime = { ReminderTime(hour: 21, minute: 0) }
    public var setReminderTime: @Sendable (_ time: ReminderTime) -> Void
    public var dailyReminderEnabled: @Sendable () -> Bool = { false }
    public var setDailyReminderEnabled: @Sendable (_ enabled: Bool) -> Void
    public var hasCompletedOnboarding: @Sendable () -> Bool = { false }
    public var markOnboardingComplete: @Sendable () -> Void
    public var showAccessoryBar: @Sendable () -> Bool = { true }
    public var setShowAccessoryBar: @Sendable (_ visible: Bool) -> Void
    // MARK: - Notification
    public var requestNotificationPermission: @Sendable () async -> Bool = { false }
    public var notificationsAuthorized: @Sendable () async -> Bool = { false }
    public var scheduleDailyReminder: @Sendable () async throws -> Void
    public var cancelDailyReminder: @Sendable () async -> Void
    /// AppFeature 入站通知路由訂閱（不再直接注入 notificationAdapter）
    public var pendingRecurringConfirmations: @Sendable () -> AsyncStream<RecurringTransaction.ID> = { .finished }
    // MARK: - Sync（原 CloudSyncUseCase）
    public var syncAvailable: @Sendable () -> Bool = { false }
    public var syncEnabled: @Sendable () -> Bool = { false }
    public var lastSyncedAt: @Sendable () -> Date? = { nil }
    public var enableSync: @Sendable () -> AsyncThrowingStream<Double, Error> = { .finished() }
    public var requestSyncNow: @Sendable () async throws -> Void = {}
    public var wipeAllSyncData: @Sendable () async throws -> Void = {}
    // MARK: - Routing（原 DeeplinkClient）
    public var parseLink: @Sendable (URL) async throws -> RouteLinkDestination
    public var canSkipOnboarding: @Sendable () async throws -> Bool
    public var resolveRecurringConfirmation: @Sendable (_ id: RecurringTransaction.ID) async throws -> RouteLinkDestination
    // MARK: - System
    public var openAppSettings: @Sendable () -> Void
}
// keypath: \.platformClient
```

**Live 組裝**：`userSettingsAdapter` + `notificationAdapter` + `cloudKitSyncAdapter` + 系統包裝。
**搬出項**（不進 Platform）：`defaultAccountId`/`setDefaultAccountId` → Ledger（A.6）；`budgetWarningEnabled`/`Threshold` → Planning（A.2）。
**Routing 解析**現行注入 recurring repo——溶解後改用 `SwiftDataStore<RecurringTransaction, SDRecurringTransaction>`。

### A.6 `LedgerClient`（步驟 5）

```swift
@DependencyClient
public struct LedgerClient: Sendable {
    // MARK: - Transactions
    public var record: @Sendable (_ transaction: Transaction) async throws -> Void
    public var update: @Sendable (_ transaction: Transaction) async throws -> Void
    public var delete: @Sendable (_ id: Transaction.ID) async throws -> Void
    public var fetch: @Sendable (_ id: Transaction.ID) async throws -> EnrichedTransaction?
    public var listRecent: @Sendable (_ limit: Int) async throws -> [EnrichedTransaction] = { _ in [] }
    public var listAll: @Sendable (_ filter: TransactionFilter) async throws -> [EnrichedTransaction] = { _ in [] }
    public var search: @Sendable (_ query: String) async throws -> [EnrichedTransaction] = { _ in [] }
    // MARK: - Accounts
    public var setupAccounts: @Sendable (_ accounts: [Account]) async throws -> Void
    public var createAccount: @Sendable (_ account: Account) async throws -> Void
    public var updateAccount: @Sendable (_ account: Account) async throws -> Void
    public var archiveAccount: @Sendable (_ id: Account.ID) async throws -> Void
    public var unarchiveAccount: @Sendable (_ id: Account.ID) async throws -> Void
    public var deleteAccount: @Sendable (_ id: Account.ID) async throws -> Void
    public var listAccounts: @Sendable () async throws -> [Account]
    public var listActiveAccounts: @Sendable () async throws -> [Account]
    public var balance: @Sendable (_ id: Account.ID) async throws -> Decimal
    public var balances: @Sendable () async throws -> [Account.ID: Decimal]
    public var defaultAccountId: @Sendable () -> Account.ID? = { nil }
    public var setDefaultAccountId: @Sendable (_ id: Account.ID?) -> Void
    // MARK: - Catalog
    public var listCategories: @Sendable (_ type: TransactionType?) async throws -> [Category] = { _ in [] }
    public var createCategory: @Sendable (_ category: Category) async throws -> Void
    public var updateCategory: @Sendable (_ category: Category) async throws -> Void
    public var deleteCategory: @Sendable (_ id: Category.ID) async throws -> Void
    public var listTags: @Sendable () async throws -> [Tag]
    public var createTag: @Sendable (_ tag: Tag) async throws -> Void
    public var updateTag: @Sendable (_ tag: Tag) async throws -> Void
    public var deleteTag: @Sendable (_ id: Tag.ID) async throws -> Void
    // MARK: - Recurring（自動記帳）
    public var listRecurring: @Sendable () async throws -> [RecurringTransaction]
    public var createRecurring: @Sendable (_ template: RecurringTransaction) async throws -> Void
    public var updateRecurring: @Sendable (_ template: RecurringTransaction) async throws -> Void
    public var deleteRecurring: @Sendable (_ id: RecurringTransaction.ID) async throws -> Void
    public var tick: @Sendable () async throws -> Void
    // MARK: - Export
    public var exportCSV: @Sendable () async throws -> URL
}
// keypath: \.ledgerClient
```

**Live 組裝**：`SwiftDataStore`×5（Transaction/Account/Category/Tag/RecurringTransaction）+ `planningClient`（§3.1 INVARIANT）+ `widgetSyncAdapter` + `watchBridgeAdapter` + `notificationAdapter`（recurring reminder）+ `userSettingsAdapter`（defaultAccountId）。Live 檔可拆：`+Live.swift`（組裝 + Transactions）、`+LiveAccounts.swift`、`+LiveCatalog.swift`、`+LiveRecurring.swift`、`+LiveExport.swift`。

**內部不變量**（附 `// INVARIANT:` 註解 + 測試）：
1. `record`/`update` → `planningClient.evaluateAfterTransaction`（§3.1，現有行為）
2. `record`/`update`/`delete` → Widget/Watch 鏡像推送（**新行為，需新測試**）
3. `tick()` → 內部 `record`（原 SAGA 內部化）
4. `createRecurring`/`updateRecurring`/`deleteRecurring` → `scheduleRecurringReminder`/`cancelRecurringReminder`（現由 4 個 Feature 呼叫端手動做——上收）
5. 領域規則照舊：有交易帳戶只能 archive；`isDefault` 分類不可刪；刪 Tag 解除交易關聯（在 Mapper/`prepareForDelete` 與 Live guard 中已存在，搬運勿失）

**死亡名單**：`TransactionClient.weeklySpending`/`statsSnapshot`/`detailStats`（kernel pass-through）不進 Ledger 合約——呼叫端一律改 `insightsClient`。

**Live 漸進組裝策略（每 commit 全綠的機制）**：採「**先 delegate、再內化**」：
1. 擴張 commit 1：完整介面 + Live 全部 closure **先 delegate 既有 UseCase/repo Live**（`LedgerUseCase`/`AccountUseCase`/`MetadataUseCase`/`RecurringUseCase`/`ExportUseCase` 此時還活著）——編譯綠、行為零變
2. 後續 commit 逐分區內化：Transactions → Accounts → Catalog → Recurring → Export，各分區改為 `SwiftDataStore` 直用 + 上收 post-condition（鏡像推送、recurring 通知排程在對應分區內化時加入，連同新測試）
3. 全部內化後才進切換/收縮 phase

過渡期 LedgerClient → 舊 UseCase 的暫時依賴**不需** §3.1 註解（生命週期僅限擴張期，收縮時消滅）。

### A.7 `WatchLedgerClient`（步驟 5，watchOS target 專用）

> 原 §E 草案名 `WatchSnapshotClient`——盤點後發現 Watch 還有**寫入路徑**（`transactionClient.add` 經 WatchConnectivity gateway 轉送 iPhone），故更名為 `WatchLedgerClient`：手錶端的帳本視圖。

```swift
@DependencyClient
public struct WatchLedgerClient: Sendable {
    // 快照讀取（cache-backed，資料來自 iPhone 推送的 WatchCacheStore）
    public var activeAccounts: @Sendable () async throws -> [Account]
    public var categories: @Sendable (_ type: TransactionType) async throws -> [Category]
    // 轉送記帳（經 WatchSessionGateway 送回 iPhone，非本地寫入）
    public var record: @Sendable (_ transaction: Transaction) async throws -> Void
}
// keypath: \.watchLedgerClient（只在 WatchFeatures target 註冊 live）
```

**Live 組裝**：搬運自 `WatchFeatures/Clients/` 現行三個 `.watchLive` extension（`WatchAccountClient`/`WatchCategoryClient`/`WatchTransactionClient`），`WatchDependencies.register` 改註冊單一 client。`WatchRecordFeature` 三個呼叫點對應：`accountClient.fetchActive→activeAccounts`、`categoryClient.fetchByType→categories`、`transactionClient.add→record`。

---

## §B 注入點盤點（2026-06-04 現況，57 處）

切換規則：每檔一個 agent、檔案不重疊；對應 FeaturesTests 的 `withDependencies` 覆寫**同 agent 同 commit 一起改**。「方法級對照」由 agent 依 §A 合約 + 現場程式碼派生。

| Feature 檔（`Features/Sources/Features/`） | 現注入 | 換成 | 步驟 |
|---|---|---|---|
| `CarrierManagement/CarrierManagementFeature` | carrierClient, userSettingsRepository, widgetSyncAdapter | carrierClient（widget reload 與 active 設定上收進 Client） | 1 |
| `CarrierManagement/AddEditCarrierFeature` | carrierClient | carrierClient | 1 |
| `Settings/SettingsFeature`（carrier 部分） | carrierClient | carrierClient | 1 |
| `BudgetManagement/BudgetManagementFeature` | budgetClient | planningClient | 2 |
| `BudgetManagement/BudgetFormFeature` | budgetClient, categoryClient | planningClient（categoryClient 留待步驟 5 → ledgerClient） | 2（部分）+5 |
| `Analysis/AnalysisFeature`（budget 部分） | budgetClient | planningClient | 2（部分） |
| `Analysis/AIAssistant/AIAssistantFeature` | aiUseCase | insightsClient（answerFinancialQuestion） | 3 |
| `Analysis/AnalysisFeature`（AI/圖表部分） | aiUseCase, transactionClient | insightsClient | 3（部分） |
| `Dashboard/DashboardFeature`（stats/AI 部分） | aiUseCase, transactionClient（stats） | insightsClient | 3（部分） |
| `MainTab/AccessoryBarFeature` | aiUseCase, speechAdapter, userSettingsRepository | captureClient + platformClient（accessoryMode） | 3+4 |
| `Dashboard/AddTransactionFeature`（AI/語音部分） | aiUseCase, speechAdapter | captureClient | 3（部分） |
| `Transactions/TransactionDetailFeature`（insight 部分） | transactionClient.detailStats | insightsClient.detailStats | 3（部分） |
| `AppFeature` | deeplinkClient, notificationAdapter | platformClient | 4 |
| `NotificationSettings/NotificationSettingsFeature` | notificationAdapter, userSettingsRepository | platformClient | 4 |
| `Settings/SyncSettings/SyncSettingsFeature` | cloudSyncUseCase, userSettingsRepository | platformClient | 4 |
| `Settings/SettingsFeature`（sync/偏好部分） | cloudSyncUseCase, userSettingsRepository, widgetSyncAdapter | platformClient | 4（部分） |
| `MainTab/MainTabFeature` | userSettingsRepository, notificationAdapter, recurringTransactionClient | platformClient + ledgerClient（recurring reschedule） | 4+5 |
| `Onboarding/OnboardingFeature` | accountClient | ledgerClient.setupAccounts + platformClient.markOnboardingComplete | 4+5 |
| `AccountManagement/AccountManagementFeature` | accountClient, transactionClient | ledgerClient | 5 |
| `AccountManagement/AddEditAccountFeature` | accountClient | ledgerClient | 5 |
| `Analysis/AnalysisFeature`（清單部分） | accountClient, categoryClient | ledgerClient | 5（部分） |
| `Dashboard/DashboardFeature`（清單部分） | accountClient, categoryClient, transactionClient（recent）, userSettingsRepository | ledgerClient | 5（部分） |
| `Dashboard/AddTransactionFeature`（記帳部分） | accountClient, categoryClient, transactionClient, ledger, recurringTransactionClient, notificationAdapter, userSettingsRepository | ledgerClient（含 recurring 通知上收、defaultAccountId） | 5（部分） |
| `CategoryManagement/CategoryManagementFeature` | categoryClient | ledgerClient | 5 |
| `CategoryManagement/AddEditCategoryFeature` | categoryClient | ledgerClient | 5 |
| `TagManagement/TagManagementFeature` | tagClient | ledgerClient | 5 |
| `TagManagement/AddEditTagFeature` | tagClient | ledgerClient | 5 |
| `RecurringTransactions/RecurringTransactionManagementFeature` | recurringTransactionClient, notificationAdapter | ledgerClient | 5 |
| `RecurringTransactions/RecurringTransactionFormFeature` | recurringTransactionClient, accountClient, categoryClient, notificationAdapter | ledgerClient | 5 |
| `Transactions/TransactionsFeature` | transactionClient, ledger | ledgerClient | 5 |
| `Transactions/TransactionDetailFeature`（CRUD 部分） | transactionClient, ledger, accountClient, categoryClient | ledgerClient | 5（部分） |
| `Transactions/FilterFeature` | categoryClient, accountClient, tagClient | ledgerClient | 5 |
| `Settings/SettingsFeature`（export/帳戶部分） | accountClient, transactionClient, categoryClient | ledgerClient（含 exportCSV） | 5（部分） |
| `Settings/Watch/WatchSettingsFeature` | accountClient, userSettingsRepository, watchBridgeAdapter | ledgerClient + platformClient（§E 裁定） | 5 |

**步驟 0 的 9 個 `userSettingsRepository` 檔**：上表所有含 userSettingsRepository 者在步驟 0 只做 keypath 機械改名（→ `userSettingsAdapter`），語意搬家在各自步驟才做。

**SPM package 內非 Feature 的呼叫端**（一併列管）：
- `Application/` 全部 Live（隨各步驟溶解）
- `Core/Adapters/Watch/WatchContextBuilder|WatchSyncObserver|WatchMidnightTimer`（注入 accountClient → §E）
- `Features/Sources/WatchFeatures/`（watchOS target，注入 accountClient/categoryClient + `.watchLive` 替代實作 → §E）

---

## §C 標準食譜（步驟 1–5 重複套用）

每個領域步驟 = 4 個 phase，各自至少一個 commit：

```
a. 擴張   新增 Domain/Clients/XxxClient.swift（§A 合約原文）
          + Application/<Context>/XxxClient+Live.swift（實作自舊 Live 搬運）
          + 新 Client Live 測試（搬運舊 UseCase/repo 測試，in-memory container）
b. 切換   §B 對應檔逐檔換 keypath + 同檔 FeaturesTests 覆寫更新
          【ultracode fan-out 點：每 agent 一組不重疊檔案】
c. 收縮   刪舊介面 + Live + DependencyValues 註冊；刪/搬舊測試
d. 驗證   完整 scheme + grep 驗無殘留
```

**驗證指令（每 commit 前必跑；1e 教訓修正版——EXIT 必須緊跟 xcodebuild，不可隔著 pipe）：**

```bash
LOG=/tmp/verify_$(date +%s).log
xcodebuild build-for-testing -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet > "$LOG" 2>&1 && echo BUILD_OK >> "$LOG"
xcodebuild test-without-building -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet >> "$LOG" 2>&1; echo "EXIT:$?" >> "$LOG"
tail -40 "$LOG"   # 判讀：BUILD_OK + EXIT:0 即綠；失敗時用 xcresulttool 取確切訊息
```

**殘留檢查（phase d）：**

```bash
# 該步驟舊型別名不得再出現（以 Carrier 為例）
grep -rn "CarrierUseCase\|carrierUseCase" Features/Sources NeuLedgerTests && echo "FAIL" || echo "CLEAN"
```

**Commit 訊息範式**（一律 `[ci skip]`）：
- `refactor(<context>): add <Xxx>Client interface + live [ci skip]`
- `refactor(<context>): switch <FeatureName> to <xxx>Client [ci skip]`
- `refactor(<context>): retire <old types> [ci skip]`

**Subagent 鐵則**（CLAUDE.md）：prompt 列明只能修改的檔案清單；清單外編譯錯誤回報 `BLOCKED`；驗證必含完整 scheme，不得只跑 `-only-testing:`。

---

## §D 步驟分解

### 步驟 0：`UserSettingsRepository` → `UserSettingsAdapter`（機械改名）

**Files:**
- Rename: `Features/Sources/Domain/Repositories/UserSettingsRepository.swift` → `Features/Sources/Domain/Adapters/UserSettingsAdapter.swift`
- Rename: `Features/Sources/Core/Repositories/UserSettingsRepository+Live.swift` → `Features/Sources/Core/Adapters/UserSettingsAdapter+Live.swift`
- Modify: 所有引用檔（型別名 `UserSettingsRepository`→`UserSettingsAdapter`、keypath `\.userSettingsRepository`→`\.userSettingsAdapter`）：9 個 Feature 檔（§B 表）、`Application/` 內引用的 Live、`NeuLedgerTests/Tests/CoreTests/Clients/UserSettingsRepositoryTests.swift`（→ `UserSettingsAdapterTests.swift`）、FeaturesTests 覆寫

- [x] **0.1 盤點引用**：`grep -rln "UserSettingsRepository\|userSettingsRepository" Features/Sources NeuLedgerTests` 取得完整清單（執行當下為準）
- [x] **0.2 git mv 兩檔 + 全域型別/keypath 改名**（沿用 Phase 2 機械改名流程；`SettingsKey` 結構與所有 persisted raw value **絕不動**）
- [x] **0.3 建置 + 完整測試**：基準 273+87+120 全綠
- [x] **0.4 Commit**：`refactor(platform): rename UserSettingsRepository to UserSettingsAdapter [ci skip]`

### 步驟 1：Carrier 試點

**特殊前置——撞名**：新 `CarrierClient`（Application）與現存 repo `CarrierClient`（Domain/Repositories）同名同 module，必須先讓位。

**Files:**
- 1a Rename: `Domain/Repositories/CarrierClient.swift` → `CarrierRepository.swift`（型別+keypath 同步改）、`Core/Repositories/CarrierClient+Live.swift` → `CarrierRepository+Live.swift`；引用端：`Application/Carrier/CarrierUseCase+Live.swift`、3 個 Feature 檔、CoreTests/DomainTests 的 CarrierClientTests
- 1b Create: `Domain/Clients/CarrierClient.swift`（§A.1 原文）、`Application/Carrier/CarrierClient+Live.swift`、Test `NeuLedgerTests/Tests/CoreTests/Clients/CarrierClientLiveTests.swift`
- 1c Modify: `CarrierManagement/CarrierManagementFeature.swift`、`CarrierManagement/AddEditCarrierFeature.swift`、`Settings/SettingsFeature.swift`（carrier 注入）+ 對應 `CarrierManagementFeatureTests`、`SettingsFeatureTests`
- 1d Delete: `Domain/UseCases/CarrierUseCase.swift`、`Application/Carrier/CarrierUseCase+Live.swift`、`Domain/Repositories/CarrierRepository.swift`、`Core/Repositories/CarrierRepository+Live.swift` + 舊測試（內容先搬運至 1b 測試）

- [x] **1a.1** repo 撞名讓位改名（機械），建置+完整測試，commit：`refactor(carrier): rename repo CarrierClient to CarrierRepository [ci skip]`
- [x] **1b.1** 寫 `CarrierClientLiveTests`（先紅燈：型別不存在）——案例搬運自現有 CarrierClientTests/CarrierUseCase 相關測試，加 2 個新案例：CRUD 後 widget reload 被呼叫（spy widgetSyncAdapter）、setActiveForWidget 寫入設定
- [x] **1b.2** 建 `Domain/Clients/CarrierClient.swift`（§A.1）+ `Application/Carrier/CarrierClient+Live.swift`（實作搬自 CarrierUseCase+Live 與 CarrierRepository+Live：`SwiftDataStore<Carrier, SDCarrier>` 直用）
- [x] **1b.3** 跑 1b.1 測試綠燈 + 完整 scheme 綠，commit：`refactor(carrier): add CarrierClient interface + live [ci skip]`
- [x] **1c.1** 三個 Feature 檔切換 keypath + 測試覆寫更新（widgetSyncAdapter/userSettings 手動呼叫碼一併移除——已上收）
- [x] **1c.2** 完整測試綠，commit：`refactor(carrier): switch features to CarrierClient [ci skip]`
- [x] **1d.1** 刪 4 個舊檔 + 舊測試，grep 殘留檢查 CLEAN，完整測試綠，commit：`refactor(carrier): retire CarrierUseCase + CarrierRepository [ci skip]`
- [x] **1e 食譜回顧**：把試點踩到的坑寫回本檔「進度狀態」區，修正後續步驟的食譜假設

### 步驟 2：Planning

按 §C 食譜 + §A.2 合約。範圍：`BudgetUseCase`（+Live）、`BudgetClient`（repo，+Live）→ `PlanningClient`；§B 表步驟 2 的 3 個 Feature 檔（BudgetForm 的 categoryClient 注入**保留**至步驟 5）。
特別注意：
- [ ] `evaluateAfterTransaction` 的呼叫端此時仍是 `LedgerUseCase+Live` ——切換它注入的 keypath（`\.budgetUseCase`→`\.planningClient`），§3.1 INVARIANT 註解保留
- [ ] 預算警告偏好自 `AppEnvironmentUseCase` 搬入（AppEnvironmentUseCase 對應方法此步驟即刪，呼叫端 SettingsFeature 改 `planningClient.warningEnabled` 等）
- [ ] `BudgetUseCaseEvaluateTests`（4 案例，actor spy）搬運為 `PlanningClientEvaluateTests`
- [ ] 收縮刪：`Domain/UseCases/BudgetUseCase.swift`、`Application/Planning/BudgetUseCase+Live.swift`、`Domain/Repositories/BudgetClient.swift`、`Core/Repositories/BudgetClient+Live.swift`（注意：`Application/Planning/RecurringUseCase+Live.swift` **不在**本步驟範圍，屬步驟 5）

### 步驟 3：AI 拆分（Insights + Capture）

按 §C 食譜 + §A.3/A.4 合約。範圍：`AnalyticsUseCase`（+Live）、`AIUseCase`（+Live）、`InsightCache` → `InsightsClient` + `CaptureClient`；§B 表步驟 3 的 6 個 Feature 檔（部分檔只動 AI/stats 注入，其餘注入留步驟 4/5）。
特別注意：
- [ ] 兩個新 Client 同一步驟擴張（瓜分 AIUseCase），但 commit 分開
- [ ] `answerFinancialQuestion` 連 `QueryTransactionsTool` 搬入 InsightsClient Live；其 transaction/category 讀取改 `SwiftDataStore` 直用
- [ ] `generateInsight`（單數）vs `generateAIInsight` 去重：先 grep 兩者呼叫端再統一為 `generateAIInsight`
- [ ] `TransactionDetailFeature.detailStats` 改 `insightsClient.detailStats`（repo pass-through 死亡的第一步）
- [ ] voice session 三方法（requestVoicePermission/startVoiceSession/stopVoiceSession）為 1:1 轉發 speechAdapter——AddTransaction 與 AccessoryBar 的 speechAdapter 注入此步驟移除
- [ ] 收縮刪：`Domain/UseCases/AnalyticsUseCase.swift`、`AIUseCase.swift`、`Application/Insights/AnalyticsUseCase+Live.swift`、`Application/Intelligence/AIUseCase+Live.swift`（InsightCache 搬家不刪）；`AIUseCaseTests` 拆兩份搬運

### 步驟 4：Platform

按 §C 食譜 + §A.5 合約。範圍：`AppEnvironmentUseCase`（+Live，扣除已搬 Planning/將搬 Ledger 的方法）、`CloudSyncUseCase`（+Live）、`DeeplinkClient`（介面在 Domain/UseCases、Live 在 Core/Adapters）→ `PlatformClient`；**Onboarding 溶解**；§B 表步驟 4 的 7 個 Feature 檔。
特別注意：
- [ ] `AppFeature` 改訂閱 `platformClient.pendingRecurringConfirmations` + `platformClient.resolveRecurringConfirmation`（notificationAdapter 注入移除）
- [ ] **Onboarding 溶解**：先 grep `OnboardingUseCase|onboardingUseCase` 呼叫端（盤點時 OnboardingFeature 只注入 accountClient，OnboardingUseCase 疑似已無注入點——若確認無人用直接刪）；`OnboardingFeature` 改注入 `\.platformClient`（markOnboardingComplete）——`accountClient.setupAccounts` 注入暫留，步驟 5 換 `ledgerClient.setupAccounts`；`OnboardingUseCase` + Live 此步驟刪除；TestStore 補「完成時兩個 effect 順序」案例
- [ ] `defaultAccountId` **不進 PlatformClient**（修訂 2026-06-04）：Feature 端（Dashboard/AddTransaction/Settings）的 defaultAccountId 是經 `userSettingsAdapter` 直讀，不經 AppEnvironmentUseCase——留在原樣到步驟 5 直接切 `ledgerClient`，避免二次搬家；AppEnvironmentUseCase 的 defaultAccountId 方法若 grep 無呼叫端，隨 UseCase 一起刪
- [ ] `wipeAll` → `wipeAllSyncData` 改名照 §A.5
- [ ] 收縮刪：`Domain/UseCases/AppEnvironmentUseCase.swift`、`CloudSyncUseCase.swift`、`DeeplinkClient.swift`、`Application/AppEnvironment/`、`Application/Sync/`、`Application/Misc/OnboardingUseCase+Live.swift`、`Core/Adapters/DeeplinkClient+Live.swift`；`DeeplinkClientTests` 搬運

### 步驟 5：Ledger（大魔王）

**步驟 4 偵察遺產（執行前必讀）**：
- **onboarding 旗標雙寫入點**：`AccountClient+Live.setupAccounts` 結尾直接 `setBool(true, .hasCompletedOnboarding)`（跨域寫入），OnboardingFeature 現在又顯式呼叫 `platformClient.markOnboardingComplete()`——重複。`LedgerClient.setupAccounts` 吸收時**移除**旗標寫入（旗標歸 Platform，Feature 已顯式呼叫），屬行為微調，記錄並補測試斷言
- MainTab 殘留的 `notificationAdapter.scheduleRecurringReminder/cancelRecurringReminder` + `recurringTransactionClient`（reschedule 那半）→ 併入 LedgerClient 的 recurring 區
- Settings 的 `defaultAccountId`（userSettingsAdapter 直讀）與 `openURL`（隱私政策，View 層讓步條款）→ defaultAccountId 切 `ledgerClient`，openURL 不動

按 §C 食譜 + §A.6 合約。範圍：`LedgerUseCase`/`AccountUseCase`/`MetadataUseCase`/`RecurringUseCase`/`ExportUseCase`（+Live 5 檔）、repo 5 件（Transaction/Account/Category/Tag/RecurringTransaction，+Live 5 檔）→ `LedgerClient`；§B 表步驟 5 的 17 個 Feature 檔；§E Watch 特例。
特別注意：
- [ ] 擴張 commit 拆小：Live 按分區分檔分 commit（Transactions → Accounts → Catalog → Recurring → Export），每 commit 全綠
- [ ] **新測試**（行為新增）：鏡像推送 post-condition（spy widgetSync/watchBridge adapter，record/update/delete 各一案例）；recurring CRUD 內部通知排程（spy notificationAdapter）
- [ ] 切換 phase 是最大 fan-out 點：17 個 Feature 檔分批（建議 4–5 個 agent，按資料夾分組：Dashboard / Transactions / 管理頁×4 / Settings+MainTab+Onboarding）
- [ ] `Dashboard/AddTransactionFeature` 與 `RecurringTransactions/*` 的 notificationAdapter 手動排程碼移除（已上收進 Client）
- [ ] `PlatformClient` 的 `defaultAccountId` TODO 此步驟搬入 LedgerClient
- [ ] 收縮刪：5 UseCase 介面 + 5 Live、5 repo 介面 + 5 Live、`Application/Misc/ExportUseCase+Live.swift`、`Application/Ledger/` 舊檔、`Application/Planning/RecurringUseCase+Live.swift`；CoreTests/Clients 與 DomainTests/Clients 對應測試搬運合併
- [ ] §E Watch 任務完成後才算本步驟 done

### 步驟 6：收網

- [x] **6.1 DoD grep audit**（全部需 CLEAN）：

```bash
# Feature 端只准 6 個 Client keypath + TCA 內建
grep -rnE '@Dependency\(\\\.' Features/Sources/Features --include="*.swift" \
  | grep -vE 'ledgerClient|planningClient|insightsClient|captureClient|carrierClient|platformClient|dismiss|continuousClock|openURL|uuid|date'
# 舊型別殘留
grep -rn "UseCase\b" Features/Sources --include="*.swift" | grep -v "Tests"
# 資料夾確認
ls Features/Sources/Domain/Repositories Features/Sources/Core/Repositories 2>&1 | grep "No such"
```

- [x] **6.2** `DatabaseClient` → `PersistenceBootstrap` 改名（Core 內部：seeding + container + CloudKitSyncAdapter 引用 + CLAUDE.md 文字）
- [x] **6.3** `docs/architecture.md` §2/§3/§3.1/§4/§5/§8 回寫為新模型（spec §3/§4 為藍本）；§9 加一段 2026-06 整併紀錄
- [x] **6.4** `CLAUDE.md` Architecture 段同步更新（Client 目錄、依賴規則）
- [x] **6.5** 完整 scheme 最終綠燈 + 本計畫「進度狀態」全勾

---

## §E Watch 特例（計畫期間發現，spec 未涵蓋——已另行裁定）

**現況**：
1. `Features/Sources/WatchFeatures/`（watchOS target）的 `WatchRecordFeature` 注入 `\.accountClient`/`\.categoryClient`，且 `WatchDependencies.swift` 以 `.watchLive(cache:)` 提供 **cache-backed 替代實作**（watchOS 無 SwiftData store，資料來自 WatchConnectivity snapshot）
2. `Core/Adapters/Watch/` 三檔（`WatchContextBuilder`/`WatchSyncObserver`/`WatchMidnightTimer`，iPhone 端）注入 `\.accountClient` 讀帳戶

**裁定**（步驟 5 內執行）：
- [ ] **E.1** WatchFeatures 建立**自己的小 Client**：`WatchLedgerClient`（合約見 §A.7：快照讀 ×2 + gateway 轉送記帳 ×1，Live 搬自 `WatchFeatures/Clients/` 三個 `.watchLive` extension）——Watch 是獨立 Presentation context，不應綁定 30 方法的 `LedgerClient`。`WatchDependencies.register` 改註冊單一 client；`WatchRecordFeatureTests` 覆寫對應更新
- [ ] **E.2** iPhone 端三檔屬 Watch 同步管線的 Infrastructure 內部協作者：`WatchContextBuilder` 改用 `SwiftDataStore` 直讀（同層合法）；`WatchSyncObserver`/`WatchMidnightTimer` 同樣處理。在 architecture.md §10 加註此例外（Infrastructure 內部讀 store 合法，因其本身就是鏡像推送管線的一部分）
- [ ] **E.3** 驗證需跑 Watch scheme 建置：`xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`（裝置名以本機可用 simulator 為準）+ `NeuLedgerWatchTests`

---

## §F 風險與已知裁定

| 風險 | 緩解 |
|---|---|
| Carrier 撞名（新 Client vs 舊 repo 同名同 module） | 步驟 1a 先讓位改名，已排程 |
| 步驟 3/4/5 對同一 Feature 檔分批動刀（如 AddTransactionFeature 被 3、5 兩步觸碰） | §B 表已標「（部分）」；每步驟只動該步驟語意的注入點，agent prompt 載明哪幾行歸它 |
| 鏡像推送 post-condition 改變 effect 時序，可能觸發 TestStore「effect still running」flaky | 新增案例用 spy adapter 同步斷言；若 flaky 重現，參照 2026-05-20 plan 的 flaky 診斷紀錄（隔離跑單 suite 比對） |
| `generateInsight`/`generateAIInsight` 去重可能有行為差異 | 步驟 3 先 grep 呼叫端 + 讀兩實作 diff 再合併，有疑義回報不擅斷 |
| Watch target 編譯破裂被 iOS scheme 測試漏接 | §E.3 把 Watch scheme 建置納入步驟 5 驗證 gate |
| 測試基準數會隨步驟變動（搬運/合併） | 每步驟 phase d 記錄新基準到「進度狀態」區，下一步以新基準驗證 |

**永不更動**：`SettingsKey` persisted raw values（含 `"syncClient.lastSyncedAt"`）；`Schema` 陣列；任何使用者資料格式。
