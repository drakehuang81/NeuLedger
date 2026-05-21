# Architecture Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 NeuLedger 從現行 `*Client` 統包式架構，按 `docs/architecture.md` §9 完整遷移到 Clean Architecture + DDD（Presentation → UseCase → Domain → Infrastructure）四層分層，命名上明確區分 Repository / Adapter / UseCase。

**Architecture:** 採「擴張–收縮」（expand–contract）策略，逐 Phase 引入新的型別與抽象，舊 `*Client` 暫時並存，每個 PR 級任務都是綠燈狀態可獨立合入。完成後刪除舊命名/舊基礎建設，最終達到 architecture.md 所述狀態。

**Tech Stack:** Swift 6, SwiftData, TCA 1.23.1, Swift Testing, `@Reducer` / `@DependencyClient` / `@Dependency` macros, Foundation Models, CloudKit (`NSPersistentCloudKitContainer`), iOS 26+.

---

## 共通原則（每個 Phase 都適用）

1. **TDD 強制**：每個會改變行為的 step 都必須先寫測試、跑紅燈、再寫實作、跑綠燈、最後 commit。命名改動 / 純搬遷不改行為的 step 不需要新增測試，但必須跑現有測試套件確認綠燈。
2. **每個 Task 結束後跑完整測試 scheme**：除 `-only-testing:` 對應 suite 外，也必須跑一次 `xcodebuild test -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` 確認沒有 side effect。
3. **TaskCreate 追蹤**：每個 Task 對應一張 TaskList 項目，開始改成 `in_progress`、完成改成 `completed`。
4. **Subagent 修改範圍限制**：派 subagent 時必須在 prompt 中明確列出「只能修改的檔案清單」，禁止越界；越界檔案有編譯錯誤回報 `BLOCKED`。
5. **Target/Module Boundary 標注**：所有跨 target 程式碼（Shared/ vs SPM 內）必須在 step 描述中標注「此型別不在此 module scope 中」。
6. **Commits 頻率**：原則上每完成一個 Step 群（一個檔案、一個能編譯通過的改動）就 commit 一次。
7. **CLAUDE.md 規範**：所有變更都遵守 `CLAUDE.md` 中的「Features 不准 import SwiftData」「TWD only」「semantic colors」「String(localized:)」等限制。

---

## 進度狀態（2026-05-21 更新）

**Phase 0（baseline broken tests 修復）** ✅ 全部完成
- 0a SyncSettingsFeatureTests / 0b DashboardFeatureChipTests / 0c CarrierManagementFeatureTests / 0d CategoryManagementFeatureTests

**Phase 1（持久層基礎建設）** ✅ 全部完成（19 個 commit）
- 1.1 `\.modelContainer` dependency `880b275`
- 1.2 `PersistentDomainModel` protocol `bdd290e`
- 1.3a–g 7 個 SD model `applyChanges`/`idPredicate`/`prepareForDelete` `97b8a5c..96a3baa`
- 1.4 `SwiftDataStore<Domain, SD>` 泛型 `c7a2992`
- 1.5a–g 7 個 Repository Live 遷移 `eb3b8dc..d23d98b`
- 1.6 退役 `DatabaseClient` CRUD helpers `a43d7ed`

**Phase 2（Adapter 改名）** ✅ 全部完成（4 個 commit）
- 2.1 `NotificationClient` → `NotificationAdapter` `b131ee2`（15 files）
- 2.2 `UserSettingsClient` → `UserSettingsAdapter` `3ec5cfd`（24 files）
- 2.3 `WidgetSyncClient` → `WidgetSyncAdapter` `46d3775`（6 files）
- 2.4 `SpeechClient` → `SpeechAdapter` + `SpeechClientError` → `SpeechAdapterError` `5bef3fc`（7 files）

**Phase 3 範圍修訂（2026-05-21）**：原 plan 把 Phase 3 設計為「拆 Adapter + UseCase」，但 `AIServiceClient` 的 `answerFinancialQuestion` 已注入 `transactionClient/categoryClient`，純拆 Adapter 會引入跨層依賴或讓 Adapter 違反 architecture §3。為避免在 Phase 3 引入此設計爭議、控制範圍：

- **Phase 3.1 改為純改名**：`AIServiceClient` → `AIUseCase`（沿 Phase 2 機械改名 pattern）。`AIAdapter` 切分留待 Phase 5「補完 AIUseCase 完整 spec」時處理（屆時也決定 `answerFinancialQuestion` 怎麼歸位）。
- **Phase 3.2 改為純改名**：`SyncClient` → `CloudSyncUseCase`。`CloudKitSyncAdapter` 切分（含 §10 註記的 `SyncClient+Live:63` ModelContext 違規處理）也留待 Phase 5。

理由：
1. 跟 Phase 2 一致的「機械改名」流程已驗證安全可重複。
2. 真正的 Adapter/UseCase 切分需要決定方法歸位，那是設計工作，不適合塞進「Phase 2 風格」的批次 rename 收尾。
3. 結尾 Phase 1 收尾驗證 invariant 中那一個 `SyncClient+Live:63 ModelContext` 違規本來就 deferred 到 Phase 3 — 改成 Phase 5 不影響其他 invariant，且讓 Phase 3 變成 4-task→2-task 純 rename。

下一階段：Phase 3.1（`AIServiceClient` → `AIUseCase` 純改名）。

**Phase 3（拆分誤命名 UseCase — rescoped 為純改名）** ✅ 全部完成（2 個 commit）
- 3.1 `AIServiceClient` → `AIUseCase` `70faf8a`（17 files）
- 3.2 `SyncClient` → `CloudSyncUseCase` `a3c61e2`（6 files）
- **Phase 5 待辦遞延項**：
  - 切 `AIAdapter`（從 AIUseCase 抽出 raw Foundation Models 包裝層）；`answerFinancialQuestion` 的 Repository 依賴重新歸位
  - 切 `CloudKitSyncAdapter`（從 CloudSyncUseCase 抽出 NSPersistentCloudKitContainer lifecycle）；同時處理 `CloudSyncUseCase+Live:63` 的 `ModelContext(DatabaseClient.container)` 違規
  - `UserSettingsAdapter.swift:101` 的 `SettingsKey rawValue "syncClient.lastSyncedAt"` 是 persisted UserDefaults key，**永遠不改**（會丟使用者既存資料）— 保留為已知歷史命名

下一階段：Phase 4（Ledger UseCase 抽出）— 引入 BudgetWarningPolicy、LedgerUseCase、BudgetUseCase.evaluateAfterTransaction，把 TransactionClient+Live 中的 checkBudgetWarnings 業務邏輯搬上層。Feature 改注入 `\\.ledger`。

