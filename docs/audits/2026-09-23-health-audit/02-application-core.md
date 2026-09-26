# Application + Core 層唯讀體檢報告

範圍：`Features/Sources/Application/`（6 個 Client Live）+ `Features/Sources/Core/`
（SD 模型、`SwiftDataStore`、mappers、adapters、`TransactionAnalyticsKernel`、
`Core/Adapters/Watch/`、`PersistenceBootstrap`），共 ~50 檔 / 約 4,500 行，全數讀過。
分支 `developer`。已排除 `known-issues.md` 條目（重疊者列在 §C）。

---

## A. 潛在 bug（依嚴重度排序）

### A1. `wipeAllSyncData` 之後預設分類永遠回不來 — 嚴重度 High
- 位置：`Features/Sources/Application/Platform/PlatformClient+Live.swift:142-176`；
  seeding 唯二呼叫點 `Features/Sources/Core/Persistence/PersistenceBootstrap.swift:86,108`
- 觸發：設定頁「抹除所有資料」（`SettingsFeature.swift:376-391` → `wipeAllSyncData`）。
- 結果：`context.delete(model: SDCategory.self)` 把 14 筆預設分類全刪，接著重建
  `localContainer` 並指派給 `PersistenceBootstrap.container`（行 166-170）。
  行 164-165 的註解宣稱「so the next `seedIfNeeded` runs」，但 `seedIfNeeded` 是
  `private extension PersistenceBootstrap` 的私有函式，只在兩個 static lazy
  initializer 內被呼叫；那兩個 initializer 在 process 生命週期中早已執行完畢，
  重新指派 `container` 不會再觸發任何 seeding。使用者被導回 onboarding、建完帳戶後
  進入記帳頁，**分類清單是空的**，直到下次冷啟動才恢復。
- 修法：把 `seedIfNeeded` 改 `internal`，在 `wipeAllSyncData` 重建 container 後
  顯式呼叫一次（同時補一個測試斷言分類數量 > 0）— 工作量 S

### A2. 週期交易只要錯過一次通知就永久停擺（`tick()` 是完全沒接上的死碼） — 嚴重度 High
- 位置：`Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift:88-134`
  （`makeTick`）；提醒排程 `Features/Sources/Core/Adapters/NotificationAdapter+Live.swift:77-95`；
  唯一推進點 `Features/Sources/Features/MainTab/MainTabFeature.swift:118-131`
- 觸發：建立任一週期交易 → 到期通知跳出 → 使用者滑掉 / 未點擊（或當下未授權通知）。
- 結果：`ledgerClient.tick()` 在整個 production 程式碼中**零呼叫點**（全域 grep 只命中
  介面宣告、Live 實作、文件註解與測試），所以沒有任何自動物化。實際運作路徑是
  「一次性通知 → 使用者點擊 → `AddTransactionFeature` 確認記帳 → delegate →
  `MainTabFeature` 用 `updateRecurring` 推進 `nextDueDate` 並重排提醒」。而
  `scheduleRecurringReminder` 用的是 `UNCalendarNotificationTrigger(..., repeats: false)`
  （行 88），一旦這一發打掉且使用者沒點，`nextDueDate` 停在過去、沒有任何新通知被排，
  該週期交易就**永久沉默**，管理頁仍顯示為「啟用中」。
- 順帶：即使把 `tick()` 接上，行 129-131 每次只推進一期
  (`nextDate(after: template.nextDueDate)`)，App 三個月沒開的月繳範本要開三次 App 才補完。
- 修法：在 App 啟動（`AppFeature.task` 或 `MainTabFeature.task`）呼叫 `ledgerClient.tick()`，
  並把行 129-131 改成 `while advanced.nextDueDate <= today` 迴圈補跑 — 工作量 M

### A3. 開啟 iCloud 同步 / 抹除資料後，`\.modelContainer` 依賴快取仍指向舊 container — 嚴重度 High
- 位置：`Features/Sources/Core/Persistence/ModelContainerKey.swift:17-20`；
  改寫點 `Features/Sources/Core/Adapters/CloudKitSyncAdapter+Live.swift:18-24` 與
  `Features/Sources/Application/Platform/PlatformClient+Live.swift:166-170`
- 觸發：設定頁開啟 iCloud 同步（`enableSync` → `switchToCloudContainer`），之後不重啟 App 直接記帳。
- 結果：`ModelContainerKey.liveValue` 是 computed property，但 swift-dependencies 的
  `CachedValues` 以 key 型別為單位快取解析結果，首次解析後就固定住那個
  `ModelContainer` 實例。`switchToCloudContainer()` 只換掉
  `PersistenceBootstrap.container` 這個 static var，**已快取的 `\.modelContainer` 不會更新**，
  於是所有 `SwiftDataStore` 仍寫入 `cloudKitDatabase: .none` 的舊 container。
  兩個 container 指向同一個 SQLite 檔（`localConfiguration` / `cloudConfiguration`
  共用 `storeURL`，`PersistenceBootstrap.swift:60-70`），所以資料不會遺失，但
  **這一輪 App 生命週期內新增的資料不會被 CloudKit mirroring 上傳**，要等下次冷啟動。
  `wipeAllSyncData` 同理。
