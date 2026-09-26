# Features 層唯讀體檢報告

範圍：`Features/Sources/Features/`（76 個 Swift 檔，24 個 `@Reducer`）
方法：全部 reducer 逐檔閱讀 + `grep` / `rg` 全域掃描 + `NeuLedgerTests/Tests/FeaturesTests/` 對照（共 31 個測試檔、約 260 個 `@Test`）。
已排除 `known-issues.md` 既有項目（確認結果見 §C）。

貫穿全層最大的問題只有一個形狀：**`.run` effect 裡 `try await` 沒有 `do/catch`**。TCA 對未捕捉的 error 只會發 runtimeWarning（Release build 連 warning 都沒有），effect 直接中止，UI 停在半路且完全不通知使用者。全層共 **28 處**，其中 12 處在「使用者按下儲存 / 刪除」的主路徑上。專案裡已經有正確寫法（`AddEditCarrierFeature` 的 `catch:` + `saveError` + `isSaving`、`CarrierManagementFeature.deleteConfirmed`、`DashboardFeature` 的 per-section `sectionFailed`），所以這是「沒套用既有 pattern」而不是「不知道怎麼做」。

---

## A. 潛在 bug（依嚴重度排序）

### A1. 記帳儲存失敗完全靜默 — 嚴重度 High
- 位置：`Features/Sources/Features/Dashboard/AddTransactionFeature.swift:281-362`（`saveTapped`）、`:189-194`（`.task`）
- 觸發：`ledger.record` / `ledger.update` / `ledger.createRecurring` 任一拋錯。實際會發生的情境：SwiftData 寫入失敗、CloudKit 容器不可用、`planningClient.evaluateAfterTransaction`（§3.1 invariant，在 `record` 內部同步呼叫）拋錯。
- 結果：`.run` 中止 → `.savedSuccessfully` 不會送 → 不 dismiss、不顯示錯誤、按鈕回彈。使用者以為「按了沒反應」，再按一次，第一次其實可能已經寫進去了 → **重複記帳**。`.task` 同樣沒 catch，載入失敗時 `isLoading` 永遠是 `true`，帳戶/分類選單永遠空白。
- 修法：仿 `AddEditCarrierFeature.swift:92-110` 加 `catch:` + `saveFailed(String)` action + `saveError` inline 顯示（專案規定驗證錯誤走 inline 不用 Alert）。— 工作量 S

### A2. 刪除確認後滑掉 sheet，交易不會被刪 — 嚴重度 High
- 位置：`Features/Sources/Features/Transactions/TransactionDetailFeature.swift:150-174`；`Transactions/TransactionDetailView.swift:85`（`presentationDetents`，**沒有** `interactiveDismissDisabled`）
- 觸發：在交易詳情頁按刪除 → 確認 → 出現 5 秒 Undo banner → 在 5 秒內往下滑關掉 sheet（或點背景）。
- 結果：sheet 關閉使 parent 的 `@Presents detail` 變 nil，TCA `ifLet` 會取消 child 所有 in-flight effect，`CancelID.deleteWindow` 的 5 秒 timer 一併被取消 → `deleteWindowExpired` 永遠不送 → `ledger.delete` 從未執行。使用者看到 Undo banner 消失、sheet 關閉，合理認定已刪除，但資料還在。`TransactionDetailFeatureDeleteWindowTests` 只測了 undo 與到期兩條路徑，沒測「窗期內被 dismiss」。
- 修法：`pendingDelete` 為 true 時上 `.interactiveDismissDisabled(true)`；或把 undo 窗期的責任上移到 parent（Transactions/Dashboard），讓 effect 不隨 sheet 生命週期消失。後者較正確。— 工作量 M

### A3. Onboarding 建立帳戶失敗會永久卡在最後一頁 — 嚴重度 High
- 位置：`Features/Sources/Features/Onboarding/OnboardingFeature.swift:92-101`
- 觸發：`ledger.setupAccounts(accounts)` 拋錯（首次啟動、SwiftData container 尚未就緒或 seeding 競態）。
- 結果：`.run` 在第一行就中止 → `platformClient.markOnboardingComplete()` 不執行、`.delegate(.onboardingCompleted)` 不送。但 `state.currentStep` 已在 `:63-68` 被改成 `.done`，UI 已經切到「準備好了」畫面。使用者卡在該畫面，沒有任何錯誤訊息、沒有重試入口，**只能砍掉重裝**（onboarding 未標記完成，重啟仍回 onboarding，但帳戶建立會再失敗一次）。
- 修法：加 `catch:` → 新增 `setupFailed(String)` action，把 `currentStep` 退回 `.ready` 並顯示 inline 錯誤 + 重試。— 工作量 S

### A4. 啟動頁取得 onboarding 狀態失敗會永久卡在 splash — 嚴重度 High
- 位置：`Features/Sources/Features/AppFeature.swift:60-64`；介面 `Features/Sources/Domain/Clients/PlatformClient.swift:104`（`canSkipOnboarding: @Sendable () async throws -> Bool`，**無預設值**）
- 觸發：`canSkipOnboarding()` 拋錯。
- 結果：`.route(...)` 不送 → `AppFeature.State` 停在 `.splash` → `AppView.swift:45-49` 永遠渲染 `LoadingView`。App 每次啟動都是一片 loading。`AppFeatureTests` 只測了 true/false 兩條成功路徑。`deepLinkReceived`（`:65-69`，`try await platformClient.parseLink`）有同樣的問題，deep link 解析失敗時靜默無事發生。
- 修法：`catch` 後 fallback 到 `.route(.onboarding)`（保守：寧可多問一次也不要卡死）。— 工作量 S

