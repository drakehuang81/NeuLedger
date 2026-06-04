# Client Layer Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Ultracode 編排模式**：本計畫設計為「步驟間序列、步驟內並行」。每個步驟是一個序列 gate（完整 test scheme 全綠才進下一步）；步驟內的「切換階段」可按 §B 檔案所有權分組 fan-out 並行 agent。每個 agent prompt 必須包含：①只能修改的檔案清單 ②目的地合約（§A 對應段）③驗證指令（§C）④越界編譯錯誤回報 `BLOCKED` 不自行修復。

**Goal:** 把 12 個 UseCase + 8 個 Repository 整併為 6 個領域 Client（UseCase == Client），溶解 Repository 層，Feature 端只准注入 Client。

**Architecture:** 依 `docs/superpowers/specs/2026-06-04-client-layer-consolidation-design.md`。擴張–收縮：每步驟新 Client 先就位 → Feature 注入點逐檔切換 → 刪舊檔，每 commit 全綠可獨立合入。

**Tech Stack:** Swift 6 / TCA 1.23.1（`@DependencyClient`）/ SwiftData（經 `SwiftDataStore<Domain, SD>`）/ Swift Testing / xcodebuild

**計畫哲學（為何沒有凍結 diff）：** 本計畫「合約完整、diff 輕量」。§A 合約與 §B 盤點是穩定的目的地；各步驟的實作 diff 由執行 agent 基於當時真實程式碼派生（舊 Live 的實作邏輯**搬運為主、重寫為輔**）。

---

## 進度狀態（2026-06-04 建立）

- [ ] 步驟 0：`UserSettingsRepository` → `UserSettingsAdapter` 機械改名
- [ ] 步驟 1：Carrier 試點（食譜驗證）
- [ ] 步驟 2：Planning
- [ ] 步驟 3：AI 拆分（Insights + Capture）
- [ ] 步驟 4：Platform
- [ ] 步驟 5：Ledger（大魔王，含 Watch 特例 §E）
- [ ] 步驟 6：收網（grep audit + `DatabaseClient` 改名 + architecture.md 回寫）

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
}
// keypath: \.insightsClient
```

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

**驗證指令（每 commit 前必跑）：**

```bash
# 建置
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 完整測試（基準：FeaturesTests 273 + CoreTests 87 + DomainTests 120，1 個 NotificationSettings known issue 屬預期）
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
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

- [ ] **0.1 盤點引用**：`grep -rln "UserSettingsRepository\|userSettingsRepository" Features/Sources NeuLedgerTests` 取得完整清單（執行當下為準）
- [ ] **0.2 git mv 兩檔 + 全域型別/keypath 改名**（沿用 Phase 2 機械改名流程；`SettingsKey` 結構與所有 persisted raw value **絕不動**）
- [ ] **0.3 建置 + 完整測試**：基準 273+87+120 全綠
- [ ] **0.4 Commit**：`refactor(platform): rename UserSettingsRepository to UserSettingsAdapter [ci skip]`

### 步驟 1：Carrier 試點

**特殊前置——撞名**：新 `CarrierClient`（Application）與現存 repo `CarrierClient`（Domain/Repositories）同名同 module，必須先讓位。

**Files:**
- 1a Rename: `Domain/Repositories/CarrierClient.swift` → `CarrierRepository.swift`（型別+keypath 同步改）、`Core/Repositories/CarrierClient+Live.swift` → `CarrierRepository+Live.swift`；引用端：`Application/Carrier/CarrierUseCase+Live.swift`、3 個 Feature 檔、CoreTests/DomainTests 的 CarrierClientTests
- 1b Create: `Domain/Clients/CarrierClient.swift`（§A.1 原文）、`Application/Carrier/CarrierClient+Live.swift`、Test `NeuLedgerTests/Tests/CoreTests/Clients/CarrierClientLiveTests.swift`
- 1c Modify: `CarrierManagement/CarrierManagementFeature.swift`、`CarrierManagement/AddEditCarrierFeature.swift`、`Settings/SettingsFeature.swift`（carrier 注入）+ 對應 `CarrierManagementFeatureTests`、`SettingsFeatureTests`
- 1d Delete: `Domain/UseCases/CarrierUseCase.swift`、`Application/Carrier/CarrierUseCase+Live.swift`、`Domain/Repositories/CarrierRepository.swift`、`Core/Repositories/CarrierRepository+Live.swift` + 舊測試（內容先搬運至 1b 測試）