- 修法：讓 `PersistenceBootstrap` 暴露一個 `reset(to:)`，在換 container 後同步
  `DependencyValues` 的快取（最簡：把 container 包一層 `final class ContainerBox`
  當 dependency，換的是 box 內容而非 box 本身）— 工作量 M

### A4. 多裝置 CloudKit 同步後的重複預設分類會讓多個 join 直接 crash — 嚴重度 High
- 位置：`Features/Sources/Application/Ledger/LedgerClient+Live.swift:90-91`、`164`；
  `Features/Sources/Application/Insights/InsightsClient+Live.swift:133,144`
- 觸發：兩台裝置各自冷啟動（各自在本機 seed 出 14 筆 `isDefault` 分類）→ 之後才開啟同步。
- 結果：`seedIfNeeded` 的 stable-ID 去重（`PersistenceBootstrap.swift:237-253`）只防得住
  **同一個 store 內**的重複；NSPersistentCloudKitContainer 以 store object ID 產生
  CKRecord name，兩台裝置的「Food」是兩筆不同 CKRecord，同步後同一台裝置會有兩筆
  `id == 9E0FED11-CCCC-0000-0000-000000000001` 的 `SDCategory`。此時
  `Dictionary(uniqueKeysWithValues:)` 直接 trap（`Fatal error: Duplicate values for key`），
  而 `enrich` 是 `listRecent` / `listAll` / `search` / `fetch` 的共同路徑 ——
  Dashboard 一開就 crash，且無法自行恢復。
  佐證：同檔的 `makeExportCSV` 已經用 `uniquingKeysWith: { first, _ in first }`
  （`LedgerClient+LiveExport.swift:23-30`），顯示這個風險在專案內是被知道的，只是沒推廣。
- 修法：五處全部改成 `Dictionary(_:uniquingKeysWith:)`；另外對 SD 模型的
  `id` 加 `#Unique` 或在 seeding 後做一次去重掃描 — 工作量 S（改 Dictionary）/ M（含去重）

### A5. 暫停（`isActive = false`）週期交易時，提醒不但沒取消還被重新排程 — 嚴重度 Med
- 位置：`Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift:63-76`；
  呼叫端 `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift:70-84`
- 觸發：管理頁把某個週期交易的開關切到關閉。
- 結果：`toggleActiveTapped` 呼叫 `ledger.updateRecurring(updated)`，而
  `makeUpdateRecurring` **無條件**呼叫 `scheduleRecurringReminder(template.id, template.nextDueDate, ...)`，
  完全沒有 `isActive` 分支。使用者暫停了範本，到期日仍然會跳出「該記帳了」通知；
  點下去還會進入確認記帳流程。呼叫端行 79-80 的註解「Reminder scheduling/cancellation
  is a post-condition of updateRecurring」與實作不符。
- 修法：`makeUpdateRecurring` 內 `if template.isActive { schedule } else { cancel }` — 工作量 S

### A6. 刪除分類不清理引用，交易與預算留下孤兒 `categoryId` — 嚴重度 Med
- 位置：`Features/Sources/Application/Ledger/LedgerClient+LiveCatalog.swift:46-60`；
  `SDCategory` 沒有 `prepareForDelete`（`Features/Sources/Core/Mappers/SDCategory+Mapping.swift` 全檔無此方法）
- 觸發：自建分類 → 指派給若干交易 → 對該分類建一個預算 → 刪除該分類。
- 結果：`makeDeleteCategory` 只擋 `isDefault`，之後是純 store delete。
  `SDTransaction.categoryId` 與 `SDBudget.categoryId` 都是裸 `UUID?` 欄位、沒有
  `@Relationship`，所以不會被 SwiftData 連帶清空。後果：
  交易在 `enrich` 拿到 `category: nil`（畫面顯示空白）、CSV 匯出該欄變空字串、
  預算永遠 `spent == 0`（`Budget.appliesTo` 比對一個不存在的 id）卻仍出現在
  `budgetGauges` / `currentStatus` 中。對照組：`SDTag` 有正確的
  `prepareForDelete()`（`SDTag+Mapping.swift:45-47`），可見缺的是分類這一份。
- 修法：替 `SDCategory` 實作 `prepareForDelete()`，把引用它的 `SDTransaction.categoryId`
  與 `SDBudget.categoryId` 設為 `nil`（或先擋住「仍有交易引用」的刪除，比照帳戶的
  archive-only 規則）— 工作量 M