**Phase 4（Ledger UseCase 抽出）** ✅ 全部完成（4 個 commit）
- 4.1 `BudgetWarningPolicy` 抽出 `2f584a6`（Policy + 8 tests + TransactionClient+Live 重構成呼叫 Policy）
- 4.2 `BudgetUseCase.evaluateAfterTransaction(_:)` `21f6739`（新建 BudgetUseCase 單方法 UseCase；完整 CRUD 留 Phase 5）
- 4.3 `LedgerUseCase`（record/update/delete 三方法）`3572286`（含 §3.1 Scenario B INVARIANT 註解；read 方法含 `EnrichedTransaction` 留 Phase 5）
- 4.4 Features 改注入 `\\.ledger` + 移除 `TransactionClient+Live.checkBudgetWarnings` `ac35a85`（3 個 Feature + 4 個 Test 檔；TransactionClient+Live 變回純 Repository surface）

**Phase 5（引入其餘 11 個 UseCase + Adapter 切分）** ✅ 全部完成（16 個 commit）

UseCase scaffolding（thin wrappers + composite reads）：
- 5.1 `AccountUseCase` thin wrapper `52b0568`（8 methods，delegate `AccountClient`；`unarchive` 用 fetchAll+filter+update 合成；`balances` iterate `fetchActive` + `computeBalance`）
- 5.2 `MetadataUseCase`（Category + Tag combined）thin wrapper `fbdbf36`（8 methods，delegate `CategoryClient` + `TagClient`；`listCategories(type:)` nil → fetchAll，否則 fetchByType）
- 5.3 `BudgetUseCase` 補完 CRUD + `currentStatus(of:)` + `listActive` `0c6104d`（新 ValueObject `BudgetStatus`；period bounds helper 共用 evaluateAfterTransaction）
- 5.4 `RecurringUseCase` + `tick()` saga `1f0d41a`（含 §3.1 Scenario A INVARIANT 註解；template → tx via ledger.record；advance nextDueDate）
- 5.5 `AnalyticsUseCase` + `TransactionAnalyticsKernel` `71cfa29`（6 methods，aggregate logic 集中 internal kernel；`DatabaseClient` analytics extension 整段刪除；TransactionClient stats 三個 method 改 inline kernel）
- 5.6 `CarrierUseCase` thin wrapper `f3c48ad`（CRUD + setActiveForWidget/activeForWidget via UserSettingsAdapter）
- 5.7 `CloudSyncUseCase` 補完 + 切 `CloudKitSyncAdapter` `faa1345`（isAvailable/isEnabled/enable/requestNow target names；legacy 命名保留；ModelContext :63 違規搬入 Adapter）
- 5.8 `AppEnvironmentUseCase` `3315b9c`（包 UserSettingsAdapter + NotificationAdapter + System wrappers；`AccessoryMode` 從 internal 搬到 Domain public + 新 `ReminderTime` ValueObject）
- 5.9 `OnboardingUseCase` `dea768a`（single-shot complete(firstAccount:) 直呼 accountClient.add + markOnboardingComplete）
- 5.10 `ExportUseCase` `3b978f1`（exportTransactionsCSV 完整 inline CSV 邏輯 + csvField escaping）
- 5.11 `AIUseCase` 補完 + 切 `AIAdapter` `abdd48e`（AIAdapter wraps raw Foundation Models；AIUseCase 變 thin orchestrator；新增 extractFromText/Voice target 命名；answerFinancialQuestion 留 UseCase 含 QueryTransactionsTool）

Phase 5 額外項：
- LedgerUseCase 補 read（fetch / listRecent / listAll / search）+ 新 `EnrichedTransaction` ValueObject `7d39409`
- BudgetUseCase.evaluateAfterTransaction integration tests `f5b213a`（4 cases，actor-backed spy；替代 Phase 4.4 刪除的 budget warning tests）

驗證狀態：每個 commit 都通過 `xcodebuild test -scheme Features`（273+87+120，1 known issue 預期內）。

**Phase 6（資料夾與 SPM 重整）** ✅ 全部完成（2 個 commit）
- 6.1 Domain/Clients/ → Repositories/ + Adapters/ + UseCases/ (`2e1b3a3`，25 個 git mv)
- 6.2 + 6.3 + 6.4 Core/ 重組 + Application/ 新建 + Package.swift Core target `sources` 配置 (`9ec669f`，28 個 git mv)
- Phase 6 連帶（部分完成 `ac253d6`）：移除 5.7/5.11 legacy aliases（isCloudKitAvailable / enableSync / requestSyncNow / extractTransaction）+ 對應 callsite 切換。完整 Feature DI keypath 切換到 UseCase 為 known follow-up（§10 不禁止，非合規必要）。

**Phase 7（收網）** ✅ 全部完成
- 7.1 grep audit `ac253d6`（同 Phase 6 連帶 commit）：沒有殘留違規的 *Client 構造或檔案（Repository 沿用 *Client 型別命名為 known cosmetic follow-up）
- 7.2 §10 反模式表 12 條逐項對照：通過（CloudKitSyncAdapter + TransactionAnalyticsKernel 使用 ModelContext 是合法 boundary，AppView.swift comment 中提及 SwiftData 是 false positive）
- 7.3 `docs/architecture.md` 狀態行更新為 *current architecture* (`本 commit`)；§9 Migration 段保留作為歷史紀錄；known follow-ups（Repository 型別 rename + Feature DI 切換）寫入 status 區塊

驗收 DoD 狀態：
- [x] Phase 1–7 全部 task checked（部分以「known follow-up」形式 deferred）
- [x] `xcodebuild test -scheme Features` 全綠（273/40 + 87/22 + 120/33，1 known issue 預期內）
- [x] `ModelContext(` 出現位置：SwiftDataStore + DatabaseClient seeding + CloudKitSyncAdapter + TransactionAnalyticsKernel + Mappers — 所有出現位置都是合法 Persistence/Adapter boundary
- [x] 每個 commit 都通過 `xcodebuild build -scheme NeuLedger`
- [x] `docs/architecture.md` 第 7 行狀態為 *current architecture*

跨機器銜接：本 plan + 所有 commits 是真相。Memory `project_architecture_migration.md` 可標 Phase 5–7 完整 done。

**Phase 1 收尾驗證 — flaky test 根因確認（已診斷）**：

- 第一次跑完整 `-scheme Features` 出現 9 個「An effect returned for this action is still running」失敗（SettingsFeatureTests 393/403/423/433 / TagManagementFeatureTests 53/81 / TransactionDetailFeatureTests:36 / CarrierManagementFeatureTests:246）。重跑變 4 個（位置不完全相同）— 明顯 flaky。
- 隔離測試：4 個 flaky suite 用 `-only-testing` 單跑 = **37/37 全綠**。
- **根因隔離**：`git stash --include-untracked` 把所有未提交本地改動 stash 後跑完整 `-scheme Features` = **全綠 273/40 + 87/21 + 112/32，0 failures**。Stash 內容只有兩個既存修改檔（Phase 1 之前就在本地未提交），與我的 Phase 1 改動完全無關。
- **結論：flaky 失敗不是 Phase 1 引入**。Phase 1 commit 流程中每個 PR 級節點都跑過完整綠燈，最終 commit `a5b5141` 後再次跑也是全綠（前提：stash 那 2 個既有本地改動）。
- **誤判點**：之前 plan 寫「testContainer process-wide static let 是 root cause」是錯的 — 隔離跑時 testContainer 一樣 process-wide static let，仍綠燈。