### A5. 冷啟動期間收到的 deep link 與週期交易確認會被靜默丟棄 — 嚴重度 Med-High
- 位置：`Features/Sources/Features/AppFeature.swift:78-102`（`.route` 的 `guard case .main(var mainState) = state else { return .none }`，出現在 `:81` 與 `:93`）
- 觸發：(a) App 未執行時點通知中心的週期交易提醒 → 冷啟動；(b) 從 Widget 點載具捷徑冷啟動；(c) 使用者尚未完成 onboarding 時收到任何 deep link。
- 結果：`.task` 的 `pendingRecurringConfirmations()` 訂閱在 `AppView.swift:72` 就啟動了，而此時 state 還是 `.splash`（`splashCompleted` 是由 `LoadingView` 的動畫回呼觸發的，有延遲）。`.route(.recurringConfirmation(...))` 抵達時 `guard` 失敗 → 直接 `return .none`，確認流程消失。使用者點了通知，App 打開後停在 Dashboard 什麼都沒發生。`AppFeatureTests` 裡的「recurringConfirmation route is ignored when not in main」正是把這個行為寫成了預期。
- 修法：在 `AppFeature.State` 加 `pendingRoute: RouteLinkDestination?`，非 `.main` 時暫存，`.route(.main)` 落地後 replay。— 工作量 M

### A6. 交易列表的六條查詢/刪除路徑全部沒有錯誤處理 — 嚴重度 High
- 位置：`Features/Sources/Features/Transactions/TransactionsFeature.swift:77-80`（`.task`）、`:92-95`（清空搜尋）、`:105-108`（`searchDebounced`）、`:117-120`（套用篩選）、`:146-149`（`deleteConfirmed`）、`:182-185`（新增後重載）
- 觸發：`ledger.listAll` / `ledger.search` / `ledger.delete` 任一拋錯。
- 結果：`.task` 失敗 → `isLoading` 卡在 `true`，畫面永遠轉圈。`deleteConfirmed` 失敗 → `transactionDeleted` 不送，列該筆還在，沒有任何提示，使用者會重按。套用篩選失敗 → `activeFilter` 已經寫進 state（`:116`）但列表還是舊資料，篩選 badge 亮著卻沒生效。
- 額外：`searchDebounced`（`:105`）與 `.task`（`:77`）都沒有 `.cancellable`，兩者的結果會互相覆蓋。搜尋「a」→ 停頓 → 搜尋「ab」，若第一個查詢較慢回來，畫面會顯示「a」的結果卻在搜尋框顯示「ab」。
- 修法：六處統一加 `catch:` → `loadFailed(String)`；`searchDebounced` 加 `.cancellable(id: CancelID.search, cancelInFlight: true)`。— 工作量 M

### A7. 一開始搜尋，已套用的篩選條件就整組失效 — 嚴重度 Med
- 位置：`Features/Sources/Features/Transactions/TransactionsFeature.swift:103-108`；Live 實作 `Features/Sources/Application/Ledger/LedgerClient+Live.swift:149-156`
- 觸發：先在篩選頁選「只看餐飲 + 本月」並套用，再在搜尋框輸入任何字。
- 結果：`searchDebounced` 走的是 `ledger.search(text)`，Live 實作只做 `all.filter { $0.note?.lowercased().contains(lowered) }`，**完全不看 `TransactionFilter`**。篩選被靜默丟棄，但 `hasActiveFilters`（`:25-31`）仍為 true，篩選按鈕維持高亮狀態，使用者不會知道結果已經不在篩選範圍內。次要問題：`search` 只比對 `note`，打分類名或帳戶名一筆都搜不到。
- 修法：刪掉 `ledger.search`，改成 `listAll(activeFilter.with(searchText: text))` —— `TransactionFilter.searchText` 與 `TransactionFilter+Matching.swift:23-24` 的比對邏輯早就存在且沒人用。見 B5。— 工作量 M

### A8. Dashboard 與交易分頁之間的資料互不同步 — 嚴重度 Med
- 位置：`Features/Sources/Features/MainTab/MainTabFeature.swift:133-137`（`case .dashboard: return .none` / `case .transactions: return .none`）
- 觸發：在 Dashboard 新增或刪除一筆交易，接著切到交易分頁（或反向操作）。
- 結果：兩個 child 各自只重載自己（`DashboardFeature.refreshAfterMutation` / `TransactionsFeature` 的 delegate 分支），MainTab 沒有做任何跨 tab 轉發。交易分頁的 `.task`（`TransactionsView.swift:43`）在 `TabView` 裡只會在該 tab 內容首次建立時觸發一次，之後切回來不會重跑。所以：Dashboard 新增 → 切到交易分頁 → 新那筆不在列表上；交易分頁刪除 → 切回 Dashboard → 已刪的那筆還在近期列表上（Dashboard 有 `.task` 但同樣只跑一次）。
- 修法：MainTab 在 `.dashboard(.delegate(...))` / 交易異動時 `.send(.transactions(.task))`，反向亦然；或改成切 tab 時重載（`tabSelected` 觸發對應 child 的 `.task`）。後者更簡單且涵蓋 CloudKit 背景同步的情形。— 工作量 M