- [ ] **1a.1** repo 撞名讓位改名（機械），建置+完整測試，commit：`refactor(carrier): rename repo CarrierClient to CarrierRepository [ci skip]`
- [ ] **1b.1** 寫 `CarrierClientLiveTests`（先紅燈：型別不存在）——案例搬運自現有 CarrierClientTests/CarrierUseCase 相關測試，加 2 個新案例：CRUD 後 widget reload 被呼叫（spy widgetSyncAdapter）、setActiveForWidget 寫入設定
- [ ] **1b.2** 建 `Domain/Clients/CarrierClient.swift`（§A.1）+ `Application/Carrier/CarrierClient+Live.swift`（實作搬自 CarrierUseCase+Live 與 CarrierRepository+Live：`SwiftDataStore<Carrier, SDCarrier>` 直用）
- [ ] **1b.3** 跑 1b.1 測試綠燈 + 完整 scheme 綠，commit：`refactor(carrier): add CarrierClient interface + live [ci skip]`
- [ ] **1c.1** 三個 Feature 檔切換 keypath + 測試覆寫更新（widgetSyncAdapter/userSettings 手動呼叫碼一併移除——已上收）
- [ ] **1c.2** 完整測試綠，commit：`refactor(carrier): switch features to CarrierClient [ci skip]`
- [ ] **1d.1** 刪 4 個舊檔 + 舊測試，grep 殘留檢查 CLEAN，完整測試綠，commit：`refactor(carrier): retire CarrierUseCase + CarrierRepository [ci skip]`
- [ ] **1e 食譜回顧**：把試點踩到的坑寫回本檔「進度狀態」區，修正後續步驟的食譜假設

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
- [ ] `defaultAccountId`/`setDefaultAccountId` 暫留 AppEnvironmentUseCase？**否**——AppEnvironmentUseCase 本步驟整個退役，這兩個方法先搬進 PlatformClient 並標 `// TODO(step5): move to LedgerClient`，步驟 5 再搬（避免跨步驟懸空）
- [ ] `wipeAll` → `wipeAllSyncData` 改名照 §A.5
- [ ] 收縮刪：`Domain/UseCases/AppEnvironmentUseCase.swift`、`CloudSyncUseCase.swift`、`DeeplinkClient.swift`、`Application/AppEnvironment/`、`Application/Sync/`、`Application/Misc/OnboardingUseCase+Live.swift`、`Core/Adapters/DeeplinkClient+Live.swift`；`DeeplinkClientTests` 搬運

### 步驟 5：Ledger（大魔王）

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

- [ ] **6.1 DoD grep audit**（全部需 CLEAN）：

```bash
# Feature 端只准 6 個 Client keypath + TCA 內建
grep -rnE '@Dependency\(\\\.' Features/Sources/Features --include="*.swift" \
  | grep -vE 'ledgerClient|planningClient|insightsClient|captureClient|carrierClient|platformClient|dismiss|continuousClock|openURL|uuid|date'
# 舊型別殘留
grep -rn "UseCase\b" Features/Sources --include="*.swift" | grep -v "Tests"
# 資料夾確認
ls Features/Sources/Domain/Repositories Features/Sources/Core/Repositories 2>&1 | grep "No such"
```

- [ ] **6.2** `DatabaseClient` → `PersistenceBootstrap` 改名（Core 內部：seeding + container + CloudKitSyncAdapter 引用 + CLAUDE.md 文字）
- [ ] **6.3** `docs/architecture.md` §2/§3/§3.1/§4/§5/§8 回寫為新模型（spec §3/§4 為藍本）；§9 加一段 2026-06 整併紀錄
- [ ] **6.4** `CLAUDE.md` Architecture 段同步更新（Client 目錄、依賴規則）
- [ ] **6.5** 完整 scheme 最終綠燈 + 本計畫「進度狀態」全勾

---

## §E Watch 特例（計畫期間發現，spec 未涵蓋——已另行裁定）

**現況**：
1. `Features/Sources/WatchFeatures/`（watchOS target）的 `WatchRecordFeature` 注入 `\.accountClient`/`\.categoryClient`，且 `WatchDependencies.swift` 以 `.watchLive(cache:)` 提供 **cache-backed 替代實作**（watchOS 無 SwiftData store，資料來自 WatchConnectivity snapshot）
2. `Core/Adapters/Watch/` 三檔（`WatchContextBuilder`/`WatchSyncObserver`/`WatchMidnightTimer`，iPhone 端）注入 `\.accountClient` 讀帳戶

**裁定**（步驟 5 內執行）：
- [ ] **E.1** WatchFeatures 建立**自己的小 Client**：`WatchSnapshotClient`（`activeAccounts`、`categories`，cache-backed Live 搬自 `.watchLive` 實作）——Watch 是獨立 Presentation context，它讀的是同步快照而非帳本本體，不應綁定 30 方法的 `LedgerClient`。`WatchRecordFeatureTests` 覆寫對應更新
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