### A7. 刪除／封存帳戶不清理指向它的設定與週期範本 — 嚴重度 Med
- 位置：`Features/Sources/Application/Ledger/LedgerClient+Live.swift:186-210`
- 觸發：把預設帳戶封存，或刪除一個沒有交易但被週期範本引用的帳戶。
- 結果：三處殘留無人清理：
  1. `defaultAccountId`（`.defaultAccountId` settings key，行 232-238）仍指向已刪／已封存帳戶；
  2. `watchDefaultAccountId` 同理 —— Watch 端有 `WatchDefaultAccountResolver` 做
     live-account 驗證所以還撐得住（`WatchDefaultAccountResolver.swift:18-23`），
     但 iOS 端的 `defaultAccountId` **沒有任何等價守衛**，直接回傳死 id；
  3. `SDRecurringTransaction.accountId` 指向已刪帳戶；若日後接上 `tick()`，
     會物化出 `accountId` 對不到任何帳戶的交易。
  `deleteAccount` 的守衛只檢查交易（行 201-208），沒檢查週期範本。
- 修法：`deleteAccount` / `archiveAccount` 後把三處指向該 id 的狀態清成 `nil`；
  `deleteAccount` 的 `operationDenied` 守衛加上週期範本檢查 — 工作量 M

### A8. Watch 入站草稿：去重先標記、寫入用 `try?`，失敗即永久遺失 — 嚴重度 Med
- 位置：`Features/Sources/Core/Adapters/Watch/WatchSessionDelegate.swift:26-57`
- 觸發：Watch 記一筆帳，iPhone 端 `store.add` 因任何理由拋錯（磁碟滿、container
  正在被 `wipeAllSyncData` 換掉、CloudKit 遷移中）。
- 結果：`parse()` 在**驗證階段**就 `dedupStore.mark(draft.id)`（行 47），然後才在
  行 31-34 的 `Task` 裡 `try? await store.add(transaction)`。寫入失敗被 `try?` 吞掉、
  沒有 log、沒有重試，而該 draft 的 id 已經被永久標記為「已處理」——
  WatchConnectivity 之後重送同一個 `transferUserInfo` 會在行 46 被 `contains` 擋掉。
  這筆記帳**靜默消失**，兩端都不會顯示任何錯誤。
- 修法：`mark(_:)` 移到 `add` 成功之後；失敗時 `os_log` 並保留 id 讓 WC 重送 — 工作量 S
  （註：本條與 known-issues 第 12 點「繞過 `ledgerClient.record`」是不同問題，
  即使改走 `record` 這個先標記／後寫入的順序錯誤依然存在）

### A9. 「Widget 顯示的載具」設定完全沒有傳到 Widget — 嚴重度 Med
- 位置：`Features/Sources/Application/Carrier/CarrierClient+Live.swift:39-48`；
  `Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift:42-64`；
  Widget 端 `NeuLedgerWidget/CarrierWidget.swift:52-66`
- 觸發：設定頁或載具管理頁選擇「用這張載具顯示在 Widget」。
- 結果：`setActiveForWidget` 把選擇寫進 `.widgetCarrierId`，而
  `UserSettingsAdapter.liveValue` 寫的是 `UserDefaults.standard`
  （`UserSettingsAdapter+Live.swift:16,22,31`），**不是 App Group suite**。
  `syncAllCarriers` 只把整份 `carrierList` 寫進 App Group，不含「哪一張是 active」。
  Widget 端 `resolveState(for:)` 只看自己的 `CarrierSelectionIntent.carrier`，
  找不到就 fallback 到 `all.first`。所以使用者在 App 內切換載具，Widget 畫面**不會變**，
  除非他另外長按 Widget → 編輯小工具。App 內那個選項目前是裝飾品。
- 修法：`setActiveForWidget` 改為（或額外）把 active id 寫進 App Group，
  Widget 的 `resolveState` fallback 改讀該 key — 工作量 S

### A10. 月底週期交易的到期日會逐月往前漂 — 嚴重度 Med
- 位置：`Features/Sources/Domain/Enums/BudgetPeriod+Calendar.swift:38-40`
  （`next(after:)`）；推進點 `MainTabFeature.swift:122-127` 與
  `LedgerClient+LiveRecurring.swift:130`
- 觸發：建立一個每月 1/31 扣款的範本（房租、信用卡帳單）。
- 結果：`calendar.date(byAdding: .month, value: 1, to: date)` 對 1/31 會 clamp 成 2/28，
  下一次從 2/28 再加一個月得到 3/28，之後永遠停在 28 號。日期一去不回頭，
  使用者每個月的提醒會愈來愈早偏離實際扣款日。
- 修法：`RecurringTransaction` 存一個 `anchorDay`（或以 `createdAt` 的日為錨），
  推進時用 `calendar.date(bySetting:)` 對月份長度做 clamp 而非累積漂移 — 工作量 M