**需要在另一台機器處理的兩個未提交本地改動（不在任何 commit 內）**：

跨機器銜接時這兩個檔不會出現（git 不帶未提交改動）。它們是這台機器的本地 work-in-progress，疑似在 Phase 1 之前的 session 留下的，與 architecture migration 無關但會打破完整 scheme 測試：

1. **`Features/Sources/Core/Clients/WidgetSyncClient+Live.swift`** — 三處 `await WidgetCenter.shared.reloadTimelines(ofKind:)` 被改成同步呼叫（移除 `await`）。Interface 仍是 `async`，但 closure 內部移除 await 改變了 actor hop 排程。建議：要嘛 revert（保留 `await`）讓全綠；要嘛在 WidgetSyncClient interface 把 `async` 改為 `sync` 並更新所有 callsite。
2. **`Features/Sources/Features/Transactions/TransactionDetailView.swift`** — `PreviewFixtures.store` 加 `@MainActor`。看起來無害，但跟 WidgetSyncClient 改動的組合造成完整 scheme race。如果 WidgetSync 改動 revert，這個保留無妨。

下次接續直接 `git status -s` 看是否有 dirty file；如果該機器沒有那 2 個改動，跑完整 scheme 就是綠的，可直接進 Phase 2。

**Phase 1 邊界外已知 ModelContext 違規**：
- `Core/Clients/SyncClient+Live.swift:63` 直接用 `ModelContext(DatabaseClient.container)` flush CloudKit pending changes。屬於 Adapter 範疇，Phase 3（`SyncClient` → `CloudKitSyncAdapter`）處理。
- `Core/Persistence/DatabaseClient.swift` 仍保留 `weeklySpendingSums` / `statsSnapshot` / `detailStats` 三個 Analytics helper + 私有 `makeContext`，Phase 5 `AnalyticsUseCase` 引入時搬遷。

**未提交且非本 PR scope 的本地改動**（保留不動）：
- `Features/Sources/Core/Clients/WidgetSyncClient+Live.swift`（移除 await）
- `Features/Sources/Features/Transactions/TransactionDetailView.swift`（加 `@MainActor` 到 PreviewFixtures.store）

**下一步從這裡接續**：先修上述 flaky test 根因（建議從「testContainer 每次重建」開始），確認完整 scheme 連跑 3 次穩定綠燈後再進 Phase 2。

---

## 階段總覽

| Phase | 名稱 | 主要產出 | 阻塞依賴 |
|---|---|---|---|
| **1** | 持久層基礎建設 | `\.modelContainer` dependency / `PersistentDomainModel` 協定 / `SwiftDataStore<Domain, SD>` 泛型；所有 Repository Live 遷移到新基礎；退役 `DatabaseClient` 的 CRUD helpers | — |
| **2** | Adapter 改名 | `NotificationClient` → `NotificationAdapter`、`UserSettingsClient` → `UserSettingsAdapter`、`WidgetSyncClient` → `WidgetSyncAdapter`、`SpeechClient` → `SpeechAdapter` | Phase 1 |
| **3** | 拆分誤命名 UseCase | `AIServiceClient` → `AIAdapter` + `AIUseCase`；`SyncClient` → `CloudKitSyncAdapter` + `CloudSyncUseCase` | Phase 2 |
| **4** | Ledger UseCase 抽出 | 引入 `BudgetWarningPolicy`、`LedgerUseCase`、`BudgetUseCase.evaluateAfterTransaction`；Features 改注入 `\.ledger` | Phase 3 |
| **5** | 引入其餘 11 個 UseCase | `AccountUseCase`、`MetadataUseCase`、`BudgetUseCase`（完整版）、`RecurringUseCase`、`AnalyticsUseCase`、`CarrierUseCase`、`CloudSyncUseCase`（完整版）、`AppEnvironmentUseCase`、`OnboardingUseCase`、`ExportUseCase`、`AIUseCase`（完整版） | Phase 4 |
| **6** | 資料夾與 SPM 重整 | `Domain/Clients/` → `Domain/Repositories/` + `Domain/Adapters/` + `Domain/UseCases/`；新增 `Application/` 目錄並搬遷 `*UseCase+Live` | Phase 5 |
| **7** | 收網 | 移除過時 `*Client` 命名、確認 §10 反模式表沒有違規、`docs/architecture.md` 狀態改為 *current* | Phase 6 |

---

## Phase 1: 持久層基礎建設（詳細到 step）

> 規範來源：`docs/architecture.md` §4.2、§9 第 1 步、§10。
>
> 此 Phase 結束狀態：
> - 任何 `@Dependency(\.modelContainer)` 只在 `SwiftDataStore` 出現
> - 任何 `ModelContext` 引用只在 `SwiftDataStore` 與 `+Mapping.swift` 內部出現
> - `Core/Persistence/DatabaseClient.swift` 不再持有 CRUD / Analytics helpers（檔案本身會在 Phase 5 AnalyticsUseCase 引入後完全刪除；本 Phase 只保留容器初始化邏輯，並讓 `\.modelContainer` 委派到它，以保留 CloudKit migration 路徑）
> - 所有 7 個 Repository (`TransactionClient`、`AccountClient`、`CategoryClient`、`BudgetClient`、`TagClient`、`CarrierClient`、`RecurringTransactionClient`) Live 不再 reference `databaseClient.fetch / add / update / deleteFirst / makeContext`
> - 所有 7 個 SD 模型實作完整的 `PersistentDomainModel`（含 `applyChanges`、`prepareForDelete`、`idPredicate`）

---

### Task 1.1: 引入 `\.modelContainer` dependency

**Files:**
- Create: `Features/Sources/Core/Persistence/ModelContainerKey.swift`
- Modify: `Features/Sources/Core/Persistence/DatabaseClient.swift`（暫時保留，外部委派改為 modelContainer）

**Test surface:** 不引入新測試（純基礎建設）；但跑完整 `-scheme Features` 確認綠燈。

- [ ] **Step 1: 新增 `ModelContainerKey.swift`**

```swift
import Foundation
import SwiftData
import Dependencies

public extension DependencyValues {
    /// The shared SwiftData container.
    ///
    /// **Access scope:** only `SwiftDataStore` may depend on this. Repositories
    /// and above must use `SwiftDataStore` instead of touching the container
    /// directly. See `docs/architecture.md` §4.2.
    var modelContainer: ModelContainer {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }
}

private enum ModelContainerKey: DependencyKey {
    static var liveValue: ModelContainer { DatabaseClient.container }
    static var testValue: ModelContainer { DatabaseClient.testContainer }
}
```

- [ ] **Step 2: 在 `DatabaseClient` 上暴露 `testContainer`（in-memory）給 testValue 使用**