### A9. 關掉 AI 輸入列後，遲到的擷取結果仍會強行彈出新增頁 — 嚴重度 Med
- 位置：`Features/Sources/Features/MainTab/AccessoryBarFeature.swift:87-100`（`aiInputDismissed`）對照 `:102-112`（`aiInputSubmitted`）
- 觸發：在底部 AI 輸入列輸入文字送出 → 在裝置端模型還在跑的時候（Foundation Models 首次推論可能數秒）按叉叉關掉輸入列。
- 結果：`aiInputDismissed` 只 `.cancel(id: CancelID.speechRecording)`，**沒有取消 `CancelID.aiExtraction`**。擷取完成後仍會走 `aiExtractionCompleted(.success)` → `.send(.delegate(.transactionExtracted))` → MainTab 轉給 Dashboard/Transactions → 使用者正在別的畫面操作時，新增交易 sheet 憑空彈出並帶著他已經放棄的內容。
- 修法：`aiInputDismissed` 改成 `.merge(.cancel(id: CancelID.speechRecording), .cancel(id: CancelID.aiExtraction), ...)`。— 工作量 S

### A10. 三張 AddEdit 表單與四個管理清單頁的寫入同樣沒有錯誤處理 — 嚴重度 Med
- 位置（表單 `saveTapped`）：`AccountManagement/AddEditAccountFeature.swift:116-140`、`CategoryManagement/AddEditCategoryFeature.swift:111-138`、`TagManagement/AddEditTagFeature.swift:92-102`
- 位置（清單頁刪除/重載）：`AccountManagement/AccountManagementFeature.swift:73-76, 109-118, 152-156, 162-166, 181-185, 192-195`、`CategoryManagement/CategoryManagementFeature.swift:64-68, 113-118, 126-130`、`TagManagement/TagManagementFeature.swift:54-57, 89-93, 100-103`、`BudgetManagement/BudgetManagementFeature.swift:53-56, 88-92, 99-102`、`CarrierManagement/CarrierManagementFeature.swift:61-64, 131-140`
- 觸發：對應的 client 呼叫拋錯。`ledger.deleteCategory` 對預設分類會丟 `CoreError.operationDenied`；`ledger.deleteAccount` 對有交易的帳戶同樣會拒絕。
- 結果：表單按儲存後毫無反應、不關閉、不報錯。清單頁的刪除確認按下去列還在。`AccountManagementFeature.deleteRequested`（`:109-118`）失敗時更糟：連確認 Alert 都不會出現，刪除按鈕像是壞掉。所有 `.task` 失敗時 `isLoading` 卡住。
- 修法：全部套 `AddEditCarrierFeature` 的形狀（`catch:` + `saveFailed` + inline `saveError`），清單頁加 `loadFailed`。建議一次性抽出共用的 `FormSaveState`（見 B9）再統一改。— 工作量 M

### A11. 分析頁快速切換期間會顯示錯誤資料，且載入失敗完全無提示 — 嚴重度 Med
- 位置：`Features/Sources/Features/Analysis/AnalysisFeature.swift:119-223`（主 effect **沒有** `.cancellable`，只有 `:214-222` 的 budgets effect 有）、`:268-270`（`loadedData(.failure)`）
- 觸發：(a) 在期間切換器上快速點「週 → 月 → 年」；(b) `ledger.listAll` 拋錯。
- 結果：(a) 三個查詢並行，先送達的 `loadedData` 會被後送達的覆蓋，順序不保證。「年」的查詢資料量最大最慢，很容易被「月」的結果蓋掉 → 選中「年」卻顯示月資料，而且 `isLoading` 已經是 false，畫面看起來是正常的。(b) `loadedData(.failure)` 只做 `state.isLoading = false`，`summary` 保持 nil → `hasData` 為 false → 畫面呈現「沒有資料」的空狀態，把「載入失敗」謊報成「你還沒有交易」。
- 修法：主 effect 加 `.cancellable(id: CancelID.load, cancelInFlight: true)`；`.failure` 分支寫入一個 `loadError` 並在 View 上用 `SectionFailureView`（元件已存在）顯示重試。— 工作量 S

### A12. 手動同步失敗仍顯示「同步成功」 — 嚴重度 Med
- 位置：`Features/Sources/Features/Settings/SyncSettings/SyncSettingsFeature.swift:98-109`
- 觸發：在 iCloud 不可用 / 無網路時點「立即同步」。
- 結果：`try? await platformClient.requestSyncNow()`（`:103`）把錯誤吞掉，接著無條件送 `syncNowFinished(platformClient.lastSyncedAt() ?? Date())`（`:108`）。`isManualSyncing` 復位、`lastSyncedAt` 被更新成舊值或**當下時間**。使用者看到「剛剛同步」，實際上什麼都沒同步。相較之下 `enableSyncTapped`（`:72-81`）有完整的 `do/catch` + `migrationFailed`，同一個檔案裡兩種標準。
- 修法：改 `do/catch`，失敗時送 `syncNowFailed(String)` 並顯示；成功才更新 `lastSyncedAt`。— 工作量 S

