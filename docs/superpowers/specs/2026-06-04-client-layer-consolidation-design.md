# Client 層整併設計：UseCase == Client、Repository 溶解、領域重切

**日期**：2026-06-04
**狀態**：已與使用者逐段核可（四段設計全數通過）
**分支**：`refactor`
**取代**：`docs/architecture.md` §2（Naming）、§3（Dependency Rules）、§4/§4.2（Repository）、§5（UseCase Catalog）的對應段落——本 spec 落地後須回寫 architecture.md

---

## 1. 背景與問題

`docs/architecture.md` 的四層架構（Phase 0–7 migration，2026-05-21 完成）紙上定義清楚，但實際程式碼存在三重混亂：

1. **命名腳踏兩條船**：`Domain/Repositories/` 8 個介面有 7 個型別仍叫 `XxxClient`；`DeeplinkClient` 介面放 `Domain/UseCases/`、Live 卻在 `Core/Adapters/`；`UserSettings` 三次改名搖擺（Client → Adapter → Repository）。
2. **Feature DI 大規模違反 §3**：Feature 直接注入 Repository 約 50 處、Adapter 11 處；走 UseCase 的僅 10 處。
3. **UseCase 切分跟著畫面長**：`OnboardingUseCase`（畫面流程）、`ExportUseCase`（Settings 按鈕）、`MetadataUseCase`（兩個管理頁的聯集）不是領域詞彙；舊 `*Client`（repo）則是一個 entity 一個，畫面各自拼裝 2–4 個。
4. **儀式性轉發**：12 個 UseCase 多數是 thin wrapper（如 `AccountUseCase` 8 方法全 delegate `AccountClient`）；Repository Live 又多是 `SwiftDataStore` 的轉發層。同一件事包了三層。

## 2. 決策記錄

| # | 決策 | 內容 |
|---|---|---|
| D1 | **嚴格分層** | Feature 只准注入 Client（可多個）；絕不出現 Feature 同時打 Client 與更下層（Adapter / SwiftDataStore / repo）。Feature 端要「一眼看出規格與操作」，不含業務邏輯實作與判斷 |
| D2 | **UseCase == Client** | Application 層型別命名保持 `XxxClient`（TCA 慣例），語意上就是 UseCase 層。「Client」一詞保留給此層專用，其他層不得使用 |
| D3 | **大力整併、按領域切** | 12 UseCase → 6 領域 Client。切分跟著 bounded context，不跟畫面、不跟技術。Ledger 變肥是預期內代價，採單一肥 struct + `// MARK:` 分區 |
| D4 | **Repository 層溶解** | 8 個 Repository 介面 + 8 個 Live 整層移除：7 個溶入對應 Client Live（直接組裝 `SwiftDataStore<Domain, SD>`），`UserSettingsRepository` 重歸類為 `UserSettingsAdapter`。Adapter 層保留 |
| D5 | **Keypath 風格** | `\.ledgerClient`、`\.planningClient` … 與型別名一致（原 spec 的 verb-first `\.ledger` 退役） |
| D6 | **三爭點裁定** | ① 領域偏好回歸領域（各 Client 自己透過 `userSettingsAdapter` 讀寫，§3.1 wrapper 例外刪除）② Widget/Watch 鏡像推送是 Ledger 的 post-condition ③ CloudKit Sync 併入 Platform |

## 3. 最終分層模型

```
┌────────────────────────────────────────────────────────┐
│ Presentation    XxxFeature / XxxView (TCA)             │
│                   │ 只准注入 Client（可注入多個）       │
│                   ▼                                    │
│ Application     XxxClient（= UseCase 層，6 個領域）    │
│                   │ 組裝                               │
│                   ├─▶ SwiftDataStore<Domain, SD>       │
│                   ├─▶ XxxAdapter（系統 API 包裝）      │
│                   ├─▶ XxxPolicy（純邏輯）              │
│                   └─▶ 其他 Client（僅限 §3.1 白名單）  │
│ Domain          Entity / ValueObject / Policy          │
│                 + Client / Adapter 介面（零外部 import）│
│ Infrastructure  SwiftDataStore + Mapper + Adapter Live │
└────────────────────────────────────────────────────────┘
```

### 依賴規則（取代 architecture.md §3）