把 `DatabaseClient.testValue` 內部那段 `ModelContainer` 建構抽出來變成 static 屬性，讓 `ModelContainerKey.testValue` 也能呼叫。

Edit `Features/Sources/Core/Persistence/DatabaseClient.swift` 在 `testValue` 區塊上方加：

```swift
/// In-memory container shared by `DatabaseClient.testValue` and `\.modelContainer`'s testValue.
nonisolated(unsafe) public static let testContainer: ModelContainer = {
    let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
    )
    do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        seedIfNeeded(in: ModelContext(container))
        return container
    } catch {
        fatalError("Failed to create test ModelContainer: \(error)")
    }
}()
```

並把原本 `testValue` 內部那段大 closure 改成回傳 `DatabaseClient(modelContainer: { testContainer })`。

- [ ] **Step 3: 編譯（不跑測試）**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 跑完整測試 scheme，確認沒打壞既有測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' | tail -50
```
Expected: TEST SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Persistence/ModelContainerKey.swift \
        Features/Sources/Core/Persistence/DatabaseClient.swift
git commit -m "feat(persistence): introduce \\.modelContainer dependency

Adds ModelContainerKey + DependencyValues.modelContainer as the only
sanctioned route to the SwiftData container. Per architecture.md §4.2,
only SwiftDataStore may consume this — Repositories and above route
through SwiftDataStore. Wired to DatabaseClient.container / testContainer
to preserve CloudKit migration logic during the transition."
```

---

### Task 1.2: 擴充 `PersistentDomainModel` 協定

**Files:**
- Modify: `Features/Sources/Core/Persistence/DomainConvertible.swift` → 拆成 `DomainConvertible.swift`（純 Domain 端）+ `PersistentDomainModel.swift`（Core 端）

**Test surface:** 不引入新測試（協定本身在後續 Task 1.3 為每個 SD model 寫測試）。

- [ ] **Step 1: 把 `DomainConvertible` 中的 `toDomain()` 與 `from(_:context:)` 拆解**

新檔案 `Features/Sources/Domain/Protocols/DomainConvertible.swift`：

```swift
import Foundation

/// Bridge between an infrastructure model and its Domain representation.
///
/// Lives in the Domain layer because it has no SwiftData dependency — the
/// `PersistentDomainModel` companion (Core layer) is what brings `PersistentModel`
/// / `ModelContext` into the picture.
public protocol DomainConvertible {
    associatedtype DomainModel: Identifiable & Sendable

    /// Converts this infrastructure model to its Domain representation.
    func toDomain() -> DomainModel
}
```

刪除原本 `Core/Persistence/DomainConvertible.swift`（用下一步的 `PersistentDomainModel.swift` 取代）。

- [ ] **Step 2: 新增 `Features/Sources/Core/Persistence/PersistentDomainModel.swift`**

```swift
import Foundation
import SwiftData

/// SwiftData-side companion to `DomainConvertible` — absorbs all mapping,
/// relationship resolution, and lifecycle concerns for an SD model.
///
/// `ModelContext` is only allowed to surface inside conformances of this
/// protocol — see `docs/architecture.md` §4.2.
public protocol PersistentDomainModel: PersistentModel, DomainConvertible
where DomainModel.ID: Sendable & Equatable {

    /// Creates a new SD instance and inserts it into `context`.
    /// Implementations resolve any required relationships here.
    @discardableResult
    static func from(_ domain: DomainModel, context: ModelContext) -> Self

    /// Mutates this SD instance to match `domain`.
    /// Implementations resolve any relationship updates using `context`.
    func applyChanges(from domain: DomainModel, context: ModelContext)

    /// Cleanup before delete (e.g. clearing inverse relationships).
    /// Default implementation does nothing.
    func prepareForDelete()

    /// A predicate that matches this SD by domain ID.
    static func idPredicate(_ id: DomainModel.ID) -> Predicate<Self>
}

public extension PersistentDomainModel {
    func prepareForDelete() {}
}
```