### A11. 分析內核的期間／範圍語意瑕疵（三處） — 嚴重度 Med
- 位置：`Features/Sources/Core/Analytics/TransactionAnalyticsKernel.swift:62-66`、`240-296`、`145`
- 觸發與結果：
  1. **`statsSnapshot` 把未來日期的交易灌進七日統計**（行 62-66）：predicate 只有
     `tx.date >= weekStart`，沒有上界。記帳表單的 `DatePicker` 沒設 `in:` 範圍
     （`AddTransactionView.swift:691-695`），使用者可以選未來日期。那筆交易會被算進
     `weekTotal`、`income`、`expense`，Dashboard 的「本週支出」與儲蓄率立刻失真。
  2. **`budgetGauges` 的 `spent` 沒有套用帳戶篩選**（行 271-280）：`accountId` 只用來
     決定「哪些預算要顯示」（行 248-263），計算已花金額時的 predicate 只有
     `type == expense && date in period`，跨所有帳戶加總。使用者在 Dashboard 切到
     「現金」帳戶，看到的儀表數字仍是全帳戶總額 —— 篩選了清單卻沒篩選數字。
  3. **`detailStats` 的「上一筆收入」可能取到比當筆更新的交易**（行 145）：
     `monthRows` 以 `date` 降冪排序，`sameCategory.first(where: { $0.id != transaction.id })`
     取的是「本月同分類最新的另一筆」，對一筆補登的舊交易來說那是**未來**的交易，
     詳情頁的「較上次 ±x%」方向會反。
- 修法：(1) predicate 補 `tx.date < endOfToday`；(2) 決定 budgetGauges 到底要不要
  帳戶範疇 —— 要就把 `accountId` 也放進 spent 的 predicate，不要就拿掉行 248-263 的
  預篩；(3) 改成 `first(where: { $0.id != transaction.id && $0.date < transaction.date })`
  — 工作量 S（三處都是單行等級）

### A12. `setupAccounts` 讀取失敗會被吞掉，導致重複插入帳戶 — 嚴重度 Low
- 位置：`Features/Sources/Application/Ledger/LedgerClient+Live.swift:159-179`
- 觸發：onboarding 的 `setupAccounts` 呼叫時，既有帳戶的 `fetchAll` 拋錯。
- 結果：行 160-162 的 `(try? await accountStore.fetchAll(...)) ?? []` 把錯誤吞成空陣列，
  於是「已存在就跳過」的去重（行 166-171）完全失效，所有傳入帳戶被重新 `add`。
  `SwiftDataStore.add` 沒有任何 id 唯一性檢查（`SwiftDataStore.swift:36-40`），
  會產生兩筆同 id 的 `SDAccount` —— 接著就踩到 A4 的
  `Dictionary(uniqueKeysWithValues:)` crash。
  另外行 164 的 `Dictionary(uniqueKeysWithValues: newAccounts.map ...)` 本身也會在
  呼叫端傳入重複 id 時 trap。
- 修法：`try?` 改成 `try`（讓錯誤往上冒到 onboarding 顯示），行 164 改
  `uniquingKeysWith:` — 工作量 S

---

## B. 架構 / 繞路 / 死碼（依價值排序）

### B1. `PlatformClient+Live` 同時踩穿三條分層規則 — 價值 High
- 位置：`Features/Sources/Application/Platform/PlatformClient+Live.swift:4-5,153-171,198-209`
- 現況：Application 層的 Client Live 直接
  (a) `import SwiftData` 並在行 154 建 `ModelContext(PersistenceBootstrap.container)`
      —— `ModelContext` 的 §4 合法位置封閉清單（`SwiftDataStore` / mappers /
      `PersistenceBootstrap` / `CloudKitSyncAdapter` / `TransactionAnalyticsKernel` /
      `Core/Adapters/Watch/`）**不包含任何 Client Live**；
  (b) `import FirebaseCrashlytics` 並在行 208 直呼 `Crashlytics.crashlytics().record`
      —— 沒有對應的 `CrashReportingAdapter`，`Core/Adapters/CrashReporting/` 底下
      只有一個 bootstrap；
  (c) 行 200-204 直接用 `UIApplication.shared.open`，且是 fire-and-forget 的
      `Task { @MainActor in ... }`，呼叫端無從得知成敗。
  §3 對 Client Live 的「May NOT depend on」欄位三項全中。
- 為什麼繞：`wipeAllSyncData` 需要「刪掉所有 model 型別」的批次操作，
  `SwiftDataStore<Domain, SD>` 的五個方法確實沒有這個能力，於是直接抄捷徑。
- 該怎麼做：`SwiftDataStore` 加一個 `deleteAll()`（或在 `PersistenceBootstrap` 開一個
  `wipeLocalStore()` infrastructure 方法）；新增 `CrashReportingAdapter`
  與 `SystemAdapter`（`openAppSettings`）兩個 Adapter。
- 工作量：M

### B2. `WatchContextBuilder` 從 Infrastructure 反向依賴兩個 Client — 價值 High
- 位置：`Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift:17-18,34,38`
- 現況：`Core/Adapters/Watch/` 的元件注入 `@Dependency(\.planningClient)` 與
  `@Dependency(\.carrierClient)`。§3 的 Adapter 列明「May NOT depend on
  Other Adapters, **Clients**, SwiftDataStore」，§E.2 的例外只放寬了
  `SwiftDataStore`，沒有放寬 Client。行 25 的註解自己承認
  「`planningClient.listActive` stays as a dependency — it crosses into the
  Application layer」；`carrierClient` 是後來加上去的，連註解都沒補。