| 誰 | 准依賴 | 禁止 |
|---|---|---|
| Feature | Client（可多個）、TCA 內建（`\.dismiss`、`\.continuousClock`、`\.openURL`、`\.uuid` 等） | SwiftDataStore、Adapter、`\.modelContainer`、系統 API |
| Client Live | SwiftDataStore、Adapter、Policy、其他 Client（限 §3.1） | `ModelContext` / SwiftData 原語、UIKit 等系統 API 直呼 |
| Adapter | 系統 API、Domain 型別 | 其他 Adapter、Client、SwiftDataStore |
| SwiftDataStore / Mapper | `\.modelContainer`、`ModelContext` | 業務邏輯 |
| Policy | 純 Swift（Foundation OK） | 任何 async / IO |

原 §3「View 內純系統呼叫」讓步條款保留（如 `UIApplication.shared.open`），但任何寫入使用者資料或儲存狀態的操作必經 Client。

### ModelContext 封印（§4.2 規則原樣保留）

- 只有 `SwiftDataStore` 五方法 + `PersistentDomainModel` mapper 能碰 `ModelContext`
- 只有 `SwiftDataStore` 能 `@Dependency(\.modelContainer)`
- 自訂查詢先 `store.fetchAll()` + Swift 端過濾；profiling 證實瓶頸時才加 `SwiftDataStore where SD == X` constrained extension，呼叫端介面不變
- 既有合法例外不變：`DatabaseClient`（container + seeding）、`CloudKitSyncAdapter`、`TransactionAnalyticsKernel`、Mappers

### §3.1 Client → Client 白名單（縮編後）

預設規則不變：Client 是平輩、不互疊，跨 Client 協調歸 Reducer。白名單：

1. **INVARIANT**：`LedgerClient.record/update → PlanningClient.evaluateAfterTransaction`（每筆交易必評估預算警告，不能指望呼叫端記得）

退出名單：
- ~~`RecurringUseCase.tick → LedgerUseCase.record`~~（SAGA）→ tick 併入 Ledger 後變內部呼叫
- ~~`AppEnvironmentUseCase` wrapper 例外~~ → 各領域自己透過 `userSettingsAdapter` 讀寫自己的設定

Widget/Watch 鏡像推送（D6-②）是 Client → Adapter 呼叫，本來就合法，不需進白名單；其「post-condition 不變量」地位以註解 + 測試固定。

## 4. 六個領域 Client 目錄

### 🧾 `LedgerClient` —「帳本上的事實」

吸收：`LedgerUseCase` + `AccountUseCase` + `MetadataUseCase` + `RecurringUseCase` + `ExportUseCase`（5 併 1，約 30 方法，`// MARK:` 分五區）。

- **Transactions**：`record` / `update` / `delete` / `fetch` / `listRecent` / `listAll(filter:)` / `search` （讀取回傳 `EnrichedTransaction`）
- **Accounts**：`createAccount` / `updateAccount` / `archiveAccount` / `unarchiveAccount` / `deleteAccount` / `listAccounts` / `listActiveAccounts` / `balances`，加上領域偏好 `defaultAccountId()` / `setDefaultAccountId(_:)`
- **Catalog**（分類詞彙）：`listCategories(type:)` / `createCategory` / `updateCategory` / `deleteCategory` / `listTags` / `createTag` / `updateTag` / `deleteTag`
- **Recurring**（自動記帳）：`listActiveRecurring` / `createRecurring` / `updateRecurring` / `deleteRecurring` / `tick()`
- **Export**：`exportCSV() -> URL`

**內部不變量**（附註解 + 測試）：
- `record`/`update` → `planningClient.evaluateAfterTransaction`（§3.1 INVARIANT）
- `record`/`update`/`delete` → Widget/Watch 鏡像推送（`widgetSyncAdapter` / `watchBridgeAdapter`）——「帳本變了、鏡像跟著變」
- `tick()` → 內部 `record`（原 SAGA 內部化）
- 帳戶有交易只能 archive 不能 delete；`isDefault` 分類不可刪；刪 Tag 自動解除所有交易關聯

### 💰 `PlanningClient` —「對未來花費的約束」

吸收：`BudgetUseCase`。判準：刪掉所有預算，記帳照常運作。