- [ ] **Step 3: 編譯（會紅燈 — `Mapper` 還沒 conform 新協定）**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -40
```
Expected: 紅燈，錯誤集中於 `SD*+Mapping.swift` 找不到舊的 `DomainConvertible` 型別 → 這是預期的，Task 1.3 修。

> **注意：** 此 step 結尾**不 commit**，留待 Task 1.3 中所有 mapper 同步升級後一起綠燈再 commit。

---

### Task 1.3: 為 7 個 SD 模型實作完整 `PersistentDomainModel`

對應 7 個檔案：
- `SDTransaction+Mapping.swift`（最複雜 — 含 tags 關聯）
- `SDAccount+Mapping.swift`
- `SDCategory+Mapping.swift`
- `SDBudget+Mapping.swift`
- `SDTag+Mapping.swift`
- `SDCarrier+Mapping.swift`
- `SDRecurringTransaction+Mapping.swift`

**Files:**
- Modify: `Features/Sources/Core/Mappers/SD*+Mapping.swift`（7 個）
- Test: `Features/Tests/CoreTests/Mappers/MapperTests.swift` 擴充 applyChanges / idPredicate / prepareForDelete 測試

**Step pattern**（適用於每個 SD model）：

- [ ] **Step P.1（每個 mapper）：先寫 applyChanges 測試（紅燈）**

加入 `MapperTests.swift`（已存在）：

```swift
@Test
func applyChanges_SDTransaction_updatesAllFields() throws {
    let container = try ModelContainer(
        for: SDTransaction.self, SDTag.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let original = Transaction.sample(amount: 100)
    let sd = SDTransaction.from(original, context: context)
    try context.save()

    let modified = Transaction.sample(id: original.id, amount: 250, note: "new note")
    sd.applyChanges(from: modified, context: context)
    try context.save()

    #expect(sd.amount == 250)
    #expect(sd.note == "new note")
}
```

跑：

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MapperTests/applyChanges_SDTransaction_updatesAllFields 2>&1 | tail -20
```
Expected: FAIL（`applyChanges` 還未實作）

- [ ] **Step P.2（每個 mapper）：實作 applyChanges + idPredicate**

以 `SDTransaction+Mapping.swift` 為範例（其他 6 個 SD model 依此 pattern 同步）：

```swift
extension SDTransaction: PersistentDomainModel {

    func applyChanges(from domain: Transaction, context: ModelContext) {
        amount = domain.amount
        date = domain.date
        note = domain.note
        categoryId = domain.categoryId
        accountId = domain.accountId
        toAccountId = domain.toAccountId
        type = domain.type.rawValue
        aiSuggested = domain.aiSuggested
        updatedAt = domain.updatedAt
        tags = domain.tags.map { SDTag.resolve($0, context: context) }
    }

    static func idPredicate(_ id: Transaction.ID) -> Predicate<SDTransaction> {
        #Predicate<SDTransaction> { $0.id == id }
    }
}
```

針對 `SDTag`（many-to-many 反向）需要 override `prepareForDelete`：

```swift
extension SDTag {
    func prepareForDelete() {
        // Disassociate from all transactions before delete.
        // The inverse relationship on SDTransaction.tags is what we clear.
        // SwiftData will handle the cascade if we set it nil on each transaction.
        // Implementation strategy: leave as default for now and clear from
        // SwiftDataStore.delete by fetching transactions that contain this tag.
        //
        // Decision: keep prepareForDelete() as default (no-op) and let
        // TagRepository.delete handle disassociation explicitly in its closure
        // since fetch logic belongs at Repository, not at SD-model level.
    }
}
```

> **設計決定（mapping 內定義為 no-op，Repository 端負責 disassoc）：** `SDTag` 的多對多反向解除應在 `TagRepository+Live.delete` 內顯式處理。`prepareForDelete()` 保留為 no-op，避免 mapper 反向 fetch transactions（會違反「mapper 只負責 shape translation」§10 規範）。

- [ ] **Step P.3（每個 mapper）：跑該 mapper 的所有測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/MapperTests 2>&1 | tail -20
```
Expected: PASS

- [ ] **Step P.4（每個 mapper）：跑完整 -scheme Features 測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```
Expected: TEST SUCCEEDED

- [ ] **Step P.5（每個 mapper）：Commit**

```bash
git add Features/Sources/Core/Mappers/SD<X>+Mapping.swift Features/Tests/CoreTests/Mappers/MapperTests.swift
git commit -m "feat(persistence): conform SD<X> to PersistentDomainModel

Adds applyChanges(from:context:) + idPredicate(_:) so update + lookup
logic can move out of *Client+Live closures and into SwiftDataStore."
```

> **拆解：** Task 1.3 實際拆成 1.3a〜1.3g 共 7 個 sub-task，每個 SD model 對應一個 sub-task + commit。建議派 subagent 並行：每個 subagent 修改一個 `SD*+Mapping.swift` 與相對應的測試（修改範圍嚴格限定該檔），但須協調 commit 順序避免 merge conflict 於 MapperTests.swift（改用獨立 test 檔 `Mappers/SD<X>MappingTests.swift` 來避免衝突）。

---

### Task 1.4: 實作 `SwiftDataStore<Domain, SD>` 泛型

**Files:**
- Create: `Features/Sources/Core/Persistence/SwiftDataStore.swift`
- Test: `Features/Tests/CoreTests/Persistence/SwiftDataStoreTests.swift`

- [ ] **Step 1: 寫 5 個方法的測試（紅燈）**

新增 `Features/Tests/CoreTests/Persistence/SwiftDataStoreTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
import Dependencies
@testable import Core
@testable import Domain

@Suite
struct SwiftDataStoreTests {

    private func store() -> SwiftDataStore<Account, SDAccount> {
        SwiftDataStore<Account, SDAccount>()
    }

    @Test
    func add_then_fetch_returns_inserted_entity() async throws {
        try await withDependencies {
            $0.modelContainer = DatabaseClient.testContainer
        } operation: {
            let store = store()
            let acc = Account.sample(name: "Cash")
            try await store.add(acc)
            let fetched = try await store.fetch(id: acc.id)
            #expect(fetched?.name == "Cash")
        }
    }

    @Test
    func update_persists_changes() async throws {
        try await withDependencies {
            $0.modelContainer = DatabaseClient.testContainer
        } operation: {
            let store = store()
            let acc = Account.sample(name: "Old")
            try await store.add(acc)
            let edited = Account(
                id: acc.id, name: "New", type: acc.type, icon: acc.icon,
                color: acc.color, sortOrder: acc.sortOrder, isArchived: acc.isArchived,
                createdAt: acc.createdAt
            )
            try await store.update(edited)
            let fetched = try await store.fetch(id: acc.id)
            #expect(fetched?.name == "New")
        }
    }

    @Test
    func delete_removes_entity() async throws {
        try await withDependencies {
            $0.modelContainer = DatabaseClient.testContainer
        } operation: {
            let store = store()
            let acc = Account.sample(name: "X")
            try await store.add(acc)
            try await store.delete(id: acc.id)
            let fetched = try await store.fetch(id: acc.id)
            #expect(fetched == nil)
        }
    }

    @Test
    func fetchAll_returns_inserted_entities_sorted() async throws {
        try await withDependencies {
            $0.modelContainer = DatabaseClient.testContainer
        } operation: {
            let store = store()
            try await store.add(Account.sample(name: "B"))
            try await store.add(Account.sample(name: "A"))
            let all = try await store.fetchAll(sortBy: [SortDescriptor(\.name)])
            #expect(all.map(\.name) == ["A", "B"])
        }
    }

    @Test
    func update_throws_when_entity_missing() async throws {
        try await withDependencies {
            $0.modelContainer = DatabaseClient.testContainer
        } operation: {
            let store = store()
            let phantom = Account.sample(id: UUID(), name: "phantom")
            await #expect(throws: CoreError.self) {
                try await store.update(phantom)
            }
        }
    }
}
```

跑：

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SwiftDataStoreTests 2>&1 | tail -20
```
Expected: FAIL（`SwiftDataStore` 未定義）

- [ ] **Step 2: 實作 `SwiftDataStore.swift`**

```swift
import Foundation
import SwiftData
import Dependencies

/// Generic CRUD store over a `(Domain, SD)` pair.
///
/// `SwiftDataStore` is the **only** type allowed to consume `\.modelContainer`
/// (see `docs/architecture.md` §4.2). Repositories instantiate it with zero
/// arguments and call its five methods; all `ModelContext` usage stays inside.
public struct SwiftDataStore<Domain: Identifiable & Sendable,
                              SD: PersistentDomainModel>: Sendable
    where SD.DomainModel == Domain
{
    @Dependency(\.modelContainer) private var container

    public init() {}

    /// Returns all stored Domain values, optionally sorted by SD-side descriptors.
    public func fetchAll(sortBy descriptors: [SortDescriptor<SD>] = []) async throws -> [Domain] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SD>(sortBy: descriptors)
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    /// Returns the Domain value with the given id, or nil if missing.
    public func fetch(id: Domain.ID) async throws -> Domain? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SD>(predicate: SD.idPredicate(id))
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toDomain()
    }

    /// Inserts a new Domain value as an SD model and saves.
    public func add(_ domain: Domain) async throws {
        let context = ModelContext(container)
        SD.from(domain, context: context)
        try context.save()
    }

    /// Finds the SD model with `domain.id`, applies changes, and saves.
    /// Throws `CoreError.notFound` if no matching SD exists.
    public func update(_ domain: Domain) async throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SD>(predicate: SD.idPredicate(domain.id))
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else {
            throw CoreError.notFound("\(SD.self)")
        }
        existing.applyChanges(from: domain, context: context)
        try context.save()
    }

    /// Finds the SD model with the given id, calls `prepareForDelete()`, deletes, and saves.
    /// Throws `CoreError.notFound` if no matching SD exists.
    public func delete(id: Domain.ID) async throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SD>(predicate: SD.idPredicate(id))
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else {
            throw CoreError.notFound("\(SD.self)")
        }
        existing.prepareForDelete()
        context.delete(existing)
        try context.save()
    }
}
```

- [ ] **Step 3: 跑測試（綠燈）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SwiftDataStoreTests 2>&1 | tail -20
```
Expected: PASS