- 為什麼繞：遷移時圖省事，但兩邊要的都只是「全部 budget 中 isActive 的」與
  「全部 carrier」，同檔行 26-28 已經在用 `CategoryStore()` / `AccountStore()` /
  `TransactionStore()`，改法完全對稱。
- 該怎麼做：`planningClient.listActive()` → `BudgetStore().fetchAll().filter(\.isActive)`；
  `carrierClient.listAll()` → `CarrierStore().fetchAll(sortBy:)`。副作用是這條路徑不再
  觸發 `CarrierClient` 的 widget reload post-condition —— 但 builder 是純讀取，本來就不該觸發。
- 工作量：S

### B3. `InsightsClient+Live` 繞過 `aiAdapter` 直接建 `LanguageModelSession` — 價值 Med
- 位置：`Features/Sources/Application/Insights/InsightsClient+Live.swift:2,17-69,226-227`；
  對照 `Features/Sources/Core/Adapters/AIAdapter+Live.swift:9,15,21`
- 現況：`answerFinancialQuestion` 在 Application 層直接 `import FoundationModels` 並
  `LanguageModelSession(tools: [tool])`，`QueryTransactionsTool` 也用了 `@Generable` /
  `Tool`。整個 App 因此有**四處**各自 new 一個 `LanguageModelSession`
  （AIAdapter 三處 + 這裡一處），無任何 session 復用或 prewarm。
  同時 `CaptureClient+Live.swift` 整檔包在 `#if canImport(FoundationModels)` 裡，
  `InsightsClient+Live.swift` 卻裸 import —— 同一個 target 內兩種寫法，
  代表其中一個 guard 是無效的。
- 為什麼繞：`Tool` 需要在 call 裡讀 SwiftData，而 `AIAdapter` 介面是純 prompt→text，
  沒有「帶 tool 的 session」這個形狀。
- 該怎麼做：`AIAdapter` 加一個
  `answerWithTools: @Sendable (String, [any Tool]) async throws -> String`，
  或更乾淨地加 `answerFinancialQuestion: @Sendable (String, @Sendable (Query) async -> String) -> String`
  把 tool callback 當參數傳進 Adapter；`FoundationModels` 的 import 收回 Core/Adapters。
- 工作量：M

### B4. Widget 載具同步有一整套死碼 + 一份重複的 DTO 編碼 — 價值 Med
- 位置：`Features/Sources/Domain/Adapters/WidgetSyncAdapter.swift:14,18`；
  `Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift:19-22,27-41,44-51`；
  `Shared/WidgetAppGroup.swift:31-67,83-86`
- 現況：全庫 grep 確認以下**零 production 呼叫點**（只有測試與註解引用）：
  `WidgetSyncAdapter.syncCarrier`、`WidgetSyncAdapter.clearCarrier`、
  `WidgetAppGroup.readCarrier`、`WidgetAppGroup.writeCarrier`、
  `WidgetAppGroup.clearCarrier`、`WidgetAppGroup.writeAllCarriers`。
  legacy 單載具四個 key（`carrierBarcode` / `carrierType` / `carrierName` /
  `carrierUpdatedAt`）**沒有任何寫入者**，所以 `readCarrier` 永遠回 `nil`。
  唯一活著的是 `syncAllCarriers` → `carrierList` → `WidgetAppGroup.readAllCarriers`。
  而 `syncAllCarriers` 自己在行 45-51 內嵌重新宣告了一份 `CarrierEntryDTO`
  （註解行 44 明說「Core cannot import Shared/」），與 `Shared/CarrierEntry` 是兩份
  必須手動保持同步的相同結構。
- 為什麼繞：SPM package 無法 import app target 的 `Shared/`，於是複製了一份 DTO；
  legacy 路徑則是遷移到多載具後忘了刪。
- 該怎麼做：刪掉上列 6 個死方法與 4 個 legacy key（`WidgetSyncAdapter` 介面剩
  `syncAllCarriers` 一個 closure）；把 `CarrierEntry` 移到 SPM package 內的
  `Domain`（或一個新的極小 `SharedDTO` target）讓 App / Widget / Core 共用同一份定義。
  順帶修 A9。
- 工作量：M

### B5. `tick()` 與它宣稱的 SAGA invariant 整條都是死碼 — 價值 Med
- 位置：`Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift:88-134`；
  文件宣稱 `Features/Sources/Application/Ledger/LedgerClient+Live.swift:33-41,67-68`、
  `docs/architecture.md:186`
- 現況：如 A2 所述 `tick()` 零呼叫點。`LedgerClient+Live.swift:67-68` 的
  「Because `tick` routes through `recordTransaction`, each materialised recurring
  transaction inherits the same reactive mirror for free」以及 architecture.md §5 的
  invariant 3「`tick()` → internal `record`」描述的是一條**從未在 production 執行過**的路徑；
  `LedgerClientRecurringTests.swift:171-224` 的兩個測試給了它「有在動」的假象。