### 其他較小的確認項（一行一條）
- `AccountManagementFeature.swift:150-187`：`archiveConfirmed` / `deleteConfirmed` / `unarchiveTapped` 用 `.merge` **平行**送出 `.delegate(.accountsChanged)` 與寫入 effect，Settings 收到 delegate 後立刻 `listActiveAccounts()`，可能早於寫入落地 → 設定頁的預設帳戶名顯示舊值。應改 `.concatenate` 或在寫入完成後才送 delegate。
- `Transactions/FilterFeature.swift:182-189`：只設「結束日期」不設起始日期時，`dateRange` 被算成 `nil`，日期條件被靜默丟棄；但 `activeFilterCount`（`:58-66`）仍把它算成 1 個生效篩選，UI 顯示有日期篩選。
- `NotificationSettings/NotificationSettingsFeature.swift:115, 134`：`try await platformClient.scheduleDailyReminder()` 無 catch，排程失敗時開關顯示已開啟但提醒不會響。
- `Dashboard/AddTransactionFeature.swift:201`：預設帳戶只在 `if case .add = state.mode` 時套用，`.addPrefilled`（AI 快速記帳）不套 → AI 記帳每次都得手動選帳戶，且直接按儲存會噴「請選擇帳戶」。
- `BudgetManagement/BudgetFormFeature.swift:127` 與 `RecurringTransactions/RecurringTransactionFormFeature.swift:168` 用 `Decimal(string:)`，`AddTransactionFeature.swift:243` 用 `parsedAmountDecimal`。前者遇到千分位會在逗號處截斷（`"1,234"` → `1`）。鍵盤是 `.numberPad` 所以打不出逗號，但貼上可以。`AddTransactionFeatureTests` 有「saveTapped parses grouped amountText as full amount」這條測試，另外兩張表單沒有對應保護。
- `Dashboard/DashboardFeature.swift:467`：`insightsEffect` 傳的 `SpendingSummary(monthTotal: 0, weekTotal: 0)` 是寫死的 0，洞察內容不可能反映真實花費。

---

## B. 架構 / 繞路 / 死碼（依價值排序）

### B1. AnalysisFeature 在 reducer 裡重寫了 InsightsClient 已經提供的三個投影，而那三個入口在生產環境是死碼 — 價值 High
- 位置：`Features/Sources/Features/Analysis/AnalysisFeature.swift:120-223`（約 100 行）、`:283-342`（`computeBudgetMetrics`）；對照 `Features/Sources/Domain/Clients/InsightsClient.swift:32`（`dailyBars`）、`:36`（`categoryProportions`）、`:42`（`budgetGauges`）
- 現況：分析頁自己 `ledger.listAll` 撈原始交易，然後在 effect 裡手做「分類佔比彙總」「每日支出彙總」「預算 gauge 計算」。而 `InsightsClient` 這三個方法都有 Live 實作（`Application/Insights/InsightsClient+Live.swift:126, 134, 145`，底層是 `TransactionAnalyticsKernel`）也有測試，**但全專案沒有任何生產程式碼呼叫它們**（grep 結果只剩 Live 註冊與測試）。
- 為什麼繞：`AnalysisFeature` 同時注入了 `ledgerClient` + `planningClient` + `insightsClient` 三個 client（`:84-86`），已經超過 §10「若一個 Feature 測試要 mock 超過 2 個 Client，代表這個 Feature 做太多事」的紅線。`computeBudgetMetrics` 甚至是一個 `static func`，把兩個 client 當參數傳進去——這就是一個假裝成 helper 的 Client。
- 該怎麼做：改呼叫 `insightsClient.categoryProportions(range)` / `dailyBars(range)` / `budgetGauges(accountId)`，刪掉 reducer 裡的彙總與 `computeBudgetMetrics`，`planningClient` 與 `ledgerClient` 的注入一併移除（只留 `listActiveAccounts` 的帳戶清單，或也搬進 insights）。`AnalysisFeatureTests` 大部分測的是被搬走的計算，要一起改寫成對 client 回傳值的斷言。
- 工作量：M

### B2. 設定頁自己刻 CSV 匯出，而 `ledger.exportCSV` 有 Live 實作與 RFC 4180 測試卻零呼叫者 — 價值 High
- 位置：`Features/Sources/Features/Settings/SettingsFeature.swift:253-299`（CSV）、`:301-318`（JSON）、`:484-490`（`csvField` 逸出 helper）；對照 `Features/Sources/Domain/Clients/LedgerClient.swift:68` 與 `Application/Ledger/LedgerClient+Live.swift:258`
- 現況：reducer 裡 47 行手刻 CSV —— 自己撈 transactions/categories/accounts、自己組 map、自己寫 `DateFormatter`、自己做欄位逸出、自己決定支出要加負號。`LedgerClient.exportCSV` 做的是同一件事，`LedgerClientLiveTests.swift:544, 562` 還測了 header 與逗號逸出，**但生產程式碼沒有任何地方呼叫它**。
- 為什麼繞：two sources of truth。兩份 CSV 的欄位順序、日期格式、逸出規則現在只是碰巧一致，任何一邊改動都不會被另一邊的測試抓到。
- 該怎麼做：`exportCSVTapped` 改成 `.run { let url = try await ledger.exportCSV(); await send(.exportCompleted(url)) } catch: {...}`，刪掉 `csvField` 與那 47 行。JSON 匯出同理——要嘛在 `LedgerClient` 補 `exportJSON`，要嘛承認它是 debug 功能並註明。（known-issues 只列了 JSON，CSV 這條是新的且更明確。）
- 工作量：S