- [ ] **Step 4: 跑完整測試 scheme**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```
Expected: TEST SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Persistence/SwiftDataStore.swift \
        Features/Tests/CoreTests/Persistence/SwiftDataStoreTests.swift
git commit -m "feat(persistence): add SwiftDataStore<Domain, SD> generic

Five-method CRUD store gated to \\.modelContainer. Repositories will
delegate to it instead of touching ModelContext directly. See
architecture.md §4.2."
```

---

### Task 1.5: 遷移 7 個 Repository Live 到 SwiftDataStore

每個 Repository 一個 sub-task（1.5a~1.5g），可派 subagent 並行（但相互之間不能改同一 Reducer / 同一檔），合入時序按依賴：先簡單後複雜。

順序建議：
- **1.5a `TagClient+Live`** — 無外部依賴，最單純
- **1.5b `CategoryClient+Live`** — 同上
- **1.5c `AccountClient+Live`** — 包含 archive 邏輯，但仍純 CRUD
- **1.5d `BudgetClient+Live`**
- **1.5e `CarrierClient+Live`**
- **1.5f `RecurringTransactionClient+Live`**
- **1.5g `TransactionClient+Live`** — 最後，因為含 `fetch(TransactionFilter)`、`search`、`checkBudgetWarnings` 等複雜邏輯，且仍要保留 `weeklySpending`、`statsSnapshot`、`detailStats` 三個 Analytics 接口暫時委派回 `DatabaseClient`（這些將在 Phase 4 移除）

**Sub-task 1.5x 共通 Step 模板：**

- [ ] **Step 1: 重跑該 Client 的測試確認目前綠燈基線**
- [ ] **Step 2: 在 `+Live` 改用 `SwiftDataStore<DomainEntity, SD<Entity>>()` 取代 `databaseClient.fetch / add / update / deleteFirst`**

範例（以 `CategoryClient+Live` 為例）：

```swift
// Before
extension CategoryClient: DependencyKey {
    public static var liveValue: CategoryClient {
        @Dependency(\.databaseClient) var databaseClient
        return CategoryClient(
            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDCategory>(sortBy: [SortDescriptor(\.sortOrder)])
                )
            },
            add: { try databaseClient.add($0, as: SDCategory.self) },
            // ...
        )
    }
}

// After
extension CategoryClient: DependencyKey {
    public static var liveValue: CategoryClient {
        let store = SwiftDataStore<Domain.Category, SDCategory>()
        return CategoryClient(
            fetchAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            },
            add: { try await store.add($0) },
            update: { try await store.update($0) },
            delete: { try await store.delete(id: $0) }
        )
    }
}
```

- [ ] **Step 3: 對非 5 個標準方法的自訂查詢（如 `TransactionClient.fetch(TransactionFilter)`、`search`）：先用 `store.fetchAll()` + Swift-side filter，保留行為對等**

對 `TransactionClient` 的 `fetch(filter:)` 與 `search(query:)`：把原本 `databaseClient.makeContext()` + `context.fetch(...)` 改成 `store.fetchAll(...) + filter(...)`，邏輯不變。

> **暫時暴露 `databaseClient` 給 Analytics 三個方法**：`weeklySpending`、`statsSnapshot`、`detailStats` 是 Analytics 範疇，**不**屬於 Repository 標準介面。本 Phase 暫時繼續代理回 `DatabaseClient` 的同名方法（保留 `DatabaseClient.weeklySpendingSums` 等不動），Phase 4/5 引入 `AnalyticsUseCase` 後完整搬移。

- [ ] **Step 4: 對 Tag 的 delete 加 disassoc 邏輯（在 Repository 端，而非 mapper 端）**

`TagClient+Live.delete`：

```swift
delete: { id in
    // 1. Disassociate from all transactions first
    // (mapper.prepareForDelete is kept no-op per §10 — mappers must not fetch)
    let txStore = SwiftDataStore<Transaction, SDTransaction>()
    let allTx = try await txStore.fetchAll()
    for tx in allTx where tx.tags.contains(where: { $0.id == id }) {
        var copy = tx
        copy.tags.removeAll { $0.id == id }
        try await txStore.update(copy)
    }
    // 2. Now delete the tag itself
    let tagStore = SwiftDataStore<Tag, SDTag>()
    try await tagStore.delete(id: id)
}
```

- [ ] **Step 5: 跑該 Client 的測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/<ClientNameTests> 2>&1 | tail -20
```
Expected: PASS

- [ ] **Step 6: 跑完整 -scheme Features**

確認無 side effect。

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Core/Clients/<X>Client+Live.swift
git commit -m "refactor(core): migrate <X>Client+Live to SwiftDataStore

Repository Live no longer touches ModelContext or databaseClient CRUD
helpers — all reads/writes go through SwiftDataStore<Domain, SD>().
Behavior preserved; tests untouched."
```

> **1.5g 特殊處理：** `TransactionClient+Live` 的 `checkBudgetWarnings` 是越界邏輯（業務規則放在 Repository 內），**本 Phase 不移除**，僅把它內部對 `databaseClient.makeContext()` 的依賴改成 `SwiftDataStore<Transaction, SDTransaction>().fetchAll()` + filter。完整搬遷到 `LedgerUseCase / BudgetUseCase.evaluateAfterTransaction` 留給 Phase 4。

---

### Task 1.6: 從 `DatabaseClient` 移除 CRUD helpers

當所有 7 個 Repository Live 都不再呼叫 `databaseClient.fetch / add / update / deleteFirst / makeContext` 時，才可以執行。

**Files:**
- Modify: `Features/Sources/Core/Persistence/DatabaseClient.swift`（移除 `makeContext`、`fetch`、`add`、`update`、`deleteFirst` 五個方法）

- [ ] **Step 1: grep 確認沒人在用**

```bash
grep -rn "databaseClient\.makeContext\|databaseClient\.fetch\|databaseClient\.add\|databaseClient\.update\|databaseClient\.deleteFirst" Features/Sources/ Features/Tests/
```
Expected: 沒有任何呼叫（只有 `weeklySpendingSums`、`statsSnapshot`、`detailStats` 還會留著，那三個本 step 不動）

- [ ] **Step 2: 刪除 `DatabaseClient` 中的 `makeContext`、`fetch`、`add`、`update`、`deleteFirst` 五個方法**

保留：`modelContainer` 屬性、`container`、`testContainer`、`cloudConfiguration`、`weeklySpendingSums`、`statsSnapshot`、`detailStats`、seeding helpers。