- 為什麼繞：遷移時把舊 `RecurringUseCase.tick` 的實作原封搬過來，但舊的呼叫點
  （應該在某個 app-lifecycle reducer）在重構中掉了，沒有人發現因為測試仍然綠。
- 該怎麼做：二選一，不要留在中間 —— 要嘛在 `AppFeature.task` 接上 `tick()`
  （並修 A2 的只補一期），要嘛刪掉 `tick` 與 `makeTick`，把
  architecture.md §5 的 invariant 3 一併刪除，明文寫「週期交易走通知確認制」。
- 工作量：S（接上）/ S（刪除）

### B6. `evaluateAfterTransaction` 每筆記帳都全表掃描，且參數根本沒用 — 價值 Med
- 位置：`Features/Sources/Application/Planning/PlanningClient+Live.swift:52-92`
- 現況：closure 簽章收 `transaction` 卻在行 52 直接 `_ in` 丟棄（註解行 53-56 坦承
  「brute re-scan keeps behaviour identical to the original」）。每次
  `record` / `update` 都會：`budgetStore.fetchAll()` + `transactionStore.fetchAll()`
  （**全部交易**，含每筆的 `tags` 關聯 map，見 `SDTransaction+Mapping.swift:25`）
  + 對每個 active budget 再跑一次 `filter` 與一個新的 `ISO8601DateFormatter()`（行 70，在迴圈內）。
  交易破千筆後，每次記帳的隱性成本是一次全表 fetch + 全量 Domain 映射。
- 為什麼繞：遷移時以「行為完全一致」為目標，沒有回頭做語意最佳化。
- 該怎麼做：用傳進來的 `transaction` 先篩出「這筆交易可能影響的預算」
  （`budget.appliesTo(transaction)` + 交易日期落在該預算的當期），只對那些預算做
  範圍查詢；`ISO8601DateFormatter` 提到迴圈外（或用
  `transaction.date` 直接算 period key）。
- 工作量：M

### B7. 每一次 SwiftData save 都重建全量 Watch 快照，沒配 Watch 也照做 — 價值 Med
- 位置：`Features/Sources/Core/Adapters/Watch/WatchSyncObserver.swift:20-50`；
  `Features/Sources/Core/Adapters/Watch/WatchContextBuilder.swift:30-38`
- 現況：observer 以 `object: nil` 監聽 `.NSManagedObjectContextDidSave`，
  即**任何** context 的 save（含 CloudKit mirroring importer 的 save）都會在 300ms
  debounce 後跑一次 `WatchContextBuilder.build`，而 build 會
  `transactionStore.fetchAll(sortBy: date desc)` 拉**全部交易**（行 33），
  只為了算「今天的支出」與「本月總預算進度」兩個數字，加上分類、帳戶、預算、
  載具四次額外 fetch，最後 JSON encode 全部分類與帳戶。
  整條路徑**沒有任何 `isPaired` / `isWatchAppInstalled` 前置守衛**
  —— 沒有 Apple Watch 的使用者每記一筆帳都付這個成本。
- 為什麼繞：WC 的 `updateApplicationContext` 只保留最新一份，所以設計成「每次推完整快照」，
  但「完整快照」被理解成「完整掃描」。
- 該怎麼做：(1) `rebuildAndPush` 開頭加 `guard bridge.isPaired() && bridge.isWatchAppInstalled()`；
  (2) 今日支出改用帶日期 predicate 的 constrained extension（`SwiftDataStore where SD == SDTransaction`），
  不要 `fetchAll`；(3) debounce 拉長到 1s 並在 CloudKit import 期間 coalesce。
- 工作量：M

### B8. `InsightsClient+Live` 用 `persistenceBootstrap` 當 `\.modelContainer` 的後門 — 價值 Med
- 位置：`Features/Sources/Application/Insights/InsightsClient+Live.swift:101-104,113-160`
- 現況：行 101-103 的註解明講「Container is reached via `PersistenceBootstrap` rather
  than `\.modelContainer` directly — architecture.md §4.2 reserves
  `@Dependency(\.modelContainer)` for `SwiftDataStore` only」。這是**規則的字面遵守、
  精神的違反**：Application 層照樣拿到了 `ModelContainer` 並把它傳給七個 kernel 呼叫。
  副作用之一：這六個投影全部是 `try`（同步）而非 `try await`，
  `TransactionAnalyticsKernel.fetch` 的同步 `context.fetch` 會阻塞呼叫端執行緒。
- 為什麼繞：`TransactionAnalyticsKernel` 的簽章要 `ModelContainer`，而它是
  §4 合法 `ModelContext` 站點之一，於是把 container 從 Application 傳進去。
- 該怎麼做：讓 kernel 自己 `@Dependency(\.modelContainer)`（它已在合法清單上），
  簽章拿掉 `container` 參數；Application 層就不再碰 container。
  順手把 kernel 方法改成 `async`。
- 工作量：S