- `listActive` / `create` / `update` / `delete` / `currentStatus(of:)`
- `evaluateAfterTransaction(_:)`（由 Ledger 以 §3.1 呼叫；內部 = `BudgetWarningPolicy` 判斷 + `notificationAdapter` 發警告）
- 領域偏好：`budgetWarningEnabled()` / `setBudgetWarningEnabled(_:)` / `budgetWarningThreshold()` / `setBudgetWarningThreshold(_:)`（Settings 畫面也注入本 Client 來改）

### 📊 `InsightsClient` —「把帳本變成可理解的資訊」（全唯讀）

吸收：`AnalyticsUseCase` + `AIUseCase.answerFinancialQuestion`（「用自然語言讀帳本」屬於洞察，不屬於輸入輔助）。判準：整個領域刪掉不遺失任何資料。

- `todayStats(referenceDate:)` / `weeklySparkline(accountId:)` / `dailyBars(range:)` / `categoryProportions(range:)` / `budgetGauges()`
- `generateAIInsight(summary:)` / `answerFinancialQuestion(_:)`（含 `QueryTransactionsTool`）
- Live 組裝：`TransactionAnalyticsKernel` + `AIAdapter` + `InsightCache`（隨之搬入 Insights 資料夾）

### 🤖 `CaptureClient` —「進帳本之前的輸入輔助」

吸收：`AIUseCase` 扣除問答後的部分。判準：只產草稿（`ExtractedTransaction`），自己永遠不寫帳——Feature 拿草稿去呼叫 `ledgerClient.record`。

- `extractFromText(_:)` / `extractFromVoice(_:)` / `suggestCategories(text:existing:)` / `isAvailable()`
- Live 組裝：`SpeechAdapter` + `AIAdapter`

> Insights 與 Capture 都用 AI，但**按方向切、不按技術切**：一個是讀的投影、一個是寫入前的輔助。AI 技術更換不影響兩域形狀。

### 🏷️ `CarrierClient` —「電子發票載具保管」

吸收：`CarrierUseCase` + carrier repo。

- `listAll` / `create` / `update` / `delete` / `setActiveForWidget(_:)` / `activeForWidget()`

### 🛠️ `PlatformClient` —「App 自身的運行環境」（與「錢」無關的都在這）

吸收：`AppEnvironmentUseCase` + `CloudSyncUseCase` + `DeeplinkClient`（3 併 1，約 16 方法，分五區）。

- **Preferences**（無主設定）：`accessoryMode()` / `setAccessoryMode(_:)` / `reminderTime()` / `setReminderTime(_:)` / `hasCompletedOnboarding()` / `markOnboardingComplete()`
- **Notification**：`requestNotificationPermission()` / `scheduleDailyReminder()` / `cancelDailyReminder()`
- **Sync**：`syncAvailable()` / `syncEnabled()` / `lastSyncedAt()` / `enableSync() -> AsyncThrowingStream<Double, Error>` / `requestSyncNow()`
- **Routing**：deeplink / 入站通知解析為 `RouteLinkDestination`（含 `resolveRecurringConfirmation`、`pendingConfirmations` 訂閱面——`AppFeature` 經由本 Client 訂閱，不再直接注入 `notificationAdapter`）
- **System**：`openAppSettings()`

### 溶解（不轉生）

- **`OnboardingUseCase` 純刪除**：`OnboardingFeature` 自己協調 `ledgerClient.createAccount` + `platformClient.markOnboardingComplete` 兩個 effect（Reducer 協調多個 Client 合法，§3.1 本則）

## 5. 檔案級衝擊

### 移除：介面 21 檔 → 6 檔