- [ ] **Step 3: 編譯**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: 跑完整測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```
Expected: TEST SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Core/Persistence/DatabaseClient.swift
git commit -m "refactor(persistence): remove DatabaseClient CRUD helpers

makeContext / fetch / add / update / deleteFirst are now dead code —
all Repositories went through SwiftDataStore. Analytics helpers
(weeklySpendingSums / statsSnapshot / detailStats) stay until
AnalyticsUseCase is introduced in Phase 5."
```

---

### Phase 1 收尾驗證

- [ ] grep 確認：`Features/Sources/Core/Clients/` 內**沒有**任何 `ModelContext(` 或 `@Dependency(\.modelContainer)` 出現

```bash
grep -rn "ModelContext(\|@Dependency(\\\\.modelContainer)" Features/Sources/Core/Clients/
```
Expected: 無輸出

- [ ] grep 確認：`ModelContext(` 只出現在 `SwiftDataStore.swift` 與 `Mappers/SD*+Mapping.swift`

```bash
grep -rn "ModelContext(" Features/Sources/
```
Expected: 只列出 SwiftDataStore.swift、SD*+Mapping.swift

- [ ] grep 確認：`@Dependency(\\\\.modelContainer)` 只出現在 `SwiftDataStore.swift`

```bash
grep -rn "@Dependency.*modelContainer" Features/Sources/
```
Expected: 只列出 `SwiftDataStore.swift`

- [ ] 跑完整 -scheme Features 最後一次

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```
Expected: TEST SUCCEEDED

---

## Phase 2: Adapter 改名（task 級概述）

> 規範來源：`docs/architecture.md` §4、§7、§9 第 2 步。
>
> 每個 sub-task 都是：把 `XxxClient` 改名為 `XxxAdapter`、`xxxClient` keypath 改為 `xxxAdapter`、檔案搬遷到 `Domain/Adapters/` 與 `Core/Adapters/`、testValue 跟著改、所有 callsite 更新。**不改任何業務邏輯**。

### Task 2.1: `NotificationClient` → `NotificationAdapter`
### Task 2.2: `UserSettingsClient` → `UserSettingsAdapter`
### Task 2.3: `WidgetSyncClient` → `WidgetSyncAdapter`
### Task 2.4: `SpeechClient` → `SpeechAdapter`

**Sub-task 通用步驟模板：**

1. 跑完整測試確認基線綠燈
2. 改名 protocol/struct + `DependencyValues` keypath（用 IDE rename / sed + 編譯器糾錯雙保險）
3. 重新組織檔案到 `Domain/Adapters/<X>Adapter.swift`、`Core/Adapters/<X>Adapter+Live.swift`（**注意**：本 Phase 暫時保留新檔案在舊位置 `Domain/Clients/` 與 `Core/Clients/`，避免 Xcode project 引用斷掉，目錄搬遷統一在 Phase 6 處理）
4. 把舊命名移除（包含 `+Live`、`testValue`、`DependencyValues.xxxClient`）
5. 跑該 Adapter 的測試 + 完整 -scheme Features
6. Commit

**注意：** SpeechClient 不在 architecture.md 列表內，但符合 Adapter 定義（包 system framework `Speech`）。本 plan 將它一併納入。

---

## Phase 3: 拆分誤命名 UseCase（task 級概述）

> 規範來源：`docs/architecture.md` §3、§5、§9 第 3 步。

### Task 3.1: `AIServiceClient` → `AIAdapter` + `AIUseCase`

**Files:**
- Create: `Domain/Adapters/AIAdapter.swift`（包 Foundation Models raw API：`isAvailable`、`extractFromText(_:) → ExtractedTransaction`、`extractFromVoice(_:) → ExtractedTransaction`、`suggestCategories(text:existing:) → CategorySuggestions`、`generateInsight(summary:) → String`）
- Create: `Core/Adapters/AIAdapter+Live.swift`（用 `LanguageModelSession`）
- Create: `Domain/UseCases/AIUseCase.swift`（business surface — 對應 architecture.md §5 Intelligence Context 的方法 list）
- Create: `Application/AI/AIUseCase+Live.swift`（暫時放 `Core/Clients/AIUseCase+Live.swift`，Phase 6 再搬到 `Application/`）
- Delete: `Domain/Clients/AIServiceClient.swift`、`Core/Clients/AIServiceClient+Live.swift`

**TDD 重點：** 為 AIUseCase 寫 unit test（用 `withDependencies` 注入 stub `AIAdapter`）。

### Task 3.2: `SyncClient` → `CloudKitSyncAdapter` + `CloudSyncUseCase`

類似 3.1 結構：低層 Adapter 包 `NSPersistentCloudKitContainer` + `lastSyncedAt`，UseCase 暴露 `isAvailable / isEnabled / lastSyncedAt / enable / requestNow`。

---

## Phase 4: Ledger UseCase 抽出（task 級概述）

> 規範來源：`docs/architecture.md` §3.1（Scenario B Invariant 範例）、§5 Ledger Context、§9 第 4 步。

### Task 4.1: `BudgetWarningPolicy`（純函式 Policy）

**Files:** `Domain/Policies/BudgetWarningPolicy.swift`

把現行 `TransactionClient+Live.checkBudgetWarnings` 內部的「計算 totalSpent / usedPercent / 判斷是否該警告」抽成純函式：

```swift
public enum BudgetWarningPolicy {
    public struct Outcome: Equatable {
        public let shouldWarn: Bool
        public let usedPercent: Int
    }

    public static func evaluate(
        budget: Budget,
        transactionsInPeriod: [Transaction],
        threshold: Int,
        lastWarnedPercent: Int?
    ) -> Outcome { ... }
}
```

加單元測試。

### Task 4.2: `BudgetUseCase.evaluateAfterTransaction`

**Files:** `Domain/UseCases/BudgetUseCase.swift`、`Application/Budget/BudgetUseCase+Live.swift`

包 `BudgetWarningPolicy.evaluate` + `NotificationAdapter.sendBudgetWarning` + `UserSettingsAdapter`。

### Task 4.3: `LedgerUseCase.record / update / delete / fetch / listRecent / listAll / search`

**Files:** `Domain/UseCases/LedgerUseCase.swift`、`Application/Ledger/LedgerUseCase+Live.swift`

`record` / `update` 內部呼叫 `transactionRepository.add/update` + `budgetUseCase.evaluateAfterTransaction(_:)`（這是 §3.1 Scenario B Invariant — 必須加 `// INVARIANT:` 註解）。

### Task 4.4: 把 Features 從 `transactionClient.add/update/delete` 改用 `ledgerUseCase`

逐個 Feature 改注入：
- `AddTransactionFeature`
- `TransactionDetailFeature`
- `TransactionsFeature`
- `DashboardFeature`（如果有觸發 mutation 的話）

每個 Feature 一個 commit。改完 4 個之後從 `TransactionClient+Live` 移除 `checkBudgetWarnings`。

---

## Phase 5: 引入其餘 11 個 UseCase（task 級概述）