### B3. 匯出檔案用固定共用暫存路徑，直接違反 §9 的反模式表 — 價值 Med-High
- 位置：`Features/Sources/Features/Settings/SettingsFeature.swift:292-293`（`NeuLedger_export.csv`）、`:311-312`（`NeuLedger_export.json`）
- 現況：`FileManager.default.temporaryDirectory.appendingPathComponent("NeuLedger_export.csv")`，每次匯出都寫同一個路徑。
- 為什麼繞：`docs/architecture.md` §9 有一列就是「Fixed shared temp-file paths → Unique subdirectory per operation (see `exportCSV`)」，而且點名 `exportCSV` 是正確範例。這裡不但違規，違的還是那條規則拿來當正解的那個 API。實務風險：使用者連續匯出 CSV 再匯出 JSON，分享 sheet 還開著時舊檔已被覆寫；平行跑的測試也會互相踩。
- 該怎麼做：跟 B2 一起解決——走 `ledger.exportCSV` 就自動拿到唯一子目錄。
- 工作量：S（併入 B2）

### B4. 時間區間計算被重寫了三份，而 Domain 已經有唯一來源 — 價值 Med
- 位置：`Features/Sources/Features/Analysis/AnalysisFeature.swift:344-358`（`currentPeriodRange(for: BudgetPeriod)`）與 `:360-374`（`dateRange(for: State.Period)`）；對照 `Features/Sources/Features/Transactions/FilterFeature.swift:16-25` 使用的 `BudgetPeriod.closedRange(containing:calendar:)` / `previousInterval(before:calendar:)`
- 現況：`AnalysisFeature` 的兩個 static helper 是逐字相同的 switch（weekly/monthly/yearly 各自 `cal.dateComponents` 取起點、回傳 `start...now`），只差在參數型別一個是 `BudgetPeriod` 一個是自家的 `State.Period`。兩者都直接用 `Calendar.current` 與 `Date()`，沒有走 `@Dependency`。
- 為什麼繞：`BudgetPeriod+Calendar` 已經是專案宣告的區間唯一來源（`FilterFeature` 的註解寫得很明白：「區間定義唯一來源是 `BudgetPeriod+Calendar`」），分析頁自己又生了一份，而且是不可測的那種。`AnalysisFeature.State.Period` 本身也只是 `BudgetPeriod` 的複製品（week/month/year vs weekly/monthly/yearly）。
- 該怎麼做：`State.Period` 直接換成 `BudgetPeriod`，兩個 helper 刪掉改呼叫 `closedRange(containing:calendar:)`，注入 `@Dependency(\.date.now)` 與 `@Dependency(\.calendar)`（`FilterFeature:98-99` 就是範例）。
- 工作量：S

### B5. `ledger.search` 是第二條查詢路徑，而 `TransactionFilter.searchText` 早就存在且沒人用 — 價值 Med-High
- 位置：`Features/Sources/Domain/Clients/LedgerClient.swift:30`；`Application/Ledger/LedgerClient+Live.swift:149-156`；對照 `Domain/Entities/TransactionFilter.swift:26` 與 `TransactionFilter+Matching.swift:23-24`
- 現況：`TransactionFilter` 有 `searchText` 欄位，`matches` 也已經實作了它的比對，但沒有任何呼叫端會把它填進去。搜尋走的是獨立的 `ledger.search(query)`，它不吃 filter 也不吃其他條件。
- 為什麼繞：同一個「查交易」的問題有兩條互斥的路，兩條合不起來就直接造成了 A7 那個 bug。`FilterFeature` 產生 `TransactionFilter` 時也刻意不填 `searchText`（`:191-197`），等於 Domain 已經準備好的組合能力被整條放著不用。
- 該怎麼做：刪掉 `LedgerClient.search`，`TransactionsFeature` 統一用 `listAll(activeFilter.with(searchText:))`；順手把比對從「只看 note」擴到分類/帳戶名（`EnrichedTransaction` 的 join 本來就有這些欄位）。這會同時修掉 A7 並讓搜尋與篩選可以疊加。
- 工作量：M

### B6. 為了呼叫一個純 entity 方法而偽造一顆 entity — 價值 Med
- 位置：`Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift:129-136`
- 現況：使用者切換週期時，程式先 `RecurringTransaction(id: UUID(), amount: 0, note: nil, categoryId: nil, accountId: UUID().uuidString, ...)` 造一顆全假的實體，只為了呼叫 `temp.nextDate(after: now)` 取得下次日期。
- 為什麼繞：`BudgetPeriod.next(after:)` 是現成的純函式，`AddTransactionFeature.swift:296` 就直接在用（`frequency.next(after: date)`）。同一個 codebase 裡對同一件事有直路和繞路兩種寫法，而且繞路那條順手引入了兩個不可測的 `UUID()`。
- 該怎麼做：`state.firstRunDate = calendar.startOfDay(for: freq.next(after: now))`，刪掉 temp entity。
- 工作量：S