| 現存 | 去向 |
|---|---|
| `Domain/Repositories/`：`TransactionClient` / `AccountClient` / `CategoryClient` / `TagClient` / `RecurringTransactionClient` | 溶入 `LedgerClient` |
| `Domain/Repositories/BudgetClient` | 溶入 `PlanningClient` |
| `Domain/Repositories/CarrierClient` | 溶入新 `CarrierClient` |
| `Domain/Repositories/UserSettingsRepository` | 搬家改名 → `Domain/Adapters/UserSettingsAdapter` |
| `Domain/UseCases/`：`LedgerUseCase` / `AccountUseCase` / `MetadataUseCase` / `RecurringUseCase` / `ExportUseCase` | 合併為 `LedgerClient.swift` |
| `Domain/UseCases/BudgetUseCase` | → `PlanningClient.swift` |
| `Domain/UseCases/AnalyticsUseCase` | → `InsightsClient.swift` |
| `Domain/UseCases/AIUseCase` | → `CaptureClient.swift`（問答移至 Insights） |
| `Domain/UseCases/`：`AppEnvironmentUseCase` / `CloudSyncUseCase` / `DeeplinkClient` | 合併為 `PlatformClient.swift` |
| `Domain/UseCases/CarrierUseCase` | → `CarrierClient.swift` |
| `Domain/UseCases/OnboardingUseCase` | 純刪除 |

`Domain/Repositories/` 資料夾消失。

### 移除：Live 22 檔 → 約 8–10 檔

- `Core/Repositories/` 整資料夾消失（8 檔）——`SwiftDataStore` 實例化與自訂查詢（`search` / `computeBalance` / `weeklySpending`…）以 private helper 溶入對應 `XxxClient+Live`
- `Application/` 13 檔重組為 6 個 Client Live（`LedgerClient+Live` 可拆多檔：`+Live.swift` / `+LiveAccounts.swift`…同 module extension 分檔）
- `Core/Adapters/DeeplinkClient+Live.swift` 溶入 `PlatformClient+Live` Routing 區
- `OnboardingUseCase+Live.swift` 純刪除
- `InsightCache.swift` 搬至 Insights 資料夾

### 原封不動的基座

```
Core/Persistence/   DatabaseClient（container + seeding；步驟 6 收網時改名 PersistenceBootstrap）、ModelContainerKey、
                    SwiftDataStore、PersistentDomainModel、ModelContextCopyable、Models/
Core/Mappers/       全部 SD mapper
Core/Adapters/      6 個 Adapter Live（+1 新成員 UserSettingsAdapter+Live）
Core/Analytics/     TransactionAnalyticsKernel（改由 InsightsClient 注入）
Domain/             Entities、ValueObjects、Policies（BudgetWarningPolicy）、Adapters/
```

### 目標資料夾佈局

```
Domain/Clients/                     6 個 Client 介面（取代 Domain/UseCases/）
  LedgerClient.swift / PlanningClient.swift / InsightsClient.swift /
  CaptureClient.swift / CarrierClient.swift / PlatformClient.swift
Domain/Adapters/                    7 個 Adapter 介面（+UserSettingsAdapter）
Application/                        6 個 context 資料夾（Live 實作）
  Ledger/    LedgerClient+Live.swift（可再拆 +LiveAccounts 等同 extension 分檔）
  Planning/  PlanningClient+Live.swift
  Insights/  InsightsClient+Live.swift、InsightCache.swift
  Capture/   CaptureClient+Live.swift
  Carrier/   CarrierClient+Live.swift
  Platform/  PlatformClient+Live.swift
```

（`Application/` 仍屬 Core target sources，無 module 邊界問題；`Intelligence/`、`Misc/`、`Sync/`、`AppEnvironment/` 資料夾退役。）

### 連帶改寫（非刪除）

- Feature 端約 60 個注入點 → 6 個 Client keypath（最大工作量）
- `NeuLedgerTests` 對應 suite 重組：repo 級測試上移為 Client Live 測試（in-memory container 模式不變）
- `docs/architecture.md` §2 / §3 / §4 / §5 改寫

淨效果：43 個介面 + Live 檔 → 約 14–16 檔；「Client」一詞只在 Application 層出現。

## 6. 遷移策略

「擴張–收縮」：新舊並存、逐領域切換、每 commit 全綠可獨立合入。由小到大，Ledger 最後。