### B9. `generateInsights` 回傳三筆硬編的假財務數字 — 價值 Med
- 位置：`Features/Sources/Application/Insights/InsightsClient+Live.swift:189-217`
- 現況：三張 InsightCard 的標題、內文、指標全是寫死的繁中字串與**捏造的金額**
  （「本週支出減少 12%」「你比上週省下 NT$ 3,200」「本月已花 NT$ 8,400，佔總支出 42%」）。
  這同時違反專案的兩條硬規則：使用者可見字串必須走 `String(localized:)`，
  以及「金額一律 TWD 整數格式化」。使用者看到的是與自己帳本完全無關的數字，
  而畫面上沒有任何「示範資料」標示。
- 為什麼繞：行 189-192 的 TODO 說明是為了先把 schema 定下來。
- 該怎麼做：短期把它改成回傳 `[]`（Dashboard 的 InsightCarousel 已有空狀態），
  或以 `SpendingSummary` 算出真實數字後套 localized 模板；中期接上
  `aiAdapter.generateText`。這條與 known-issues 第 14 點的
  「InsightCarousel 連動＋AI 失效策略」是同一件事的 Client 端根因。
- 工作量：S（回傳 []）/ M（接真資料）

### B10. `budgetGauges` 是 N+1 查詢 — 價值 Low
- 位置：`Features/Sources/Core/Analytics/TransactionAnalyticsKernel.swift:266-294`
- 現況：`for budget in filteredBudgets` 迴圈內每一圈都做一次獨立的
  `fetch(container:predicate:)`（行 271-279）。加上行 251-257 的預篩查詢，
  N 個預算就是 N+1 次 SwiftData 查詢；每次 Dashboard 切換帳戶都重跑一輪。
- 該怎麼做：所有 active budget 的期間取聯集後一次 fetch，Swift 端分桶；
  期間相同的預算（同為 `.monthly` 的那幾個）本來就共用同一份資料。
- 工作量：S

### B11. `SDRecurringTransaction.tagIds` 是「寫入即丟棄」的死欄位 — 價值 Low
- 位置：`Features/Sources/Core/Mappers/SDRecurringTransaction+Mapping.swift:10-24,53-64`；
  `Features/Sources/Core/Persistence/Models/SDRecurringTransaction.swift:32`
- 現況：`toDomain()` 行 19 無條件回 `tags: []`（註解說 v1 不解析），
  而 `applyChanges` 行 60 又用 `tagIds = domain.tags.map(\.id)` 回寫。
  兩者組合的結果是：任何一次 `updateRecurring`（包含 A5 的暫停、
  `MainTabFeature` 的 `nextDueDate` 推進）都會**把已存的 `tagIds` 清成空陣列**。
  目前沒有實際損害，因為表單兩處都寫死 `tags: []`
  （`RecurringTransactionFormFeature.swift:133,233`），欄位從來沒被填過。
- 該怎麼做：二選一 —— 刪掉 `tagIds` 欄位與相關 mapping（需 schema migration 評估），
  或在 `toDomain()` 補上 tag 解析並讓表單支援。留在現狀等於埋了一顆將來
  「加上 tag 支援時資料神秘消失」的雷。
- 工作量：S（刪）/ M（補齊）

### B12. `PersistentDomainModel` 的 `fatalError` stub 與三處文件漂移 — 價值 Low
- 位置：`Features/Sources/Core/Persistence/PersistentDomainModel.swift:34-49`
- 現況：`applyChanges` / `idPredicate` 的 protocol extension 預設實作是
  `fatalError(...)`，行 42-43 的 `TODO(Phase 1 收尾)` 說要刪掉它們好讓漏實作在
  編譯期被抓到。Phase 1 早已結束，七個 mapper 全都有實作，這兩個 stub 現在的作用
  只剩下「把編譯期錯誤降級成執行期崩潰」。
- 同時，文件與程式碼已漂開三處（皆可一行修正）：
  1. `CLAUDE.md` 與 `docs/architecture.md:147` 宣稱 seeding 會建立預設 "Cash" 帳戶
     —— 全庫 grep 無此程式碼，`seedIfNeeded` 只 seed 14 筆分類；
  2. `CLAUDE.md` 宣稱「All SwiftData operations run on a `@ModelActor`-isolated
     context」—— `SwiftDataStore` 實際上是每個方法 `ModelContext(container)` 新建
     （`SwiftDataStore.swift:22,29,37,45,59`），沒有 `@ModelActor`；
  3. `CLAUDE.md` 宣稱 seeding 條件是「only when `SDCategory` count == 0」——
     實作已改為 per-stable-ID 逐筆檢查（`PersistenceBootstrap.swift:240-252`）；
  4. `PlatformClient.recordError` 沒有出現在 architecture.md §5 的 PlatformClient 目錄中。
- 該怎麼做：刪 stub（編譯會直接證明七個 mapper 都有實作）；四處文件同步。
- 工作量：S

---

## C. 已知問題確認（仍存在）