### B7. 時間 / 亂數依賴注入全層不一致，一半的 reducer 不可測 — 價值 Med
- 位置（已注入的正例）：`Onboarding/CustomAccountFormFeature.swift:45`（`\.uuid`）、`Transactions/FilterFeature.swift:98-99`（`\.date.now` + `\.calendar`）、`Dashboard/DashboardFeature.swift:163`、`RecurringTransactions/RecurringTransactionManagementFeature.swift:42`
- 位置（裸用的反例）：`Dashboard/AddTransactionFeature.swift:295`（`UUID()`）、`:327`（`Date()`）；`RecurringTransactions/RecurringTransactionFormFeature.swift:44-47, 55, 137, 155, 199-200, 226`（同一個檔案裡 `@Dependency(\.date.now)` 與 `Calendar.current`/`Date()` 混用）；`Analysis/AnalysisFeature.swift:172, 345-346, 361-362`；`NotificationSettings/NotificationSettingsFeature.swift:17, 28, 82, 112-113, 130-131`；`Settings/SettingsFeature.swift:411`；`Settings/SyncSettings/SyncSettingsFeature.swift:64, 67, 102, 104, 108`
- 現況：同一層裡兩套規矩。最刺眼的是 `SyncSettingsFeature`——它注入了 `@Dependency(\.continuousClock)` 卻用真實 `Date()` 量經過時間（`:64/67`、`:102/104`）。在測試裡 `TestClock` 不會推進真實時間，`Date().timeIntervalSince(start)` 恆為 ~0，`remaining` 恆為 1.0，永遠會走 sleep 分支；但在真機上若操作超過 1 秒就完全跳過。測試與生產走的是不同分支。
- 該怎麼做：全層統一 `@Dependency(\.date.now)` / `\.calendar` / `\.uuid`；`SyncSettingsFeature` 的耗時量測改用 `clock.now`。可以用 `ast-grep --lang swift -p 'Date()'` 加進 PR 前的稽核清單（排除 `#Preview` 區塊）。
- 工作量：M

### B8. 金額的解析與格式化各有三套寫法 — 價值 Med
- 位置（解析）：`Dashboard/AddTransactionFeature.swift:243`（`parsedAmountDecimal`）、`BudgetManagement/BudgetFormFeature.swift:127`（`Decimal(string:)`）、`RecurringTransactions/RecurringTransactionFormFeature.swift:168`（`Decimal(string:)`）
- 位置（Decimal → 顯示字串）：`AddTransactionFeature.swift:75, 94`（`.formatted(.number.precision(.fractionLength(0)))`）、`BudgetFormFeature.swift:41`（`"\(budget.amount)"`）、`RecurringTransactionFormFeature.swift:51`（`"\(NSDecimalNumber(decimal:).intValue)"`）
- 現況：三張金額表單，三種解析、三種回填。`Common/Extensions/String+Parsing.swift` 的 `parsedAmountDecimal` 已經處理了千分位與 locale 分隔符，只有一張表單在用。
- 該怎麼做：`parsedAmountDecimal` 當唯一解析入口；在 `Common` 補一個對稱的 `Decimal.amountFieldText`（或直接用既有的 `twdFormatted` 家族）當唯一回填入口。這件事與 known-issues 的「NumberFormatter 重複 ×4」屬同一根源，建議併成一張單。
- 工作量：S

### B9. 表單錯誤處理沒有共同形狀，九張表單各做各的 — 價值 Med
- 位置（完整的正例）：`CarrierManagement/AddEditCarrierFeature.swift:22-23`（`isSaving` + `saveError`）+ `:108-110`（`catch:`）+ `:120-123`；`RecurringTransactions/RecurringTransactionFormFeature.swift:33`（`saveError`）+ `:253-255`
- 位置（缺的）：`AddEditAccountFeature` / `AddEditCategoryFeature` / `AddEditTagFeature` / `BudgetFormFeature` / `AddTransactionFeature` 五張表單既沒有 `saveError` 也沒有 `isSaving`，儲存中沒有 disable 保護（可連按觸發重複寫入），失敗也沒有出口。
- 現況：正確做法在 codebase 裡存在且被證實可行，但沒有被抽出來，所以每張新表單都靠作者記得。
- 該怎麼做：在 `Features/Shared/` 抽一個 `FormSaveState { isSaving: Bool; saveError: String? }` + 對應的 `saveFailed(String)` action 慣例（或做成一個小 Reducer），九張表單一次改齊。這同時解掉 A1 與 A10 的一半，建議當成同一個 PR 的骨幹。
- 工作量：M

### B10. `"NT$"` 前綴切字串已經擴散到四個地方 — 價值 Low-Med
- 位置：`Analysis/Sections/KPIStrip.swift:63-67`、`Analysis/Sections/DailyBarsCard.swift:76, 88-91`、`Analysis/Sections/CategoryDonutCard.swift:142-145, 196-199`
- 現況：先用 `twdFormatted` 產生 `"NT$1,234"`，再用 `hasPrefix`/`dropFirst(3)`/`replacingOccurrences` 把前綴切掉，只為了讓 `"NT$"` 用小一號的字級渲染。四份實作用了三種不同的切法。另外 `Text("NT$")`（`DailyBarsCard:66`、`CategoryDonutCard:142, 196`、`AddTransactionView:194`、`RecurringTransactionFormView:116`）與 `Text(verbatim: "NT$")`（`TxHero:44`、`BudgetFormView:95`）混用——前者會拿 `"NT$"` 去字串目錄查 key（查不到才 fallback 成字面值）。
- 該怎麼做：在 `Common` 補 `Decimal.twdParts -> (symbol: String, digits: String)`，四處統一；`Text(verbatim:)` 當作唯一寫法。known-issues 記的是 ×3，現況是 ×4。
- 工作量：S