| 步驟 | 範圍 | 理由 |
|---|---|---|
| 0 | `UserSettingsRepository` → `UserSettingsAdapter` 機械改名（~10 檔） | 後續領域「自己讀自己的設定」的前置；沿用 Phase 2 驗證過的流程 |
| 1 | **Carrier（試點）**：新 `CarrierClient` ← CarrierUseCase + carrier repo | 最小完整垂直切片（6 方法、3 注入點），驗證食譜 |
| 2 | **Planning**：← BudgetUseCase + budget repo + 接收預算警告設定 | 含 invariant 與「領域自有設定」兩個關鍵 pattern |
| 3 | **AI 拆分**：新 `InsightsClient` + `CaptureClient` ← Analytics + AI 重切 | 兩 Client 瓜分 AIUseCase（問答、InsightCache 搬家、Kernel 注入），必須同步處理 |
| 4 | **Platform**：← AppEnvironment + CloudSync + Deeplink；Onboarding 溶解 | 注入點多（userSettings 9 + notification 6…）但邏輯淺 |
| 5 | **Ledger（大魔王）**：← 5 UseCase + 5 repo；tick 內部化；鏡像推送 post-condition 化 | ~40 注入點，等 pattern 成熟後最後動 |
| 6 | **收網**：grep audit、刪空資料夾、`DatabaseClient` 改名 `PersistenceBootstrap`（Core 內部小範圍：seeding + container + CloudKitSyncAdapter 引用）、architecture.md 改寫、§3.1 縮編 | 驗收 + 文件落地；讓「Client 只在 Application 層」無例外 |

每個領域的標準食譜（步驟 1–5 重複）：

```
a. 擴張：新增 XxxClient 介面 + Live（實作自舊 repo/usecase 搬入，直組 SwiftDataStore/Adapter）
b. 切換：Feature 注入點逐個換 keypath，每換完一個 Feature 跑該 suite
c. 收縮：刪舊介面 + Live，測試 suite 搬家重組
d. 驗證：完整 test scheme 全綠 → commit（PR 級可獨立合入單位）
```

### 安全網

- 行為保持型重構：既有 273 + 87 + 120 測試是安全網；不新增行為不新增測試，但每 commit 全綠（CLAUDE.md TDD 例外條款）
- 唯二新增行為需補測試：① 鏡像推送 post-condition（新 invariant）② Onboarding 溶解後的 Feature 雙 effect 協調（TestStore 驗順序）
- 全程 `refactor` 分支、`[ci skip]` 慣例照舊

## 7. 驗收標準（DoD）

- [ ] Feature 端 grep：`@Dependency` 只出現 6 個 Client keypath + TCA 內建（`dismiss` / `continuousClock` / `openURL` / `uuid`）
- [ ] 「Client」字樣只存在於 Application 層型別
- [ ] `Domain/Repositories/`、`Core/Repositories/`、`Domain/UseCases/`、`Application/` 舊檔結構不存在（重組為新結構）
- [ ] §3.1 白名單只剩 1 條 INVARIANT
- [ ] `ModelContext(` 出現位置不變（SwiftDataStore + DatabaseClient seeding + CloudKitSyncAdapter + TransactionAnalyticsKernel + Mappers）
- [ ] 完整 test scheme 全綠；每個遷移 commit 可獨立建置
- [ ] `docs/architecture.md` 回寫完成

## 7.1 附錄：Watch 特例（2026-06-04 計畫期間發現）

`WatchFeatures`（watchOS target）注入 `accountClient`/`categoryClient`/`transactionClient` 且有 cache/gateway-backed `.watchLive` 替代實作（含經 WatchConnectivity 轉送 iPhone 的記帳寫入路徑）；`Core/Adapters/Watch/` 三檔（iPhone 端）也注入 repo。裁定：
- WatchFeatures 建自己的 `WatchLedgerClient`（快照讀 + gateway 轉送記帳，不綁 30 方法的 LedgerClient；合約見 plan §A.7）
- iPhone 端 Watch 管線三檔屬 Infrastructure 內部協作者，改 `SwiftDataStore` 直讀（同層合法，§10 加註）
- 步驟 5 驗證 gate 須含 Watch scheme 建置

細節見 plan §E（`docs/superpowers/plans/2026-06-04-client-layer-consolidation.md`）。

## 8. 範圍外（明確不做）

- 任何行為變更或新功能
- `SwiftDataStore` constrained extension 預先優化（僅瓶頸時做）
- Watch / Widget extension target 內部的重構（只動 SPM package 內的同步觸發點）
- `SettingsKey` 的 persisted UserDefaults raw value（如 `"syncClient.lastSyncedAt"`）永不更動——使用者既存資料