- `TransactionAnalyticsKernel.weeklySpending:41` 帳戶預篩仍是單向 `tx.accountId != aid`；`detailStats:103` 仍用 `cal.dateInterval(of: .month)` 未走 `BudgetPeriod` — 仍存在（另見 A11 補充的第二、三項）。
- `TransactionAnalyticsKernel.scalarTransaction:304-319` 與 `SDTransaction+Mapping.toDomain():8-30` 仍是兩份 SD→Domain 投影 — 仍存在。
- `Core/Adapters/Watch/WatchMidnightTimer.swift` 仍是死碼：`arm()` 全庫零呼叫點，`WatchSyncObserver` 內也沒有它的引用（該檔行 10-11 的文件卻宣稱 observer 會 arm 它）— 仍存在。
- `WatchSyncObserver.rebuildAndPush:67-70` / `WatchMidnightTimer.fire:48-52` / `PlatformClient+Live.pushWatchContext:83-86` 三處 catch 吞錯無 log — 仍存在（另發現三處新的吞錯，見 §D）。
- `WatchSessionDelegate:31-34` 入站 Watch 記帳仍直寫 `TransactionStore()`，繞過 `ledgerClient.record` 的預算警告與鏡像推送 — 仍存在（另見 A8 的去重順序問題）。
- `CaptureClient+Live.swift:1` 的 `#if canImport(FoundationModels)` 仍缺 `&& !os(watchOS)`；且 `InsightsClient+Live.swift:2` 根本沒有 guard，同 target 內兩種寫法 — 仍存在。
- 跨領域聚合 PR C 的項目（App Group 常數 ×4、Code128 三套渲染等）在 Core 側的體現：`WidgetSyncAdapter+Live.swift:18` 與 `PersistenceBootstrap.swift:40` 各自硬編 `"group.com.drake.NeuLedger"` — 仍存在。

---

## D. 檢查過但沒問題的面向

- `SwiftDataStore` 的 `ModelContext` 確實不逃逸：五個方法都在單一函式體內建立並用完，方法內無 `await` 懸掛點，Swift 6 併發檢查上是安全的（但 `CLAUDE.md` 的 `@ModelActor` 描述不實，見 B12）。
- `SDTag.prepareForDelete()`（`SDTag+Mapping.swift:45-47`）確實清空 `transactions`，刪標籤會解除所有交易關聯 —— 規則正確且 `LedgerClientLiveTests.swift:523` 有測試覆蓋。
- 預設分類不可刪的守衛位置正確：在 Client Live 的 `makeDeleteCategory`（`LedgerClient+LiveCatalog.swift:53-57`）而非 mapper，符合「mapper 不做業務邏輯」。
- 帳戶 archive-only 規則（`LedgerClient+Live.swift:200-208`）用 `Transaction.involves(account:)` 做雙向判定，與 `balance` 的 `signedEffect(on:)` 語意一致，轉入方帳戶也擋得住。
- `exportCSV` 的唯一子目錄（`LedgerClient+LiveExport.swift:64-67`）與 RFC 4180 escaping（行 76-82）都正確，符合 §9 的「Fixed shared temp-file paths」反模式修正。
- `CoreError` 只有 `.notFound` / `.operationDenied` 兩個 case，全 Core 沒有第三種自訂錯誤型別外洩。
- `ProcessedDraftIdsStore`（`ProcessedDraftIdsStore.swift`）的 FIFO 上限 200 + `NSLock` 是合理設計，UserDefaults 佔用有界，不需要額外清理策略。
- `LiveWatchSessionTransport` 的 activation 前 `pendingContext` 緩衝 + activate 後 flush（`WatchSessionTransport+Live.swift:48-56,65-80`）正確避開了 `WCError.sessionNotActivated`。
- `Budget.evaluate` / `Budget.spent` / `Transaction.signedEffect` / `BudgetPeriod.dateInterval` 都是純函式、無 IO，符合「領域規則以 entity 方法承載」。
- `InsightCache` 的 actor 隔離與 `Decimal.description` locale 無關性推理（`InsightCache.swift:23-24`）正確。
- 除了 §C 已列的三處與 A8/A12，另外找到三處新的吞錯，已在對應條目說明：
  `InsightsClient+Live.swift:151-153`（budgetGauges 任何錯誤回 `[]`）、
  `PlanningClient+Live.swift:60,64`（預算評估靜默 no-op）、
  `PersistenceBootstrap.swift:232-234`（seeding 失敗只 `print`，App 會以零分類啟動）。
- 測試缺口（`NeuLedgerTests/Tests/CoreTests/`）：happy path 覆蓋良好（`SwiftDataStoreTests` 六案、`LedgerClientLiveTests` 三十餘案），但以下路徑**零覆蓋**——
  刪分類/刪帳戶的連帶清理（A6/A7）、`updateRecurring(isActive: false)` 的提醒取消（A5）、
  `tick` 補跑多期（A2）、`wipeAllSyncData`（A1）、container 抽換後的依賴快取（A3）、
  重複 id 的 `Dictionary` 防禦（A4）。
  測試容器注入方式正確（各 suite 自建 in-memory container，無 process 級共享狀態）。