### B11. 硬編中文字串（含一條在 reducer 裡） — 價值 Low-Med
- 位置：`Settings/SettingsFeature.swift:464`（`"已產生 \(accountCount) 個帳戶、\(transactionCount) 筆交易"`）、`Settings/SettingsView.swift:263`（`label: "產生隨機測試資料"`）、`Transactions/TransactionsView.swift:196-205`（六組搜尋範例的 `query` 與 `hint`，含 `"Starbucks · coffee"` / `"Shared / splittable"` 等英文顯示字串）
- 現況：全層 266 個 `String(localized:)` key 與 57 個 `Text("key")` 逐一比對 `NeuLedger/Resources/Localizable.xcstrings`（517 個 key），**沒有任何一個缺漏**——本地化紀律整體很好。上述三處是僅有的破口。前兩處是 debug 功能但仍會出現在設定頁；第三處是正式的搜尋空狀態提示卡，中英混雜且不隨系統語言變。
- 該怎麼做：三處補 key。搜尋範例的 `query`（實際搜尋詞）是否要本地化需要產品決定，但 `hint` 一定要。
- 工作量：S

### B12. `SettingsFeature.defaultAccountSelected` 同時扮演「載入」與「使用者選取」 — 價值 Low-Med
- 位置：`Features/Sources/Features/Settings/SettingsFeature.swift:191-206`（`.task`）、`:217-224`（`defaultAccountSelected`）
- 現況：`.task` 讀出已儲存的 `defaultAccountId` 後，用 `.defaultAccountSelected(defaultId)` 把它送回自己。該 handler 會 (a) 呼叫 `ledger.setDefaultAccountId(id)` 把剛讀到的值原封不動寫回去，(b) 把 `isPickingDefaultAccount` 設成 false。所以「每次進設定頁」都會產生一次不必要的寫入；若使用者從未設定過預設帳戶，`defaultId` 是 `""`，這行會把空字串**持久化**。
- 為什麼繞：一個 action 承擔兩種語意，副作用就只能無條件執行。
- 該怎麼做：拆成 `defaultAccountLoaded(String)`（純寫 state）與 `defaultAccountSelected(String)`（寫 state + 持久化 + 收起 picker）。順帶：`.task`（`:192-205`）是一條長的循序 effect，前面任何一步拋錯就吃掉後面全部的載入（見 A10 註記），拆成獨立 effect 後這個問題一併消失。
- 工作量：S

### 其他較小的架構項（一行一條）
- `RecurringTransactionManagementFeature.swift:28-30, 86-88`：`deleteTapped` 是當初「不能改 `NotificationSettingsView`」留下的轉接 action，現在 `NotificationSettingsView.swift:382` 可以直接送 `deleteRequested`，這個 case 與註解可以刪。
- `MainTabFeature.swift:53, 118-131`：MainTab 注入 `ledgerClient` 只為了在收到 `savedRecurringConfirmation` 後做一次「撈全部 → 找一筆 → 更新 nextDueDate」，而且 `catch { // silently ignore }`。這段推進週期範本的邏輯屬於 ledger context（`tick` 的鄰居），應該內化進 `LedgerClient`，MainTab 就不需要注入 ledger。
- `Transactions/TransactionsView.swift:283, 293`、`Dashboard/Sections/DashboardTopBar.swift:6`、`Analysis/Sections/DailyBarsCard.swift:21, 134`、`Analysis/Sections/AnalysisTopBar.swift:106-107`：View 內用 `Calendar.current` 做日期分組與「今天/昨天」判斷。屬於展示層的日曆運算，可接受，但與 B7 同一根源，統一時可一併處理。
- `Settings/SettingsFeature.swift:403-459`：debug 種資料在迴圈裡逐筆 `ledger.record`，每筆都會觸發 §3.1 的預算評估與 Widget/Watch 鏡像推送（最多 5 帳戶 × 60 筆 = 300 次）。debug-only 所以優先度低，但若要留著應該走批次寫入路徑。

---

## C. 已知問題確認