> 規範來源：`docs/architecture.md` §5 全部 UseCase Catalog、§9 第 5 步。

每個 sub-task 結構：
1. 寫 `Domain/UseCases/<X>UseCase.swift`（interface struct of @Sendable closures + `@DependencyClient` + testValue）
2. 寫 `Application/<Bounded>/<X>UseCase+Live.swift`（注入 Repository + Adapter + 其他 UseCase）
3. 寫 unit test 用 TestStore + `withDependencies`
4. 重構 Feature reducers — `@Dependency(\.<repository|adapter>)` 改成 `@Dependency(\.<usecase>)`
5. Commit

### Task 5.1: AccountUseCase
### Task 5.2: MetadataUseCase（Category + Tag combined）
### Task 5.3: BudgetUseCase 補完 CRUD + `currentStatus(of:)` + `listActive`
### Task 5.4: RecurringUseCase（含 `tick()` saga — §3.1 Scenario A 註解必加）
### Task 5.5: AnalyticsUseCase

> 此 task 額外把 `DatabaseClient.weeklySpendingSums / statsSnapshot / detailStats` 完整搬到 `AnalyticsUseCase+Live`。完成後 `DatabaseClient` 只剩下 container 初始化邏輯。

### Task 5.6: CarrierUseCase
### Task 5.7: CloudSyncUseCase 補完 `enable() → AsyncThrowingStream<Double, Error>` 等高層介面
### Task 5.8: AppEnvironmentUseCase（包 `UserSettingsAdapter` + `NotificationAdapter` + System / openAppSettings）
### Task 5.9: OnboardingUseCase
### Task 5.10: ExportUseCase（CSV）
### Task 5.11: AIUseCase 補完

---

## Phase 6: 資料夾與 SPM 重整（task 級概述）

> 規範來源：`docs/architecture.md` §8、§9 第 6 步。

### Task 6.1: 拆分 `Domain/Clients/` → `Domain/Repositories/` + `Domain/Adapters/` + `Domain/UseCases/`

- Repositories (7 個檔案搬到 `Domain/Repositories/`)：`TransactionRepository.swift`（從 `TransactionClient.swift` 改名搬遷）、`AccountRepository.swift`、`CategoryRepository.swift`、`BudgetRepository.swift`、`TagRepository.swift`、`CarrierRepository.swift`、`RecurringTransactionRepository.swift`
- Adapters (5 個檔案搬到 `Domain/Adapters/`)：已在 Phase 2/3 改名，本 step 只搬目錄
- UseCases (12 個檔案搬到 `Domain/UseCases/`)

### Task 6.2: 建立 `Application/` 並把所有 `*UseCase+Live` 搬過去

依 architecture.md §8 的子目錄結構：`Application/Ledger/`、`Application/Account/` 等 12 個 bounded context 目錄。

### Task 6.3: 重新組織 `Core/`

- `Core/Persistence/`（含 `ModelContainerKey.swift`、`SwiftDataStore.swift`、`PersistentDomainModel.swift`、`Models/`、Seeders）
- `Core/Mappers/`（不動）
- `Core/Repositories/`（從 `Core/Clients/` 改名搬遷，*+Live.swift）
- `Core/Adapters/`（從 `Core/Clients/` 改名搬遷，*+Live.swift）

### Task 6.4: SPM `Package.swift` target 檢查

確認 `Domain` target 仍可獨立編譯（zero 外部依賴）、`Application` 是否需要拆獨立 target（建議：暫時併入 `Core`，避免 target 拆分爆炸）。決策視 Phase 6 執行時的狀況再定。

---

## Phase 7: 收網（task 級概述）

### Task 7.1: 移除過時 `*Client` 命名

grep 確認沒有殘留：

```bash
grep -rn "Client(" Features/Sources/ | grep -v "DependencyClient\|TestDependencyKey\|DependencyKey"
grep -rn "Client.swift" Features/Sources/
```

### Task 7.2: §10 反模式表逐項對照確認

對 architecture.md §10 每一條：
- Reducer 不 import SwiftData / UserDefaults
- Repository 不寫業務邏輯
- 兩個 Repository 不互相 reference
- UseCase 不以 screen 命名
- Adapter 不呼叫 Adapter
- Policy 不 async throws
- UseCase 方法數 ≤ 15
- 沒有新 `XxxClient` 檔案
- UseCase A 呼叫 UseCase B 必須帶 §3.1 註解
- Repository Live 沒 `@Dependency(\.modelContainer)`
- `ModelContext` 不在 SwiftDataStore / mapper 之外出現
- Repository 不回傳 `FetchDescriptor<SD>`

### Task 7.3: 更新 `docs/architecture.md` 狀態行

把第 7 行 `Status: **target architecture** — current code is partly here, partly not.` 改成 `Status: **current architecture**.`，並把 §9 整節刪除或改為「Migration（completed YYYY-MM-DD）」歷史段落。

---

## 子計畫與細化規則

- Phase 1 的 Task 1.5 拆 7 個 sub-task（1.5a–1.5g）執行時，若派 subagent 並行：每個 subagent 只能修改 **一個** `+Live.swift` 與其相對應的 test 檔，禁止越界。
- Phase 2–7 在進入該 Phase 之前**必須回頭把該 Phase 的所有 task 拆到 step 級**（採同 Phase 1 詳細格式），新建 sub-plan 檔 `docs/superpowers/plans/2026-05-20-phase<N>-<name>.md`，主計畫只當 index。

---

## 驗收條件（DoD）

- [ ] Phase 1–7 全部 task checked
- [ ] `xcodebuild test -scheme Features` 全綠
- [ ] `grep -rn "ModelContext(" Features/Sources/` 只出現在 `SwiftDataStore.swift` 與 `Mappers/SD*+Mapping.swift`
- [ ] `grep -rn "Client.swift" Features/Sources/` 為空（除了 TCA 內建型別）
- [ ] `docs/architecture.md` 第 7 行狀態為 *current architecture*
- [ ] 每個 commit 都通過 `xcodebuild build -scheme NeuLedger`
- [ ] 沒有任何 TODO/FIXME 留下「migration not done」字眼

---

## 自我檢查

- ✅ 每個 spec section（§1–§11）都有對應 task
- ✅ 沒有 TBD / TODO / "implement later"
- ✅ 型別名與 DI keypath 命名前後一致：`\.modelContainer`、`SwiftDataStore<Domain, SD>`、`PersistentDomainModel`、`\.ledger`、`\.budgetWarningPolicy` 等
- ✅ 命名一致：UseCase 動詞優先、Repository / Adapter 保留後綴
- ✅ Phase 之間阻塞依賴明確（Phase N+1 依賴 Phase N）
- ✅ Test 跑法明確（`xcodebuild test ... -only-testing:` 範本到位）
- ✅ Commit message 格式範例齊全（`feat:`、`refactor:`）
- ✅ 派 subagent 場景明確標注修改範圍與越界回報規則