- `FilterFeature` `.task` 的 `.run` 沒 catch — **仍存在**（`Transactions/FilterFeature.swift:117-123`）。
- `BudgetFormFeature.saveTapped` 沒 catch、沒 `saveFailed` — **仍存在**（`BudgetManagement/BudgetFormFeature.swift:137-161`）。補充：同檔 `.task`（`:90-93`）也沒 catch，分類清單載入失敗時分類選單永遠空白。
- `TransactionsView.swift` 交易列不顯示分類 — **仍存在**（`Transactions/TransactionsView.swift:237-256`，`title: transaction.note ?? type.displayName` / `subtitle: type.displayName`；`TransactionsFeature.swift:79` 仍在 `.map(\.transaction)` 丟掉 join）。
- `AnalysisFeature` 分類佔比用原始英文 seed 名 — **仍存在**（`Analysis/AnalysisFeature.swift:149` 用 `$0.name` 而非 `localizedName`；同檔 `:280` 的 CSV 路徑有用 `localizedName`，同一檔案兩種標準）。
- `TransactionAnalyticsKernel` 的帳戶預篩單向 / `detailStats` 未走 `BudgetPeriod` — 屬 Core 層，本次未查（Features 層無對應程式碼）。
- `TransactionAnalyticsKernel.scalarTransaction` 與 `SDTransaction+Mapping` 兩份投影 — 屬 Core 層，本次未查。
- `#if canImport(FoundationModels)` 缺 `&& !os(watchOS)` — 屬 Domain/Core 層，本次未查。
- `WatchMidnightTimer` 死碼 / 三處吞錯無 log — 屬 Core 層，本次未查。
- `WatchSessionDelegate` 直寫 store 繞過 `ledgerClient.record` — 屬 Core 層，本次未查。
- `RecurringTransactionFormFeature` 切換帳戶時同帳戶 `toAccountId` 的 UI 死角 — **仍存在**（`:140-142` 的 `accountChanged` 只寫 `accountId`，不清除也不重驗 `toAccountId`；要等到 `saveTapped:181` 才擋下來）。
- `AddTransactionFeature` transfer 驗證缺 `toAccount` nil 必填 — **仍存在**（`Dashboard/AddTransactionFeature.swift:253-258` 只檢查「同帳戶」，`toAccountId == nil` 會直接放行並寫入一筆沒有目的帳戶的轉帳；`RecurringTransactionFormFeature:177-180` 有擋，兩者不對稱）。
- `DashboardFeature` / `SettingsFeature` State 肥大 — **仍存在**（`SettingsFeature.State` 17 個欄位、`DashboardFeature.State` 16 個）。
- Dashboard 三張 follow-up 的程式碼錨點 — **仍存在**（`TODO(stats-follow-up)` 於 `DashboardFeature.swift:65, 103, 269`；`TODO(insights-follow-up)` 於 `:272`）。
- 跨領域聚合 PR C 的七項：`NumberFormatter` 重複 — Features 層剩 2 處（`Detail/AIInsightCard.swift:90`、`Detail/TxHero.swift:91`）；`"NT$"` 切字串 — **已增加到 4 處**（見 B10）；`parsedAmountDecimal` 只有 AddTransaction 用 — **仍存在**（見 B8）；`SettingsFeature` 自己做 JSON export — **仍存在，且 CSV 也是**（見 B2）；CarrierType icon/color/hint、Code128 三套、App Group 常數 ×4 — 不在 Features 層，本次未查。

---

## D. 檢查過但沒問題的面向

- **分層規則**：Features 層零 `import SwiftData`、零 Adapter 注入、零 `@Dependency(\.modelContainer)`。全層 61 處 `@Dependency` 全數是六個領域 Client 或 TCA 內建（`\.dismiss` / `\.continuousClock` / `\.uuid` / `\.openURL` / `\.date.now` / `\.calendar`）。§3 的依賴方向沒有被破壞。
- **§3.1 Client → Client**：Features 層沒有任何 Client 互相呼叫，跨域協調確實都由 reducer 用多個 `.run` 完成。
- **Typography gateway**：`Font.system(size:)` 與 `.font(.system(...))` 兩種拼法在 `Features/Sources/Features/` 底下皆零命中，全部走 `Font.Design` token。
- **Color gateway**：`Color(hex:)` / `Color(hexLiteral:)` 零命中，runtime hex 都走 `Color.Design.fromHex`。剩餘的 `Color.accentColor` / `Color.primary` / `Color.secondary`（21 處，集中在 `AccessoryView`、`OnboardingView`、`RecurringTransactionFormView`）是 SwiftUI 系統語意色，不在 hex 禁令範圍內，但若要求「所有 Color 走 Color.Design」則是待收斂的尾巴。
- **本地化 key 完整性**：266 個 `String(localized:)` + 57 個 `Text("key")` / `LocalizedStringKey` 字面 key，全數存在於 `NeuLedger/Resources/Localizable.xcstrings`（517 keys），零缺漏。動態組出的 key（`carrier_barcode_error_phone` / `_cert`）與 `AlertState` 裡的 `TextState` key（`transaction_detail_delete_failed_*` / `common_ok`）也逐一確認存在。
- **View 層純度**：View 內沒有任何 client 呼叫（唯一命中是 `#Preview` 的 `withDependencies` 覆寫，屬正確用法）。View 內的計算限於日期分組、貨幣字串切分與排版，沒有業務規則。
- **導航可達性**：`MainTabView` 是三個 `Tab`（Ledger / Settings / Transactions 以 `role: .search`），交易頁確實可達；Analysis 由 `DashboardScreen` 的「餘額總覽」標題列 `analysisShortcutTapped` 進入（`DashboardFeature.swift:314-316`）；`SettingsFeature.Destination` 八個目的地全部有對應的 `*Tapped` 入口。沒有發現無法到達的畫面。唯一的路由破口是 A5（冷啟動期間的 deep link）。
- **`@Presents` 生命週期**：九組 `@Presents` 的 `.ifLet` 註冊完整，`dismissed` delegate 路徑都有把 parent 的 presentation state 清掉，沒有發現殘留子畫面狀態。
- **Alert 使用場合**：表單驗證錯誤全部走 inline（`nameError` / `amountError` / `transferError` / `barcodeError`），`AlertState` 只用於刪除確認與刪除失敗，符合專案規定。
- **既有測試覆蓋**：儲存、刪除、篩選套用、onboarding 完成四條關鍵路徑都有 `TestStore` 測試（`AddTransactionFeatureTests` 38 條、`TransactionsFeatureTests` 19 條、`FilterFeatureTests` 26 條、`SettingsFeatureTests` 37 條、Dashboard 拆成 8 個檔）。**缺的全部是錯誤路徑**——因為對應的錯誤路徑在程式碼裡根本不存在（A1 / A3 / A6 / A10）。修完 A 類 bug 後這些測試需要一併補上。
