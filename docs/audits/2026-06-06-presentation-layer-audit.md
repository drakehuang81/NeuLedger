# Presentation Layer 全面審查報告（2026-06-06）

> 產出方式：64 個 agent 的多階段審查 workflow — 31 組 Screen/Feature 各由一個審查 agent 依三維度（重構殘留 property/死 action、State 內 SSOT、測試覆蓋）審查，發現再由獨立 agent 對抗式逐項驗證（必須自行重新 Grep 全 repo 找反證）並補漏；另有跨 feature SSOT 視角一組。

## 總計

| 指標 | 數值 |
|---|---|
| 審查組數 | 31 |
| confirmed 發現 | 91 |
| uncertain | 0 |
| refuted | 0 |
| reviewer 補漏 | 38 |

## 各組概況

| 組 | confirmed | 補漏 | action 覆蓋 |
|---|---|---|---|
| App | 3 | 0 | 7/10 |
| MainTab | 4 | 2 | 4/8 |
| AccessoryBar | 3 | 2 | 16/18 |
| Dashboard | 8 | 2 | 25/31 |
| AddTransaction | 5 | 1 | 22/30 |
| Transactions | 4 | 1 | 11/17 |
| TransactionDetail | 5 | 2 | 14/19 |
| Filter | 4 | 1 | 13/14 |
| Analysis | 4 | 2 | 12/14 |
| AIAssistant | 1 | 0 | 7/7 |
| Settings | 5 | 1 | 20/37 |
| SyncSettings | 1 | 1 | 5/7 |
| WatchSettings | 1 | 2 | 3/3 |
| NotificationSettings | 3 | 2 | 8/9 |
| AccountManagement | 4 | 1 | 11/17 |
| AddEditAccount | 1 | 1 | 3/10 |
| CategoryManagement | 4 | 0 | 6/10 |
| AddEditCategory | 1 | 0 | 0/9 |
| TagManagement | 2 | 3 | 6/10 |
| AddEditTag | 1 | 2 | 2/7 |
| BudgetManagement | 3 | 1 | 6/10 |
| BudgetForm | 2 | 2 | 9/12 |
| CarrierManagement | 3 | 2 | 8/11 |
| AddEditCarrier | 3 | 1 | 5/9 |
| Onboarding | 1 | 0 | 8/8 |
| CustomAccountForm | 2 | 0 | 5/5 |
| RecurringManagement | 3 | 1 | 6/10 |
| RecurringForm | 3 | 1 | 6/17 |
| WatchApp | 2 | 1 | 4/17 |
| WatchCarrier | 1 | 1 | 4/4 |
| WatchRecord | 4 | 2 | 10/12 |

---

# 跨 Feature SSOT（Global 視角）

## CrossFeature-SSOT

**健康度摘要**：跨 feature SSOT 整體健康度尚可：大多數畫面組是「各自透過 client 自行 load 唯讀清單」的可接受模式，真正的雙寫 desync 只集中在 Settings 與其 NavigationStack 子畫面（AccountManagement / CarrierManagement）之間——父子同時存活、各自 stored 同一份 accounts/carriers，且子畫面沒有任何 delegate 回拋，pop 回 Settings 後資料必然 stale。另有兩處「income/expense 加總投影」在 Dashboard 與 Analysis reducer 內各自手刻、未走 insightsClient，以及 Dashboard vs AccountManagement 對 per-account balance 用了兩條不同的 client 路徑。Settings / Dashboard / AddTransaction 三個 State 屬於肥大、混雜多重關注點，值得後續拆解。

**Action 覆蓋率**：0/0

### 經交叉驗證確認的發現（confirmed）

- **[medium] ssot-violation** — Settings 與其 push 的 AccountManagement 各自 stored accounts，子畫面無 delegate 回拋導致 pop 後 Settings.accounts/defaultAccountName desync
  - 位置: `Features/Sources/Features/Settings/SettingsFeature.swift:37`
  - 細節: SettingsFeature.State 持有 `accounts: [Account]`（行 37）與衍生顯示用的 `defaultAccountName`（行 39），由 SettingsView.task 只在畫面首次出現時 load 一次（SettingsView.swift:61，effect .cancellable(id: .task)，pop 回來不會重跑）。同一條 NavigationStack 上 push 的 AccountManagementFeature（SettingsFeature.swift:149）自己也 stored `accounts`（AccountManagementFeature.swift:13），並在 archive/delete/unarchive/reorder/addEdit.saved 時只 reload 自己的 state.accounts（行 174-182、200-202、234-239）。AccountManagementFeature 完全沒有 `case delegate(...)`（grep enum Delegate / case delegate( 皆無），而 Settings 的 `case .path:` 直接 return .none（SettingsFeature.swift:180-181），沒有攔截子畫面的帳戶異動。操作順序：Settings → 點帳戶管理 → 改名或封存某帳戶 → 返回 Settings → 開「預設帳戶」picker（SettingsView.swift:129 ForEach(store.accounts)）仍列出舊清單、行 119 的 store.defaultAccountName 可能顯示已被封存/改名的帳戶。
  - 建議修法: AccountManagementFeature 補一個 delegate(.accountsChanged) 或讓 Settings 在 .path(.popped) / 子畫面 .saved 時重新發 accountsLoaded，把帳戶這份事實收斂到單一 reload 路徑。

- **[medium] ssot-violation** — Settings 與其 push 的 CarrierManagement 各自 stored carriers，子畫面無 delegate 回拋導致 pop 後 Settings.carriers/widgetCarrierName desync
  - 位置: `Features/Sources/Features/Settings/SettingsFeature.swift:45`
  - 細節: 與帳戶案例同構：SettingsFeature.State 持有 `carriers: [Carrier]`（行 45）+ 衍生顯示 `widgetCarrierName`（行 47），只在 SettingsView.task（SettingsView.swift:61）load 一次（widgetCarriersLoaded，SettingsFeature.swift:336-345）。push 的 CarrierManagementFeature（SettingsFeature.swift:165）自己 stored `carriers`（CarrierManagementFeature.swift:13），並在新增/刪除/編輯時 reload 自己（addEdit.delegate.saved，CarrierManagementFeature.swift:117）。CarrierManagementFeature 無對父畫面的 delegate（grep 僅見自己 addEdit 子層的 .saved/.dismissed），Settings `case .path:` 不攔截。操作順序：Settings → 載具管理 → 刪掉目前被設為 widget 的載具 → 返回 → 「Widget 載具」picker（SettingsView.swift:192 ForEach(store.carriers)）仍列出已刪載具、行 178 widgetCarrierName 顯示已不存在的名稱。
  - 建議修法: CarrierManagementFeature 對父畫面補 delegate(.carriersChanged)，或 Settings 於 .path 變動時重新發 widgetCarriersLoaded，讓載具清單只有一個 reload 來源。

- **[low] other** — income/expense 加總投影在 DashboardFeature 與 AnalysisFeature reducer 內各自手刻 filter+reduce，未走 insightsClient
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:343`
  - 細節: 完全相同的 derived 邏輯「把 [Transaction] 依 type 拆成 income 總和 / expense 總和再組 Summary」散落兩個 reducer：DashboardFeature.swift:343-351 用 `filter { $0.type == .expense/.income }.reduce(Decimal.zero){ $0 + $1.amount }` 組 SpendingSummary；AnalysisFeature.swift:141-150 同樣的 filter+reduce 組 FinancialSummary。CLAUDE.md 定義 `insightsClient` 為「帳本的唯讀投影」（detailStats / todayStats 等），這類 totals fold 應由 client 投影產出而非在 presentation 層各刻一份；兩份未來若對 transfer 是否計入、四捨五入規則調整，極易各自漂移（目前 Analysis 行 140 註解明寫 exclude transfers，Dashboard 版本未顯式排除，語意已不一致）。
  - 建議修法: 把 income/expense 總和投影收進 insightsClient（如沿用 detailStats），Dashboard 與 Analysis 改呼叫同一投影方法，消除手刻 fold。

- **[low] other** — per-account 餘額在 Dashboard 用 ledger.balances() 一次撈、AccountManagement 改用 ledger.balance(id) 逐筆 task group，兩條不同路徑算同一投影
  - 位置: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift:78`
  - 細節: DashboardFeature.swift:227-236 對全帳本餘額用單呼叫 `ledger.balances()` 取回 [Account.ID: Decimal]；AccountManagementFeature.swift:78-90 卻對每個帳戶 `ledger.balance(id)` 在 withTaskGroup 內逐筆查（N 次 round-trip）再自己組同一個 dict，存入 state.balances（行 14、93-94）。LedgerClient 同時宣告 `balance(id)` 與 `balances()`（Domain/Clients/LedgerClient.swift:42-43），投影本身住在 client（SSOT 正確），但同一份『每帳戶餘額 map』在兩個 feature 用了不同 client 入口、AccountManagement 多做 N-1 次無謂查詢，且兩條路徑對「封存帳戶是否回傳 key」的行為若有差異會造成顯示不一致。
  - 建議修法: AccountManagement 也改用單呼叫 `ledger.balances()` 取整份 map，與 Dashboard 統一餘額投影入口並省掉 task group。

- **[low] other** — SettingsFeature.State 肥大：20 個 stored property 混雜 6+ 個關注點，值得拆解
  - 位置: `Features/Sources/Features/Settings/SettingsFeature.swift:35`
  - 細節: State（行 35-76）塞了 20 個 stored property，橫跨：帳戶/預設帳戶 picker（accounts, selectedDefaultAccountId, defaultAccountName, isPickingDefaultAccount）、語言（currentLanguage）、匯出（exportingFormat, exportedFileURL, exportError）、accessory 開關（showAccessoryBar）、載具/widget picker（carriers, widgetCarrierId, widgetCarrierName, isPickingWidgetCarrier）、wipe-all-data（isConfirmingWipeAllData, isWipingAllData, wipeAllDataError）、seed-random-data debug（isSeedingRandomData, seedRandomDataResult, seedRandomDataError）。明顯多於同類管理畫面（AccountManagement 5、Carrier 5、Tag 4 個 property）。其中 debug 用的 seed-random-data 與 wipe-all-data 兩組共 6 個 property 可抽成獨立子 feature 或 @Presents 子狀態。
  - 建議修法: 將 export、wipe-all-data、seed-random-data 各自抽成獨立子 reducer/狀態，Settings.State 只保留路由與少數頂層顯示欄位。

- **[low] other** — DashboardFeature.State 肥大：查詢/結果/AI/stats/carousel/五個 per-section phase 全擠一個 struct（約 22 個 stored）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:51`
  - 細節: State（行 51-115）約 22 個 stored property，混合：查詢參數（selectedAccountID）、查詢結果（accounts, accountBalances, recentTransactions, earliestTransactionDate, categoryMap, weeklySpending）、AI insight（aiInsight, isLoadingInsight, lastInsightTransactionCount）、全域 stats（todaySpending, weekSpending, savingsPercentage——行 71 註解自承尚未隨 selectedAccountID 連動的 TODO）、insight carousel（insights, insightIndex）、五個獨立 SectionPhase（hero/stats/transactions/insight/accounts）。雖然檔內已用註解嚴格標注每欄位的唯一寫入 action（SSOT 自律良好），但 5 個 section phase + 3 組 stats + carousel 可考慮聚成 per-section 子狀態以降低單一 struct 體積。
  - 建議修法: 把五個 SectionPhase 聚成一個 [Section: SectionPhase] 或 per-section 子狀態，stats 三欄與 carousel 兩欄各自封裝，縮小頂層 State。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] ssot-violation** — MainTabFeature.State 與 SettingsFeature.State 各自 stored `showAccessoryBar`，靠 delegate 單向同步——屬正確 SSOT 模式，列此為『非問題』澄清
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:25`
  - 細節: MainTabFeature.State 持有 showAccessoryBar（行25），SettingsFeature.State 也持有同名 showAccessoryBar（SettingsFeature.swift:44）。乍看是雙寫，但實際是單一寫入點+delegate 廣播：Settings 在 accessoryBarToggleChanged 時 setShowAccessoryBar 並 .send(.delegate(.accessoryBarVisibilityChanged))（SettingsFeature.swift:326-329），MainTab 於 .settings(.delegate(.accessoryBarVisibilityChanged))（MainTabFeature.swift:139-141）收斂回自己的 state。底層 SSOT 是 platformClient.showAccessoryBar()，兩份 state 皆為其鏡像且有即時同步路徑。這正是 G1/G2 缺少的 delegate 回拋模式，故不構成 desync。列此是為對比說明：原審查員的 G1/G2 判斷方向正確，且本 codebase 已有正確範本可循（accessoryBar 即是）。
  - 建議修法: 無需修復；可作為 G1/G2 修法的參考範本——AccountManagement/Carrier 補同樣的 delegate(.xxxChanged) → Settings 收斂即可。

- **[low] other** — category 投影在 DashboardFeature、AnalysisFeature、AddTransaction 等多處各自 `ledger.listCategories(nil)` + 自組 categoryMap，重複的 Dictionary(uniquingKeysWith:) 樣板
  - 位置: `Features/Sources/Features/Analysis/AnalysisFeature.swift:154`
  - 細節: 把 [Category] 折成 [Category.ID: Name/Category] 的 `Dictionary(categories.map{...}, uniquingKeysWith:{ first,_ in first })` 樣板至少出現三次：DashboardFeature.swift:257-260（id→Category，含 CloudKit 同步去重註解）、AnalysisFeature.swift:154-157（id→name）、AnalysisFeature.swift:320（computeBudgetMetrics 內 id→name）。與 G3/G4 同類：唯讀投影邏輯（含去重策略）在 presentation 層各刻一份，未來去重規則或 localizedName 取用方式調整易漂移。相較 G3/G4 涉及金額 fold，此處風險較低但同屬 insightsClient 可承載的唯讀投影外溢。原審查員只抓了 income/expense fold 與 balances，遺漏此 categoryMap 折疊重複。
  - 建議修法: 於 insightsClient 或共用 helper 提供 categoryMap(by:) 投影，Dashboard/Analysis/budget 共用同一去重策略。

### 覆蓋率抽查結論

不適用

---

# 各畫面組詳情

## App

**健康度摘要**：AppFeature 是一個結構乾淨的根路由 reducer（State 為 splash/onboarding/main 三態 enum，6 個 action），維度 1（死碼）與維度 2（SSOT）皆零問題 — 所有 state case 與 action 都有真實消費者，沒有重複或可推導的 stored state。唯一弱點在維度 3：10 條有意義的邏輯分支中只覆蓋 7 條，三條未測的恰好都是高風險導航膠水（widget 深連結入口、carrier-management 落地、抹除資料後 bounce 回 onboarding），建議優先補上這三條測試。

**Action 覆蓋率**：7/10

**未覆蓋關鍵路徑**：
- deepLinkReceived(URL): widget 的 neuledger://carrier-management 唯一入口 — parseLink 失敗/none/carrierManagement 三條分支全無測試
- route(.carrierManagement): 在 .main 時切到 settings tab 並 path.append(.carrierManagement) 的導航膠水未驗證；非 .main 時的 guard 早退也未驗證
- main(.settings(.delegate(.allDataWiped))): debug 抹除全部資料後 bounce 回 onboarding 的關鍵狀態重置完全無測試

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — deepLinkReceived(url) action 與其 parseLink effect 完全無測試覆蓋
  - 位置: `Features/Sources/Features/AppFeature.swift:65`
  - 細節: AppFeature.Action.deepLinkReceived(URL) 由 AppView.swift:69-71 的 .onOpenURL 在生產上送出，是 widget 的唯一深連結入口（NeuLedgerWidget/CarrierWidget.swift:113,203,235 發出 neuledger://carrier-management）。reducer 在 line 65-69 呼叫 platformClient.parseLink(url) 並把結果轉送 .route(destination)。但全域 grep（NeuLedgerTests 全目錄）顯示沒有任何 store.send(.deepLinkReceived(...)) — AppFeatureTests.swift 完全沒測到這條。parseLink 可回傳 .carrierManagement / .none 兩種真實結果，皆未驗證 effect 編排。
  - 建議修法: 在 AppFeatureTests 加一個 test：override platformClient.parseLink 回 .carrierManagement，send(.deepLinkReceived(url)) 後 receive(\.route.carrierManagement) 並斷言切到 settings tab。

- **[medium] test-gap** — route(.carrierManagement) 分支（切 tab + path.append）無測試覆蓋
  - 位置: `Features/Sources/Features/AppFeature.swift:80`
  - 細節: AppFeature.swift:80-85 的 .route(.carrierManagement) case 會把 mainState.selectedTab 設為 .settings 並 mainState.settings.path.append(.carrierManagement(...))，且有 guard case .main 早退保護。這是 widget 深連結落地後實際執行的導航膠水。AppFeatureTests.swift 中 store.send(.route(...)) 只覆蓋到 .recurringConfirmation（line 68,90），carrierManagement 這條分支（含 .main 與非 .main 兩種狀態）零覆蓋。
  - 建議修法: 新增 test：initialState=.main，send(.route(.carrierManagement)) 後斷言 selectedTab==.settings 且 settings.path 尾端為 .carrierManagement。

- **[high] test-gap** — main(.settings(.delegate(.allDataWiped))) → 重置回 onboarding 的關鍵路徑無測試
  - 位置: `Features/Sources/Features/AppFeature.swift:72`
  - 細節: AppFeature.swift:72-77 處理 SettingsFeature 的 .delegate(.allDataWiped)（由 SettingsFeature.swift:385 在 debug 抹除全部資料後送出），效果是 .send(.route(.onboarding)) 把整個 MainTab state 丟掉並回到 onboarding 讓使用者重建首個帳戶。這是破壞性最高的狀態轉換之一。grep NeuLedgerTests 顯示只有 OnboardingFeatureTests 用到 onboardingCompleted；allDataWiped 在 AppFeature 測試層完全沒被 send/receive 過。
  - 建議修法: 新增 test：initialState=.main，send(.main(.settings(.delegate(.allDataWiped)))) 後 receive(\.route.onboarding) 並斷言 state 變為 .onboarding(OnboardingFeature.State())。

### 覆蓋率抽查結論

同意原審查員的覆蓋率統計。我自行枚舉 AppFeature body 的 switch 分支，得到 10 條有意義的處理路徑：(1) task、(2) splashCompleted、(3) deepLinkReceived、(4) onboarding(.delegate(.onboardingCompleted))、(5) main(.settings(.delegate(.allDataWiped)))，以及 route 子 switch 的 (6) .carrierManagement、(7) .main、(8) .onboarding、(9) .recurringConfirmation、(10) default(.none)。逐一核對 AppFeatureTests.swift 的 7 個 @Test：task（行 93/124 兩個測試）、splashCompleted（行 10/26）、onboardingCompleted（行 42）、route.main（行 21 receive）、route.onboarding（行 37 receive）、route.recurringConfirmation（行 56/78/93）、route default/.none（行 124 task 解析到 .none）皆已覆蓋 = 7 條；未覆蓋 = deepLinkReceived、route.carrierManagement、allDataWiped = 3 條。10/7/3 與原統計完全一致，三條未覆蓋關鍵路徑描述亦準確。補充查核：我也檢查了 SettingsFeature.Delegate 的另一 case accessoryBarVisibilityChanged，它由 MainTabFeature.swift:139 正確消費（不屬 AppFeature 職責）且 SettingsFeatureTests 已測，非遺漏；OnboardingFeature.Delegate 僅 onboardingCompleted 一案，已覆蓋。我在三個維度（殘留 property / 死 action / SSOT / 測試覆蓋）重掃 AppFeature.swift 與 AppView.swift，未發現原審查員以外的新問題 — 三項發現已窮盡此檔案組的實質缺口，故 missedFindings 為空。"}

---

## MainTab

**健康度摘要**：MainTab 這組在「死碼」與「SSOT」兩個維度都乾淨：State 的全部 stored property（selectedTab / dashboard / transactions / settings / accessory / showAccessoryBar）與 computed isAccessoryVisible 皆有實際消費者，所有 Action case 都有 live handler 或 producer，無重構殘留；showAccessoryBar 雖在 MainTab 與 Settings 子 State 各存一份，但屬 TCA child-scope + delegate 同步的正規寫法（持久真值在 platformClient，各自單一寫入點），不算內部 desync。唯一實質問題集中在測試覆蓋：8 條有意義的 reducer 邏輯分支只覆蓋 4 條，其中含 client 副作用編排（savedRecurringConfirmation）、SSOT 同步（accessoryBarVisibilityChanged）、跨 tab 導航（seeAllTransactionsTapped）三條關鍵路徑完全沒測。

**Action 覆蓋率**：4/8

**未覆蓋關鍵路徑**：
- dashboard(.delegate(.savedRecurringConfirmation)) — effect 編排（ledger.listRecurring() → 找到 template → updateRecurring()），且 catch 區塊靜默吞錯；MainTab 端此 effect 完全沒測，AddTransactionFeatureTests 只驗證 delegate 被『發出』，沒驗證 MainTab『接收後做了什麼』。
- settings(.delegate(.accessoryBarVisibilityChanged)) — Settings 子畫面切換 accessory 開關後回傳上層、MainTab 須同步 state.showAccessoryBar，這條 SSOT 同步膠水路徑無測試保護，desync 風險最高卻最缺覆蓋。
- dashboard(.delegate(.seeAllTransactionsTapped)) — 跨 tab 導航分支（設定 selectedTab = .transactions），無測試。
- tabSelected(Tab) — selectedTab setter，影響 isAccessoryVisible 計算結果，純 setter 但會連動可見性，建議補一條最小驗證。

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — savedRecurringConfirmation delegate 的 effect 編排（listRecurring + updateRecurring + 靜默吞錯）在 MainTab 端零覆蓋
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:118`
  - 細節: MainTabFeature.swift:118-131 handler 收到 dashboard 的 .delegate(.savedRecurringConfirmation(id, newNextDueDate)) 後跑一個 .run effect：try await ledger.listRecurring()、用 id 找 template、改 nextDueDate、try await ledger.updateRecurring(template)，並 catch 後靜默 ignore。MainTabFeatureTests.swift 全檔（grep store.send/store.receive 僅 task / contextActionRequested×2 / transactionExtracted×2）完全沒送過此 delegate，listRecurring/updateRecurring 也沒被 stub。NeuLedgerTests 中對 savedRecurringConfirmation 的唯一斷言在 AddTransactionFeatureTests.swift:294-322，那只驗證 child『發出』delegate，並未驗證 MainTab 的編排（template 命中、nextDueDate 被覆寫、updateRecurring 確實被呼叫、找不到 id 時不呼叫）。這是整組唯一含實際 client 副作用編排的分支，卻無任何保護。
  - 建議修法: 在 MainTabFeatureTests 新增測試：注入 ledgerClient.listRecurring 回傳含目標 id 的 template、updateRecurring 用 spy 斷言被呼叫且 nextDueDate 已更新，並補一條 id 不存在時不呼叫 updateRecurring 的案例。

- **[medium] test-gap** — settings.delegate.accessoryBarVisibilityChanged 同步 showAccessoryBar 的路徑無測試
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:139`
  - 細節: MainTabFeature.swift:139-141：case let .settings(.delegate(.accessoryBarVisibilityChanged(visible))): state.showAccessoryBar = visible。此為 Settings 子畫面開關 → 回傳上層 → MainTab 同步可見性的關鍵 SSOT 膠水（showAccessoryBar 同時存在於 MainTab.State 與 SettingsFeature.State，靠此 delegate 對齊）。MainTabFeatureTests 沒有任何 store.send(.settings(.delegate(...))) 或 store.receive(\.settings...)，此同步分支完全未驗證；一旦回歸破壞，accessory bar 可見性會 desync 卻無測試攔截。
  - 建議修法: 新增測試送出 .settings(.delegate(.accessoryBarVisibilityChanged(false)))，斷言 state.showAccessoryBar == false。

- **[medium] test-gap** — dashboard.delegate.seeAllTransactionsTapped 跨 tab 導航分支無測試
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:114`
  - 細節: MainTabFeature.swift:114-116：收到 dashboard 的 .delegate(.seeAllTransactionsTapped) 後設定 state.selectedTab = .transactions，是 Dashboard『查看全部交易』跳轉到交易 tab 的核心導航邏輯。MainTabFeatureTests 無對應 store.send/receive（grep 確認），此分支未覆蓋。
  - 建議修法: 新增測試送出 .dashboard(.delegate(.seeAllTransactionsTapped))，斷言 state.selectedTab == .transactions。

- **[low] test-gap** — tabSelected setter 連動 isAccessoryVisible 無測試
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:89`
  - 細節: MainTabFeature.swift:89-91 的 .tabSelected(tab) 設定 selectedTab，而 selectedTab 是 computed isAccessoryVisible（line 27-34）的輸入之一（不同 tab 對 path.isEmpty 的判定不同）。雖屬 setter，但會改變 accessory bar 可見性結果，測試檔無任何 .tabSelected 案例。屬低優先，列出供補強。
  - 建議修法: 可選擇性補一條：切到 .transactions tab 後斷言 isAccessoryVisible 為預期值，順帶覆蓋 setter。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — F4 的 suggestedFix 用 .transactions tab 斷言 isAccessoryVisible 無鑑別力——應改用 .settings/.dashboard 才能覆蓋 path.isEmpty gate
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:32`
  - 細節: isAccessoryVisible（MainTabFeature.swift:27-34）對 selectedTab==.transactions 直接 return true（line 32），不經 path.isEmpty 判定；只有 .settings(line 30)/.dashboard(line 31) 才依 child path.isEmpty gate 可見性。原審查員 F4 建議『切到 .transactions tab 後斷言 isAccessoryVisible 為預期值』在 child path 非空時無法區分 tab 切換是否真的改變了可見性結果。若要藉 tabSelected 同時覆蓋可見性連動，測試應切到 .settings（或 .dashboard）並在 settings.path 非空 vs 空兩態下斷言 isAccessoryVisible 切換。此為對既有發現修法的精準度補強，非新分支。
  - 建議修法: F4 補測改為：送 .tabSelected(.settings) 後，分別在 settings.path 為空（isAccessoryVisible==true）與非空（false）兩態斷言，才真正覆蓋 selectedTab→isAccessoryVisible 的 gate 連動。

- **[medium] test-gap** — savedRecurringConfirmation handler 的 .run effect 對 listRecurring/updateRecurring 失敗的『靜默吞錯』分支（line 128-130）即使補測也難以斷言，屬風險點
  - 位置: `Features/Sources/Features/MainTab/MainTabFeature.swift:128`
  - 細節: MainTabFeature.swift:118-131 的 catch 區塊完全空白（line 128-130 僅註解 silently ignore），與 MEMORY.md 記錄的『watch push 三處吞錯補 os_log』為同類問題模式。即使依 F1 補測，TestStore 也只能驗『updateRecurring 未被呼叫且無 state 變更』，無法觀測到吞錯本身（無 log/無 delegate）。這放大了 F1 的嚴重性：listRecurring throw 或 id 命中但 updateRecurring throw 時，使用者的 recurring nextDueDate 不會被更新且無任何回饋或診斷訊號。建議除 F1 的測試外，考慮在 catch 補 os_log（與 watch 同步 follow-up 一致）以利可觀測性。
  - 建議修法: 在 catch 補 os_log 記錄失敗（對齊 watch push 吞錯處理），並在 F1 測試新增 listRecurring throws 與 updateRecurring throws 兩條案例斷言 reducer 不崩潰且不變更 state。

### 覆蓋率抽查結論

抽查同意原審查員『已覆蓋 4』的結論，並對『action case 總數 8』提出修正。我自己數 Action enum（MainTabFeature.swift:38-49）為 7 個 top-level case（tabSelected/task/accessoryBarVisibilityLoaded/accessory/dashboard/transactions/settings）；Reduce switch（line 74-145）實際展開為 12 個 branch（含 .accessory/.dashboard/.transactions/.settings 四個 no-op catch-all）。原審查員『總數 8』應是排除 no-op catch-all 後的有意義 branch 數（8 = 12 − 4 passthrough），這個算法可接受。實際被測試送達或斷言的有意義 branch 為 4：.task、.accessoryBarVisibilityLoaded（task 內 receive）、.accessory(.delegate(.contextActionRequested))（×2 tab）、.accessory(.delegate(.transactionExtracted))（×2 tab）。未覆蓋的關鍵分支與原審查員列出的四項（savedRecurringConfirmation effect 編排、accessoryBarVisibilityChanged SSOT 同步、seeAllTransactionsTapped 跨 tab 導航、tabSelected setter）完全吻合，無遺漏也無虛報。覆蓋率統計合理性通過。補充：transactions/settings 子 reducer 雖被 Scope 掛載並在 task 測試中以 exhaustivity=.off 間接觸及，但 MainTab 層的 .transactions/.settings 非 delegate 路徑本身為 no-op passthrough，不構成需獨立覆蓋的邏輯分支，不算遺漏。

---

## AccessoryBar

**健康度摘要**：AccessoryBar 整體結構健康，State 7 個 property 全部被 View 消費、parent scope/delegate 接線完整。主要問題集中在一個重構殘留的死 Action（aiInputTextChanged，輸入欄已改為 voice-only 後 View 不再有 TextField/binding 去送它）以及一條未被測試覆蓋的關鍵 effect 路徑（aiInputSubmitted 的成功擷取分支，extractFromText 在測試中從未被 stub）。SSOT 維度無違規：各 UI phase 布林為單一寫入點的暫態，aiUnavailable 與 accessoryMode 各有獨立語義，非冗餘投影。

**Action 覆蓋率**：16/18

**未覆蓋關鍵路徑**：
- aiInputSubmitted 成功分支：非空白文字 → isAIInputLoading=true → captureClient.extractFromText → aiExtractionCompleted 串接（extractFromText 從未被 stub，僅 guard 路徑被測）
- recordingTapped granted 分支的語音串流 effect：startVoiceSession yield 文字 → transcriptionUpdated（測試用空串流，effect 實際產出 transcription 未驗證）
- recordingTapped granted 分支的串流錯誤 effect：startVoiceSession throw → catch → transcriptionFailed（catch 路徑未被 effect 觸發）
- aiInputTextChanged：死 action，無發送來源（建議刪除而非補測）

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — 死 Action aiInputTextChanged — voice-only 重構後 View 無任何發送路徑
  - 位置: `Features/Sources/Features/MainTab/AccessoryBarFeature.swift:29`
  - 細節: Action case aiInputTextChanged(String)（宣告於 line 29、處理於 line 88-90，只做 state.aiInputText = text）在全域搜尋 Features/Sources、NeuLedgerTests、NeuLedgerWatchTests、NeuLedgerWidget、Shared、NeuLedger 後，除了 Reducer 自身的宣告與 handler 外沒有任何 store.send 來源。AccessoryView.swift 註解明示展開輸入欄為「Expanded AI input (voice-only)」（line 118），確認無 TextField；grep 'TextField|onChange|$store|binding' 在 View 與 Reducer 皆零命中，也無 BindingReducer/BindableAction，故無任何可能的發送路徑。文字改動只透過 effect 內 transcriptionUpdated 寫入 aiInputText（line 165-167），aiInputTextChanged 是文字輸入欄改成語音後遺留的死碼。正控制（同一 grep 對 aiInputButtonTapped 命中 View line 29/63）證明搜尋手法有效，空結果為真陰性。
  - 建議修法: 刪除 aiInputTextChanged action case 及其 line 88-90 的 handler；若日後恢復文字輸入再重新引入。

- **[high] test-gap** — aiInputSubmitted 成功擷取路徑（extractFromText effect 編排）零覆蓋
  - 位置: `Features/Sources/Features/MainTab/AccessoryBarFeature.swift:107`
  - 細節: Reducer line 107-117 的 aiInputSubmitted 在非空白且非錄音時，會設 isAIInputLoading = true、清 aiInputError，並 .run 呼叫 captureClient.extractFromText 後派 aiExtractionCompleted（帶 cancelInFlight）。測試檔兩個 aiInputSubmitted 案例（line 124 submitIgnoredWhenEmpty、line 303 submitIgnoredWhileRecording）都只觸發 guard 的 early-return；grep 確認 captureClient.extractFromText 在整個測試檔從未被 stub。因此 isAIInputLoading 轉 true 的狀態變更、extractFromText 的呼叫、以及 submit → aiExtractionCompleted 的串接從未被端到端驗證（aiExtractionCompleted 雖被直接 send 測過，但與 submit 的接線斷開）。
  - 建議修法: 新增測試：state.aiInputText 非空、非錄音，stub captureClient.extractFromText 後 send(.aiInputSubmitted) 斷言 isAIInputLoading=true，再 receive(.aiExtractionCompleted(.success(...)))。

- **[medium] test-gap** — 語音串流 transcription effect 路徑（startVoiceSession 產出 → transcriptionUpdated / transcriptionFailed）未經 effect 驗證
  - 位置: `Features/Sources/Features/MainTab/AccessoryBarFeature.swift:145`
  - 細節: recordingTapped 的 granted 分支（line 138-153）會 for-await captureClient.startVoiceSession() 把每筆 text 經 effect 派為 transcriptionUpdated，catch 則派 transcriptionFailed。唯一用到 startVoiceSession 的測試（line 190-206 recordingTappedStartsWhenPermitted）用 continuation.finish() 的空串流，stream 立即結束，因此 effect 實際 yield text → transcriptionUpdated、以及 throw → transcriptionFailed 的 catch 路徑都沒被走到（transcriptionUpdated/transcriptionFailed 僅用直接 store.send 測過，未驗證它們由錄音 effect 產生）。
  - 建議修法: 在 recording 測試中讓 startVoiceSession 串流 yield 一筆文字再 finish，receive(.transcriptionUpdated(...))；另加一個讓串流 throw 的案例 receive(.transcriptionFailed)。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] other** — AccessoryView 切換鍵 chevron 連續兩個 .font 修飾子，.font(.title) 被 .font(Font.Design.size11Semibold) 覆蓋成死碼
  - 位置: `Features/Sources/Features/MainTab/AccessoryView.swift:100`
  - 細節: compactPillContent 的 Menu label Image(systemName: "chevron.up.chevron.down")（line 99）後接 .font(.title)（line 100）再接 .font(Font.Design.size11Semibold)（line 101）。SwiftUI 後者覆蓋前者，line 100 的 .font(.title) 完全無效果（殘留修飾子）。應為 voice/font 調整時遺留，實際生效的是 size11Semibold。屬殘留死碼維度，非邏輯錯誤；inline 視覺尺寸由第二個 .font 決定。
  - 建議修法: 刪除 line 100 的 .font(.title)，只保留 .font(Font.Design.size11Semibold)。

- **[low] test-gap** — aiInputSubmitted 成功分支會清除 aiInputError（Reducer:110），但因 submit 成功路徑未測，此 inline 清錯行為零覆蓋
  - 位置: `Features/Sources/Features/MainTab/AccessoryBarFeature.swift:110`
  - 細節: Reducer:110 在 submit 進入 extraction 前 state.aiInputError = nil。由於 F2 指出整個 submit 成功分支從未被測（extractFromText 從未 stub），此「重新送出時先清掉上一輪 inline 錯誤」的 UX 不變量也一併無覆蓋。與 F2 同源但獨立的斷言點：若日後有人誤刪 line 110，現有測試不會抓到。建議在 F2 補的成功路徑測試中，預設 initial.aiInputError 非 nil，斷言 send(.aiInputSubmitted) 後 aiInputError 變 nil。
  - 建議修法: 在 F2 新增的 submit 成功測試裡加 initial.aiInputError 非 nil 前置，斷言提交後 $0.aiInputError = nil。

### 覆蓋率抽查結論

原審查員「action case 總數 18、已覆蓋 16」基本合理，但需校正計數口徑：AccessoryBarFeature 的「頂層」Action enum 實際只有 16 個 case（task / aiAvailabilityLoaded / accessoryModeLoaded / accessoryModeSwitched / aiInputButtonTapped / aiInputTextChanged / aiInputSubmitted / aiInputDismissed / aiExtractionCompleted / recordingTapped / recordingStarted / permissionDenied / transcriptionUpdated / transcriptionFailed / contextActionTapped / delegate）。要湊到 18，是把巢狀 Delegate enum 的 2 個 sub-case（contextActionRequested / transactionExtracted）也算進去——這兩個有被 store.receive 驗到（test:90/115）。以「handler 是否被 reducer 路徑觸達」granularity 計：14 個 handler 被測試觸達，唯一完全沒被觸達的是 aiInputTextChanged（即 F1 死碼）。delegate handler 本身只 return .none，被當輸出驗證。所以「16/18 covered」在他的計數法下自洽，且未覆蓋清單（aiInputTextChanged 死碼、aiInputSubmitted 成功分支、startVoiceSession yield→transcriptionUpdated、stream throw→transcriptionFailed）四項全部正確、無漏列。需提醒的是他把 aiInputSubmitted 兩個 guard-only case 計為「covered」——以 case-reached 口徑成立，但以 branch/effect 口徑這條成功分支其實零覆蓋（已由 F2 補足）。結論：覆蓋率數字方向正確，計數含巢狀 sub-case 需註明；未覆蓋關鍵路徑清單準確。

---

## Dashboard

**健康度摘要**：Dashboard 組整體結構清楚（sectionPhase 機器、SSOT computed 設計如 filteredBalance/totalBalance/orderedAccounts 都正確且有測試保護），但留有一批重構殘留：refreshCompleted / accountTapped / 三個 quickAction*Tapped 是死 action（無 View 送出也無 parent 轉送），aiInsight / isLoadingInsight / isLoading 三個 state 屬性被 reducer 維護卻無任何 View 讀取、只剩測試斷言。維度 2（SSOT）沒有發現真正的雙份儲存或會 desync 的膠水——computed 衍生用得很乾淨，故零 findings。維度 3 最關鍵的缺口是「子 sheet 寫入後的 refreshAfterMutation 統一重載」（saved/updated/deleted/recurring 四入口）以及 analysisShortcutTapped 導航完全沒有測試，屬 high 風險。

**Action 覆蓋率**：25/31

**未覆蓋關鍵路徑**：
- addTransaction(.presented(.delegate(.saved / .savedWithTransaction))) → refreshAfterMutation：交易新增/編輯後的統一重載（accounts+balances+transactions+stats+sparkline 四 effect merge）完全沒有測試，這是 Dashboard 寫入後資料一致性的核心路徑
- addTransaction(.presented(.delegate(.savedRecurringConfirmation))) → refreshAfterMutation + .send(.delegate(.savedRecurringConfirmation))：週期確認既要重載又要往上轉送 delegate，雙 effect 編排無測試
- detail(.presented(.delegate(.deleted / .updated))) → refreshAfterMutation：交易詳情刪除/更新後的重載分支無測試
- analysisShortcutTapped：餘額總覽 header 唯一導航入口（path.append(.analysis(selectedAccountId:)))，View 實際送出的 action，卻完全沒測試（被測的是 dead 的 accountTapped）
- retrySection(.accounts)：五個 section 只有 accounts 的 retry 分支沒測試（hero/stats/transactions/insight 都有）

### 經交叉驗證確認的發現（confirmed）

- **[low] dead-action** — Action.refreshCompleted 永不被觸發（死 action）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:124`
  - 細節: 全 repo grep `refreshCompleted` 僅命中宣告（line 124）與 case handler（line 214），沒有任何 `.send(.refreshCompleted)`、沒有任何 effect 回傳它、parent（MainTab）也不轉送、測試也不送。pull-to-refresh 由 `.refreshable { await store.send(.pulledToRefresh).finish() }` 驅動，而 isLoading=false 的還原是在 `transactionsUpdated`（line 243）做的，refreshCompleted 的 handler（state.isLoading=false; return .none）形同孤兒。
  - 建議修法: 刪除 refreshCompleted case 與其 handler（line 124、214-216）。

- **[medium] dead-action** — Action.accountTapped(Account.ID) 在 Dashboard 是死 action（導航實際走 analysisShortcutTapped）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:154`
  - 細節: Dashboard 的 chip strip 送的是 `accountChipSelected`（filter 用），header 導航送的是 `analysisShortcutTapped`（line 83 DashboardScreen）。grep `accountTapped` 在 Dashboard 範圍內只命中 DashboardFeature 宣告+handler 與 DashboardFeatureTests 的單一 send；MainTab 不轉送 dashboard.accountTapped。其餘 accountTapped 命中屬 AccountManagementFeature（型別是 Account 非 Account.ID，同名不同 case）。此 case 與 analysisShortcutTapped 邏輯完全重複（都 path.append(.analysis(selectedAccountId:)))，只是參數來源不同，且無任何 View 送出。
  - 建議修法: 刪除 accountTapped case 與 handler（line 154、405-407）並移除對應測試 testAccountTappedOpensAnalysis，導航統一走 analysisShortcutTapped。

- **[medium] dead-action** — 三個 quickAction*Tapped 為死 action（無 View 送出、無 parent 轉送）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:148`
  - 細節: quickActionExpenseTapped/IncomeTapped/TransferTapped（line 148-150）全 repo grep 只命中 DashboardFeature 宣告+handler 與 DashboardFeatureTests 的 send；Dashboard 任何 section view / DashboardScreen 都未送出（sections grep 結果為空），MainTab 只轉送 addTransactionButtonTapped 與 addTransactionWithPrefilledData，不轉送 quickAction*。三者 handler 與 addTransactionButtonTapped 邏輯重疊（expense 那條完全相同）。
  - 建議修法: 若 UI 短期不會接快捷三按鈕則刪除三個 case、handler（line 380-396）與三條對應測試；要保留則須在 view 接上送出點。

- **[medium] unused-property** — State.aiInsight 被 reducer 寫入但無任何 View 讀取（只剩測試斷言）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:67`
  - 細節: 全 repo grep `aiInsight`（排除 action/方法名）只命中宣告（line 67）與兩處 reducer 寫入（line 365 寫入、line 371 清空）及多筆測試斷言；DashboardScreen 與所有 sections（InsightCarousel 渲染的是 store.insights 這個 InsightData 陣列，與 aiInsight: String? 是不同資料）都沒讀取 store.aiInsight。整條 fetchAIInsight → generateAIInsight → aiInsightResponse 產出的字串無處顯示。
  - 建議修法: 若 InsightCarousel 不打算顯示這段 AI 文字，刪除 aiInsight 屬性與其寫入並同步移除測試；若要顯示則在 view 綁定它。

- **[medium] unused-property** — State.isLoadingInsight 被 reducer 維護但無 View 消費（只剩測試斷言）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:68`
  - 細節: grep `isLoadingInsight` 非測試命中只在 DashboardFeature：宣告（line 68）、true（line 341）、false（line 364、370）。DashboardScreen 與所有 sections 皆未讀取（InsightCarousel 的 loading 由 insightPhase 驅動，非 isLoadingInsight）。此 Bool 與 aiInsight 同屬無 UI 出口的死狀態，且與 insightPhase 的 loading 語義部分重疊。
  - 建議修法: 與 aiInsight 一併刪除（含三處寫入），並移除測試中對 isLoadingInsight 的斷言。

- **[low] unused-property** — State.isLoading 無任何 View 讀取（refreshable 走 .finish() 不讀此旗標）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:81`
  - 細節: grep `store.isLoading`/`.isLoading` 在 DashboardScreen 與所有 sections 結果為空；reducer 於 line 190/203 設 true、line 215/243 設 false，但 pull-to-refresh 的 spinner 由 `.refreshable { await store.send(.pulledToRefresh).finish() }`（DashboardScreen line 44-46）自行管理，初次載入的骨架由各 sectionPhase 驅動。isLoading 只剩測試斷言其轉移，無實際 UI 作用。
  - 建議修法: 確認無未來消費者後刪除 isLoading 屬性與四處讀寫，並更新測試；或若要當 redundant 保險則明確標註並接上 view。

- **[high] test-gap** — 交易寫入後的統一重載 refreshAfterMutation 完全未測（saved/updated/deleted 三入口）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:420`
  - 細節: addTransaction delegate（.saved/.savedWithTransaction，line 420-422）、savedRecurringConfirmation（line 424-428，含 refresh + delegate 轉送雙 effect）、detail delegate（.deleted/.updated，line 436-438）三條都呼叫 refreshAfterMutation（accounts+transactions+stats+sparkline 四 effect merge，line 524-531）。grep 顯示 Dashboard 測試套件無任何 addTransaction/detail presentation delegate 的 send；這是「Dashboard 在子 sheet 完成寫入後資料一致性」的核心編排，零覆蓋。
  - 建議修法: 新增測試：send addTransaction/detail 的 presented delegate，receive refreshAfterMutation 觸發的 accountsUpdated/transactionsUpdated/statsComputed/weeklySpendingComputed，並驗證 savedRecurringConfirmation 同時往上送 delegate。

- **[medium] test-gap** — analysisShortcutTapped 導航與 retrySection(.accounts) 分支未測
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:409`
  - 細節: analysisShortcutTapped（line 409-411，View 唯一導航入口，path.append 帶當前 selectedAccountID）grep 在 NeuLedgerTests 零命中；retrySection 五分支只有 hero/stats/transactions/insight 有測試（SectionPhase/Insight/Stats/Scope 套件），.accounts 分支（line 285-287）無測試。delegate.savedRecurringConfirmation 的往上轉送亦未被任一 Dashboard 測試覆蓋。
  - 建議修法: 補三條測試：analysisShortcutTapped 在 selectedAccountID 有值/nil 時的 path.append、retrySection(.accounts) 走 accountsEffect、delegate.savedRecurringConfirmation 轉送。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — accountChipSelected 的 statsPhase/insightPhase 不變雖被測，但 stats/insights 並未隨 chip 重查（已知 TODO，非缺陷）— 真正遺漏的是 retrySection(.transactions) 的 phase-reset 與 accountChipSelected 共用 transactionsEffect 但 cancelInFlight 行為未交叉驗證
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:288`
  - 細節: retrySection(.transactions)（:288-290）與 accountChipSelected（:299-313）都呼叫 transactionsEffect(cancelInFlight:true) 共用 CancelID.transactionObservation。ScopeTests:216 只測 retry 單獨路徑；無測試驗證『chip 切換中途再 retry』或兩者 cancelInFlight 互相取消的競態。屬補強，非硬缺陷，severity low。
  - 建議修法: 補一條測試：accountChipSelected 後緊接 retrySection(.transactions)，斷言前一 effect 被取消、只收到最後一次 transactionsUpdated。

- **[low] dead-action** — State.savingsPercentage 由 statsComputed 寫入並由 StatsRow 讀取，但 insightsClient.todayStats 的 savings 計算與 chip scope 永遠脫鉤（stats 為全域數字，selectedAccountID 變更不重算）
  - 位置: `Features/Sources/Features/Dashboard/DashboardFeature.swift:74`
  - 細節: 非死碼但屬潛在 SSOT 落差：todaySpending/weekSpending/savingsPercentage（:72-74）標註 TODO(stats-follow-up) 說明 todayStats 缺 accountId 參數，導致選帳戶後 StatsRow 仍顯示全域數字（accountChipSelected:299-313 刻意不 merge statsEffect）。這是已在程式碼註解承認的 known gap，原審查員未列為發現。嚴格說不算 bug（設計已知），列為 low 供追蹤。
  - 建議修法: 無需改碼；確保 stats-follow-up 單已開，或在 StatsRow 加註此數字為全域 scope 以免使用者誤解。

### 覆蓋率抽查結論

原審查員「action case 總數 31、已覆蓋 25」的數字需小幅修正但結論成立。我實際清點 DashboardFeature.Action 的 top-level case 為 30 個（lines 122-166；不含 Section/SectionPhase/Destination/CancelID 等其他 enum，也不含 Delegate 巢狀的 2 個 sub-case）。實測有 send/receive 覆蓋的為 25 個（與其數字一致）：task, pulledToRefresh, accountsUpdated, accountBalancesComputed, transactionsUpdated, categoriesLoaded, weeklySpendingComputed, accountChipSelected, statsComputed, insightsLoaded, insightIndexChanged, transactionRowToggled, sectionFailed, retrySection, fetchAIInsight, aiInsightResponse, addTransactionButtonTapped, quickActionExpenseTapped/IncomeTapped/TransferTapped, addTransactionWithPrefilledData, seeAllTransactionsTapped, accountTapped, transactionTapped, delegate。完全未覆蓋的 5 個：refreshCompleted, analysisShortcutTapped, path, addTransaction(presented 各 delegate 分支), detail(presented delegate 分支)。25+5=30，與我的 raw count 吻合；審查員的『31』疑似把 delegate 與其 sub-case 重複計入或把某個巢狀 case 算進去，誤差 1。其列出的 5 條未覆蓋關鍵路徑（refreshAfterMutation 三入口、savedRecurringConfirmation 雙 effect、analysisShortcutTapped、retrySection(.accounts)）我逐條獨立重現，全部屬實且精準，對應 F7/F8。整體覆蓋率評估可信，僅 total case 數字 31→30 需訂正，不影響缺口判斷。

---

## AddTransaction

**健康度摘要**：整體健康度良好。維度 1（死碼）與維度 2（SSOT）皆零發現：所有 State property 與 Action case 都有 View / reducer / parent 消費者，mode enum 內嵌整包 entity 屬於標準 TCA 表單編輯模式（單一寫入點在 init、entity 唯讀），非 desync 風險。問題集中在維度 3：reducer 有約 30 條分支，但測試遺漏數條關鍵邏輯路徑，最嚴重的是 .add 模式下「建立週期性範本（createRecurring）」的 effect 編排完全沒被測，以及 AI 類別建議成功/失敗回應、note 防抖 AI 擷取 effect 都缺測。

**Action 覆蓋率**：22/30

**未覆蓋關鍵路徑**：
- .add 模式 recurring 範本存檔（saveTapped→ledger.record + ledger.createRecurring 兩段 effect，含 weekly/monthly/yearly 三條 nextDue 計算分支）完全無測，這是 recurring 功能的核心副作用
- categorySuggestionsReceived(.success) 的 filteredCategories 過濾與 (.failure) 錯誤處理分支無測
- .binding(\.note) → 500ms debounce → extractFromText → backgroundExtractionCompleted 的完整 AI 擷取 effect 鏈與 .cancel(noteDebounce) 分支無測
- recurringFrequencyChanged 週期切換（recurring 範本最終頻率唯一寫入點）無測
- accountSelected / categorySelected 的 inline 驗證錯誤清除分支無測

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — saveTapped 在 .add 模式 + recurringFrequency != nil 時建立 RecurringTransaction 範本的 effect 完全未測
  - 位置: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:291`
  - 細節: reducer line 291-314：.add 存檔成功後若 recurringFrequency_ 非 nil，會額外計算 nextDue（weekly/monthly/yearly 三分支）並呼叫 ledger.createRecurring(template)。全域搜尋 createRecurring 在 AddTransactionFeatureTests.swift 零命中（grep 結果為空），且無任何測試把 .add 模式 state.recurringFrequency 設成非 nil 後送 saveTapped。三條 BudgetPeriod nextDue 計算分支與整個 createRecurring 寫入路徑皆無覆蓋，屬於業務關鍵的副作用編排（record + createRecurring 兩段）。
  - 建議修法: 新增測試：.add 模式設定 recurringFrequency = .monthly 後送 saveTapped，spy ledger.createRecurring 斷言被呼叫一次且 template.frequency/nextDueDate 正確。

- **[medium] test-gap** — categorySuggestionsReceived 的 success 與 failure 分支皆未測
  - 位置: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:441`
  - 細節: reducer line 441-452 處理 AI 類別建議回應：.success 會把 suggestions 過濾成 filteredCategories 內存在的名稱寫進 suggestedCategoryNames 並清 isSuggestingCategory；.failure 設 categorySuggestionError。測試只覆蓋 suggestCategoryTapped 的「AI unavailable no-op」分支（test 第 213-219 行），grep 確認測試檔無任何 categorySuggestionsReceived 的 store.send/receive。成功路徑的 filteredCategories 過濾邏輯（核心分支）與錯誤處理都無覆蓋。
  - 建議修法: 在 makeStore(aiAvailable: true) 下送 suggestCategoryTapped，receive(.categorySuggestionsReceived(.success(...))) 斷言 suggestedCategoryNames 過濾結果，並補一條 .failure 設 categorySuggestionError 的測試。

- **[medium] test-gap** — .binding(\.note) 的防抖 AI 擷取 effect 編排未測
  - 位置: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:167`
  - 細節: reducer line 167-181：使用者輸入 note 時同步設 isBackgroundParsingNote、並以 500ms debounce 觸發 captureClient.extractFromText 後送 backgroundExtractionCompleted（含 isAvailable() false 時直接 send(nil) 的早退分支與 note 清空時 .cancel 分支）。測試只直接送 backgroundExtractionCompleted（第 227/249 行），grep 確認無 binding.note 的測試。整段 binding→debounce→extractFromText→backgroundExtractionCompleted 的 effect 鏈與 isBackgroundParsingNote 同步點皆無覆蓋。
  - 建議修法: 用 TestClock 注入 scheduler，送 \.binding.note 後 advance 500ms，receive backgroundExtractionCompleted 並斷言 isBackgroundParsingNote 流轉；另補 note 清空送 .cancel 的分支。

- **[low] test-gap** — recurringFrequencyChanged action 未被任何測試送出
  - 位置: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:235`
  - 細節: reducer line 235-237 處理 Picker 變更週期（View line 482 由頻率 Picker 送出）。grep recurringFrequencyChanged 在 NeuLedgerTests 零命中——只有 recurringToggled 被測（test 第 256-292 行）。雖屬簡單 setter，但它是 recurring 範本最終頻率的唯一寫入點，與上方未測的 createRecurring 存檔路徑相依，建議一併補。
  - 建議修法: 補一條 send(.recurringFrequencyChanged(.yearly)) 斷言 state.recurringFrequency == .yearly。

- **[low] test-gap** — categorySelected 與 accountSelected 的錯誤清除分支未測
  - 位置: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:215`
  - 細節: accountSelected（line 215-219，View line 622 送出）清 accountError + transferError；categorySelected（line 226-229，View line 539 送出）清 categoryError。測試只覆蓋 toAccountSelected（test 第 117-130 行）。grep 確認 AddTransactionFeatureTests 內無 categorySelected/accountSelected 的 store.send。這兩條是表單驗證錯誤的 inline 清除路徑（與 saveTapped 設錯誤對稱），屬驗證邏輯而非純 binding。
  - 建議修法: 各補一條：預設 state 帶對應 error，送 accountSelected/categorySelected 斷言該 error 與 transferError 被清為 nil。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — typeChanged action 完全未測——其 categoryId 重置副作用無覆蓋
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/AddTransactionFeatureTests.swift:0`
  - 細節: reducer line 210-213 的 typeChanged 不只是 setter：它把 state.type 設成新值後會將 state.categoryId 重置為 nil（因為 filteredCategories 依 type 過濾，切換類型後舊分類必須清掉）。`grep typeChanged NeuLedgerTests/Tests/FeaturesTests/AddTransactionFeatureTests.swift` 零命中（全 repo 僅 CarrierManagementFeatureTests 有同名 action，非本 feature）。原審查員的 F1-F5 與覆蓋率摘要的「未覆蓋關鍵路徑」清單皆完全遺漏此 action。它由 View line 163 的類型分段按鈕送出，是表單最常觸發的互動之一，且帶有清分類的業務語意，比 F4/F5 更值得補。
  - 建議修法: 補一條：state 預設 categoryId 非 nil，送 .typeChanged(.income) 斷言 state.type == .income 且 state.categoryId == nil。

### 覆蓋率抽查結論

部分修正。質性結論成立但數字偏高。我自己數：Action enum 頂層 case = 21（binding/task/optionsLoaded/typeChanged/accountSelected/toAccountSelected/categorySelected/recurringToggled/recurringFrequencyChanged/saveTapped/dismiss/savedSuccessfully/savedSuccessfullyWithTransaction/delegate/backgroundExtractionCompleted/suggestCategoryTapped/categorySuggestionsReceived/recordingTapped/transcriptionUpdated/transcriptionFailed/recordingPermissionResult），加 Delegate 子 enum 4 個（saved/savedWithTransaction/savedRecurringConfirmation/dismissed）共 25 個 case，並非原審查員宣稱的 30。30 應是把 binding 三條子路徑（amountText/note/泛型）與 categorySuggestionsReceived 的 success/failure 拆算所致，屬重複計數。實際完全未被任一測試送出/接收的頂層 case 為：typeChanged、accountSelected、categorySelected、recurringFrequencyChanged、categorySuggestionsReceived，以及 .binding(\\.note) 子路徑——共 5 個頂層 case + 1 條 binding 子路徑未測。原審查員列出的 F1-F5 全部成立，但漏列 typeChanged（見 missedFindings）。覆蓋率「已覆蓋 22」與分子分母都不可信，但「列出的未覆蓋關鍵路徑確實未覆蓋」此一核心判斷經我逐條 grep 驗證為真。SSOT 方面無違規：兩檔皆無 import SwiftData，View 全程透過 store.* 讀取，無重複狀態源。

---

## Transactions

**健康度摘要**：TransactionsFeature 整體結構健康：State 無 stored property 重複或 SSOT desync（transactions 為單一資料來源，分組/搜尋顯示皆於 View computed 推導；activeFilter 與 searchText 為各自獨立關注點，無手動同步膠水）。唯一殘留是 State.activeFilterCount 這個 computed property（重構後計數邏輯已搬到 FilterFeature，本檔版本零消費者，低風險）。真正的問題在測試覆蓋：17 個 action case 僅 11 個被驗證，且未覆蓋的正是搜尋主路徑（searchDebounced→ledger.search）與 detail/addTransaction 三組 delegate 回流＋reload effect 編排——這些是最容易回歸的核心邏輯，建議優先補齊。

**Action 覆蓋率**：11/17

**未覆蓋關鍵路徑**：
- searchDebounced — debounce 後實際呼叫 ledger.search(text) 並把結果灌回 transactionsLoaded 的搜尋主路徑，完全沒有測試（測試只覆蓋到送出 searchTextChanged 設值，debounce + search effect 被 exhaustivity=.off 略過）
- detail(.presented(.delegate(.deleted/.updated))) — 從詳情頁刪除/更新交易後同步 state.transactions 並關閉 sheet 的兩條 delegate 分支無測試，updated 的 firstIndex 替換邏輯尤其需驗證
- addTransaction(.presented(.delegate(.saved))) — 新增交易成功後關閉 sheet 並重新 listAll 重載清單的 effect 編排無測試
- filter(.presented(.delegate(.dismissed))) 與 addTransaction(.presented(.delegate(.dismissed))) — 子頁取消時關閉 sheet 的分支無測試
- addTransactionWithPrefilledData — 從 TabBar AI 抽取結果開啟 .addPrefilled 模式 sheet 的分支在本 suite 無測試（僅在 MainTabFeatureTests 間接驗證 routing）

### 經交叉驗證確認的發現（confirmed）

- **[low] unused-property** — State.activeFilterCount computed property 無任何消費者（與 FilterFeature.activeFilterCount 同名但不同型別）
  - 位置: `Features/Sources/Features/Transactions/TransactionsFeature.swift:33`
  - 細節: 全域 grep `activeFilterCount` 命中四處：TransactionsFeature.swift:33（宣告）、FilterView.swift:53-54、FilterFeature.swift:44。FilterView.swift:53 的 `store` 型別是 StoreOf<FilterFeature>，讀的是 FilterFeature.State.activeFilterCount（FilterFeature.swift:44），不是本檔的版本。TransactionsView.swift 內 grep `activeFilterCount` 為空，reducer body 也未讀取此 property。故 TransactionsFeature.State.activeFilterCount 為重構殘留：badge 計數邏輯已搬到 FilterFeature，這份是 dead copy。注意它是 computed property（非 stored），不會造成 desync，但仍是死碼。
  - 建議修法: 刪除 TransactionsFeature.State.activeFilterCount（line 33-41），badge 計數由 FilterFeature 內的同名 property 負責。

- **[high] test-gap** — searchDebounced（debounce 後呼叫 ledger.search 的搜尋主路徑）完全無測試
  - 位置: `Features/Sources/Features/Transactions/TransactionsFeature.swift:112`
  - 細節: testSearchTextChanged（測試檔 line 46-61）把 exhaustivity 設為 .off 後只斷言 searchText 被設值，debounce effect 與後續 .searchDebounced → ledger.search(text) → transactionsLoaded 的整段非空字串搜尋路徑從未被 store.receive 驗證（grep store.receive 在本 suite 無 searchDebounced/search 相關命中）。這是本畫面最核心的搜尋功能，stub 的 $0.ledgerClient.search 在該測試中根本沒被走到。
  - 建議修法: 新增測試直接 send(.searchDebounced)（或用 TestClock advance 0.3s）斷言 receive(\.transactionsLoaded) 帶 search stub 結果。

- **[high] test-gap** — detail delegate 三分支（deleted / updated / dismiss）與 addTransaction.saved 重載路徑無測試
  - 位置: `Features/Sources/Features/Transactions/TransactionsFeature.swift:173`
  - 細節: reducer 在 line 173-187 處理 detail delegate deleted（從 state.transactions 移除 + 關 sheet）、updated（firstIndex 替換 + 關 sheet）、dismiss；line 193-202 處理 addTransaction.saved（關 sheet + 重新 listAll）與 dismissed。測試檔 grep store.send/receive 僅覆蓋 transactionTapped 開啟 detail（line 194），這些 delegate 回傳與 effect 編排分支均無測試。updated 的 firstIndex 命中/未命中分支、saved 後的 reload effect 是高價值且易回歸的邏輯。
  - 建議修法: 補測 detail(.presented(.delegate(.deleted/.updated))) 與 addTransaction(.presented(.delegate(.saved))) 的 state 變更與 reload effect。

- **[medium] test-gap** — filter / addTransaction 的 dismissed delegate 關閉 sheet 分支無測試
  - 位置: `Features/Sources/Features/Transactions/TransactionsFeature.swift:131`
  - 細節: line 131-133 filter(.presented(.delegate(.dismissed))) 與 line 200-202 addTransaction(.presented(.delegate(.dismissed))) 各將對應 @Presents state 設為 nil。測試檔無對應 store.send（grep 僅見 filterApplied 於 line 116）。雖屬導航膠水，但這兩條 delegate 分支是明確的條件邏輯路徑，且 dismissed 與 SwiftUI .dismiss 行為不同（手動清 state），值得一條測試守住。
  - 建議修法: 各補一條 send(.filter(.presented(.delegate(.dismissed)))) / addTransaction 版本，斷言對應 presents state 變 nil。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] ssot-violation** — 三條重載路徑（.task / 清空搜尋 / addTransaction.saved）硬編 TransactionFilter() 忽略 state.activeFilter，導致 filter 仍亮燈但清單回到全部
  - 位置: `Features/Sources/Features/Transactions/TransactionsFeature.swift:196`
  - 細節: activeFilter 是「清單該顯示哪些交易」的 source of truth，但只有 .filter(.filterApplied)（line 127 用 newFilter）尊重它。其餘三處都傳空 filter：.task（line 87 `ledger.listAll(filter: TransactionFilter())`）、清空搜尋分支（line 102 同樣 TransactionFilter()）、addTransaction.saved 重載（line 196 同樣 TransactionFilter()）。後果：使用者套用 filter（hasActiveFilters→true，filterButton 亮 8pt 圓點 TransactionsView.swift:88）後新增/儲存一筆交易，line 193-198 用空 filter 重抓 → 清單顯示全部交易，但 activeFilter 仍非空、filter 燈仍亮，UI 與 visible list desync。search() 走另一條 ledger.search(query) 只吃字串、本就不吃 filter，屬另一語意。修正方向：上述三處改傳 state.activeFilter（saved/task），或明確設計決定清掉 activeFilter。非導航膠水、非單一寫入點快取，是 reload effect 的 filter 來源邏輯分歧。
  - 建議修法: saved 重載與 .task 改用 `ledger.listAll(filter: state.activeFilter)`（清空搜尋分支同理），讓三條重載路徑與 filterApplied 共用同一 activeFilter 來源。

### 覆蓋率抽查結論

同意原審查員統計。我自行枚舉 Action enum（TransactionsFeature.swift:46-67）得 17 個 case，與「總數 17」一致。逐一核對測試覆蓋：已覆蓋 11（task、transactionsLoaded、searchTextChanged、filterButtonTapped、contextActionTapped、transactionTapped、deleteTransaction、deleteConfirmed、deleteCancelled、transactionDeleted、filter — 其中 filter 僅測 filterApplied 分支）；未覆蓋 4（searchDebounced、addTransactionWithPrefilledData、detail、addTransaction）。原審查員把 addTransactionWithPrefilledData 列入未覆蓋關鍵路徑但「未」放進 F1-F4 正式發現，判斷正確：它經由 MainTabFeature 的 Scope 在 MainTabFeatureTests.swift:90-91（store.receive(\\.transactions.addTransactionWithPrefilledData) 並斷言 addTransaction?.mode == .addPrefilled）間接驅動到 child reducer，per-suite 直接測試雖缺、但 reducer 路徑已被走過，降一級處理合理。11/17 覆蓋數準確。

---

## TransactionDetail

**健康度摘要**：TransactionDetail 整組架構大致健康：刪除視窗（5 秒 undo / 過期刪除 / 刪除失敗 alert）、insight 載入、detent 切換、編輯儲存回傳 delegate 等核心邏輯都有對應測試。主要問題集中在維度 2 的 SSOT：State 同時保存 account/toAccount 整包與其 name 投影兩份，name 投影無任何 View 消費卻靠 namesLoaded 手動同步，屬冗餘且可 desync 的重複狀態，應砍掉改讀 account?.name。維度 1 另有一個 edit-only 畫面收不到的 .saved delegate 分支。維度 3 三條低風險路徑（dismiss 關閉、編輯取消、deleteFailureAlert dismiss）缺覆蓋。

**Action 覆蓋率**：14/19

**未覆蓋關鍵路徑**：
- dismiss — common_close 按鈕觸發的 await dismiss() 效果無測試，關閉行為無回歸保護
- editTransaction(.delegate(.dismissed)) — 取消編輯後收起 sheet 的 state.editTransaction = nil 路徑未測
- deleteFailureAlert(PresentationAction) — 刪除失敗 alert 的 dismiss/互動分支（reducer 第193行）未測
- editTransaction(.delegate(.saved)) — 此分支於 edit-only 畫面不可達，無法也不需測（屬死碼）

### 經交叉驗證確認的發現（confirmed）

- **[medium] ssot-violation** — state.accountName 是 account.name 的重複投影，無任何 View 消費
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:22`
  - 細節: State 同時存了 account: Account?（第24行）與 accountName: String?（第22行）。reducer 在 namesLoaded（第124行）用 account?.name 把名字再存一份。全域 Grep accountName：唯一的讀取者是測試（TransactionDetailFeatureTests.swift:143）與 preview 的死寫入（TransactionDetailView.swift:206/213/220），沒有任何 production View body 讀 store.accountName。實際渲染帳戶名的 DetailFieldsCard 是吃 store.account（TransactionDetailView.swift:23）再透過 AccountChip 顯示。因此 accountName 是 account.name 的冗餘投影，且兩者靠 namesLoaded 手動同步，屬會 desync 的重複狀態。
  - 建議修法: 移除 accountName property、namesLoaded 的 accountName 參數與 reducer 賦值；需顯示名稱處改用 account?.name，並同步刪除測試斷言與 preview 死寫入。

- **[medium] ssot-violation** — state.toAccountName 是 toAccount.name 的重複投影，無任何 View 消費
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:23`
  - 細節: 與 accountName 同樣的問題：State 同時有 toAccount: Account?（第25行）與 toAccountName: String?（第23行），reducer 在 namesLoaded（第125行）用 toAccount?.name 再存一份。全域 Grep toAccountName：唯一讀取者是測試（TransactionDetailFeatureTests.swift:144），production 端 DetailFieldsCard 用 store.toAccount（TransactionDetailView.swift:24）渲染，沒有任何 View 讀 store.toAccountName。preview 第222行為死寫入。
  - 建議修法: 移除 toAccountName property、namesLoaded 的 toAccountName 參數與 reducer 賦值，需要名稱處改讀 toAccount?.name，同步更新測試與 preview。

- **[low] dead-action** — editTransaction(.delegate(.saved)) 分支在本畫面不可達
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:204`
  - 細節: TransactionDetailFeature 只會以 .edit 模式開 AddTransactionFeature（第144行 mode: .edit(state.transaction)）。AddTransactionFeature 的儲存路徑中，.edit 分支送 .savedSuccessfullyWithTransaction → .delegate(.savedWithTransaction) 後立即 return（AddTransactionFeature.swift:316-333），永遠不會走到 .savedSuccessfully → .delegate(.saved)（AddTransactionFeature.swift:363-368，僅 .add/.addPrefilled 模式）。故 detail reducer 第204-206行的 .saved 分支在 production 不可達；即使收到，緊接的 catch-all .editTransaction（第212行）也會以相同行為（return .none，但不清 sheet）處理，語義反而不一致。
  - 建議修法: 刪除 line 204-206 的 .saved 分支（edit-only 畫面收不到）；若擔心防禦性需求，保留並加註解說明僅為冗餘保險。

- **[low] test-gap** — dismiss action 的關閉效果完全未測
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:196`
  - 細節: reducer 的 .dismiss 分支（第196-197行）回傳 .run { await dismiss() }，由 View 的 common_close 按鈕觸發（TransactionDetailView.swift:52），parent 也在 TransactionsFeature.swift:185 監聽 .detail(.dismiss)。四個測試檔 Grep store.send/store.receive 結果中沒有任何 .dismiss，此關閉路徑與 DismissEffect 呼叫無測試覆蓋。
  - 建議修法: 加一測：注入 spy DismissEffect，send(.dismiss) 後斷言 dismissed == true。

- **[low] test-gap** — 編輯表單取消（editTransaction(.dismissed)）清 sheet 路徑未測
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:208`
  - 細節: reducer 第208-210行處理 .editTransaction(.presented(.delegate(.dismissed)))，將 state.editTransaction 設為 nil 以收起編輯 sheet（此 delegate 在 AddTransactionFeature.swift:386 取消時送出，於 edit 模式可達）。測試只覆蓋了 .savedWithTransaction（TransactionDetailFeatureTests.swift:61）分支，沒有任何測試送 .dismissed，取消編輯後 sheet 是否正確關閉無回歸保護。
  - 建議修法: 加一測：先設 editTransaction 非 nil，send(.editTransaction(.presented(.delegate(.dismissed)))) 後斷言 editTransaction == nil。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — deleteFailureAlert 的互動/dismiss 分支（reducer line 193）從未被 send，只斷言 AlertState 出現
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:193`
  - 細節: DeleteWindowTests.swift:99-109 只在 deleteFailed 後斷言 deleteFailureAlert 的 AlertState 內容（appearance），但 grep 全 NeuLedgerTests 對 send(.deleteFailureAlert / receive(.deleteFailureAlert / .deleteFailureAlert(.presented(.dismiss)) 零命中——使用者按 alert 的 common_ok（action: .dismiss）後走 reducer line 193-194 case .deleteFailureAlert: return .none 這條互動分支完全沒測。原審查員的覆蓋率備註已把 deleteFailureAlert(PresentationAction) 列為未覆蓋，方向正確，此處補上精確證據：appearance 已測、interaction 未測。
  - 建議修法: 加一測：先進入 deleteFailureAlert 非 nil，send(.deleteFailureAlert(.presented(.dismiss))) 後斷言 deleteFailureAlert == nil（由 ifLet 自動清除）。

- **[low] test-gap** — .task 失敗落到 insightFailed 的整合路徑未測（只測了直接 send(.insightFailed)）
  - 位置: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift:113`
  - 細節: InsightTests.swift:25-35 直接 send(.insightFailed) 驗 state.insight = nil，但 reducer .task 的第二個 .run（Feature.swift:113-120）在 insightsClient.detailStats 拋錯時才 send(.insightFailed) 這條 catch 路徑沒有整合測試覆蓋——沒有任何測試注入會 throw 的 detailStats 再 send(.task) 驗 receive(.insightFailed)。屬低風險邊角（branch 本身極簡），但 .task 的錯誤分支無回歸保護。
  - 建議修法: 加一測：$0.insightsClient.detailStats = { _ in throw SomeError() }，send(.task) 後 receive(\.insightFailed) 斷言 insight == nil。

### 覆蓋率抽查結論

原審查員「action case 總數 19、已覆蓋 14」的「19」並非 Action enum 的頂層 case 數。我實際數過：頂層 Action case（Feature.swift:42-67）為 16 個；reducer body 的 switch 分支（Feature.swift:93-217）為 19 個——差在 editTransaction 一個 enum case 在 reducer 展開成 4 條分支（savedWithTransaction / saved / dismissed / catch-all）。所以「19」對應的是 reducer 分支數而非 action case 數，用詞不精確但分母合理（以行為路徑計）。其列的四條未覆蓋路徑我逐一複核皆成立：(1) dismiss—確無測；(2) editTransaction(.delegate(.dismissed))—確無測；(3) deleteFailureAlert PresentationAction 互動分支—確只測 appearance 未測 interaction；(4) editTransaction(.delegate(.saved))—確為 edit-only 畫面不可達的死碼、不需測，判定正確。整體覆蓋率統計結論：同意其判斷方向，惟「總數 19」應註明是 reducer 分支數、頂層 action case 實為 16；另補兩條原審查員漏列的低風險 test-gap（deleteFailureAlert 互動分支、.task 失敗→insightFailed 整合路徑）。"}

---

## Filter

**健康度摘要**：FilterFeature 的核心 toggle/apply/clear/delegate 邏輯健康且測試覆蓋良好。主要問題集中在重構殘留：isLoading property 與 .dismiss action 在 View/reducer 路徑上完全沒有消費者，僅被測試引用；hasActiveFilters 計算屬性同樣只有測試在用。另外 applyTapped 內最具風險的 dateRange 三分支邏輯完全沒有測試覆蓋。State 的 single source of truth 沒有違規。

**Action 覆蓋率**：13/14

**未覆蓋關鍵路徑**：
- applyTapped 的 dateRange 分支邏輯（start<=end / 僅 start fallback Date() / start>end）——三條分支皆未測，是 reducer 內唯一非 trivial 的純函數運算
- .task effect 的錯誤路徑——listCategories/listAccounts/listTags 任一 throw 時 isLoading 卡在 true、optionsLoaded 不送出，目前測試只覆蓋 happy path
- .task 的 .cancellable(id:) 取消行為——sheet 在載入途中被關閉時是否正確取消，未驗證

### 經交叉驗證確認的發現（confirmed）

- **[low] unused-property** — State.isLoading 在 View 與 reducer 路徑上無消費者，僅測試引用
  - 位置: `Features/Sources/Features/Transactions/FilterFeature.swift:23`
  - 細節: isLoading 在 .task 設為 true（line 94）、.optionsLoaded 設為 false（line 105），但全域 grep 顯示 FilterView.swift 完全沒有 store.isLoading 讀取點（回傳 NONE）——FilterView 是用 `if !store.categories.isEmpty`（line 22/25/28）gate 各 section，並非靠 loading 旗標。唯一消費者是 FilterFeatureTests testTaskLoadsOptions（line 44-52）。其他 isLoading 命中（TransactionsFeature/TransactionsView）是同名不同型別、屬另一 feature，已點開確認無關。屬重構殘留死 state。
  - 建議修法: 移除 isLoading property 及 .task/.optionsLoaded 兩處賦值，並同步刪掉 testTaskLoadsOptions 對 $0.isLoading 的斷言。

- **[medium] dead-action** — Action.dismiss 永不被送出（View 無 Cancel 鈕、parent 不轉送），僅測試觸發
  - 位置: `Features/Sources/Features/Transactions/FilterFeature.swift:70`
  - 細節: .dismiss case（宣告 line 70、body line 182-186）送 delegate(.dismissed)+呼叫 dismiss()。grep 確認 FilterView.swift 從未 store.send(.dismiss)（toolbar cancellationAction line 44 送的是 .clearAllTapped）。parent TransactionsFeature 只 handle .filter(.presented(.delegate(.dismissed)))（line 131）回收 sheet，從不主動送子 feature 的 .dismiss action。唯一觸發者是 FilterFeatureTests testDismissEmitsDelegateAction（line 311）。sheet 由系統下滑/parent ifLet 自動回收，這條通道實際 UI 不會走到。非 @Presents/CancelID 機制，而是無發送點的自訂 case。
  - 建議修法: 若 sheet 只靠系統下滑回收，移除 .dismiss case 與對應測試；若需顯式關閉鈕，則在 FilterView toolbar 補一個送 .dismiss 的 Button 讓此 case 生效。

- **[low] unused-property** — State.hasActiveFilters 計算屬性僅測試引用，View 與 reducer 皆未消費
  - 位置: `Features/Sources/Features/Transactions/FilterFeature.swift:38`
  - 細節: hasActiveFilters（line 38-42）為 computed property。消費者全域搜尋：FilterView.swift grep 回傳 NONE（View 顯示 active 數量用的是 activeFilterCount，line 53-54，那個有被消費）；reducer body 未引用。唯一引用是 FilterFeatureTests 的 testHasActiveFiltersFalseInitially（line 320）與 testHasActiveFiltersTrueWithTypes（line 327）。TransactionsFeature.hasActiveFilters（line 25）同名不同型別屬另一 feature 且有被 TransactionsView 消費，已確認無關。屬只被測試使用的 derived API surface（computed 故無 desync 風險，severity 低）。
  - 建議修法: 移除 hasActiveFilters 計算屬性與其兩條測試；若想保留供未來用途請明確標註，否則為死碼。

- **[medium] test-gap** — applyTapped 的 dateRange 三分支（start<=end / start-only fallback / start>end）完全無測試
  - 位置: `Features/Sources/Features/Transactions/FilterFeature.swift:152`
  - 細節: applyTapped（line 151-171）建構 dateRange 有三分支：①start 且 end 且 start<=end → start...end（line 153）；②僅 start → start...Date()（line 155-156）；③否則 nil（line 157）。FilterFeatureTests 三個 apply 測試（testApplyTappedEmitsDelegate line 192、testApplyTappedEmptyFilter line 211、testApplyTappedWithCategoryFilter line 230）全部 dateRange 都是 nil 路徑，從未先設 startDate/endDate 再 apply。最有風險的「僅設 start fallback Date()」與「start>end 落回 nil」邏輯零覆蓋——含 Date() 與比較運算的分支最易回歸破。
  - 建議修法: 新增測試：設 start+end(start<=end) 驗 dateRange=start...end；僅設 start 驗下界=start 上界為當下；設 start>end 驗落回 nil（可注入 $0.date 固定時鐘以斷言 upperBound）。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — .task effect 的錯誤路徑（listCategories/listAccounts/listTags 任一 throw）完全無測試，且失敗時 UI 靜默呈現空 section
  - 位置: `Features/Sources/Features/Transactions/FilterFeature.swift:95`
  - 細節: .task 的 .run（line 95-101）對三個 ledger 呼叫用 try await (categories, accounts, tags)，無 catch。任一 throw 時 error 直接由 effect 吞掉、.optionsLoaded 永不送出，state.categories/accounts/tags 保持空、isLoading 卡在 true。FilterView 的 section 由 !store.categories.isEmpty（line 22/25/28）gate，故載入失敗時 filter sheet 會靜默只剩 typeSection+dateSection，使用者看不到分類/帳戶/標籤也無任何錯誤提示。makeStore（FilterFeatureTests:25-36）三個 closure 都 stub 成 happy path，無任一測試覆寫成 throw。原審查員在覆蓋率敘述（未覆蓋關鍵路徑第 2 條）有口頭提到此路徑，但未列入結構化發現清單，屬遺漏。
  - 建議修法: 新增測試：把 $0.ledgerClient.listCategories（或其一）覆寫成 throw，斷言 .optionsLoaded 不送出、categories 維持空；並考慮在 reducer 用 .catch/ TaskResult 至少把 isLoading 復位或送出錯誤狀態，避免載入失敗時 section 靜默消失。

### 覆蓋率抽查結論

合理性抽查通過，同意原審查員統計。我自己枚舉 FilterFeature.Action：top-level 12 個（task, optionsLoaded, typeToggled, categoryToggled, accountToggled, tagToggled, startDateChanged, endDateChanged, applyTapped, clearAllTapped, dismiss, delegate）＋ Delegate 內 2 個 sub-case（filterApplied, dismissed）＝ 14，與「總數 14」一致。逐 case 數測試發送/接收次數：全部 14 個 case 都至少被觸發一次（dismiss 1 次、delegate.dismissed 1 次、其餘多次），所以「已覆蓋 13」指的是 case-level 全覆蓋、唯一未涵蓋的是 applyTapped 這個 case 內部的 dateRange 三分支（intra-case branch，非整個 case），與 F4 一致。原審查員列的三條「未覆蓋關鍵路徑」（dateRange 分支 / .task 錯誤路徑 / .task 取消行為）我覆核皆屬實——其中 dateRange 分支已成 F4 結構化發現，.task 錯誤路徑我已補成 missedFinding（原本只在敘述提及未入清單），.task .cancellable 取消行為確實也無測試（屬 low，未另立發現）。統計無高估。

---

## Analysis

**健康度摘要**：Analysis 畫面組整體健康度良好：State 命名清楚、effect 編排合理、測試覆蓋率相當高（14 個 top-level action 中 12 個有測，含 success/empty/failure/AI/帳戶過濾等分支）。三個維度各找到具體殘留：dismissInsight 是無任何 UI 觸發的死 action；AnalysisData.budgetMetrics 是恆空、永不讀取的重複死投影；AIAssistantCardView 的 isAvailable gating 因子 .task 永不觸發而形成死鎖，使整段 AI 助理區塊變成死碼。測試面最大缺口是 loadData 兩條並發 effect 的協調與 budget effect 的 cancellable 取消語義從未被驗證。

**Action 覆蓋率**：12/14

**未覆蓋關鍵路徑**：
- aiAssistant(_) scope 整合：parent AnalysisFeatureTests 從未送出 .aiAssistant(...)，子 reducer 雖有自己的 AIAssistantFeatureTests，但 Scope wiring（parent 是否正確轉送、isAvailable gating）在 Analysis 層完全沒測；恰好這裡藏著 isAvailable 永遠為 false 的死鎖 bug（見 findings）
- binding(_)：BindableAction/BindingReducer 已接上但無任何 $store 雙向綁定送出此 case，測試也未覆蓋（屬無效機制，非關鍵路徑）

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — dismissInsight action 無任何 View 會送出（死 Action）
  - 位置: `Features/Sources/Features/Analysis/AnalysisFeature.swift:232`
  - 細節: 全域 grep `dismissInsight` 只命中三處：Action 宣告(line 70)、reducer case(line 232)、以及測試 testDismissInsight。唯一渲染 insight 的 UI 是 AIDock.swift，它只有一個 local @State `isOpen` 的展開/收合 toggle（line 13、23），完全沒有送出 dismissInsight 的按鈕或手勢；AnalysisView 也未送此 action。父層 DashboardFeature 把 AnalysisFeature push 進 path（DashboardFeature.swift:406/410）但不轉送此 case。Effect 也不回傳它。insight 的清空實際發生在 loadedData(.success) 的兩條路徑（line 270、276），dismissInsight 從未在執行期被觸發。
  - 建議修法: 移除 dismissInsight action case 與 reducer 分支，並刪掉只為它存在的 testDismissInsight 測試；若設計上需要使用者手動關閉洞察，改在 AIDock 加一個送出此 action 的關閉鈕。

- **[low] ssot-violation** — AnalysisData.budgetMetrics 欄位永遠寫死 [] 且從不被讀取（與 .budgetMetricsLoaded 重複的死投影）
  - 位置: `Features/Sources/Features/Analysis/AnalysisFeature.swift:81`
  - 細節: AnalysisData struct 宣告 `budgetMetrics: [BudgetGaugeMetrics]`(line 81)，但建構時恆為空陣列(line 213 `budgetMetrics: []`)，而 loadedData(.success) 處理器(line 264-277)從未讀取 `data.budgetMetrics`。實際 budget 指標走的是完全獨立的第二個 .run effect → .budgetMetricsLoaded action → state.budgetMetrics(line 221-228、260-261)。同一份「預算指標」概念在 AnalysisData 裡留了一個永遠為空、永不消費的孿生欄位，是重構後的殘留死狀態，會誤導讀者以為兩條 effect 任一可填它。
  - 建議修法: 從 AnalysisData struct 刪除 budgetMetrics 欄位與 line 213 的初始化參數，讓 budget 指標單一來源只剩 .budgetMetricsLoaded 那條 effect。

- **[high] dead-action** — AIAssistantCardView 的 isAvailable gating 形成死鎖，AIDock 的 ai 助理區塊永遠不顯示
  - 位置: `Features/Sources/Features/Analysis/AnalysisView.swift:120`
  - 細節: AnalysisView line 120 以 `if store.aiAssistant.isAvailable` 包住 AIAssistantCardView。但 aiAssistant.isAvailable 預設為 false（AIAssistantFeature.swift:32），唯一把它設 true 的地方是子 reducer 的 .task 分支（AIAssistantFeature.swift:54-55），而送出 .aiAssistant(.task) 的唯一位置又是 AIAssistantCardView 自身的 .task modifier（AIAssistantCardView.swift:16-18）。全域 grep `aiAssistant(.task)` 為空、AnalysisFeature.task(line 100-107)也不轉送子 .task。因此 card 被 gating 擋住→.task 永不觸發→isAvailable 永遠 false→card 永遠不出現，AI 助理功能整段死碼。
  - 建議修法: 在 AnalysisFeature 的 .task 分支 merge 一個 `.send(.aiAssistant(.task))`，或把 AnalysisView line 16 的 .task 也對子 store 觸發一次，讓 isAvailable 能被求值。

- **[medium] test-gap** — loadData 兩條並發 effect 的協調與 cancellable 取消語義未被測試
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/AnalysisFeatureTests.swift:71`
  - 細節: loadData(AnalysisFeature.swift:121-230) 是 .merge 兩條 .run：主資料 effect + budget 指標 effect（後者帶 `.cancellable(id: CancelID.budgets, cancelInFlight: true)`，line 229）。現有測試各自只用 exhaustivity=.off 驗證單一下游（loadedData 或 budgetMetricsLoaded），但從未在同一個 exhaustive 測試裡同時 receive 兩條 action 驗證兩者都送達，也沒有任何測試覆蓋「連續兩次 loadData 觸發 cancelInFlight 取消前一個 budget effect」這條取消路徑。budget effect 是唯一帶取消語義的編排，零覆蓋。
  - 建議修法: 新增一個 exhaustive 測試：送一次 loadData 後 receive 兩條下游 action；再加一個測試連送兩次 loadData，斷言舊 budget effect 被取消（只收到後一次的 budgetMetricsLoaded）。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] dead-action** — MonthlyTrendCard 被硬編碼 hasMonthlyTrendData = false 永久擋住，是靜態不可達的死 View
  - 位置: `Features/Sources/Features/Analysis/AnalysisView.swift:87`
  - 細節: AnalysisView.swift:17 宣告 `private let hasMonthlyTrendData: Bool = false`（常數、無 setter、無任何路徑改寫它），:87 的 `if hasMonthlyTrendData { MonthlyTrendCard(monthlyTotals: []) }` 因此是編譯期即可判定的不可達分支。grep 確認 hasMonthlyTrendData/MonthlyTrendCard 全 repo 只此一處構造，且 monthlyTotals 永遠傳空 []。整個 MonthlyTrendCard.swift（74 行）目前是死碼。雖有 TODO 註解說明待 reducer 補 prior-period 資料，但與 F1/F2/F3 同類：執行期不可達的殘留 UI。原審查員未提及。
  - 建議修法: 暫移除 MonthlyTrendCard 的渲染分支與 hasMonthlyTrendData 常數（保留檔案於分支或 issue 追蹤），待 reducer 真能供應 6 個月 prior-period 資料時再以實際 store 資料接回，而非硬編碼 false + 空陣列佔位。

- **[low] dead-action** — AnalysisData.insight 欄位連同整個 AnalysisData struct 的多數欄位都是「先塞 state 再讀」的轉運站，但 binding case 是完全空轉的機制
  - 位置: `Features/Sources/Features/Analysis/AnalysisFeature.swift:97`
  - 細節: BindingReducer()(:94) + `case binding: return .none`(:97) 已接上，AnalysisView(:8) 與 AnalysisTopBar(:14) 都用 @Bindable var store，但全 repo grep 無任何 `$store.xxx` 雙向綁定送出 binding(BindingAction) — 所有互動都走顯式 action（periodChanged/accountSelected/categoryTapped）。binding 機制是無效空轉、測試也零覆蓋。原審查員的覆蓋率備註已自承此點（標為『無效機制，非關鍵路徑』），故非全新遺漏，僅補強證據：BindableAction 在此 feature 屬可移除的死配線（移除後行為不變），可降低誤導。
  - 建議修法: 若無計畫導入 $store 雙向綁定，移除 BindingReducer()、binding action case 與兩處 @Bindable（改回 let store: StoreOf<...>），消除空轉機制。

### 覆蓋率抽查結論

原審查員四項發現（F1-F4）我獨立全部 confirmed，無 refuted。但覆蓋率統計的「action case 總數 14」不正確：自行逐行核對 AnalysisFeature.Action（AnalysisFeature.swift:62-74），實際只有 13 個 case（binding、task、accountsLoaded、accountSelected、periodChanged、loadData、loadedData、budgetMetricsLoaded、dismissInsight、categoryTapped、categoryTransactionsLoaded、categoryDrilldownDismissed、aiAssistant）。原審查員多算了 1 個（疑似把 State.Period 子 enum 的 case 或 Scope 計入）。實際被測試直接 send/receive 的有 11 個；未覆蓋的恰好是 binding 與 aiAssistant 兩個——這正是原審查員指出的兩條未覆蓋路徑，其『質性』結論（aiAssistant scope wiring 沒測、且藏著 isAvailable 死鎖 bug；binding 為無效機制）完全正確且最有價值。結論：分母數字錯（應為 13 非 14、已覆蓋應為 11 非 12），但未覆蓋關鍵路徑的判斷與 F3 死鎖的串連推論精準，整體覆蓋率質性結論成立，僅需修正計數。"


---

## AIAssistant

**健康度摘要**：AIAssistant 這組整體健康度良好。State 的 6 個 stored property（messages / inputText / isExpanded / isLoading / errorMessage / isAvailable）全部被 reducer、AIAssistantCardView 與測試三方消費，無重構殘留；7 個 action case 全部可達且皆有 store.send/receive 覆蓋（含兩條 submitTapped guard、answerReceived 與 answerFailed effect 分支、delegate 無、錯誤處理 dismissError）。SSOT 維度無重複資料、無需手動同步的 derived state。唯一可改善處是 submitTapped 的 cancelInFlight 取消路徑因 isLoading guard 而永遠不可達，屬 low severity 的防禦性殘留。

**Action 覆蓋率**：7/7

**未覆蓋關鍵路徑**：
- submitTapped 的 .cancellable(cancelInFlight: true) 取消路徑無測試覆蓋；但因 !state.isLoading guard 先攔截，第二次 submitTapped 在載入中永遠 return .none，cancelInFlight 實際上不可達（見 finding）

### 經交叉驗證確認的發現（confirmed）

- **[low] dead-action** — submitTapped 的 cancelInFlight: true 因 !state.isLoading guard 而永遠不可達
  - 位置: `Features/Sources/Features/Analysis/AIAssistant/AIAssistantFeature.swift:81`
  - 細節: submitTapped（line 66-81）第一行 guard 為 `guard !state.inputText.isEmpty, !state.isLoading else { return .none }`（line 67）。一旦送出請求即 `state.isLoading = true`（line 71），在 answerReceived/answerFailed 將其設回 false 之前，任何後續 submitTapped 都會在 guard 處 return .none，永遠不會再回傳第二個帶 CancelID.ask 的 .run effect（line 73-81）。因此 `.cancellable(id: CancelID.ask, cancelInFlight: true)`（line 81）的 cancelInFlight 行為在 reducer 邏輯中沒有任何路徑能觸發——它要取消的「in-flight 前一個請求」永遠不存在。這是重構殘留的防禦性 orchestration：cancelInFlight 與 isLoading guard 語義重疊，二者擇一即可。測試（AIAssistantFeatureTests.swift testSubmitTapped_guardLoading line 85-99）已證實 loading 時被擋下、effect 不執行，反向佐證取消分支不可達。
  - 建議修法: 移除 cancelInFlight:true（保留 .cancellable(id:) 供 view 卸載時取消即可），或若想以「新問題打斷舊問題」為產品行為則移除 !state.isLoading guard——二選一，避免兩套互斥機制並存。

### 覆蓋率抽查結論

同意原審查員的覆蓋率統計，並自己數過核對無誤。Action case 共 7 個（task、expandTapped、inputChanged、submitTapped、answerReceived、answerFailed、dismissError），全部有測試：task×2（可用/不可用）、expandTapped×2（展開/收合）、inputChanged×1、submitTapped×3（空輸入 guard、loading guard、附加使用者訊息）；answerReceived 透過 testSubmitTapped_appendsUserMessage 的 store.receive(\\.answerReceived) 覆蓋；answerFailed×1；dismissError×1。view 端 5 個對外 action 皆有 store.send 呼叫點，answerReceived/answerFailed 為 effect 內部回呼，無死 action。原審查員指出的唯一未覆蓋路徑（cancelInFlight 取消路徑無測試）成立但因 F1 證明該路徑不可達，不算真正的測試缺口，描述精準。補漏掃描結果：六個 @ObservableState property（messages/inputText/isExpanded/isLoading/errorMessage/isAvailable）在 view body 內皆有讀取（含 isAvailable 於 AnalysisView.swift:120 的父層 gating），無殘留 property。另就 AIAssistantCardView.swift:199 的 Color.white 評估後判定非 violation——`.white`/Color.white 在 Features 各 view（SettingsView、CarrierManagementView、FilterView 等十多處）為全專案普遍接受的寫法，CLAUDE.md 的 Color.Design gateway 規則針對的是 fileprivate 的 hex-to-Color 初始化器與硬編碼 #FFFFFF/#000000 hex 字面值，並非系統內建 .white，故不列為 missedFinding 以免誤報。無 SSOT 違規、無未覆蓋的可達路徑。

---

## Settings

**健康度摘要**：SettingsFeature 整體結構健康、delegate 與導航機制大多正確接線，但有兩處重構殘留與一段明顯的測試空白。殘留：seedRandomDataDismissed 是死 action（View 永不送出），widgetCarrierId 是只寫不讀的冗餘投影（與已被消費的 widgetCarrierName 同源、僅測試引用）。最關鍵風險是破壞性最高的 wipeAllData 與 seedRandomData 兩條完整 effect 流程（含 allDataWiped delegate 路由回 onboarding）完全沒有任何測試，37 條邏輯路徑只覆蓋 20 條。

**Action 覆蓋率**：20/37

**未覆蓋關鍵路徑**：
- wipeAllDataConfirmed → effect 編排：platformClient.wipeAllSyncData() 成功/失敗兩條分支、isWipingAllData 旗標、CancelID.wipeAll 取消，完全沒測
- wipeAllDataCompleted → .delegate(.allDataWiped)：摧毀資料後叫 parent 路由回 onboarding 的唯一通道，零覆蓋（AppFeature 端也未測此 delegate）
- wipeAllDataFailed：錯誤訊息寫入 wipeAllDataError 並關閉 loading，未測
- seedRandomDataTapped → seedRandomDataCompleted 鏈：guard 去重 + 隨機種子 effect 成功後再 .run 觸發 accountsLoaded 重載（多 effect 協調），完全沒測
- seedRandomDataFailed / 三個導航 action（carrierManagementTapped / syncSettingsTapped / watchSettingsTapped）的 path.append 未測

### 經交叉驗證確認的發現（confirmed）

- **[low] dead-action** — seedRandomDataDismissed action 從未被任何 View / effect / parent 送出
  - 位置: `Features/Sources/Features/Settings/SettingsFeature.swift:469`
  - 細節: 全域 grep（Features/Sources、NeuLedgerTests、NeuLedgerWidget、Shared、NeuLedger）對 seedRandomDataDismissed 只命中三處：enum 宣告(119)、reducer case(469)、SettingsView 完全沒有 store.send(.seedRandomDataDismissed)。SettingsView 的 DEBUG section 只讀取 store.seedRandomDataResult/seedRandomDataError 作為 footer/value(258、264)，沒有任何 UI 控制項會送出此 action，effect 也不回傳它。對比同組 wipeAllDataDismissed 有接到 confirmationDialog 的 set: 回呼(SettingsView:284)。結果是 seedRandomDataResult/seedRandomDataError 一旦顯示就無法經由正常路徑清除。
  - 建議修法: 刪除此 case，或在 SettingsView 為 seed 結果列接上能送出 seedRandomDataDismissed 的清除手勢/按鈕。

- **[medium] unused-property** — State.widgetCarrierId 只被寫入、reducer 與 View 都不讀（僅 SSOT 的冗餘投影）
  - 位置: `Features/Sources/Features/Settings/SettingsFeature.swift:46`
  - 細節: widgetCarrierId 在 SettingsFeature 內僅出現於兩處賦值（widgetCarriersLoaded:339、widgetCarrierSelected:348），reducer 沒有任何分支讀它，SettingsView 也只讀 store.widgetCarrierName(178、180)、從不讀 widgetCarrierId。唯一引用它的是兩個測試斷言(SettingsFeatureTests:499、521)。Application/Carrier 與 Domain/Adapters 命中的 .widgetCarrierId 是另一個同名符號（UserSettingsAdapter 的 SettingsKey），非此 State property，已點開確認無關。widgetCarrierId 與 widgetCarrierName 同源（都從 carriers + carrierClient.activeForWidget() 推導），目前只有 name 有真實消費者。
  - 建議修法: 刪除 widgetCarrierId（連同 init 參數）並同步移除兩處測試斷言；若日後 picker 需要高亮目前選取項再以 computed property 由 carriers 推導。

- **[high] test-gap** — wipeAllData 整條摧毀資料流程（effect + 錯誤 + allDataWiped delegate）零測試
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/SettingsFeatureTests.swift:1`
  - 細節: 全域 grep NeuLedgerTests 對 wipeAllData 無任何命中（已確認 0 筆）。未覆蓋：wipeAllDataConfirmed 觸發 platformClient.wipeAllSyncData() 的成功/失敗兩分支(SettingsFeature:366-378)、wipeAllDataCompleted 發出 .delegate(.allDataWiped)(385)（這是摧毀資料後 AppFeature 路由回 onboarding 的唯一機制，AppFeature:72）、以及 wipeAllDataFailed 寫入 wipeAllDataError(387)。這是破壞性最高、後果最重的路徑卻完全沒有迴歸保護。
  - 建議修法: 新增三個測試：confirmed→completed 成功路徑斷言收到 delegate(.allDataWiped)；confirmed→failed 斷言 wipeAllDataError 與 isWipingAllData=false；以及 dismissed 關閉確認框。

- **[medium] test-gap** — seedRandomData 流程（guard 去重 + 種子 effect + 完成後鏈式重載 accountsLoaded）零測試
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/SettingsFeatureTests.swift:1`
  - 細節: 全域 grep NeuLedgerTests 對 seedRandomData 無任何命中。未覆蓋：seedRandomDataTapped 的 guard !isSeedingRandomData 去重(SettingsFeature:393)、effect 內 createAccount/record 的編排、seedRandomDataCompleted 後再 .run 觸發 ledger.listActiveAccounts() → accountsLoaded 的多 effect 鏈(456-462)、以及 seedRandomDataFailed 錯誤路徑(464)。雖屬 DEBUG-only，但含分支與 effect 協調邏輯，且會改動 ledger 狀態。
  - 建議修法: 至少補一個 completed 路徑測試（stub createAccount/record/listCategories/listActiveAccounts），斷言 seedRandomDataResult 與緊接的 accountsLoaded receive，以及一個 failed 路徑測試。

- **[low] test-gap** — 三個導航 action（carrier / sync / watch ManagementTapped）未測 path.append
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/SettingsFeatureTests.swift:397`
  - 細節: SettingsNavigationTests 涵蓋 account/category/budget/tag/notification 五個導航 action，但缺 carrierManagementTapped(SettingsFeature:164)、syncSettingsTapped(172)、watchSettingsTapped(176)。全域 grep NeuLedgerTests 對這三者均 0 命中。三者各自 append 不同的 Destination.State，屬可斷言的明確邏輯路徑（非純 setter binding）。
  - 建議修法: 在 SettingsNavigationTests 補上對應三個 store.send 測試，斷言 path.append 到正確的 Destination case。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — 四個 picker 旗標 action（defaultAccountTapped / defaultAccountPickerDismissed / widgetCarrierTapped / widgetCarrierPickerDismissed）零測試，且原審查員 F5 只點名三個導航 action 而漏掉這四個
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/SettingsFeatureTests.swift:449`
  - 細節: 逐 action 交叉比對 SettingsFeatureTests.swift 後，37 個 action case 中除了 F5 點到的三個導航 action 外，還有四個 picker 旗標 action 完全未測：defaultAccountTapped(SettingsFeature:218 設 isPickingDefaultAccount=true)、defaultAccountPickerDismissed(222 設 false)、widgetCarrierTapped(226 設 isPickingWidgetCarrier=true)、widgetCarrierPickerDismissed(230 設 false)。grep 該測試檔對四者均 0 命中。這四個旗標確實有真實 View 消費者（isPickingDefaultAccount 綁 SettingsView:124、isPickingWidgetCarrier 綁 SettingsView:187 的 confirmationDialog isPresented），所以是真正可測的狀態切換而非死碼。雖屬純 setter binding（單行 flag 切換）、回歸風險低，但原審查員的覆蓋率敘述以『37 中 20 覆蓋』收尾卻只在未覆蓋清單列了三個導航 action，遺漏這四個會讓讀者誤以為剩下未測的只有破壞性/導航路徑。
  - 建議修法: 若要補測，在既有 suite 各加一條 store.send 斷言 isPickingDefaultAccount/isPickingWidgetCarrier 的 true/false 切換；或於覆蓋率報告明確標注這四個 setter 屬『刻意不測的純 binding』以免清單失真。

### 覆蓋率抽查結論

我自己數過：SettingsFeature.Action enum（SettingsFeature.swift:80-120，排除巢狀 Delegate 的 2 個 case）剛好 37 個 action case，與原審查員『總數 37』完全一致。『已覆蓋 20』也經我逐 action 交叉比對確認：實際在測試檔出現 send/receive 的有 19 個業務 action（accountManagementTapped、categoryManagementTapped、budgetManagementTapped、tagManagementTapped、notificationSettingsTapped、task、accountsLoaded、defaultAccountSelected、languageTapped、languageLoaded、exportCSVTapped、exportJSONTapped、exportCompleted、exportFailed、exportSheetDismissed、accessoryBarToggleChanged、privacyPolicyTapped、widgetCarrierSelected、widgetCarriersLoaded）加上 delegate（透過 \\.delegate.accessoryBarVisibilityChanged 覆蓋）共 20，數字精確無誤。原審查員『未覆蓋關鍵路徑』清單抓得準（wipe 全流程、seed 鏈、三導航），唯一不完整處是未覆蓋清單漏列四個 picker 旗標 action（已補入 missedFindings，severity=low）。整體覆蓋率統計判定：同意，數字正確，僅未覆蓋清單需補上四個低風險 setter 才算完整。"


---

## SyncSettings

**健康度摘要**：SyncSettings 這組在維度 1（無用 property / 死 action）與維度 2（SSOT）皆無問題：State 五個 stored property（isSyncEnabled / isCloudKitAvailable / migrationState / lastSyncedAt / isManualSyncing）與七個 action case 經全域 grep 確認都被 View 或 reducer 實際消費，且彼此語義獨立、無重複投影或手動同步膠水。唯一缺口在維度 3 測試覆蓋：手動同步路徑（syncNowTapped / syncNowFinished，含 re-entrancy guard 與 effect 編排）完全沒有測試，且 taskLoadsState 缺少狀態斷言，整體 7 個 case 只實質覆蓋 5 個。

**Action 覆蓋率**：5/7

**未覆蓋關鍵路徑**：
- syncNowTapped 的 re-entrancy guard（guard !state.isManualSyncing 直接 return .none）完全未測，無法保證重複點擊不會重入啟動第二個 sync effect
- syncNowTapped 的 effect 編排：requestSyncNow() 呼叫 + clock padding（湊滿 1 秒最短顯示）→ send(.syncNowFinished) 未測，連 ImmediateClock 路徑都沒驗
- syncNowFinished(date) 將 isManualSyncing 設回 false 且把 lastSyncedAt 更新為傳入 date 的狀態變更未測
- requestSyncNow() 拋錯時被 try? 吞掉、仍走 padding 並 finish（以 lastSyncedAt() ?? Date() 收尾）的容錯路徑未測
- task 雖有送出但 trailing closure 沒有任何 state 斷言（stub 回傳值恰等於 State 預設值），若 reducer 停止指派 isSyncEnabled/isCloudKitAvailable/lastSyncedAt 測試不會失敗

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — syncNowTapped / syncNowFinished 兩個 action case 完全沒有測試覆蓋
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/SyncSettingsFeatureTests.swift:8`
  - 細節: SyncSettingsFeatureTests 只有三個 @Test：taskLoadsState、enableSyncCompletes、enableSyncFails，分別覆蓋 task / enableSyncTapped / migrationProgressUpdated / migrationCompleted / migrationFailed 五個 case。Reducer 共 7 個 action case（SyncSettingsFeature.swift:38-44），其中 .syncNowTapped（line 98-109）與 .syncNowFinished（line 111-114）在整個測試檔內以 grep 搜尋皆零命中。這兩個 case 含具體邏輯：syncNowTapped 有 re-entrancy guard（guard !state.isManualSyncing else { return .none }，line 99）、呼叫 requestSyncNow()、用 continuousClock 湊滿最短 1 秒顯示、再 send(.syncNowFinished)；syncNowFinished 把 isManualSyncing 設回 false 並更新 lastSyncedAt。手動同步是 enabledCard 的主要互動（View line 308 store.send(.syncNowTapped)），屬關鍵邏輯路徑而非 UI 雞毛事件。
  - 建議修法: 新增一個 @Test 注入 platformClient.requestSyncNow 與 lastSyncedAt（並用 ImmediateClock），send(.syncNowTapped) 斷言 isManualSyncing=true、receive(.syncNowFinished) 斷言 isManualSyncing=false 且 lastSyncedAt 更新；另補一個重入測試驗證 isManualSyncing=true 時 syncNowTapped 直接 no-op。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — taskLoadsState 測試對 .task 完全無 state 斷言（trailing closure 缺失），形同空驗證
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/SyncSettingsFeatureTests.swift:19`
  - 細節: taskLoadsState（line 11-20）的 await store.send(.task) 後面沒有任何 trailing closure，等於不斷言 reducer 對 state 的任何寫入。更糟的是注入的 stub 值（syncEnabled={false}、syncAvailable={true}、lastSyncedAt={nil}，line 15-17）恰好等於 State 預設值（SyncSettingsFeature.swift:9 isSyncEnabled=false、line 10 isCloudKitAvailable=true、line 12 lastSyncedAt=nil）。即使 reducer 把 line 56-58 三行賦值整段刪掉、或改成賦錯來源，TestStore 仍會綠燈通過——這條測試對 task case 的有效覆蓋實際上是 0，與 enableSync/sync now 缺測同屬 test-gap 維度。原審查員在 coverage 統計第 5 點有提到此現象，但未把它列為獨立 finding。
  - 建議修法: 把 stub 改成與預設值不同的值（如 syncEnabled={true}、lastSyncedAt 回傳固定日期），並在 await store.send(.task){ $0.isSyncEnabled=true; $0.lastSyncedAt=<固定日期> } 加上 trailing closure 斷言三個欄位確實被指派。

### 覆蓋率抽查結論

同意原審查員的覆蓋率統計。親自清點 SyncSettingsFeature.swift:38-44 確為 7 個 Action case（task、enableSyncTapped、migrationProgressUpdated、migrationCompleted、migrationFailed、syncNowTapped、syncNowFinished）；測試檔僅 3 個 @Test 覆蓋前 5 個，syncNowTapped / syncNowFinished 兩個未覆蓋，與「總數 7、已覆蓋 5」吻合。其列出的五項未覆蓋關鍵路徑（re-entrancy guard、effect 編排、syncNowFinished 狀態變更、requestSyncNow try? 吞錯後仍 padding+finish 的容錯、task trailing closure 無斷言）逐項屬實，且第 5 點我已升格為獨立 missedFinding。屬性/死碼維度補掃乾淨：5 個 @ObservableState property 全在 View 被讀（isSyncEnabled View:42、isCloudKitAvailable View:44/451/454、migrationState View:47、lastSyncedAt View:297、isManualSyncing View:311/336），7 個 action case 全可達，無殘留 property 或死 action。SSOT 維度：lastSyncedAt 由 platformClient 單一來源讀取並鏡射進 local state（標準單一寫入點快取，不算違規）；SyncSettings 經 SettingsFeature StackState push 整合（SettingsFeature.swift:172-173，標準 TCA 導航，不算違規），無 SSOT 問題。額外觀察（非本組 scope，僅備註）：父層 SettingsFeatureTests.swift 對 .syncSettings 推入路徑無任何斷言，與 CLAUDE.md 提醒的 parent Scope 會走到 child 依賴一致，但不在本次審查檔組內。"}

---

## WatchSettings

**健康度摘要**：WatchSettings 這組整體健康度良好。維度一（死碼）與維度二（SSOT）皆零問題：4 個 stored property（accounts / selectedAccountId / isPaired / isWatchAppInstalled）與 3 個 action case（task / loaded / accountSelected）都被 View 與 reducer 實際消費，CancelID.pushWatchContext 為導航/取消機制不算殘留；State 內沒有重複投影或會 desync 的 derived state，selectedAccountId 的兩個寫入點（loaded 的存活性對帳、accountSelected）語義清晰無同步膠水。維度三測試覆蓋接近完整，三個 action case 全覆蓋、loaded 的『沿用既存預設 / nil 預設取首個 / 死預設回退首個』三分支與 accountSelected 的 persist+push+cancel-in-flight 編排都有測；唯一缺口是 task effect 中 listActiveAccounts 拋錯被 try? 吞掉的低風險錯誤分支未被觸發。

**Action 覆蓋率**：3/3

**未覆蓋關鍵路徑**：
- task — ledger.listActiveAccounts() 拋錯時被 try? 吞掉、accounts 退化為 []、selectedAccountId 因 accounts.first?.id 為 nil 而落空的錯誤分支從未被測試（三個 task 測試都回傳非空陣列）

### 經交叉驗證確認的發現（confirmed）

- **[low] test-gap** — task effect 的 listActiveAccounts 拋錯分支（try? 吞錯 → accounts 退化為空）未被覆蓋
  - 位置: `Features/Sources/Features/Settings/Watch/WatchSettingsFeature.swift:47`
  - 細節: WatchSettingsFeature.swift:47 `let accounts = (try? await ledger.listActiveAccounts()) ?? []` 對拋錯做了 try? 吞錯並退化成空陣列；隨後 loaded:64 的 `accounts.contains(...) ? selectedAccountId : accounts.first?.id` 在空陣列下會讓 selectedAccountId 落為 nil。WatchSettingsFeatureTests.swift 中三個 .task 測試（行 35、60、85 的 listActiveAccounts stub）全部回傳 [cash, card] 非空陣列，沒有任何測試讓 listActiveAccounts throw 以驗證『取帳戶失敗時 selectedAccountId 不會殘留為某個無效 id、且 accounts 為空』這條路徑。屬於低風險分支（View 對空 accounts 的 ForEach 會自然渲染為空），但 TDD 視角下這是 reducer 內唯一未被觸發的條件分支。
  - 建議修法: 新增一個測試：stub `$0.ledgerClient.listActiveAccounts = { throw CoreError.operationDenied }`，送 .task 後 receive(\.loaded) 斷言 accounts == [] 且 selectedAccountId == nil。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] ssot-violation** — WatchSettingsFeature.loaded 的 selectedAccountId 後備規則（:64-66）是 WatchDefaultAccountResolver.resolve 的逐行重寫，兩處規則並存有 drift 風險
  - 位置: `Features/Sources/Features/Settings/Watch/WatchSettingsFeature.swift:64`
  - 細節: WatchDefaultAccountResolver.swift:5-12 的 docstring 明文宣稱自己是『Single source of truth for the rule shared by WatchSyncObserver, WatchMidnightTimer, and PlatformClient.pushWatchContext』，其規則為 :23-26 `if let stored, activeAccounts.contains(where:{$0.id==stored}) { return stored }; return activeAccounts.first?.id`。WatchSettingsFeature.swift:64-66 `state.selectedAccountId = accounts.contains(where:{$0.id==selectedAccountId}) ? selectedAccountId : accounts.first?.id` 是同一規則的逐行重寫，reducer 註解 :58 自承『Mirror WatchDefaultAccountResolver』。第四個共用點（settings 畫面的預選）並未列入 resolver docstring 的共用清單，規則已散落第二處。注意：此重寫是 layering 逼出來的——resolver 位於 Core 並 import SwiftData（WatchDefaultAccountResolver.swift:2），Features reducer 無法直接呼叫它，故無法簡單以一行委派消除。若後續改 tie-break 規則（例如改以 name 排序），resolver 與 reducer 兩處需同步修改，否則 watch push 端與 settings 顯示端會不一致。屬低風險、非可直接移除的硬違規，列為觀察項。
  - 建議修法: 在 Domain/Application 層暴露一個純值規則（如 Account 上的靜態 `resolveDefault(stored:in:)` 純函式，不碰 SwiftData），讓 resolver 與此 reducer 同時呼叫它，使後備規則只宣告一次。

- **[low] test-gap** — accountSelected 對『傳入 id 不在 state.accounts 內』不做驗證即寫入 selectedAccountId，與 loaded 路徑的 membership 檢查不對稱，且無測試覆蓋此非對稱
  - 位置: `Features/Sources/Features/Settings/Watch/WatchSettingsFeature.swift:72`
  - 細節: WatchSettingsFeature.swift:71-73 `case let .accountSelected(id): state.selectedAccountId = id; platformClient.setWatchDefaultAccountId(id)` 無條件接受任意 id 並持久化，與 :64 loaded 路徑會驗證 `accounts.contains` 的行為不對稱。實務上 View 的 accountSelected 一律由 WatchSettingsView.swift:48-50 `ForEach(store.accounts)` 內的 Button 觸發，傳入 id 必在 accounts 內，故此非對稱目前不可達、非真 bug。測試 selectingAccountPersists（:104）與 selectingAccountPushesWatchContext（:133）皆只送 accounts 內既有 id（card.id），無『送一個不在 accounts 內的 id』之測試。屬 low：因 View 結構保證不可達，標為測試完整性觀察項而非缺陷。
  - 建議修法: 若要與 loaded 路徑對齊一致性，可在 accountSelected 加 `guard state.accounts.contains(where:{$0.id==id}) else { return .none }`，並補一個送非成員 id 的測試斷言 state/持久化皆不變；或明確以註解記載『id 由 ForEach 保證為成員』故不驗證。

### 覆蓋率抽查結論

原審查員的覆蓋率統計（action case 總數 3、已覆蓋 3）抽查後同意。我獨立數過 Action enum（WatchSettingsFeature.swift:28-32）確為 3 個 case：task、loaded、accountSelected。測試檔 send/receive 比對：.task 由 :43/:68/:95 觸發、\\.loaded 由 :44/:69/:96 receive、.accountSelected 由 :126/:155/:197/:200 觸發，三個 case 皆有覆蓋。State 四個 property（accounts/selectedAccountId/isPaired/isWatchAppInstalled）全 repo grep 後確認皆在 WatchSettingsView body 被讀取（accounts→:48 ForEach、selectedAccountId→:58 比對、isPaired→:17/:39、isWatchAppInstalled→:17/:40），無殘留 property。Gateway 抽查（已過 positive control）：此檔組無 import SwiftData、無 Font.system/.font(.system) gateway 繞道、無 Color(hexLiteral:) 直呼（僅用 Color.Design.fromHex/.textPrimary/.accentOrange），無 hardcoded Text(\"...\") 字面字串，全部走 String(localized:)。原審查員指出的唯一未覆蓋關鍵路徑（listActiveAccounts throw 分支）與 F1 一致且屬實。統計合理。"

---

## NotificationSettings

**健康度摘要**：NotificationSettingsFeature 整體健康度良好：State 的 7 個 stored property 全部被 View/reducer/測試實際消費，無重構殘留；9 個 Action case 經全域 grep 確認皆為 live（openSystemSettingsTapped 與 permissionDenied 雖在 parent SettingsFeature 的 .path catch-all 處被 .none 吞掉，但都在 View/effect 中被送出，非死碼）。維度 1（殘留）與維度 2（SSOT）均零問題——reminderDate 是 ReminderTime 的單一寫入點 UI 投影、isAuthorized 與 showPermissionDeniedBanner 語義不重疊，無 desync 風險。唯一缺口在維度 3：權限『請求被授予後自動重試』的多 effect 串接分支（daily/budget 兩條）與 openSystemSettingsTapped、budgetWarning authorized persist 路徑未覆蓋，其中授予後重試屬高風險關鍵編排。

**Action 覆蓋率**：8/9

**未覆蓋關鍵路徑**：
- openSystemSettingsTapped → platformClient.openAppSettings()（permission banner 按鈕路徑，完全無測試）
- dailyReminderToggled 未授權→requestNotificationPermission 回 true→authorizationStatusLoaded(true)+自動重試 toggled(true)→scheduleDailyReminder（授予後重試串接 effect 零覆蓋）
- budgetWarningToggled 未授權→requestNotificationPermission 回 true→自動重試啟用→setWarningEnabled(true)（同上，授予分支零覆蓋）
- budgetWarningToggled authorized 啟用/停用分支與 setWarningEnabled persist 副作用未斷言
- reminderDateChanged 在 dailyReminderEnabled==false 時的 early-return（line 133 guard，不應排程）未測

### 經交叉驗證確認的發現（confirmed）

- **[medium] test-gap** — openSystemSettingsTapped 完全未被任何測試覆蓋
  - 位置: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift:167`
  - 細節: Action 案例 .openSystemSettingsTapped（reducer line 167-169，呼叫 platformClient.openAppSettings()）由 View line 77 的 permission banner 按鈕送出，但在 NotificationSettingsFeatureTests 全檔搜尋無 openSystemSettingsTapped/openAppSettings 任何 store.send（grep 僅在 DomainTests/PlatformClientTests:254 測到底層 client，非本 reducer 路徑）。這是 9 個自有 action case 中唯一完全未觸及的。屬於『effect 編排 + 系統路由』邏輯路徑，非單純 setter binding。
  - 建議修法: 新增測試：send(.openSystemSettingsTapped) 並用 LockIsolated spy 斷言 platformClient.openAppSettings 被呼叫一次。

- **[high] test-gap** — 權限『請求後被授予→自動重試開啟』分支（dailyReminder/budgetWarning）皆未測
  - 位置: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift:117`
  - 細節: reducer line 117-125 與 line 147-155 的 else 分支裡，requestNotificationPermission 回傳 true 時會連送 authorizationStatusLoaded(true) + 再次 toggled(true) 做 retry。但 NotificationSettingsFeatureTests 兩處 requestNotificationPermission stub 都只給 { false }（line 102、185），grep 全檔無 requestNotificationPermission = { true }。授予後的多 effect 串接（self-send 重試 + 排程/persist）這條關鍵編排路徑零覆蓋，回歸時不會被測試攔到。
  - 建議修法: 各補一條 requestNotificationPermission = { true } 的測試，receive(.authorizationStatusLoaded) 後再 receive(.dailyReminderToggled(true))/.budgetWarningToggled(true)，斷言最終 scheduleDailyReminder / setWarningEnabled(true) 被呼叫。

- **[medium] test-gap** — budgetWarningToggled 的 authorized 啟用/停用分支與 setWarningEnabled 持久化未測
  - 位置: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift:136`
  - 細節: reducer line 136-156：!enabled 停用分支（line 137-140 呼叫 planningClient.setWarningEnabled(false)）與 isAuthorized 已授權啟用分支（line 142-145 呼叫 setWarningEnabled(true)）都會改 state 並 persist。但測試僅 testBudgetWarningToggleOnUnauthorizedDenied（line 178）測到『未授權被拒』分支；grep 全檔無 setWarningEnabled，代表開/關狀態更新與 planningClient persist 副作用都沒有斷言。
  - 建議修法: 補兩條測試：State(isAuthorized:true) 下 send(.budgetWarningToggled(true)) 斷言 state 與 setWarningEnabled(true)；以及 budgetWarningEnabled:true 起始 send(false) 斷言 setWarningEnabled(false)。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — dailyReminderToggled 未授權→granted=true 重試路徑即使補測，也須斷言重試後 setReminderTime + scheduleDailyReminder 真的觸發（F2 範圍延伸，原 suggestedFix 漏列 setReminderTime 斷言）
  - 位置: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift:121`
  - 細節: reducer 重試是用 self-send .dailyReminderToggled(true)，第二次進來時 state.isAuthorized 已為 true，走 line 109-115 分支會呼叫 setReminderTime(line 114) 與 scheduleDailyReminder(line 115)。原審查員 F2 的 suggestedFix 只提『斷言 scheduleDailyReminder 被呼叫』，未提 setReminderTime——但重試分支同時寫入 reminderTime，若回歸只斷言 schedule 會漏掉 setReminderTime 退化。這不是新 action，而是 F2 應有的更完整斷言面，列為補充以免補測時又留半個洞。
  - 建議修法: 在 F2 的 daily granted=true 測試中，除斷言 scheduleDailyReminder 外，加 LockIsolated spy 斷言 setReminderTime(ReminderTime(hour:21,minute:0)) 與 setDailyReminderEnabled(true) 各被呼叫一次。

- **[medium] test-gap** — reminderDateChanged 在 dailyReminderEnabled==false 的 guard early-return（line 133，不應排程但仍 persist reminderTime）未測
  - 位置: `Features/Sources/Features/NotificationSettings/NotificationSettingsFeature.swift:133`
  - 細節: 唯一的 reminderDateChanged 測試（test 行 147-174）初始 State 為 dailyReminderEnabled:true，因此 line 133 的 `guard state.dailyReminderEnabled else { return .none }` 的 false 分支從未被走到。grep 確認沒有任何 dailyReminderEnabled:false 起始再 send(.reminderDateChanged) 的測試。此分支語意重要：關閉提醒時改時間仍要 setReminderTime（line 132）persist，但『不應』呼叫 scheduleDailyReminder。回歸若誤把 guard 拿掉或誤排程，現有測試攔不到。原審查員的覆蓋率清單第 5 條有提到此路徑，但未獨立列為一條可補的測試（僅在 coverage 敘述帶過），這裡明確列出。
  - 建議修法: 新增測試：State(dailyReminderEnabled:false) 下 send(.reminderDateChanged(date))，spy 斷言 setReminderTime 被呼叫一次、scheduleDailyReminder 完全未被呼叫（用會 fail 的 unimplemented stub 或 LockIsolated 計數=0）。

### 覆蓋率抽查結論

同意原審查員的 actionCoverage 統計。自己數一遍：Action enum 共 9 個 case（task, authorizationStatusLoaded, dailyReminderToggled, reminderDateChanged, budgetWarningToggled, warningThresholdChanged, permissionDenied, openSystemSettingsTapped 共 8 個自有 + recurringManagement 子 reducer 1 個）。測試中被送出或接收的 case：task(28/138/209)、authorizationStatusLoaded(33/139)、dailyReminderToggled(59/84/107)、reminderDateChanged(168)、budgetWarningToggled(188)、warningThresholdChanged(235)、permissionDenied(108/189)、recurringManagement.task(211)——共 8 個。唯一從未觸及者為 openSystemSettingsTapped，故『總數 9、已覆蓋 8』正確。原審查員列的 5 條未覆蓋關鍵路徑全部抽查屬實（含第 5 條 reminderDateChanged guard early-return）。另補充：不存在殘留 property / 死 action——isAuthorized 雖在 View 零讀取，但它是 reducer 內部授權閘（line 96/97/109/142 皆有讀），非死碼；recurringManagement 經 View line 33-36 的 store.scope 使用、亦由 SettingsFeature.swift:169 推入導航，皆為活躍。SSOT 方面 setWarningEnabled 寫入點集中於 reducer 137-144 + Live 實作，無第二寫入者，無違規。三項待驗證發現全數 confirmed。

---

## AccountManagement

**健康度摘要**：AccountManagement 這組 State 的 SSOT 健康（balances 為單一寫入點的快取投影、activeAccounts/archivedAccounts 已是 computed property、無重複儲存的 derived state），維度 2 零問題。主要問題在維度 1 與 3：accountMoved 是 drag-to-reorder 被永久移除後遺留的死 Action（僅測試送得到）；測試覆蓋了 17 個 reducer 分支中的 11 個，但最常觸發的 accountTapped 主入口雙分支、addEdit delegate 的儲存後重載編排、alert→unarchive 轉送鏈、以及所有 ledger effect 的錯誤路徑皆無測試。建議優先補 accountTapped 與 addEdit delegate 兩條路徑的回歸測試，並裁定 accountMoved 去留。

**Action 覆蓋率**：11/17

**未覆蓋關鍵路徑**：
- accountTapped(account) — 兩條分支皆未測：account.isArchived 時彈出 unarchive 確認 alert，未封存時開啟 .edit 模式並排除自身名稱的 existingNames，是整個畫面最常被觸發的 row tap 主入口卻零覆蓋
- alert(.presented(.unarchiveConfirmed(id))) — 封存帳戶 row tap → alert → unarchiveConfirmed 會 relay 成 .unarchiveTapped，這條 alert 轉送鏈未測（unarchiveTapped 本身有測，但經 alert 進入的路徑沒測）
- addEdit(.presented(.delegate(.saved))) — AddEdit 表單儲存後清空 sheet 並 reload accounts/balances 的編排（dismiss + 重新拉清單）完全未測，是新增/編輯帳戶後資料是否刷新的關鍵路徑
- addEdit(.presented(.delegate(.dismissed))) — 表單取消 delegate 清空 sheet 的分支未測
- deleteRequested 的 ledger.listAll 拋錯路徑 — .run effect 沒有 catch，listAll throw 時 effect 靜默失敗、不彈任何 alert，無測試守住此錯誤處理缺口

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — accountMoved(IndexSet, Int) 為死 Action：View 已永久移除 drag-to-reorder，僅測試會送出
  - 位置: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift:204`
  - 細節: AccountManagementView.swift:62-65 的 TODO 明確寫『drag-to-reorder is intentionally dropped — .onMove requires SwiftUI List and we use ScrollView+GlassContainer here』，全專案 grep accountMoved/.onMove 僅在 reducer(line 204)、View 的 TODO 註解、及 AccountManagementFeatureTests.swift:319/335 出現。父層 SettingsFeature 以 case .path: return .none 泛化處理 stack action，不會注入此 case。故此 case 在正式流程永遠不會被送出，純粹是『只被測試引用、View 與真實 reducer 路徑都不消費』的重構殘留（含 CancelID.reorder 與整段 reorder effect）。
  - 建議修法: 若短期內不打算重接 reorder UI，移除 accountMoved case、CancelID.reorder 與對應測試 testAccountMoved；若要保留則在 View 補上 context-menu『上移/下移』或 reorder 模式真正觸發它。

- **[high] test-gap** — accountTapped 兩條核心分支（封存帳戶彈 unarchive alert / 未封存進 edit 模式）完全無測試
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/AccountManagementFeatureTests.swift:1`
  - 細節: reducer line 104-127 的 accountTapped 是 row tap（View line 189）與 edit context-menu（line 196）的主入口，分歧出『isArchived → unarchive 確認 alert』與『非封存 → addEdit(.edit) 並用 filter{ $0.id != account.id } 排除自身名稱』兩條重要分支。測試檔 grep store.send 無任何 .accountTapped；existingNames 排除自身名稱的邏輯（避免編輯時把自己名稱判為重複）尤其需要回歸測試守護。
  - 建議修法: 新增兩個 @Test：一個送封存帳戶斷言 state.alert 為 unarchive 文案、一個送一般帳戶斷言 addEdit.mode == .edit(account) 且 existingNames 不含自身名稱。

- **[medium] test-gap** — addEdit delegate（.saved 重載 / .dismissed 清空）與 alert unarchiveConfirmed 轉送鏈未覆蓋
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/AccountManagementFeatureTests.swift:1`
  - 細節: reducer line 234-243 的 addEdit(.presented(.delegate(.saved))) 會清 sheet 並 reload accounts+balances，是新增/編輯後資料刷新的關鍵編排；line 241-243 的 .dismissed 清 sheet 分支；以及 line 185-186 的 alert(.presented(.unarchiveConfirmed)) → .send(.unarchiveTapped) 轉送。測試只用 store.send(\.addEdit.dismiss)（line 82，走 ifLet 自動 dismiss）覆蓋了 PresentationAction.dismiss，未碰到任何 delegate 分支，也未從 alert 路徑進入 unarchive。
  - 建議修法: 補測 addEdit delegate .saved（斷言 addEdit=nil 並 receive accountsLoaded/balancesLoaded）與 .dismissed，以及 alert(.presented(.unarchiveConfirmed)) 會 receive(\.unarchiveTapped)。

- **[low] other** — deleteRequested 的 ledger.listAll 拋錯無錯誤處理，effect 靜默失敗且無測試
  - 位置: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift:129`
  - 細節: reducer line 129-139 的 .run 內 try await ledger.listAll(...) 沒有 do/catch；同樣地 archiveConfirmed/deleteConfirmed/unarchiveTapped 的 ledger 寫入 effect（line 171-202）皆 try 後無 catch。一旦 client throw，effect 直接終止、不彈 alert、UI 無任何回饋，使用者看不到失敗。此錯誤分支在測試中也完全未模擬（所有測試的 client closure 都回傳成功值）。
  - 建議修法: 在這些 .run effect 加上 catch 後 send 一個錯誤 alert action（並補一條讓 ledger closure throw 的測試），或在 plan 中明確標注錯誤回饋由上層 toast 處理。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] dead-action** — accountTapped 的 isArchived 分支與其下游 unarchiveConfirmed 轉送鏈，是 production UI 永不可達的死碼（不只是 F2 說的測試缺口）
  - 位置: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift:105`
  - 細節: 原審查員 F2/F3 把這條歸為『測試缺口』，但實際更嚴重：archived 帳戶在 View 中由 archivedAccountRow(line 229) 渲染，該 row 沒有任何 tap Button、沒有送 accountTapped；唯二送 accountTapped 的位置都在 accountRowButton(line 189 row tap、line 196 context-menu edit)，而 accountRowButton 只被 groupSection(line 139)→activeGroups(只含非封存帳戶)使用。我 grep 全 View 確認 accountTapped 只有這兩處呼叫。因此 archived 帳戶永遠走不到 accountTapped，reducer line 105-117 的 isArchived 分支（建構 unarchive AlertState）在 production 不可達；而 unarchiveConfirmed 只由該 alert 的 ButtonState 產生（grep 確認全 repo 僅 line 109 一處發出），故 line 185-186 的 alert(.presented(.unarchiveConfirmed)) 轉送分支也連帶死碼。真正的解封存入口是 archivedSection 的 context menu 直接送 .unarchiveTapped(account.id)(View line 165)，繞過整個 alert。連帶 localization key alert_archived_account / alert_unarchive_account_message(Localizable.xcstrings:5070/5172) 成為孤兒字串。
  - 建議修法: 若不打算讓封存 row tap 也彈 unarchive 確認，移除 accountTapped 的 isArchived 分支、unarchiveConfirmed alert case 與兩個孤兒 localization key；若要保留此 UX，於 archivedAccountRow 包一個送 .accountTapped(account) 的 Button 使該分支真正可達。

### 覆蓋率抽查結論

大致同意，但統計有 off-by-one。reducer switch 共 17 個分支（grep `case .`/`case let .` 得 line 65/73/93/97/104/129/141/156/171/178/185/188/191/204/234/241/245），與『17 個 action case』吻合。但『已覆蓋 11』偏低：我逐分支對照測試，實際被 send/receive 觸及的有 12 個——原審查員漏算了泛化 `case .addEdit:`(line 245)，它被測試 line 82 的 store.send(\\.addEdit.dismiss) 觸及（PresentationAction.dismiss 不匹配 .presented(.delegate(...))，落到此 catch-all）。未覆蓋的關鍵路徑清單（accountTapped 兩分支、alert→unarchiveConfirmed 轉送、addEdit.delegate.saved/dismissed、deleteRequested 的 listAll throw 路徑）我逐一核對皆屬實且重要，方向正確。唯需補充：accountTapped 的 isArchived 分支與 unarchiveConfirmed 轉送其實是 production 不可達死碼（見 missedFindings），補測無法守護真實流程，應優先決定移除或接上 UI。

---

## AddEditAccount

**健康度摘要**：此組整體健康度良好：AddEditAccountFeature 的 7 個 State property（mode/name/type/icon/colorHex/nameError/existingNames）全部被 View 與 reducer 消費，無重構殘留；8 個 Action case（含 delegate 巢狀 2 個）全部可達——setter 由 View 送出、savedSuccessfully/delegate 為內部 send 並由父層 AccountManagementFeature 消費，無死 action。State 為單純表單欄位，無 SSOT 重複或會 desync 的 derived-stored 投影（nameError 屬標準 inline 驗證樣式，與所有 sibling form feature 一致，不算違規）。唯一實質問題在測試覆蓋：核心的 saveTapped 成功寫入鏈（create/update→savedSuccessfully→delegate→dismiss）與 cancel 路徑完全無測試，10 個 action 路徑只覆蓋 3 個。"}

**Action 覆蓋率**：3/10

**未覆蓋關鍵路徑**：
- saveTapped 成功分支：trimmedName 通過驗證後的 .run effect（mode=.add 呼叫 ledger.createAccount / mode=.edit 呼叫 ledger.updateAccount 並保留 id/sortOrder/isArchived/createdAt），目前零覆蓋，這是本 feature 的核心寫入邏輯
- savedSuccessfully → delegate(.saved) → dismiss() 的 effect 編排（兩段協調），以及父層 AccountManagementFeature 對 addEdit(.presented(.delegate(.saved))) 的清空+reload 反應，整條鏈路皆未測
- cancelTapped → delegate(.dismissed) → dismiss() 路徑，含父層 addEdit(.presented(.delegate(.dismissed))) 的 addEdit=nil 反應，未測
- typeChanged：點選 type tile 連動寫入 type 並（在 View 端）一併送出 iconChanged/colorHexChanged 的預設值，此連動行為（型別切換重置 icon/color）無 reducer 測試守護
- edit 模式 saveTapped 成功：updated Account 必須以 existing.id/sortOrder/isArchived/createdAt 重建，回歸風險高（容易誤用 .add 路徑或漏帶欄位），無測試

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — AddEditAccountFeature 的 saveTapped 成功寫入分支（createAccount/updateAccount）完全無測試
  - 位置: `Features/Sources/Features/AccountManagement/AddEditAccountFeature.swift:115`
  - 細節: Grep 全域搜尋 createAccount/savedSuccessfully/delegate(.saved) 於 NeuLedgerTests，僅命中 LedgerClientLiveTests（Client 層）、Carrier/AddTransaction/Budget 等其他 feature；AccountManagementFeatureTests 對 AddEditAccountFeature 只測了 saveTapped 的兩個驗證失敗分支（empty 行97、duplicate 行116）與 nameChanged 行115。第115行起的 .run effect（mode=.add → ledger.createAccount；mode=.edit → ledger.updateAccount 以 existing.id/sortOrder/isArchived/createdAt 重建）、第138行 send(.savedSuccessfully)、第141行 savedSuccessfully → delegate(.saved)+dismiss、第147行 cancelTapped → delegate(.dismissed)+dismiss 全數未被任何 store.send/store.receive 覆蓋。delegate(.saved)/(.dismissed) 的父層反應（AccountManagementFeature 行234/241 清空 addEdit 並 reload）也無測試（CarrierManagementFeatureTests 行370 有等價測試，此組沒有）。
  - 建議修法: 新增 AddEditAccountFeatureTests：覆蓋 add 成功（spy createAccount + receive savedSuccessfully + receive delegate.saved）、edit 成功（斷言 updated 帶回原 id/sortOrder/createdAt）、cancelTapped → delegate.dismissed，並在父層補 addEdit(.presented(.delegate(.saved))) 觸發 reload 的測試。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] ssot-violation** — AddEditAccountFeature.State 的 .add init 硬寫 icon="creditcard" / colorHex="#3478F6"，與 AccountType.cash 的 SSOT 預設（defaultIcon="banknote" / defaultColor="#8E8E93"）不一致
  - 位置: `Features/Sources/Features/AccountManagement/AddEditAccountFeature.swift:39`
  - 細節: 類型預設的單一真相是 Domain/Enums/AccountType.swift 第45行 defaultIcon 與第55行 defaultColor：.cash → 'banknote' / '#8E8E93'。但 AddEditAccountFeature.State.init 的 .add 分支（第38-40行）預選 type=.cash，卻硬寫 icon='creditcard'、colorHex='#3478F6'（#3478F6 是 DesignConstants 第31行的通用 brandPrimary 藍，與任何 AccountType.defaultColor 都不符）。AddEditAccountView 第83-85行的 typeTile 在使用者點選類型時會一併送 iconChanged(type.defaultIcon)+colorHexChanged(type.defaultColor) 把值校正回 SSOT；但若使用者進新增頁後不碰類型選擇器（.cash 已預選），直接改名存檔，產生的帳戶 icon/color 將是 creditcard/#3478F6 而非 .cash 的正規 banknote/#8E8E93——亦即帳戶外觀與其類型不符。Grep 確認此 init 完全沒有引用 AccountType.cash.defaultIcon/defaultColor。對照 CustomAccountDraft（AccountType.swift 第88-96行）與 AccountType.new（第25-33行）都正確走 type.defaultIcon，本處是唯一繞過 SSOT 的硬寫點。
  - 建議修法: 將 .add 分支改為 self.icon = AccountType.cash.defaultIcon、self.colorHex = AccountType.cash.defaultColor（或統一改用 let t: AccountType = .cash 後取 t.defaultIcon/defaultColor），消除硬寫常數與類型 SSOT 的分歧。

### 覆蓋率抽查結論

同意原審查員的覆蓋率統計。Action case 我自己數過：top-level 8 個（nameChanged / typeChanged / iconChanged / colorHexChanged / saveTapped / cancelTapped / savedSuccessfully / delegate）加上 Delegate 子枚舉 2 個（saved / dismissed）= 10，與「總數 10」吻合。「已覆蓋 3」指 nameChanged（第115行測試）、saveTapped 的 empty 分支、saveTapped 的 duplicate 分支三條路徑——若以 distinct action case 嚴格計其實只有 2 個（nameChanged、saveTapped），但以「被驗到的分支路徑」算為 3 也合理，不影響結論。未覆蓋的關鍵路徑清單（saveTapped 成功 add/edit 寫入、savedSuccessfully→delegate.saved→dismiss 兩段編排、cancelTapped→delegate.dismissed、edit 模式 id/sortOrder/isArchived/createdAt 保留、typeChanged 連動重置 icon/color）我逐一在 reducer 與測試交叉核對，全部屬實零覆蓋。此外補充一點 typeChanged 連動：該「點類型→重置 icon/color」邏輯實際住在 View（AddEditAccountView 第83-85行）而非 reducer，故即使補 reducer 測試也守不到該連動，需在 reducer 層另設計或以 snapshot/UI 測試覆蓋——這加強了原審查員「typeChanged 連動無守護」的論點。"}

---

## CategoryManagement

**健康度摘要**：CategoryManagement 的 State 維度健康（filteredCategories 為正確的 computed 投影、無 SSOT 重複或同步膠水），無維度 2 findings。主要問題集中在兩處：(1) categoriesMoved reorder action 在 redesign 移除 .onMove 後成為純死碼，只剩 TODO 註解與測試撐著；(2) 測試覆蓋有明顯缺口 — 最關鍵的『確認刪除』『存檔後重載』『進入編輯』三條副作用路徑全無覆蓋，刪除/編輯流程目前沒有任何回歸保護。建議優先補 deleteConfirmed 與 delegate(.saved) 兩條測試。

**Action 覆蓋率**：6/10

**未覆蓋關鍵路徑**：
- alert(.presented(.deleteConfirmed)) — 實際刪除分類 + 重載清單的 effect 完全沒測，刪除壞掉不會被任何測試攔截
- addEdit(.presented(.delegate(.saved))) — 新增/編輯存檔後 listCategories 重載這條清單刷新唯一機制無保護
- categoryTapped — 開啟 edit sheet 的入口（含 context-menu Edit）未覆蓋
- addEdit(.presented(.delegate(.dismissed))) — 取消編輯時 sheet 清理路徑未覆蓋

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — categoriesMoved action 在重新設計後成為死碼 — 唯一的觸發源 .onMove 已移除，僅存 TODO 註解
  - 位置: `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift:95`
  - 細節: 全域 grep `categoriesMoved` 只命中：reducer 宣告(line 37/95)、View 第 106 行的『一句 TODO 註解』、以及測試 line 88/105。View 並無任何 `store.send(.categoriesMoved...)` 呼叫（grep 確認 0 筆），且 View 第 104-106 行明確註記 `.onMove` drag-to-reorder 已在 redesign 中移除、改以 context-menu 重做但尚未實作。父層 SettingsFeature(line 152-153) 只是 push child 上 stack，從不轉送此 action。因此 line 95-124 整段 reorder 邏輯（含 sortOrder 重排與 `ledger.updateCategory` 迴圈 effect）在 production 永遠不會被執行，只靠 line 88 的測試讓它『看起來有用』。
  - 建議修法: 若短期內不重做 reorder UI，移除 categoriesMoved case、CancelID.reorder 與對應測試；若要保留，依 TODO 在 View 補上 context-menu 觸發點。

- **[high] test-gap** — alert 確認刪除路徑 (.alert(.presented(.deleteConfirmed))) 完全沒測 — deleteCategory + 重載 effect 從未被觸發
  - 位置: `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift:146`
  - 細節: reducer line 146-152 在使用者確認刪除後呼叫 `ledger.deleteCategory(id)` 再 `listCategories` 重載，是本畫面最關鍵的副作用。測試 CategoryManagementFeatureTests line 156-169 只驗證 `deleteRequested` 會『建構出』alert（deleteConfirmed 僅出現在 ButtonState 構造內，line 160），但從未 `store.send(.alert(.presented(.deleteConfirmed(id))))`。對照所有兄弟 feature（AccountManagement line 219、BudgetManagement line 117、TagManagement line 166、CarrierManagement line 289 等）都有送出 deleteConfirmed 並斷言 delete+reload，唯獨 CategoryManagement 缺。grep `deleteConfirmed` 在本測試檔只 1 筆且是構造、非 send。
  - 建議修法: 新增測試 send `.alert(.presented(.deleteConfirmed(id)))`，stub `ledgerClient.deleteCategory` 與 `listCategories`，並 receive `.categoriesLoaded` 斷言刪除後清單。

- **[high] test-gap** — addEdit 存檔/取消 delegate 回流路徑未測 — saved 觸發的重載 effect 與 dismissed 的清理皆無覆蓋
  - 位置: `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift:158`
  - 細節: reducer line 158-164 收到 child 的 `.delegate(.saved)` 後會 `state.addEdit = nil` 並重新 `listCategories` → `categoriesLoaded`（新增/編輯後清單刷新的唯一機制）；line 166-168 的 `.delegate(.dismissed)` 負責關閉 sheet。AddEditCategoryFeature 確認兩個 delegate case 都會被 emit（line 142 send(.delegate(.saved))、line 148 send(.delegate(.dismissed))）。但 CategoryManagementFeatureTests 內 grep `delegate / .saved / .dismissed` 為 0 筆；testAddButtonTapped 只測到 presents 與手動 `.addEdit.dismiss`，沒走 delegate 分支。代表『存檔後清單會不會刷新』這條 happy path 無保護。
  - 建議修法: 新增測試送 `.addEdit(.presented(.delegate(.saved)))`，stub listCategories，斷言 addEdit 歸 nil 並 receive `.categoriesLoaded`；另測 `.delegate(.dismissed)` 僅清空 addEdit。

- **[medium] test-gap** — categoryTapped (進入編輯) action 未測 — 點選非預設分類開啟 edit sheet 的路徑無覆蓋
  - 位置: `Features/Sources/Features/CategoryManagement/CategoryManagementFeature.swift:90`
  - 細節: reducer line 90-92 在 categoryTapped 時設定 `state.addEdit = AddEditCategoryFeature.State(mode: .edit(category))`，是進入編輯流程的入口，由 View 第 135 與 180 行兩處送出（row 主按鈕與 context-menu Edit）。本測試檔 grep `categoryTapped` 為 0 筆（其他命中皆屬 AnalysisFeatureTests 的同名不同型別 action，已點開確認非本 feature）。因此 add 入口(addButtonTapped)有測、edit 入口無測。
  - 建議修法: 新增測試送 `.categoryTapped(customExpenseCategory)`，斷言 `$0.addEdit = AddEditCategoryFeature.State(mode: .edit(category))`。

### 覆蓋率抽查結論

同意原審查員的覆蓋率統計，且自行重數核對無誤。頂層 Action 枚舉 9 個 case（task / categoriesLoaded / selectedTypeChanged / addButtonTapped / categoryTapped / categoriesMoved / deleteRequested / addEdit / alert）加上巢狀 Alert.deleteConfirmed = 共 10 個。逐筆對照測試 store.send 與 receive：已覆蓋為 task(send 43)、categoriesLoaded(receive 45)、selectedTypeChanged(send 66/82)、addButtonTapped(send 133)、categoriesMoved(send 105)、deleteRequested(send 156/183) = 6 個，與『10 中 6』相符。未覆蓋的 4 條關鍵路徑也與我獨立驗證完全吻合：alert(.presented(.deleteConfirmed))、addEdit(.presented(.delegate(.saved)))、addEdit(.presented(.delegate(.dismissed)))、categoryTapped。唯一須加註的細節：categoriesMoved 雖被測試計入『已覆蓋』，但對應 production action 為死碼（見 F1），屬於『測試覆蓋了一條 production 永不可達的路徑』，等於這 1 格覆蓋率對實際品質保護無意義——原審查員已在 F1 detail 點出此點，故不另列。State property 全部在 View 被讀取（isLoading:25、filteredCategories:28/112/114、selectedType:80、addEdit:58 binding、alert:62 binding），無殘留 property；寫入單一經 ledgerClient、導航走 TCA，無 SSOT 違規。原四項發現已完整涵蓋所有 live 未測路徑，無額外可補的實質缺陷。

---

## AddEditCategory

**健康度摘要**：維度 1（死碼）與維度 2（SSOT）皆零問題：State 的 7 個 property 全部被 View 消費，8 個 action case（含 Delegate 兩子例）全部可達——saveTapped/cancelTapped 由 View 送出，savedSuccessfully 由 reducer 自送，delegate 由 parent CategoryManagementFeature L158/L166 轉接消費；type 雖可獨立編輯但屬正常單畫面表單暫態，存檔時的權威值仍從 mode 重新推導（L118/L130），無跨 action 同步膠水、不會 desync，不算違規。唯一問題集中在維度 3：此組完全沒有專屬測試檔，9 個 reducer case 覆蓋率 0，且 saveTapped 內多條分支（空名驗證、transfer fallback、default 保留原 type、delegate+dismiss 編排）均無測試保護，建議優先補上。

**Action 覆蓋率**：0/9

**未覆蓋關鍵路徑**：
- saveTapped (.add) 空白名稱 → state.nameError = error_category_name_empty 且不發 effect 的驗證分支
- saveTapped (.add) 有效輸入 → ledger.createCategory 被呼叫、type==.transfer 時 fallback 回 initialType、接著 receive(.savedSuccessfully)
- saveTapped (.edit) → ledger.updateCategory 帶 existing.id/sortOrder，且 existing.isDefault 時強制保留 existing.type（忽略使用者改動）
- savedSuccessfully → 編排 delegate(.saved) + dismiss()；以及 cancelTapped → delegate(.dismissed) + dismiss() 的雙 effect 順序
- typeChanged 在 isDefault==true 時被 guard 擋下（不改 state.type），isDefault==false 時正常切換

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — AddEditCategoryFeature 完全沒有專屬測試檔，9 個 action case 0 覆蓋
  - 位置: `Features/Sources/Features/CategoryManagement/AddEditCategoryFeature.swift:76`
  - 細節: 全 repo 搜尋 (Features/Sources、NeuLedgerTests、NeuLedgerWatchTests、NeuLedgerWidget、Shared、NeuLedger) 只有 NeuLedgerTests/Tests/FeaturesTests/CategoryManagementFeatureTests.swift:134 觸及此型別，且僅以 AddEditCategoryFeature.State(mode: .add(.income)) 建構 State 後在 L139 立即 dismiss，從未透過 store.send 驅動 AddEditCategoryFeature 的 reducer body。因此 reducer 處理的 9 個 case（nameChanged / iconChanged / colorHexChanged / typeChanged / saveTapped / cancelTapped / savedSuccessfully / delegate(.saved) / delegate(.dismissed)）覆蓋率為 0。同類 Form feature 皆有專屬測試（AddEditTagFeatureTests、AddEditAccountFeature、BudgetFormFeatureTests、CarrierManagementFeatureTests 都測了 saveTapped 空名/有效/edit 三路徑），唯獨 Category 缺。saveTapped 內含多條未驗證的關鍵邏輯分支：空名 guard 設 nameError（L99-103）、.add 時 type==.transfer 的 fallback 回 initialType（L118）、.edit 時 existing.isDefault 強制保留 existing.type 而非使用者選的 type（L130）、savedSuccessfully/cancelTapped 的 delegate+dismiss 雙 effect 編排（L141-150）。這些都是純邏輯、無 UI 依賴，極易回歸。
  - 建議修法: 新增 AddEditCategoryFeatureTests，至少覆蓋 saveTapped 空名設 nameError、.add 有效輸入呼叫 createCategory 並 receive savedSuccessfully、.edit isDefault 保留原 type、以及 typeChanged 在 isDefault 時被 guard 擋下這幾條路徑。

### 覆蓋率抽查結論

合理性抽查後同意原統計的實質結論（覆蓋 0），但對「9 個 action case」的計數方式需註記。實際 Action enum 頂層只有 8 個 case：nameChanged / iconChanged / colorHexChanged / typeChanged / saveTapped / cancelTapped / savedSuccessfully / delegate（reducer switch 也是 8 個 arm）。原審查員的「9」是把 delegate 展開成 delegate(.saved) 與 delegate(.dismissed) 兩條可區分處理路徑分開計（而不計裸 delegate catch-all），屬可接受的計數慣例；無論用 8（頂層 case）或 9（含 delegate 子路徑）計，已覆蓋數皆為 0，結論不變。另獨立核對另兩個維度均無遺漏：(a) 殘留 property — State 7 個 property（mode/name/icon/colorHex/type/nameError/isDefault）在 AddEditCategoryView 全部有被讀取（mode L14、name L74/76/80/158、icon L68/181、colorHex L62/182/196、type L97/127、nameError L166、isDefault L117/118），無殘留；(b) 死 action — 8 個 case 全部有發送端與處理端（前六個由 View store.send 發出、savedSuccessfully 由 reducer L136 內部發、delegate 兩子 case 由 reducer L142/148 發並由 parent CategoryManagementFeature L158/166 接），無死碼；(c) SSOT — parent 的 state.categories 僅由 categoriesLoaded（L75）與 categoriesMoved（L114）寫入，存檔後走 delegate(.saved) → parent 重新 listCategories → categoriesLoaded 單一載入路徑，未發現重複真實來源，無 SSOT 違規。故無需補列 missedFindings。

---

## TagManagement

**健康度摘要**：TagManagementFeature 整體健康度良好：兩個 State property（tags、isLoading）與 @Presents addEdit/alert 皆有實際消費者，無重構殘留的死 property 或死 Action（維度 1 零問題）；State 也沒有同一資訊存兩份或需手動同步的 derived state，tags/isLoading 各司其職（維度 2 零問題）。唯一缺口在維度 3 測試覆蓋：10 個 action 分支覆蓋 6 個，缺的是兩條 addEdit delegate 路徑——尤其 .saved 同時關 sheet 並重新 listTags 的刷新編排（high），以及 .dismissed 的取消關閉（medium）。建議補這兩個 parent 端 delegate 接收測試即可補齊關鍵邏輯。

**Action 覆蓋率**：6/10

**未覆蓋關鍵路徑**：
- addEdit(.presented(.delegate(.saved))) — 存檔後關 sheet 並重新 listTags 的清單刷新編排無測試，重載遺漏不會被發現
- addEdit(.presented(.delegate(.dismissed))) — 按取消鈕關閉 sheet 的路徑（與系統 dismiss 不同入口）無回歸保護
- task 的 .cancellable(id: CancelID.task) 取消行為未驗證（重複進入畫面時的 in-flight 取消語義無測試，優先度較低）

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — addEdit(.presented(.delegate(.saved))) 的 sheet 關閉 + listTags 重載分支完全未測
  - 位置: `Features/Sources/Features/TagManagement/TagManagementFeature.swift:98`
  - 細節: reducer 在 case .addEdit(.presented(.delegate(.saved))) 同時做兩件事：state.addEdit = nil 以及 .run 重新呼叫 ledger.listTags() 並 send(.tagsLoaded)。這是新增/編輯標籤後讓清單刷新的唯一路徑，屬關鍵 effect 編排。但 TagManagementFeatureTests.swift 全檔沒有任何測試送出 .addEdit(.presented(.delegate(.saved)))（grep 確認測試只觸碰 saveTapped/nameChanged 等 child 內部 action，未觸碰 parent 的 delegate 接收）。一旦未來改動把重載漏掉，現有測試無法捕捉。
  - 建議修法: 加一個測試：addEdit 已 presented，送出 .addEdit(.presented(.delegate(.saved)))，斷言 addEdit 變 nil 並 receive(.tagsLoaded) 後 tags 更新。

- **[medium] test-gap** — addEdit(.presented(.delegate(.dismissed))) 的 sheet 關閉分支未測
  - 位置: `Features/Sources/Features/TagManagement/TagManagementFeature.swift:105`
  - 細節: case .addEdit(.presented(.delegate(.dismissed))) 把 state.addEdit 設為 nil（取消編輯時關閉 sheet）。測試中只用 store.send(\.addEdit.dismiss)（PresentationAction.dismiss）來關閉，從未走 delegate(.dismissed) 這條由 child cancelTapped 觸發的路徑。兩條路徑語義不同（一個是系統下滑關閉、一個是按取消鈕），目前 cancel 鈕路徑無回歸保護。
  - 建議修法: 加一個測試送出 .addEdit(.presented(.delegate(.dismissed)))，斷言 addEdit 變 nil。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[high] test-gap** — AddEditTagFeature.saveTapped 成功寫入路徑（createTag/updateTag）完全未測 — 整個 feature 的核心寫入邏輯無回歸保護
  - 位置: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift:81`
  - 細節: saveTapped 的非空名稱分支（line 88-101）是新增/編輯標籤的唯一寫入點：add mode 呼叫 ledger.createTag(Tag(name: trimmedName, color: colorHex))、edit mode 呼叫 ledger.updateTag(Tag(id: existing.id, ...))，再 send(.savedSuccessfully)。TagManagementFeatureTests.swift 對 AddEditTagFeature 只有兩個測試：testAddTagEmptyNameValidation（line 62-73，只測空名稱 guard 走 nameError 分支）與 testNameChangedClearsError（line 94-107）。grep createTag/updateTag 在整個 NeuLedgerTests 只命中 LedgerClientLiveTests 與 DomainTests（Client 層測試），無任何 Feature 測試斷言 createTag/updateTag 被以正確的 trimmed name + colorHex 呼叫，也無斷言收到 .savedSuccessfully。名稱 trim、add/edit 分流、id 帶入皆零覆蓋，比 F1/F2 更關鍵卻被原審查員遺漏（原審查只盤點了 parent TagManagementFeature 的 10 個 reducer 分支，未盤點 child AddEditTagFeature 的 action 覆蓋）。
  - 建議修法: 加兩個測試：add mode saveTapped 用 LockIsolated 捕捉 createTag 參數斷言 name=trimmed/color=colorHex 並 receive(.savedSuccessfully)；edit mode saveTapped 斷言 updateTag 帶入原 id。

- **[medium] test-gap** — AddEditTagFeature.savedSuccessfully / cancelTapped 的 delegate 發射 + dismiss 編排未測
  - 位置: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift:103`
  - 細節: savedSuccessfully(line 103-107) 在 .run 內 send(.delegate(.saved)) 後 await dismiss()；cancelTapped(line 109-113) send(.delegate(.dismissed)) 後 await dismiss()。這兩個是 child 通知 parent（F1/F2 的上游觸發點）的關鍵編排，但測試從未送出 .savedSuccessfully 或 .cancelTapped，也無 receive(\.delegate.saved)/(\.delegate.dismissed) 或 dismiss 效果斷言。F1/F2 驗的是 parent 收 delegate 後的反應，這裡缺的是 child 發 delegate 的那一端——兩端皆無測試，等於整條 child→parent 通訊鏈無任何單元覆蓋。
  - 建議修法: 加測試送 .cancelTapped 斷言 receive(.delegate(.dismissed)) 並驗 dismiss 被呼叫；savedSuccessfully 同理斷言 receive(.delegate(.saved))。

- **[low] test-gap** — AddEditTagFeature.colorHexChanged 未測
  - 位置: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift:77`
  - 細節: colorHexChanged(line 77-79) 設 state.colorHex = hex。View 在 AddEditTagView.swift:116 經 ColorSwatchPicker onSelect 觸發。grep colorHexChanged 在 NeuLedgerTests 對 TagManagement 零命中，無測試斷言選色後 colorHex 更新（而 colorHex 又是 saveTapped 寫入 createTag 的 color 來源）。優先度低（單純賦值），但原審查員的覆蓋率盤點完全未提及此 child action。
  - 建議修法: 加一行測試 store.send(.colorHexChanged("#A66BF0")) 斷言 $0.colorHex = "#A66BF0"。

### 覆蓋率抽查結論

原審查員的「action case 總數 10、已覆蓋 6」我抽查後判定合理，但需澄清計數口徑：TagManagementFeature 的「頂層 enum Action」其實只有 7 個 case（task / tagsLoaded / addButtonTapped / tagTapped / deleteRequested / addEdit / alert，巢狀 Alert 是另一個 enum 非頂層 case）。原審查員的「10」是把 reducer switch 拆解後的分支數：task、tagsLoaded、addButtonTapped、tagTapped、deleteRequested、alert(.presented(.deleteConfirmed))、alert(catch-all)、addEdit(.presented(.delegate(.saved)))、addEdit(.presented(.delegate(.dismissed)))、addEdit(catch-all) = 10，與我重數一致。已覆蓋 6（前五個分支 + alert deleteConfirmed，其中 addEdit/alert 兩個 catch-all 也被 \\.addEdit.dismiss 測試隱性命中）也合理，真正未覆蓋的具名分支正是 F1(saved)/F2(dismissed)，與統計吻合。但這份統計只盤點了 parent TagManagementFeature，完全未把 child AddEditTagFeature 的 action 納入覆蓋率視野——而 child 的 saveTapped 成功寫入、savedSuccessfully、cancelTapped、colorHexChanged 才是這個畫面組最大的測試缺口（見 missedFindings）。結論：parent 的數字準確，但覆蓋率評估的「分母」漏了整個 child reducer，給人「只差 2 條」的錯覺，實際缺口比原審查員呈現的更大。

---

## AddEditTag

**健康度摘要**：AddEditTag 這組程式碼本身相當乾淨：4 個 stored property（mode/name/colorHex/nameError）與 7 個 action case 全數可達且被 View 或 reducer 消費，無重構殘留死碼；State 也無 single-source-of-truth 違規（name/colorHex 是刻意從 mode 種子化、單一寫入點的可編輯表單欄位，符合 TCA form 慣例，無 desync 膠水）。唯一問題在測試覆蓋：與 prompt 假設相反，此組其實有測試（位於 TagManagementFeatureTests.swift），但僅覆蓋 saveTapped 空名驗證與 nameChanged 兩條，最核心的 save happy-path（createTag/updateTag）、savedSuccessfully/cancelTapped 的 dismiss + delegate 副作用、以及 edit 沿用 existing.id 的分支全部未測。維度 1、2 零問題，維度 3 一條 high 的 test-gap。

**Action 覆蓋率**：2/7

**未覆蓋關鍵路徑**：
- saveTapped 的 add happy path：trimmedName 非空 → ledger.createTag(Tag(name:color:)) → 收到 savedSuccessfully。這是整個畫面最核心的副作用編排，目前完全沒測（含對 createTag 是否帶正確 name/colorHex 的斷言）。
- saveTapped 的 edit happy path：mode == .edit(existing) → ledger.updateTag(Tag(id: existing.id, ...)) 必須沿用既有 id。id 沿用邏輯出錯會造成新增而非更新，屬高風險未測分支。
- savedSuccessfully → .run { send(.delegate(.saved)); dismiss() }：parent(TagManagementFeature) 靠 delegate(.saved) 收尾並 reload tags，這條 delegate 傳遞鏈未測。
- cancelTapped → .run { send(.delegate(.dismissed)); dismiss() }：取消流程與 dismiss 副作用未測。
- colorHexChanged：colorHex 寫入未驗證（雖屬簡單 setter，但它是 saveTapped 寫入 Tag.color 的唯一來源，至少需一條確認所選色被帶入儲存）。

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — AddEditTagFeature 的 save happy-path（createTag/updateTag → savedSuccessfully → delegate.saved → dismiss）完全沒有測試
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/TagManagementFeatureTests.swift:62`
  - 細節: AddEditTagFeature 共 7 個邏輯 action case（nameChanged、colorHexChanged、saveTapped、cancelTapped、savedSuccessfully、delegate.saved、delegate.dismissed）。現有測試僅 testAddTagEmptyNameValidation（saveTapped 空名分支，AddEditTagFeature.swift:83-86）與 testNameChangedClearsError（nameChanged，:72-75）兩條。完全未覆蓋者：saveTapped 的非空分支（:91-101，add 走 ledger.createTag、edit 走 ledger.updateTag 並沿用 existing.id）、savedSuccessfully（:103-107 送 delegate.saved + dismiss）、cancelTapped（:109-113 送 delegate.dismissed + dismiss）、colorHexChanged（:77-79）、delegate（:115）。注意 prompt 假設『此組沒有任何測試』與事實不符——測試存在於 TagManagementFeatureTests.swift，但 save 主鏈與 dismiss/delegate 副作用是未測的關鍵路徑。edit 分支用 existing.id 重建 Tag（:97）一旦寫錯會變成新增而非更新，屬高風險未測分支。
  - 建議修法: 在 TagManagementFeatureTests.swift 新增針對 AddEditTagFeature 的 add/edit save happy-path 測試：用 withDependencies 注入 ledgerClient.createTag/updateTag spy 斷言帶入的 name/color/id，並 store.receive(\.savedSuccessfully) 後驗 dismiss 與 delegate.saved；另補 cancelTapped 與 colorHexChanged 各一條。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — colorHexChanged 寫入的色碼最終是否被帶進 createTag/updateTag 的 Tag.color 完全沒有端到端斷言
  - 位置: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift:94`
  - 細節: F1 已將 colorHexChanged 列為未覆蓋，但只把它當『簡單 setter』。實際風險點是：colorHex 是 saveTapped 寫入 Tag(name:color:)（:94）/ Tag(id:name:color:)（:97）color 欄位的唯一來源。目前無任何測試在改色後送 saveTapped 並用 createTag/updateTag spy 斷言收到的 Tag.color == 所選 hex。若 reducer 未來誤用 state.name 當 color 或漏帶 colorHex，現有測試完全抓不到。應補一條『colorHexChanged 改色 → saveTapped → createTag spy 驗 tag.color 等於新色』的整鏈測試，而非只驗 state.colorHex setter。
  - 建議修法: 在 AddEditTag 的 add happy-path 測試中先送 .colorHexChanged(新hex)，再送 .saveTapped，用 LockIsolated 捕獲 ledgerClient.createTag 收到的 Tag，#expect 其 color 等於該 hex 並 store.receive(\.savedSuccessfully)。

- **[low] ssot-violation** — 預設色 "#3478F6" 在 AddEditTagFeature 內硬編兩次（:30 與 :33），且與 Color.Design.brandPrimary / DesignConstants.tagColorOptions 重複
  - 位置: `Features/Sources/Features/TagManagement/AddEditTagFeature.swift:30`
  - 細節: init 的 add 分支（:30）與 edit fallback（:33 tag.color ?? "#3478F6"）各硬編一次同一個 magic literal；同一字串又出現在 Color+extension.swift:74 brandPrimary、DesignConstants.swift:31/39 tagColorOptions、以及 AddEditAccountFeature.swift:40。屬低度的常數重複，非 TCA 導航/快取機制問題。若品牌預設色變更，需多點同步修改。嚴格度低——是既有 codebase 普遍模式（AddEditAccount 亦同），列為提醒而非阻擋項。
  - 建議修法: 抽出一個具名常數（如 DesignConstants.tagDefaultColorHex 或沿用 brandPrimary 對應的 hex token），:30 與 :33 同時引用，避免雙重硬編。

### 覆蓋率抽查結論

同意 F1 的實質結論，但對統計口徑做一點修正。原審查員稱『action case 總數 7、已覆蓋 2』；實際上 AddEditTagFeature.Action 頂層 enum（:47-60）只有 6 個 case：nameChanged、colorHexChanged、saveTapped、cancelTapped、savedSuccessfully、delegate。數字 7 是把巢狀 Delegate 的 .saved / .dismissed 拆成兩項所致。無論用 6 還是 7 當分母，已測的有意義邏輯路徑僅 2 條（空名驗證 + nameChanged 清錯），save 主鏈（add createTag / edit updateTag 沿用 existing.id）、savedSuccessfully→delegate.saved+dismiss、cancelTapped→delegate.dismissed+dismiss、colorHexChanged 全未覆蓋——這個核心判斷正確且嚴重度為 high 合理。另我抽查了殘留 property / 死 action 兩維度：4 個 state property（mode 經 navigationTitle 於 View:36 讀取、name 於 View:63/90、colorHex 於 View:58/114、nameError 於 View:99）全部有讀取；6 個 action case 全部可達（View 送 cancelTapped/saveTapped/nameChanged/colorHexChanged，reducer 內送 savedSuccessfully/delegate）。無殘留 property、無死 action。SSOT 方面 parent TagManagementFeature 於 delegate(.saved) 單點 reload tags（:98-103），符合單一寫入點，不算違規。

---

## BudgetManagement

**健康度摘要**：BudgetManagement 整組存在一段明確的重構殘留：`.toggleActive` action 與其唯一驅動 UI（Components/BudgetRow.swift）皆為死碼——實際畫面 BudgetManagementView 用自家的 budgetRow（無 toggle）渲染，從不送出此 action，而 BudgetRow 在全 repo 零實例化，兩者應一併刪除（測試也要同步移除 testToggleActive）。State 的 single source of truth 沒有問題：budgets 是唯一資料來源，isLoading 與 budgets.isEmpty 語義不重疊，totalBudgetAmount/activeBudgets 都正確地以 View computed property 推導而非冗存。測試覆蓋了載入、刪除與（死）toggle，但 add/edit 表單閉環四條分支全無覆蓋，其中 `.delegate(.saved)` 的 dismiss + reload 編排最該補測。

**Action 覆蓋率**：6/10

**未覆蓋關鍵路徑**：
- addEdit(.presented(.delegate(.saved))) — 表單儲存後應 dismiss sheet 並重新載入 budgets；目前完全沒測，是 add/edit 流程閉環的關鍵 effect 編排
- addEdit(.presented(.delegate(.dismissed))) — 取消表單應將 addEdit 設回 nil；無測試保證 dismiss 行為
- budgetTapped(budget) — 應以 .edit(budget) 模式開啟表單 sheet；編輯入口無測試
- addButtonTapped — 應以 .add 模式開啟表單 sheet；新增入口無測試

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — Action `.toggleActive(Budget)` 為死 action：唯一可送出它的 UI（BudgetRow）從未被建構
  - 位置: `Features/Sources/Features/BudgetManagement/BudgetManagementFeature.swift:29`
  - 細節: 全域搜尋 `toggleActive` 在 Features/Sources、NeuLedgerTests、Widget、Shared、Watch 範圍內，命中僅有三處：BudgetManagementFeature.swift 第 29 行（宣告）、第 73 行（handler）、以及 BudgetManagementFeatureTests.swift 第 56 行（測試 store.send）。實際 render 路徑 BudgetManagementView 的 budgetRowButton/budgetRow（第 153-209 行）並無任何 toggle 控制項，也從不送出 `.toggleActive`。唯一帶 onToggle 並會觸發此 action 語義的 UI 是 Components/BudgetRow.swift，但其 `BudgetRow(` 在全 repo 零次實例化（見下一條 finding）。parent SettingsFeature 也不會轉送此 case。故此 action 僅存在於 reducer 與測試，屬重構殘留死碼（RecurringTransactions 的 `toggleActiveTapped` 是不同型別，非誤判）。
  - 建議修法: 移除 `.toggleActive` case 與其 reducer 分支（第 29、73-80 行），並一併刪除 BudgetManagementFeatureTests 的 testToggleActive 測試；若日後要恢復行內 toggle 應改走 View 實際使用的元件。

- **[medium] other** — 元件 `BudgetRow`（Components/BudgetRow.swift）整支為死碼，從未被任何 View 實例化
  - 位置: `Features/Sources/Features/BudgetManagement/Components/BudgetRow.swift:5`
  - 細節: 搜尋 `BudgetRow(` 於 Features/Sources、NeuLedgerTests、NeuLedgerWatchTests、NeuLedgerWidget、Shared、NeuLedger 全部回傳 0 命中；`BudgetRow` 識別字僅出現在其自身宣告處（第 5 行）。BudgetManagementView 並未引用它，而是用自己的 private `budgetRow(_:)`（第 174 行）渲染列。此元件是唯一帶 onToggle 回呼、會驅動 `.toggleActive` 的 UI；它與該 dead action 是同一段重構殘留，應一併清除。
  - 建議修法: 刪除整個 Features/Sources/Features/BudgetManagement/Components/BudgetRow.swift 檔案。

- **[medium] test-gap** — add/edit 表單閉環的 4 個分支（含關鍵 `.delegate(.saved)` reload effect）零覆蓋
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/BudgetManagementFeatureTests.swift:39`
  - 細節: 現有測試覆蓋 .task、.budgetsLoaded、.toggleActive、.deleteRequested、.alert(.deleteConfirmed)。但 reducer 中 `.addButtonTapped`（第 65 行，開 .add sheet）、`.budgetTapped`（第 69 行，開 .edit sheet）、`.addEdit(.presented(.delegate(.saved)))`（第 107-112 行，dismiss + 重新 listAll）、`.addEdit(.presented(.delegate(.dismissed)))`（第 114-116 行，dismiss）四條分支均無 store.send/receive 覆蓋。其中 `.delegate(.saved)` 同時做 state mutation（addEdit = nil）與 effect 編排（listAll → budgetsLoaded），是 add/edit 流程最關鍵且最易回歸的路徑，卻完全沒測。
  - 建議修法: 新增測試：send `.addButtonTapped`/`.budgetTapped` 斷言 addEdit 進入正確 mode；send `.addEdit(.presented(.delegate(.saved)))` 斷言 addEdit 歸 nil 並 receive `.budgetsLoaded`；以及 dismissed 分支斷言 addEdit 歸 nil。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — 唯一覆蓋 `.toggleActive` 的測試 `testToggleActive` 是在測一條死 action（測試本身連帶為殘留），刪 F1 時必須一併移除否則編譯失敗
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/BudgetManagementFeatureTests.swift:43`
  - 細節: 原審查員在 F1 的 suggestedFix 有提到刪測試，但未把『此測試正在驗證一條永不被 UI 觸發的 action』獨立列為覆蓋率失真點。testToggleActive（43-59 行）send `.toggleActive(Self.sampleBudget)` 並斷言 isActive 翻轉，這給人『toggle 流程有測試保護』的假象，實際上 production 不存在任何能送出此 action 的路徑。覆蓋率統計把它算進『已覆蓋 6』會高估真實有效覆蓋：扣掉這條死 action 測試，真正對應 live 路徑的有效測試只有 5 條。移除 F1 的 case 時，此測試會因 `.toggleActive` 不存在而編譯失敗，必須同步刪除。
  - 建議修法: 刪 F1 的 case 時同步刪除 testToggleActive；統計有效覆蓋率時不應將此死 action 測試計入。

### 覆蓋率抽查結論

大致同意原審查員的覆蓋率方向，但數字需修正。我實際清點：top-level Action case 有 8 個（task、budgetsLoaded、addButtonTapped、budgetTapped、toggleActive、deleteRequested、addEdit、alert），而 reducer switch 展開後共 11 條分支（含 .alert(.deleteConfirmed)、.alert catch-all、.addEdit(.saved)、.addEdit(.dismissed)、.addEdit catch-all）。原審查員寫『action case 總數 10、已覆蓋 6』的 10 與 6 都不精確：若以 reducer 分支計應為 11 條、實際被 send/receive 觸到的只有 5 條（task、budgetsLoaded、toggleActive、deleteRequested、alert.deleteConfirmed）。更重要的是其中 toggleActive 是死 action（見 F1/missedFindings），扣除後對應 live UI 路徑的有效覆蓋僅 4 條。原審查員列的四條未覆蓋關鍵路徑（saved/dismissed/budgetTapped/addButtonTapped）與我重點抽查結果完全一致，方向正確；分母/分子數字偏鬆，建議改以『11 分支、5 觸及（其中 1 條為死 action）』表述。"

---

## BudgetForm

**健康度摘要**：BudgetForm 三檔健康度良好：維度一（死碼）與維度二（SSOT）均零問題 — 所有 9 個 State property 都被 View 或 reducer 消費，12 個 action case（delegate 展開為 saved/dismissed）全部有 View 觸發、effect 回傳或 parent（BudgetManagementFeature）轉送的合法來源，無重複或可推導的殘留 state；mode 內含整包 Budget 但僅在 save 時讀取不可編輯的 id/isActive，屬標準表單模式非 desync。唯一可改進處在測試：action case 覆蓋 9/12，缺口集中在 categoryChanged 這條會影響預算 scope 的存檔路徑（連同 period/startDate 經 saveTapped 組進 Budget 的欄位都無斷言保護），未覆蓋的 3 個 case 中 categoryChanged 屬實質邏輯路徑而非純 UI setter。

**Action 覆蓋率**：9/12

**未覆蓋關鍵路徑**：
- categoryChanged → 選定分類經 saveTapped round-trip 進 Budget.categoryId 的存檔路徑（影響預算 scope，目前零覆蓋）
- periodChanged / startDateChanged 雖為純 setter 可豁免，但其值經 saveTapped 組進 Budget 的傳遞未被任何斷言驗證

### 經交叉驗證確認的發現（confirmed）

- **[medium] test-gap** — categoryChanged action 與 categoryId 存檔路徑完全沒有測試覆蓋
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/BudgetFormFeatureTests.swift`
  - 細節: reducer 的 categoryChanged（BudgetFormFeature.swift:117-119）設定 state.categoryId，而該值會在 saveTapped 內被組進 Budget（BudgetFormFeature.swift:143 add、153 edit）。但測試中對 categoryId 唯一一次提及是 sampleBudget 的 categoryId: nil（測試檔 line 14），grep 全檔無任何 .send(.categoryChanged...) 或對 addedBudget/updatedBudget.categoryId 的斷言。testSaveTappedValidAdds 只斷言 name 與 amount（line 139-140），未驗證選定分類會 round-trip 進入持久化的 Budget。這是真正的邏輯路徑（非純 UI setter），因 categoryId 透過 save 影響預算的 scope。
  - 建議修法: 新增一筆測試：send(.categoryChanged(someId)) 後 saveTapped，斷言 planningClient.create 收到的 budget.categoryId == someId。

- **[low] test-gap** — saveTapped 建立的 Budget 未驗證 period 與 startDate 欄位
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/BudgetFormFeatureTests.swift`
  - 細節: testSaveTappedValidAdds（line 120-141）只 #expect name 與 amount，沒有斷言 period 或 startDate 是否正確寫入。periodChanged（reducer line 109-111）與 startDateChanged（line 113-115）本身是純 setter 可豁免，但它們的值會被 saveTapped 組進 Budget（BudgetFormFeature.swift:144-145、154-155），而這段組裝邏輯（含 add/edit 兩分支對 period/startDate 的傳遞）目前無斷言保護，等於組裝路徑半覆蓋。
  - 建議修法: 在既有 add/edit 存檔測試中補上對 budget.period 與 budget.startDate 的 #expect 斷言。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — edit 分支的 isActive: existing.isActive 保留邏輯完全無斷言（testSaveTappedEditUpdates 未驗 isActive）
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/BudgetFormFeatureTests.swift:145`
  - 細節: BudgetFormFeature.swift:156 在 edit 分支重建 Budget 時以 isActive: existing.isActive 保留現有啟用狀態，這是一個刻意的保留不變量。但 testSaveTappedEditUpdates(line 145-166) 只 #expect name(163)/id(164)/amount(165)，grep 'isActive' 在整個測試檔只命中 line 17（sampleBudget isActive: true 的建構），無任何對 updatedBudget.value?.isActive 的斷言。若重構誤把 isActive 寫死成 true 或漏傳，測試不會抓到。此 gap 比 F2（聚焦 add 模式 period/startDate）更具體且針對 edit 分支獨有的保留邏輯，原審查員未列出。
  - 建議修法: 在 testSaveTappedEditUpdates 補 #expect(updatedBudget.value?.isActive == Self.sampleBudget.isActive)，並一併補 period/startDate/categoryId 斷言以鎖死 edit 分支組裝。

- **[low] test-gap** — saveTapped 的 .run effect 對 planningClient.create/update 拋錯無 catch、無 saveFailed action，且零測試覆蓋失敗路徑
  - 位置: `Features/Sources/Features/BudgetManagement/BudgetFormFeature.swift:137`
  - 細節: saveTapped 的 .run（line 137-161）以 try await planningClient.create/update 寫入，但無 catch；grep 'saveFailed|catch|error' 在 reducer 僅命中 nameError/amountError 的 validation，無任何寫入失敗處理 action。若 client 拋錯，savedSuccessfully 永不送出、表單既不 dismiss 也不顯示回饋，錯誤被 TCA 靜默吞掉。測試亦無對應的失敗路徑案例。屬行為+測試雙重缺口；嚴格落在三維度中的 test-gap（失敗路徑零覆蓋）。
  - 建議修法: 於 .run 加 catch 並 send 一個 saveFailed action 設定 inline 錯誤（符合 CLAUDE.md「validation 用 inline 不用 Alert」），並補一筆 planningClient.create throws 的測試斷言表單停留且顯示錯誤。

### 覆蓋率抽查結論

原審查員的覆蓋率統計方向正確但數字偏高，需修正。實際 top-level Action enum 為 11 個 case（task、categoriesLoaded、nameChanged、amountChanged、periodChanged、startDateChanged、categoryChanged、saveTapped、cancelTapped、savedSuccessfully、delegate），非其聲稱的 12（疑似把 Delegate 子 case 或 Mode case 一併誤計）。實際被測試 send 或 receive 涵蓋的 distinct action 為 8 個（task、categoriesLoaded、nameChanged、amountChanged、saveTapped、cancelTapped、savedSuccessfully、delegate），未覆蓋為 3 個（periodChanged、startDateChanged、categoryChanged），非其聲稱的「9 covered / 3 uncovered」。其指出的兩條未覆蓋關鍵路徑（categoryChanged round-trip 進 Budget.categoryId、period/startDate 經 saveTapped 傳遞未斷言）經我獨立 grep 全數成立。結論：覆蓋率分母/分子應修正為 11 個 case、8 covered、3 uncovered，但「3 條關鍵路徑未覆蓋」的核心判斷正確且我同意。另補 edit 分支 isActive 保留與 save 失敗路徑兩個原統計未提及的缺口。"


---

## CarrierManagement

**健康度摘要**：CarrierManagementFeature 整體健康度良好：五個 State property（carriers / isLoading / expandedCarrierId / addEdit / alert）皆被 View 與 reducer 實際消費，無重構殘留的死 property；State 也無 SSOT 違規（delete 時的 name 是 inline 推導非 stored，符合慣例）。唯一缺口在測試覆蓋：editTapped action 雖被 View 兩處送出且 reducer 有處理，卻完全沒有測試；addEdit delegate(.dismissed) 分支與 delete 的 catch 錯誤路徑也未覆蓋。維度 1（死碼）與維度 2（SSOT）零問題，問題集中在維度 3。

**Action 覆蓋率**：8/11

**未覆蓋關鍵路徑**：
- editTapped(Carrier) — 設定 addEdit=.edit(carrier) 的分支，View 兩處送出卻無任何測試，編輯入口回歸無保護
- addEdit(.presented(.delegate(.dismissed))) — cancelTapped 觸發的關閉分支未驗證，與已測的 saved 分支為獨立路徑
- deleteConfirmed 的 catch: 錯誤回復 effect — delete 拋錯時用 listAll 重載列表，錯誤編排完全未覆蓋

### 經交叉驗證確認的發現（confirmed）

- **[medium] test-gap** — editTapped action 路徑零測試覆蓋（View 兩處送出、reducer 有 case）
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
  - 細節: CarrierManagementFeature.swift:76-78 的 `case let .editTapped(carrier):` 會設定 `state.addEdit = AddEditCarrierFeature.State(mode: .edit(carrier))`，且 CarrierManagementView.swift:172（contextMenu）與:210（expandedDetail 的鉛筆按鈕）都會 `store.send(.editTapped(carrier))`。但全域 grep 確認測試檔內無任何 `editTapped`（grep 結果為空，TransactionDetailFeature 的同名 case 為不同型別已排除）。這是使用者可觸發的真實分支卻無回歸保護，若 mode 傳遞或 State 初始化回歸不會被測出。
  - 建議修法: 新增一條測試：send(.editTapped(carrierA)) 斷言 $0.addEdit == AddEditCarrierFeature.State(mode: .edit(carrierA))。

- **[low] test-gap** — addEdit delegate(.dismissed) 分支未被測試（與已測的系統 dismiss 不同路徑）
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
  - 細節: CarrierManagementFeature.swift:130-132 的 `case .addEdit(.presented(.delegate(.dismissed)))` 將 `state.addEdit = nil`。此分支由 AddEditCarrierFeature.swift:127 的 cancelTapped → `send(.delegate(.dismissed))` 觸發。測試只覆蓋了 `store.send(\.addEdit.dismiss)`（testAddTapped 第 84 行，走系統 @Presents dismiss）與 `.delegate(.saved)`，grep `dismissed` 在測試檔結果為空。saved 與 dismissed 是兩條獨立 reducer 分支，dismissed 完全沒有斷言保護。
  - 建議修法: 新增測試：先設 addEdit 為 .add，send(.addEdit(.presented(.delegate(.dismissed)))) 斷言 $0.addEdit = nil 且無後續 carriersLoaded effect。

- **[medium] test-gap** — deleteConfirmed 的 catch 錯誤回復路徑未測試
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
  - 細節: CarrierManagementFeature.swift:109-112 的 `catch:` 區塊：當 carrierClient.delete 拋錯時，會 `(try? await carrierClient.listAll()) ?? []` 後 send(.carriersLoaded)，用以回復列表狀態。所有 delete 測試（testDeleteTappedClearsWidget / testDeleteTapped / testDeleteTappedTriggersSyncAllCarriers）的 delete stub 都成功不拋錯（grep `throw`/`catch` 在測試檔為空），錯誤分支從未走到。這是錯誤處理編排，屬關鍵路徑。
  - 建議修法: 新增測試：delete stub `throw CoreError.operationDenied`，斷言仍 receive(\.carriersLoaded) 用 listAll 回傳值回復列表。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — AddEditCarrierFeature 的 saveFailed → saveError 錯誤路徑零測試（同檔 AddEdit suite，渲染 inline 錯誤 UI）
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
  - 細節: AddEditCarrierFeature.swift:108-110 的 saveTapped catch 區塊 `send(.saveFailed(error.localizedDescription))`，第120-123行 `case let .saveFailed(message): state.isSaving = false; state.saveError = message`。此 saveError 會在 AddEditCarrierView.swift:249-250 渲染為 inline `ErrorText`（使用者可見的儲存失敗提示）。同檔 AddEditCarrierFeature suite 共10個測試（testValidPhoneBarcode…testSaveTappedUpdate），全部 create/update stub 成功不拋錯；grep `saveFailed`/`saveError` 在整個測試檔命中數為 0。原審查員把範圍限縮在 CarrierManagementFeature suite，漏掉同一檔案組裡的 AddEditCarrierFeature reducer——而 saveFailed 與 F3 性質一致（都是錯誤回復編排未測），且這條還直接驅動可見 UI，遺漏不應接受。對照組：RecurringTransactionFormFeatureTests.swift:157 有對應的 saveFailed→saveError 測試，證明這是團隊既有的測試慣例，此處屬真空。
  - 建議修法: 在 AddEditCarrier suite 新增測試：create stub `throw CoreError.operationDenied`，send(.saveTapped){ $0.isSaving=true }，receive(\.saveFailed){ $0.isSaving=false; $0.saveError=<message> }，不應 receive .savedSuccessfully/.delegate。

- **[low] test-gap** — AddEditCarrierFeature 的 cancelTapped → delegate(.dismissed) 起點未測（只測到 parent 收端 F2，未測 child 發端）
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift`
  - 細節: AddEditCarrierFeature.swift:125-129 `case .cancelTapped: return .run { await send(.delegate(.dismissed)); await dismiss() }`。AddEditCarrier suite 的10個測試完全沒有 `cancelTapped`（grep 命中數 0），故 child 端「按取消會 emit delegate(.dismissed) 並呼叫 dismiss」這條從未被驗證。這與 F2 互補但不重疊：F2 是 parent CarrierManagementFeature 收到 dismissed 後清空 addEdit 的收端分支；此處是 child 發出 dismissed 的發端，兩端都無覆蓋意味整條取消鏈路無回歸保護。對照組 CustomAccountFormFeatureTests.swift:87 testCancelTappedEmitsDismissed 證明此模式有既有測試慣例。
  - 建議修法: 在 AddEditCarrier suite 新增測試：send(.cancelTapped) 後 receive(\.delegate.dismissed)，並以 @Dependency(\.dismiss) override 斷言 dismiss 被呼叫。

### 覆蓋率抽查結論

統計合理，抽查後同意。原審查員「action case 總數 11、已覆蓋 8」對應的是 reducer body 內的 switch 分支數，我獨立數得正好 11 個分支（.task / .carriersLoaded / .carrierRowTapped / .addTapped / .editTapped / .deleteTapped / .alert(.presented(.deleteConfirmed)) / .alert / .addEdit(.presented(.delegate(.saved))) / .addEdit(.presented(.delegate(.dismissed))) / .addEdit），數字正確（注意：Action enum 頂層只有8個 case，11 是含巢狀 PresentationAction/Delegate 路徑的分支數，計法一致無爭議）。未覆蓋的3條（editTapped / addEdit dismissed / deleteConfirmed catch）即 F1/F2/F3，與「已覆蓋8」相符（11-3=8）。需補充：catch-all `case .alert:`（取消刪除/alert dismiss）回 .none 也無專測，但屬無副作用 no-op，不列入關鍵路徑缺口，故不影響「8」的判定。三個未覆蓋項的關鍵性分級（editTapped/deleteConfirmed catch 為 medium、dismissed 為 low）我亦同意。另外原審查員把分析範圍限縮在 CarrierManagementFeature suite，未把同檔 AddEditCarrierFeature suite 的兩個錯誤/取消路徑納入（見 missedFindings），那是 suite 邊界造成的盲區，不影響本統計本身的正確性。所有 property（carriers/isLoading/expandedCarrierId/addEdit/alert）皆在 View body 被讀取（CarrierManagementView.swift:23/26/113/115/160/184 等），無殘留 property；無死 action；SSOT 無違規（widget 同步單一寫入點在 carrierClient 內、導航走 TCA @Presents，皆屬合規機制）。

---

## AddEditCarrier

**健康度摘要**：AddEditCarrierFeature 的 State 與 Action 設計乾淨：7 個 stored property 全部被 View 或 reducer 消費（含 saveError 由 View line 249 渲染），無重構殘留的死 property；9 條 action 邏輯路徑也都可達（delegate.dismissed 由 parent CarrierManagementFeature line 130 消費），無死 action。無 SSOT 重複（canSave 已正確設計為 computed property）。主要問題集中在「測試覆蓋」：任務前提「此組目前沒有測試檔案」其實有誤——NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift 的 AddEditCarrierFeature Tests suite 已涵蓋 validation 與 save 路徑，但 cancelTapped（delegate.dismissed 傳遞）與 saveFailed（錯誤處理，會寫入 saveError）兩條關鍵路徑完全未測，且姊妹 feature（BudgetForm / RecurringTransactionForm）都有對應測試，屬可補齊的缺口。

**Action 覆蓋率**：5/9

**未覆蓋關鍵路徑**：
- saveFailed — carrierClient.create/update throw 後的錯誤分支：isSaving 復位 + saveError 寫入完全未驗證（AddEditCarrierFeature.swift line 120-123）
- cancelTapped → delegate(.dismissed) + dismiss()：取消時的 delegate 傳遞與 dismiss 副作用未驗證（line 125-129）
- delegate(.dismissed)：此 delegate case（line 57）從未被任一測試 receive，parent 的 .addEdit(.presented(.delegate(.dismissed))) 串接亦未端到端驗證
- nameChanged：純 setter binding（line 67-69），View line 177 會送出但無測試；屬純 UI setter，優先級最低，非必補

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — saveFailed 錯誤處理路徑（寫入 saveError、清 isSaving）完全無測試覆蓋
  - 位置: `/Users/drakehuang/SideProject/iOSProject/NeuLedger/Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift:120`
  - 細節: saveTapped 的 .run 在 catch 中送出 .saveFailed(error.localizedDescription)（line 108-109），對應的 case .saveFailed（line 120-123）會 state.isSaving = false 並 state.saveError = message。全域 grep saveFailed 僅命中本 feature 與 RecurringTransactionForm；在 AddEditCarrierFeatureTests suite（CarrierManagementFeatureTests.swift line 7-164）內 grep saveFailed / saveError 均零命中。沒有任何測試讓 carrierClient.create/update throw，因此 isSaving 復位、saveError 寫入與 ErrorText 渲染來源（View line 249）這條錯誤分支從未被驗證。姊妹 RecurringTransactionFormFeatureTests.swift line 157 有對應的『saveFailed sets saveError on state』測試，可平移。
  - 建議修法: 新增測試：覆寫 $0.carrierClient.create = { _ in throw SomeError } 後 send(.saveTapped) 並 receive(\.saveFailed) 斷言 isSaving==false 且 saveError != nil。

- **[medium] test-gap** — cancelTapped → delegate.dismissed + dismiss 的取消傳遞路徑無測試覆蓋
  - 位置: `/Users/drakehuang/SideProject/iOSProject/NeuLedger/Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift:125`
  - 細節: case .cancelTapped（line 125-129）回傳 .run 依序送出 .delegate(.dismissed) 並呼叫 dismiss()，由 View line 46 觸發、parent CarrierManagementFeature line 130 消費。在 AddEditCarrierFeatureTests suite 內 grep cancelTapped / dismissed 零命中（已確認），delegate.dismissed case 本身（line 57 宣告）也從未被任一測試 receive 或斷言。同型別的 CustomAccountFormFeatureTests.swift line 87 與 BudgetFormFeatureTests.swift line 170 都有『cancelTapped emits delegate.dismissed』測試，本 feature 缺漏。
  - 建議修法: 新增測試：注入 $0.dismiss spy 後 send(.cancelTapped)、receive(\.delegate.dismissed) 並斷言 dismiss 被呼叫。

- **[low] test-gap** — 任務前提有誤：本組已有測試檔，但 saveError property 從未被任何測試斷言
  - 位置: `/Users/drakehuang/SideProject/iOSProject/NeuLedger/NeuLedgerTests/Tests/FeaturesTests/CarrierManagementFeatureTests.swift:7`
  - 細節: 任務描述稱『此組目前沒有任何測試檔案』，實際上 CarrierManagementFeatureTests.swift line 7-164 的 @Suite("AddEditCarrierFeature Tests") 已存在並覆蓋 validation / saveTapped add+update / 空名稱預設 / edit 初始化。但全域 grep 顯示 saveError 在本 suite 完全沒有出現——saveError（AddEditCarrierFeature.swift line 23）唯一被寫入非 nil 的路徑是 saveFailed，而該路徑未測，導致 saveError 的寫入與 View line 249-251 ErrorText 顯示鏈路完全未被驗證（saveError property 仍是 live，因 View 有消費，不算殘留）。
  - 建議修法: 補上 saveFailed 測試時一併 #expect(store.state.saveError != nil)，並修正『無測試檔案』的前提認知。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — parent CarrierManagementFeature 的 .addEdit(.presented(.delegate(.dismissed))) handler（line 130-132，清 addEdit=nil）端到端未測
  - 位置: `/Users/drakehuang/SideProject/iOSProject/NeuLedger/Features/Sources/Features/CarrierManagement/CarrierManagementFeature.swift:130`
  - 細節: child 端 delegate.dismissed 缺測已被 F2 涵蓋，但 parent 側對應的接收 handler 同樣缺測且是另一條獨立路徑。我 grep 'delegate(.dismissed)'/'delegate.dismissed'/'addEdit.dismiss' 於 CarrierManagementFeatureTests.swift，唯一命中是 line 249 的 \.addEdit.dismiss——那是 TCA 框架 PresentationAction 的 .dismiss 機制，與 reducer 自訂的 .delegate(.dismissed) 是不同 case。對照 .delegate(.saved) 的 parent handler(line 117)在測試 line 370/394/419/536 有端到端覆蓋，dismissed 這條 parent reset(line 131 state.addEdit=nil)完全沒有 send(.addEdit(.presented(.delegate(.dismissed)))) 的測試。屬 saved 路徑的對稱缺口，非 TCA 機制本身違規。
  - 建議修法: 在 CarrierManagementFeature suite 補一筆 send(.addEdit(.presented(.delegate(.dismissed)))) 斷言 $0.addEdit = nil。

### 覆蓋率抽查結論

基本同意原審查員的覆蓋率盤點，數字口徑略可商榷但不影響結論。我親自數 AddEditCarrierFeature.Action 為 8 個 top-level case(nameChanged/typeChanged/barcodeChanged/saveTapped/cancelTapped/savedSuccessfully/saveFailed/delegate)，外加 Delegate 子列舉 2 個(saved/dismissed)；原審查員報的『9』應是把 delegate 與其子 case 合併計數的結果，數字本身略含糊，但其『未覆蓋關鍵路徑』清單我逐項核對全部正確：(1)saveFailed 錯誤分支未測——確認；(2)cancelTapped→delegate(.dismissed)+dismiss()未測——確認；(3)child 的 delegate(.dismissed) case 從未被 receive——確認；(4)nameChanged 純 setter 未測且優先級最低——確認(grep 顯示 carrier 測試檔 nameChanged 零命中，而 Budget/Account/Tag 等姊妹 feature 都有測，原審查員標『非必補』合理)。已覆蓋的 5 條(typeChanged、barcodeChanged、saveTapped add/update/空名稱、savedSuccessfully via receive、delegate.saved via receive)我也逐一在測試檔 line 75/26-65/105-159/106/107 驗到。State property 我逐一比對 View 消費情況(mode/name/type/barcode/barcodeError/isSaving/saveError/canSave 全部在 View body 被讀取)，無殘留 property。唯一原審查員未明列的補充項是 parent 側 dismissed handler 的端到端缺測(已列入 missedFindings，low)。整體盤點可信。"


---

## Onboarding

**健康度摘要**：Onboarding 這組整體健康度良好：三個 State stored property（currentStep / selectedTypes / customAccounts）與 @Presents 的 customAccountSheet 全部被 reducer 與 View 實際消費，無重構殘留；8 個 action case 全部可達且皆有測試 send/receive 覆蓋（含 finishOnboarding 的多 effect 編排與順序驗證）；State 無一份資料存兩份的 SSOT 問題（totalSelectedCount 正確地以 View computed property 推導，未冗存）。唯一缺口是 finishOnboarding 在零帳戶情境（accountSelection 取消預設帳戶後按 Skip）的分支沒有測試，屬低風險邊界路徑。

**Action 覆蓋率**：8/8

**未覆蓋關鍵路徑**：
- finishOnboarding 在零帳戶下的行為（selectedTypes 與 customAccounts 皆為空時，setupAccounts([]) 被以空陣列呼叫）——可由「accountSelection 步驟取消勾選預設 .cash 後按 Skip」觸發，reducer 無任何 guard，目前無測試。

### 經交叉驗證確認的發現（confirmed）

- **[low] test-gap** — finishOnboarding 的零帳戶路徑（空 selectedTypes + 空 customAccounts）未被測試
  - 位置: `Features/Sources/Features/Onboarding/OnboardingFeature.swift:92`
  - 細節: reducer 的 .finishOnboarding（OnboardingFeature.swift:92-101）把 state.selectedTypes 與 state.customAccounts 映射成 accounts 後呼叫 ledger.setupAccounts(accounts)，對空集合沒有任何 guard。在 OnboardingView 中，Skip 按鈕（OnboardingView.swift:41）會直接 send(.finishOnboarding)，且 showsSkip（OnboardingView.swift:86-91）在 .accountSelection 步驟為 true；使用者只要在 accountSelection 取消勾選預設的 .cash（typeToggled）使 selectedTypes 變空、再按 Skip，就會以 setupAccounts([]) 收尾。對照測試 OnboardingFeatureTests.swift 的 testFinishWritesAccounts/testFinishOnboardingDirect/testFinishEffectOrdering，三者都只用非空的 selectedTypes（[.cash] 或 [.cash,.creditCard]），完全沒有覆蓋『空帳戶』分支，無法驗證此情況下 setupAccounts 收到什麼、或是否該被擋下。
  - 建議修法: 新增一條 finishOnboarding 在 selectedTypes=[] 且 customAccounts=[] 時的測試，斷言 setupAccounts 收到的陣列內容（確認預期行為），必要時於 reducer 補零帳戶 guard 並一併測試。

### 覆蓋率抽查結論

原統計「action case 總數 8、已覆蓋 8」大致正確但數字略有出入：Action enum 實際只有 7 個頂層 case（nextButtonTapped / finishOnboarding / typeToggled / addCustomAccountTapped / customAccountSheet / customAccountDeleted / delegate），原審查員的「8」應是把巢狀 Delegate.onboardingCompleted 也算進去。無論如何，逐一核對後每個 case 都有測試觸及：nextButtonTapped（testNextFromWelcome / testNextFromAccountSelection / testFinishWritesAccounts）、finishOnboarding（testFinishOnboardingDirect / testFinishEffectOrdering，並於 testFinishWritesAccounts receive）、typeToggled（testToggleAdd / testToggleRemove）、addCustomAccountTapped（testOpenSheet）、customAccountSheet（testSheetSubmit / testSheetDismiss）、customAccountDeleted（testDeleteCustom）、delegate.onboardingCompleted（finish 三測試 receive）。我同意原審查員「未覆蓋關鍵路徑＝finishOnboarding 零帳戶分支」的判斷，且該描述精確：此為 finishOnboarding case 內的一個未測 branch，而非整個 action case 未覆蓋。額外補充：我亦把四個 @ObservableState property（currentStep / selectedTypes / customAccounts / customAccountSheet）與全部 action 在 repo 全域（Features/Sources、NeuLedgerTests、Widget、Shared、NeuLedger、WatchTests）grep 過，均有被 View 讀取或 dispatch，無殘留 property / 死 action；markOnboardingComplete 僅由 reducer 單點呼叫、由 AppFeature delegate 觸發路由，無 SSOT 雙寫。故無新增 missedFindings。

---

## CustomAccountForm

**健康度摘要**：整組健康度良好：State 僅 name/type/color 三個獨立輸入加一個 computed `canSubmit`，無 SSOT 重複或同步膠水代碼，三個 property 皆被 View binding 與 reducer 草稿建構消費。測試覆蓋完整（5 個 action case 展開後全數以 send/receive 覆蓋，含 submit 的 valid/no-op/trimming payload 三條分支與 uuid 依賴注入）。唯一實質問題是 `cancelTapped` 為死碼——View 無取消按鈕、parent 不轉送、無 effect 產生，僅測試直接 send，連帶 `Delegate.dismissed` 在 runtime 不可達；另有 `._printChanges()` 除錯遺留待清。"}

**Action 覆蓋率**：5/5

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — Action case `cancelTapped` 為死碼：View 無取消按鈕、parent 不轉送、無 effect 產生，僅單元測試直接 send
  - 位置: `Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift:36`
  - 細節: 全域 grep `cancelTapped`（Features/Sources、NeuLedgerTests、Shared、NeuLedger、NeuLedgerWidget、NeuLedgerWatchTests）對此 feature 只命中四處：reducer 宣告（行 36）、switch arm（行 55）、以及測試 CustomAccountFormFeatureTests.swift 的 testCancelEmitsDismiss（行 87、92）。CustomAccountFormView.swift 的所有 store.send 只有 `.submitTapped`（行 50），整個 View 無 cancel/dismiss/close 按鈕（grep cancel|dismiss|close 於 View 為空）。OnboardingView.swift 用 `.sheet(item: $store.scope(...))`（行 23）呈現，關閉走 SwiftUI 原生 swipe-to-dismiss——只會把 binding 設 nil，不會 route 經 `cancelTapped`。OnboardingFeature 的 `.customAccountSheet(.presented(.delegate(.dismissed)))` 雖有 handler（行 81-86），但既然此 feature 內唯一產生 `delegate(.dismissed)` 的來源就是 `cancelTapped`，runtime 永遠走不到，連帶 `Delegate.dismissed`（行 42）也只在測試中被合成觸發。確認無 parent 注入：grep `presented(.cancelTapped)` 為空。
  - 建議修法: 移除 `cancelTapped` case、其 switch arm 與 `Delegate.dismissed`（連同 testCancelEmitsDismiss 與 OnboardingFeature 的 .dismissed handler / testSheetDismiss）；若設計上需保留可取消的 X 按鈕，則改為在 View 補上送出 `cancelTapped` 的按鈕，讓此路徑真正可達。

- **[low] test-gap** — 測試殘留 `._printChanges()` 與失效註解，屬除錯遺留應清掉
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/CustomAccountFormFeatureTests.swift:55`
  - 細節: testSubmitDraftPayload 在 reducer 建構時掛了 `._printChanges()`（行 55），這是 TCA 除錯輸出，不應留在 committed 測試。另外 testSubmitEmitsDelegate（行 43-44）留有「TestStore's .receive does not let us inspect... use a ref-cell pattern instead」的註解，但該測試其實沒做 payload 斷言，真正的 payload 驗證在下一個 test 用 LockIsolated 完成，使此註解與空殼測試形成冗餘。非覆蓋率缺口（payload 路徑已被 testSubmitDraftPayload 覆蓋），屬測試衛生問題。
  - 建議修法: 刪除行 55 的 `._printChanges()`；合併或移除 testSubmitEmitsDelegate 的失效註解，避免與 testSubmitDraftPayload 重複。

### 覆蓋率抽查結論

同意原審查員的覆蓋率結論，但需註記一個語意陷阱。我自己數過：top-level Action enum 有 4 個 case（binding / cancelTapped / submitTapped / delegate），Delegate 巢狀 enum 有 2 個 case（dismissed / submitted）。原審查員的『5』最合理的解讀是把可達 action 變體攤平計算：binding、cancelTapped、submitTapped、delegate.submitted、delegate.dismissed = 5，且五者皆有對應測試（testBinding、testCancelEmitsDismiss、testSubmit*、testSubmitDraftPayload、testCancelEmitsDismiss 收到 dismissed），故『5/5 覆蓋』在『單元測試有觸碰』這個定義下成立。但要強調：cancelTapped 與 delegate.dismissed 雖被單元測試直接 send 而標記為 covered，其 production 路徑實為死碼（F1）——『被測試覆蓋』不等於『可達』。換言之這份覆蓋率把一條死路徑算進分母又算進分子，數字無誤但掩蓋了 F1。其餘維度（殘留 property、SSOT）我也抽查過：name/type/color/canSubmit 四者皆在 View 被讀取或 $store 綁定（28/44/45/52/53/61/63 行），colorPalette 同時被 View(43) 與 State 預設(21-22) 使用，無 unused property；無金額/餘額儲存或重複 hex helper 等 SSOT 違規。除 F1/F2 外無新增遺漏發現。

---

## RecurringManagement

**健康度摘要**：整組健康度良好：State 為單一來源（items 為唯一事實，active/paused/summary 皆在 View 內由 items 純函數推導，無重複 stored state 或同步膠水），無真正的死 property 或死 Action——deleteTapped 雖被註解標為 backward-compat，但確實由 NotificationSettingsView 觸發故非死碼。主要缺口在測試覆蓋（10 個 action case 僅 6 個被 store.send/receive 覆蓋）：deleteTapped 委派、form 存檔後 reload、addButtonTapped、alert 取消等關鍵路徑無守護網。建議補測上述分支，尤其 deleteTapped 與 form delegate.saved reload 兩條使用者可見路徑。

**Action 覆蓋率**：6/10

**未覆蓋關鍵路徑**：
- deleteTapped(id) — NotificationSettingsView 唯一觸發此 case，reducer 將其委派為 .send(.deleteRequested(id))，但無任何測試送出 .deleteTapped；此「向後相容委派」分支若被誤刪/改寫不會被測試攔截
- form(.presented(.delegate(.saved))) — 表單儲存後重新 listRecurring 並 reload 的 effect 編排完全未測，新增/編輯週期交易後清單是否刷新無保護網
- addButtonTapped — 設定 form = .add 進入新增流程的導航分支未測（與 itemTapped 的 .edit 分支對稱，後者有測）
- alert catch-all（.dismiss / 按下取消鈕）— 取消刪除不應呼叫 deleteRecurring 的負向路徑未測

### 經交叉驗證確認的發現（confirmed）

- **[medium] test-gap** — deleteTapped 委派分支（NotificationSettings 專用路徑）完全無測試覆蓋
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift:87`
  - 細節: case .deleteTapped(id) 是 NotificationSettingsView.swift:382 唯一觸發的 case（grep 確認：standalone RecurringTransactionManagementView 用的是 .deleteRequested，只有內嵌的 RecurringSectionView 走 .deleteTapped）。reducer 在 line 88 回傳 .send(.deleteRequested(id))。但測試檔內 store.send 全列舉只有 .task/.toggleActiveTapped/.deleteRequested/.alert(.presented(.deleteConfirmed))/.itemTapped，從未送出 .deleteTapped。這條被註解標為「backward-compat」的委派邏輯沒有測試守護，未來重構（例如有人以為 deleteTapped 是死碼想刪掉）會直接破壞 NotificationSettings 的刪除手勢且 CI 不會紅。
  - 建議修法: 新增一條測試 store.send(.deleteTapped(id)) 並 store.receive(\.deleteRequested) 斷言會轉成 deleteRequested 並彈出確認 alert。

- **[medium] test-gap** — form 儲存後 reload（form delegate .saved）的 effect 編排未測
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift:119`
  - 細節: case .form(.presented(.delegate(.saved))) 會觸發 ledger.listRecurring() 並 send(.loaded) 重新整理清單，這是新增/編輯週期交易完成後清單刷新的唯一機制。測試檔 grep 結果：addButtonTapped / delegate(.saved) / .form( 皆為 NONE，此分支零覆蓋。表單存檔後清單不刷新會是使用者可見 bug，卻無測試攔截。
  - 建議修法: 新增測試：透過 store.send(.form(.presented(.delegate(.saved)))) 並覆寫 ledgerClient.listRecurring，receive(\.loaded) 斷言 items 被刷新。

- **[low] test-gap** — addButtonTapped 進入新增表單的導航分支未測
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift:62`
  - 細節: case .addButtonTapped 設定 state.form = RecurringTransactionFormFeature.State(mode: .add)，由 View（line 35、89）與 NotificationSettings addRow 觸發。對稱的 .itemTapped（mode: .edit）有 testEditFormStateReflectsExistingNextDueDate 覆蓋，但 .addButtonTapped 在測試檔中 grep 為 NONE。雖是 setter，但攜帶 mode 分支語義，屬應覆蓋的導航邏輯而非純 binding。
  - 建議修法: 新增測試 store.send(.addButtonTapped) 斷言 state.form?.mode 為 .add（或 form != nil）。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — alert 取消/dismiss 負向路徑（按取消鈕不應呼叫 deleteRecurring）未測
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionManagementFeature.swift:116`
  - 細節: reducer line 116-117 的 case .alert（catch-all，涵蓋 PresentationAction.dismiss 與按下 .cancel 鈕）回 .none，是「取消刪除時必須不執行 deleteRecurring」的守護點。測試檔僅有正向 deleteConfirmed 路徑（line 122-127，斷言 deletedId == rt.id），無任何 store.send(.alert(.dismiss)) 或 cancel-button 路徑斷言 deleteRecurring 不被呼叫。原審查員在覆蓋率統計的『未覆蓋關鍵路徑』list 第 4 點明確提到此 alert catch-all 負向路徑，卻未把它升格為一條編號 finding（F1-F3 只涵蓋 deleteTapped/form saved/addButtonTapped）。這是一條被點名但漏建檔的真實測試缺口：若有人誤改 catch-all 為也呼叫 delete，取消刪除會誤刪資料且 CI 不會紅。
  - 建議修法: 新增測試：初始 state 帶 alert，store.send(.alert(.dismiss)){ $0.alert = nil }，並以會 fail 的 ledgerClient.deleteRecurring stub（如 unimplemented）驗證取消時 deleteRecurring 完全不被呼叫、無 .loaded 收到。

### 覆蓋率抽查結論

原審查員的覆蓋率統計大致正確、可採信，但「action case 總數 10」的數法需澄清。實際 top-level Action enum case 為 9 個（task/loaded/addButtonTapped/itemTapped/toggleActiveTapped/deleteRequested/deleteTapped/form/alert，feature line 21-33）；「10」應是把 nested Alert.deleteConfirmed（line 37）一併計入才得到。若改以 reducer switch 分支計則為 11 個（form 與 alert 各拆 presented/catch-all）。無論哪種數法，「已覆蓋 6」與「未覆蓋 4 關鍵路徑」的實質結論成立：測試確實涵蓋 task→loaded、toggleActiveTapped→loaded、deleteRequested、alert(.presented(.deleteConfirmed))→loaded、itemTapped 共 6 條獨立路徑；未覆蓋 addButtonTapped、deleteTapped、form(.delegate(.saved))、alert catch-all 共 4 條，與其 list 完全吻合。State property（items/isLoading/form/alert）全部在 view 有讀取，無殘留 property；每個 Action case 皆有 producer 與 reducer handler，無死 action。SSOT 方面 deleteTapped→deleteRequested 屬 §3.1 之外的同 feature 內部委派、form .saved reload 屬單一寫入後刷新，皆為正常 TCA 編排，不算違規。結論：同意原統計的實質判斷，僅「10」這個總數的計法建議標注為「含 nested Alert case」。"}

---

## RecurringForm

**健康度摘要**：RecurringForm 整體結構乾淨，State 沒有 SSOT 違規（firstRunDate 與 notificationTime 是刻意的日期/時間分軸，於 save 合併，nextDueDateLabel 為純推導顯示，無重複儲存）。主要問題集中在維度 1 與維度 3：toAccountChanged action 與 toAccountId 在 add 模式下完全是死碼（View 有 TODO 未實作 toAccount picker，且 View 註解「type==.transfer 時靜默設定」與事實不符），以及測試覆蓋率偏低——edit 模式的 saveTapped 整條分支、task/optionsLoaded effect 編排、cancelTapped→dismissed 路徑、notificationTime 合併邏輯皆未測。

**Action 覆蓋率**：6/17

**未覆蓋關鍵路徑**：
- saveTapped 的 .edit 分支（行194-205）：複製既有 RecurringTransaction + 呼叫 ledger.updateRecurring，整條編輯儲存路徑零覆蓋，updateRecurring 從未被 stub/斷言
- task → optionsLoaded effect 編排（行95-106）：兩個 async let 並行載入 accounts/categories 並寫入 state.accounts/categories，且 .cancellable(id:) 取消行為未測
- cancelTapped → delegate(.dismissed) + dismiss()（行241-245）：取消流程的 delegate 傳遞與 dismiss 副作用未測（注意 parent 並未消費 .dismissed，僅靠 @Dependency(.dismiss)）
- saveTapped 中 notificationTime 與 firstRunDate 的時間合併（行182-188）：小時/分鐘是否正確套入 nextDueDate 未被驗證，現有測試以 startOfDay 比對而抹掉時間部分
- firstRunDateChanged 的 startOfDay 正規化（行147-149）：手動日期挑選會被 startOfDay 截斷，此正規化邏輯未測

### 經交叉驗證確認的發現（confirmed）

- **[medium] dead-action** — toAccountChanged action 從未被任何 View / Effect / parent 送出（死 Action）
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift:68`
  - 細節: 全域 grep 'toAccountChanged' 僅命中宣告（行68）與 reducer handler（行139-140），沒有任何 store.send(.toAccountChanged) 呼叫點：RecurringTransactionFormView 完全沒有 toAccount picker（行248-252 是 TODO 註解），parent RecurringTransactionManagementFeature 也不轉送此 case。因此 .toAccountChanged 是 reducer 中永遠走不到的分支。
  - 建議修法: 移除 toAccountChanged action 與其 handler，待 design 補上 transfer 第二帳戶 picker（TODO 行248）時再一併加回。

- **[medium] unused-property** — toAccountId 在 add 模式為永遠寫不進值的殘留 property，且 View 註解描述與事實不符
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift:23`
  - 細節: state.toAccountId 唯一的寫入點是死 action .toAccountChanged（行140）。在 .add 模式 init 為 nil（行40）且 View 無任何 UI 改它，所以 saveTapped 組裝 template 時 toAccountId 永遠是 nil（行178、214）——即使使用者選 type==.transfer 也存不進轉入帳戶。View 行250-252 註解宣稱『type==.transfer 時 toAccountId 會被靜默設定』，但 grep 證實程式中沒有任何地方做這件事，註解誤導。edit 模式雖能從既有 template 帶入並原樣回寫（行50、201），不致資料遺失，但 add 模式下此欄位是無法經 UI 觸達的殘留。
  - 建議修法: 連同 toAccountChanged 一起移除 toAccountId（add 模式不支援 transfer 目標帳戶時），或補上 picker 讓它可寫入；同時修正 View 行250-252 的錯誤註解。

- **[high] test-gap** — edit 模式的 saveTapped 整條分支零覆蓋，且 task/cancel/binding 路徑均未測
  - 位置: `NeuLedgerTests/Tests/FeaturesTests/RecurringTransactionFormFeatureTests.swift:50`
  - 細節: 測試只用 mode:.add 建 store，saveTapped 的 switch mode case .edit（行194-205：複製既有 template、updateRecurring）整條分支從未被執行；ledgerClient.updateRecurring 也從未被 stub 或斷言。另外 grep 統計：task=0、optionsLoaded=0、cancelTapped=0、delegate.dismissed=0、notificationTimeChanged=0、firstRunDateChanged=0、noteChanged=0、typeChanged=0、categoryChanged=0 次出現於測試。saveTapped 中 notificationTime 與 firstRunDate 合併出 nextDueDate 的時間部分（行182-188）也沒有任何測試驗證『小時/分鐘有正確套用』——testAddModeAllowsUserToPickFirstDate 只比對 startOfDay（行152-153），時間部分被 startOfDay 抹掉。
  - 建議修法: 新增 mode:.edit 的 saveTapped 測試（stub updateRecurring、斷言 template 欄位），並補一條驗證 notificationTime 小時/分鐘有併入 nextDueDate 的測試。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — saveTapped 對 type==.transfer 完全無 toAccountId 驗證，可存出 toAccountId==nil 的殘缺轉帳 recurring，且與 AddTransactionFeature 的轉帳驗證 SSOT 分歧
  - 位置: `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift:161`
  - 細節: saveTapped（行161-172）只驗 amount>0（行162）與 accountId!=nil（行166），完全沒有 transfer 相關檢查。當 View 行70-72 讓使用者選 type==.transfer 時，因為沒有 toAccount picker（F2/F1），組裝出的 template.toAccountId 必為 nil（add 模式），等於存出一筆『轉入帳戶為 nil』的殘缺轉帳週期，下游 LedgerClient+LiveRecurring.swift:113 會原樣寫入 toAccountId: nil。對照 AddTransactionFeature.swift:262 有 `if state.type == .transfer && state.accountId != nil && state.accountId == state.toAccountId` 的同帳戶自轉驗證（add_transaction_error_same_account），RecurringForm 兩種驗證皆缺。form 測試檔 grep '.transfer' 0 命中，此路徑零覆蓋。這比 F1/F2（聚焦死 action/殘留 property 本身）更進一步：是實際可達 UI（type pill）導致的資料完整性破口。
  - 建議修法: saveTapped 在 type==.transfer 時補驗 toAccountId 非 nil 且 != accountId（沿用 AddTransactionFeature 的 transferError inline 模式），並在補上 toAccount picker 前考慮對 transfer 類型禁用儲存；同時補一條 transfer-type recurring 的測試。

### 覆蓋率抽查結論

同意原統計，數字可重現。Action enum 我自己數：15 個 top-level case（task, optionsLoaded, amountChanged, noteChanged, typeChanged, frequencyChanged, accountChanged, toAccountChanged, categoryChanged, firstRunDateChanged, notificationTimeChanged, saveTapped, saveFailed, cancelTapped, delegate）+ 2 個 Delegate 子 case（saved, dismissed）= 17，與『action case 總數 17』一致（原審查員把 Delegate 兩子 case 一併計入，是合理計法）。已覆蓋 6 也吻合：form 測試實際碰到 amountChanged、accountChanged、saveTapped、frequencyChanged、saveFailed、delegate.saved 共 6 個不同 case。原列出的五條未覆蓋關鍵路徑（edit saveTapped/updateRecurring、task→optionsLoaded cancellable、cancelTapped→delegate.dismissed、notificationTime 時分併入、firstRunDateChanged startOfDay 正規化）我逐一抽查皆屬實，無灌水。唯一補充：覆蓋率統計只談『被觸發』，未點出『type==.transfer 路徑可達但無驗證且零測試』這條資料完整性破口（見 missedFindings），建議併入未覆蓋清單。

---

## WatchApp

**健康度摘要**：WatchAppFeature 是一個極薄的 root composer（tab + 兩個 Scope 子 feature），維度 1（無用 property / 死 action）與維度 2（SSOT）完全乾淨：tab 由 View 的 selection binding 消費、isPagingLocked 已正確以 computed property（非 stored）承載、三個 action 全部有真實送出或轉送路徑，無重複狀態或同步膠水。問題集中在維度 3：這組唯一的 App-level 邏輯就是 isPagingLocked 不變量與其驅動的 TabView tag 移除，但測試只覆蓋 categoryTapped 上鎖 / cancelTapped 解鎖兩條，遺漏 draftSent 解鎖路徑與整個 carrier 子分支（共 17 個 nested action case 僅覆蓋 4 個），且 View 自己註解警告的 selection-stranding 高風險組合無回歸護欄。建議補 2 條測試即可閉合關鍵路徑。

**Action 覆蓋率**：4/17

**未覆蓋關鍵路徑**：
- record(.confirmTapped) → record(.draftSent)：送出成功後 step 重設回 .category 使 isPagingLocked 解鎖、carrier 頁恢復可見的關鍵還原路徑（App-level 唯一邏輯的另一半）
- carrier(.task) / carrier(.carriersUpdated) / carrier(.carrierTapped) / carrier(.barcodeDismissed)：carrier 子分支經 Scope 轉送在此 reducer 層 0 覆蓋
- tab==.carrier 且 record 進入 amount step 的組合：WatchAppView 移除 .tag(.carrier) 時的 TabView selection-stranding 風險，無測試鎖定該不變量

### 經交叉驗證確認的發現（confirmed）

- **[medium] test-gap** — isPagingLocked 解鎖路徑只測 cancelTapped，未測 draftSent（送出成功後的自我復原）
  - 位置: `NeuLedgerWatchTests/WatchAppFeatureTests.swift:41`
  - 細節: WatchAppFeature.State.isPagingLocked = (record.step != .category)（WatchAppFeature.swift:34）是這組唯一的 App-level 邏輯，它是 WatchAppView.swift:29 移除 carrier tag（避免 TabView selection 被遺棄）的唯一依據。測試 pagingLocksDuringEntry 只驗證 categoryTapped 上鎖、cancelTapped 解鎖兩條路徑。但 record flow 還有第二條解鎖路徑：confirmTapped → record(.draftSent)（WatchRecordFeature.swift:193-196 將 step 重設回 .category）。送出成功後 isPagingLocked 必須回到 false，否則送完帳 carrier 頁永遠回不來。此關鍵還原路徑無測試，且 confirmTapped 會走到 ledgerClient.record（@DependencyClient 預設 unimplemented），補測時須依 CLAUDE.md §10① 在 withDependencies 覆寫 watchLedgerClient.record。
  - 建議修法: 新增測試：在 confirm 步驟 send(.record(.confirmTapped))（stub watchLedgerClient.record）→ receive(.record(.draftSent)) 後 #expect(isPagingLocked == false)。

- **[medium] test-gap** — carrier 分支（4 個 nested action）完全未在 App-level 受測，TabView selection-stranding 不變量無回歸防護
  - 位置: `NeuLedgerWatchTests/WatchAppFeatureTests.swift:48`
  - 細節: WatchAppFeature 透過 Scope 轉送 carrier(WatchCarrierFeature.Action)（WatchAppFeature.swift:50-52），但測試從未送出任何 .carrier(...) action（task / carriersUpdated / carrierTapped / barcodeDismissed 四個 case 在此 reducer 層 0 覆蓋）。WatchAppView.swift:24-34 有一段高風險邏輯：當 isPagingLocked 為 true 時把帶 .tag(.carrier) 的 view 從 hierarchy 移除——若此時 tab == .carrier，selection 會被遺棄。tabSelectionBinds 測試（line 48）只單純驗 tab binding setter，未涵蓋『tab 停在 .carrier 時 record 進入 amount step』這條會觸發 selection-stranding 的組合路徑，而 View 註解（line 22-28）明確警告這正是最脆弱處。
  - 建議修法: 新增測試：tab=.carrier 下 send(.record(.categoryTapped)) 使 isPagingLocked 轉 true，斷言 tab 仍為 .carrier（鎖定 cross-reducer 不變量，作為 View 移除 tag 行為的回歸護欄）。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — WatchAppFeature 層完全沒有 carrier 子分支的 happy-path 轉送測試（連 carrierTapped → presentedCarrier 這條純狀態路徑都未在 App 層驗過）
  - 位置: `NeuLedgerWatchTests/WatchAppFeatureTests.swift:48`
  - 細節: 原審查員 F2 聚焦在 tab==.carrier 的 selection-stranding 組合，但更基礎的缺口是：經 Scope 轉送的 carrier 純狀態路徑（carrierTapped 設 presentedCarrier、barcodeDismissed 清空，WatchCarrierFeature.swift:70-76）在 WatchAppFeature 層一次都沒被 send 過。雖然 WatchCarrierFeature 自身可能有單元測試，但 §10① 提醒『Scope parent 測試會走到 child 依賴』反向也成立——App 層的 Scope wiring（action key path `\.carrier` 是否正確接上）目前無任何測試證明轉送鏈沒接錯。這與 F2 是同維度但不同切角的覆蓋缺口。
  - 建議修法: 在 WatchAppFeatureTests 補一條 `send(.carrier(.carrierTapped(id)))` 並斷言 `$0.carrier.presentedCarrier` 被設值，證明 Scope 轉送鏈接通。

### 覆蓋率抽查結論

原審查員的覆蓋率統計合理，抽查後同意。Action case 總數 17 的算法可還原：WatchRecordFeature.Action 12 個 leaf（task/loaded/categoryTapped/categoryLongPressed/accountPickerDismissed/accountPicked/amountDigit/amountBackspace/amountConfirmed/confirmTapped/cancelTapped/draftSent）+ WatchCarrierFeature.Action 4 個（task/carriersUpdated/carrierTapped/barcodeDismissed）+ binding = 17，數字精確。已覆蓋 4 的算法：pagingLocksDuringEntry 送 record(.categoryTapped)、record(.cancelTapped)（2 條 record leaf）+ tabSelectionBinds 送 binding(.tab=.carrier)、binding(.tab=.record)（同屬 binding case 但兩次 set）= 4，是把 binding 兩次 set 各計一條的算法，屬合理近似（若以 distinct leaf case 計則為 3）。三條未覆蓋關鍵路徑列表與我獨立 grep 結果一致：confirmTapped→draftSent 在 App 層未測（child 層有）、carrier 四 leaf 在 App 層 0 覆蓋、tab==.carrier 組合無測。覆蓋率敘述準確，無誇大。WatchAppFeature 本身無殘留 property 或死 action——三個 State property（tab/record/carrier）與 isPagingLocked 全部被 View 讀取，reducer 為純組合，無 SSOT 違規。

---

## WatchCarrier

**健康度摘要**：這組整體健康度良好。維度一（無用 property / 死 action）零問題：兩個 property（carriers、presentedCarrier）與四個 action（task、carriersUpdated、carrierTapped、barcodeDismissed）都被 reducer/View/parent scope/測試消費，全域 grep 無殘留。維度二有一條中度 SSOT 問題：presentedCarrier 整包複製了 carriers 裡已有的 entity，並用 carriersUpdated 內的手動 re-resolve 膠水（lines 63-67）維持同步，改存 id + computed property 可結構性消除 desync。維度三覆蓋率紮實：4/4 action 都在測試中被觸發，carriersUpdated 三條分支（rename 重解析、刪除 dismiss、降級為 nil）皆有測；唯一未覆蓋路徑是 .task 內的 NotificationCenter re-load 長存 effect 迴圈，屬中度 gap。

**Action 覆蓋率**：4/4

**未覆蓋關鍵路徑**：
- WatchCarrierFeature.task 的 NotificationCenter.default.notifications(named: WatchCacheStore.didUpdateNotification) re-load 迴圈（WatchCarrierFeature.swift:54-58）— task 測試只斷言首次 .carriersUpdated，未驗證「快取更新通知抵達 → 再次發 .carriersUpdated」這條長存 effect 的實際 re-load 行為，等於 .task 相對於一次性載入的唯一額外職責沒被測到。

### 經交叉驗證確認的發現（confirmed）

- **[medium] ssot-violation** — presentedCarrier 整包存 Carrier 與 carriers 重複，靠 carriersUpdated 手動 re-resolve 膠水同步
  - 位置: `Features/Sources/WatchFeatures/Carrier/WatchCarrierFeature.swift:23`
  - 細節: State 同時持有 carriers: [Carrier]?（清單）與 presentedCarrier: Carrier?（同一筆 entity 的整包複本）。被展示的 Carrier 在 carriers 裡已經有一份，presentedCarrier 是它的第二份投影。為了避免 desync，reducer 在每次 carriersUpdated 都寫了同步膠水：lines 63-67 以 id 從新 carriers 重新解析 presentedCarrier（重新撈取 rename/barcode 編輯、被刪除時 dismiss）。這正是 prompt 點名的「entity 整包與其投影各存一份且靠手動同步」「已有同步膠水代碼的重複」。它不是 @Presents/StackState 暫態（是純 stored Carrier?），也不是單一寫入點快取——presentedCarrier 有三個寫入點：carrierTapped(line 71)、barcodeDismissed(line 75)、carriersUpdated re-resolve(line 66)。若改存 presentedCarrierID: Carrier.ID?，被展示的 Carrier 改為 computed property（carriers?.first { $0.id == presentedCarrierID }），lines 63-67 整段 re-resolve 膠水即可刪除，rename/刪除自動跟著 carriers 走，結構上不可能 desync。View(line 32)與測試也只需據 id 取回 entity。
  - 建議修法: 把 presentedCarrier 改為 presentedCarrierID: Carrier.ID?，被展示的 Carrier 以 computed property 從 carriers 推導，刪除 carriersUpdated 內 lines 63-67 的 re-resolve 同步膠水（測試 updateReresolvesPresented / updateDismissesDeletedPresented 同步改為斷言推導結果）。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[low] test-gap** — carriersUpdated 的 presented==nil 分支（純清單刷新不觸碰 presentedCarrier）零測試，且 re-resolve 後仍呈現舊 barcode 的場景未驗
  - 位置: `NeuLedgerWatchTests/WatchCarrierFeatureTests.swift:95`
  - 細節: carriersUpdated 的 re-resolve 膠水（WatchCarrierFeature.swift:63-67）有兩條路徑：presented!=nil（重撈/dismiss）與 presented==nil（跳過 if，僅更新 carriers）。測試只覆蓋前者：updateReresolvesPresented(:59) 驗 rename、updateDismissesDeletedPresented(:79) 驗刪除。後者唯一接近的 updateToNilClearsList(:96) 起始 presentedCarrier 為預設 nil 而非「有清單但無 presented」，等於沒有專門斷言「2+ 清單存在、無人被展示時收到更新只動 carriers 不動 presentedCarrier」。雖屬低風險（行為單純），但這是 reducer 一條分支岔路，與原審查員列的 .task 迴圈 gap 不同、未被點到。
  - 建議修法: 新增一個 @Test：初始 carriers=[phone,cert]、presentedCarrier=nil，send(.carriersUpdated([renamed,cert])) 只斷言 $0.carriers 變更、presentedCarrier 維持 nil。

### 覆蓋率抽查結論

同意原審查員的覆蓋率統計。自己數一遍 action case：WatchCarrierFeature.swift:35-38 共 4 個（task / carriersUpdated / carrierTapped / barcodeDismissed），全部被測試走到——task→taskLoadsCarriers(:27)、carriersUpdated→三個 update* 測試、carrierTapped 與 barcodeDismissed→tapPresentsBarcode(:43, :50/:53)，4/4 正確。原審查員點名的未覆蓋關鍵路徑也成立且精準：taskLoadsCarriers(:35-39) 在收到首次 .carriersUpdated 後立即 task.cancel()，從未 post WatchCacheStore.didUpdateNotification，因此 :54-58 那條長存通知訂閱 re-load 迴圈（.task 相對於一次性載入的唯一額外職責）確實零驗證。我另查 WatchCarrierClientTests.swift 全部 5 個測試只覆蓋 client.carriers() 投影（含 nil/legacy/order/empty），沒有任何測試 post 該通知，故此 gap 在整個 watch 測試集內無他處補回，原審查員結論正確。設計系統 gateway 抽查全綠：碰到的 font/color token（size9/size10Monospaced/size12Monospaced/size20Monospaced/size22SemiboldRounded、barcodeSurface/barcodeInk/accentOrange/textSecondary）皆已在 Font+extension.swift / Color+extension.swift 定義，無越界 .system/Color(hex:) 呼叫；localization key（watch_carrier_title/empty_hint/syncing_hint）均存在於 Localizable.xcstrings。無殘留 property、無死 action。

---

## WatchRecord

**健康度摘要**：WatchRecord 畫面組在 state/action 整潔度上很健康：6 個 stored property（categories/accounts/defaultAccountId/draft/step/accountPickerForCategoryId）全數被 View 或 reducer 消費，3 個 computed property（activeCategory/activeAccountId/activeAccount）皆有 ConfirmView 或 reducer 使用，12 個 action 全部都有 View 端送出點或 effect 回傳，父層 WatchAppFeature 僅 Scope 不攔截，無死碼。SSOT 也乾淨——step 與 draft 是一組真正獨立的狀態機（.amount 與 .confirm 無法只靠 draft!=nil 推導），accountPickerForCategoryId 屬導航暫態，無重複投影或同步膠水。主要問題集中在測試覆蓋：12 個 action 覆蓋 10 個，缺 amountConfirmed（核心轉場含 amount>0 guard）與 accountPickerDismissed，另 confirmTapped 的無帳戶失敗路徑與金額上限夾擠的斷言皆為弱覆蓋。

**Action 覆蓋率**：10/12

**未覆蓋關鍵路徑**：
- amountConfirmed：amount > 0 才推進到 .confirm 的分支條件完全沒測——amount == 0 時應 return .none（停在 keypad），amount > 0 時應 step = .confirm，兩條都未覆蓋
- confirmTapped 的失敗 guard 路徑：當 activeAccountId 為 nil（無 override 且 defaultAccountId 為 nil）時應 return .none、不送交易，現有測試只覆蓋成功路徑
- accountPickerDismissed：sheet 關閉清空 accountPickerForCategoryId 的路徑沒測（WatchRootView 的 sheet binding set 會送此 action）
- amountDigit 的金額上限 clamp：cap 測試用 exhaustivity = .off 且只斷言 <= 9_999_999（因 min() 而恆真），未驗證打滿位數後實際等於 9_999_999 的邊界夾擠行為
- task 的 NotificationCenter 重載迴圈：WatchCacheStore.didUpdateNotification 觸發第二次 load() 的 self-heal 行為沒測

### 經交叉驗證確認的發現（confirmed）

- **[high] test-gap** — amountConfirmed action 完全無測試覆蓋，amount>0 推進與 amount==0 攔截兩條分支皆未驗證
  - 位置: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`
  - 細節: WatchRecordFeature.swift:166-169 的 .amountConfirmed 含關鍵 guard：`guard state.draft?.amount ?? 0 > 0 else { return .none }`，通過才 `state.step = .confirm`。全域 grep `amountConfirmed` 在 NeuLedgerWatchTests / NeuLedgerTests 皆零命中（只有 View 端 AmountKeypadView.swift:55 送出）。從 .amount 進到 .confirm 是整個記帳流程的核心轉場，但測試完全跳過——現有測試是直接用 initialState step: .confirm 偽造狀態（confirmingSendsAndResets、cancelClearsDraft），等於繞過了這個 action。amount==0 時不該推進的防呆也沒測。
  - 建議修法: 新增測試：draft.amount=0 送 .amountConfirmed 斷言 step 不變；draft.amount>0 送 .amountConfirmed 斷言 step 變 .confirm。

- **[medium] test-gap** — confirmTapped 的 activeAccountId == nil 失敗 guard 路徑未測，可能靜默吞掉使用者送出
  - 位置: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`
  - 細節: WatchRecordFeature.swift:171-186 的 .confirmTapped 有雙重 guard：`guard let draft = state.draft, let accountId = state.activeAccountId else { return .none }`。activeAccountId 為 `draft?.accountIdOverride ?? defaultAccountId`（line 63-65），當無 override 且 defaultAccountId 為 nil（冷啟動 / 無帳戶）時會走 return .none，使用者按確認卻什麼都沒發生、也不送 .draftSent。測試 confirmingSendsAndResets（line 84-122）只覆蓋 defaultAccountId 有值的成功路徑，失敗分支零覆蓋。這是「按了確認沒反應」的潛在無聲失敗。
  - 建議修法: 新增測試：state 無 override 且 defaultAccountId=nil 時送 .confirmTapped，斷言不 receive .draftSent 且 record 未被呼叫。

- **[low] test-gap** — accountPickerDismissed action 未測，sheet 關閉清空 accountPickerForCategoryId 的路徑無守護
  - 位置: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`
  - 細節: WatchRecordFeature.swift:141-143 的 .accountPickerDismissed 將 `state.accountPickerForCategoryId = nil`，由 WatchRootView.swift:32 的 sheet binding set 在使用者下滑關閉 picker 時送出。全域 grep `accountPickerDismissed` 在所有測試目錄零命中。雖屬導航回收，但它與 longPressAccountOverride 測試（line 124-147，只測 set 與 picked，未測 dismiss）共用同一 navigation 狀態欄位；長按開啟後「不選帳戶直接關閉」應回到 category 而非殘留 picker 狀態，此回收路徑無迴歸守護。
  - 建議修法: 在 longPressAccountOverride 測試後追加：送 .accountPickerDismissed 斷言 accountPickerForCategoryId 歸 nil 且 draft 仍為 nil。

- **[medium] test-gap** — amount 上限 clamp 的 cap 測試斷言恆真（min() 數學保證），未驗證邊界實際夾擠到 9_999_999
  - 位置: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`
  - 細節: amountAppendsAndCaps 測試（line 149-183）在 line 174 設 `store.exhaustivity = .off` 後連送 6 個 0，最後 line 182 只斷言 `(store.state.draft?.amount ?? 0) <= 9_999_999`。由於 reducer line 155 是 `draft.amount = min(candidate, Self.amountCap)`，此斷言在數學上恆為真——即使 cap 邏輯壞掉（例如 cap 設成更大值或被移除），只要不溢位這條斷言仍會綠燈，等於沒驗到 clamp。應斷言打滿後精確等於 9_999_999 才能證明夾擠生效。
  - 建議修法: 把 line 182 改為斷言 `store.state.draft?.amount == 9_999_999`（或精確值），證明 clamp 真的觸發。

### Reviewer 補漏（單方發現，未經第三方驗證）

- **[medium] test-gap** — .task 的 NotificationCenter self-heal 重載迴圈未測（冷啟動空畫面在 WatchCacheStore.didUpdateNotification 到達後 re-load 的核心自癒行為無迴歸守護）
  - 位置: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`
  - 細節: WatchRecordFeature.swift:116-123 在首次 load() 後 `for await _ in NotificationCenter.default.notifications(named: WatchCacheStore.didUpdateNotification)` 迴圈再次 load()，這是註解明寫的『empty cold-start screen self-heals once the first WC context arrives』關鍵行為。loadingPopulatesState 測試（test:39-61）只斷言第一次 .loaded 後即 task.cancel()，從未 post WatchCacheStore.didUpdateNotification 驗證第二次 .loaded。WatchCacheStore.swift:40 確實會 post 此通知（save 時），但 reducer 端對通知的反應零覆蓋。此項原審查員在覆蓋率清單第 5 點口頭提及卻未開成正式 finding。
  - 建議修法: 新增測試：送 .task 並 receive 首次 .loaded 後，post WatchCacheStore.didUpdateNotification，斷言 reducer 再次 receive(.loaded) 並更新 categories/accounts，最後 cancel task。

- **[low] test-gap** — amountBackspace 從個位數退到 0 的歸零分支未測（只測 48→48，未測 amount 個位數整除後落到 0 與 disabled 條件邊界）
  - 位置: `NeuLedgerWatchTests/WatchRecordFeatureTests.swift`
  - 細節: WatchRecordFeature.swift:159-164 的 .amountBackspace 用 `(draft.amount as NSDecimalNumber).intValue / 10` 整數除法截尾。唯一測試 amountAppendsAndCaps:169 只驗 480→48（兩位以上）。當 amount 為個位數（如 4）退格時 4/10=0，draft.amount 應歸 0——此歸零路徑會讓 AmountKeypadView 的 confirm/backspace 鍵 disabled（View:91-97 amount<=0），是 UI 可用性的邊界，但 reducer 端從未驗 amount 退到 0。屬低度補強，原審查員未列。
  - 建議修法: 在 amountAppendsAndCaps 末段補一步：amount=4 時送 .amountBackspace，斷言 draft.amount == 0。

### 覆蓋率抽查結論

同意原審查員的 12 個 action case 統計，我逐一數過 enum Action（WatchRecordFeature.swift:73-89）：task、loaded、categoryTapped、categoryLongPressed、accountPickerDismissed、accountPicked、amountDigit、amountBackspace、amountConfirmed、confirmTapped、cancelTapped、draftSent，正好 12 個。以 action-name 維度抽查兩個測試檔的 send/receive，實際被觸及的 distinct action 為：task、loaded、categoryTapped、categoryLongPressed、accountPicked、amountDigit、amountBackspace、confirmTapped、cancelTapped、draftSent = 10 個；未觸及恰為 amountConfirmed、accountPickerDismissed = 2 個，與『10/12』吻合。但需補一點精度修正：confirmTapped 雖被計入『已覆蓋』，其失敗 guard 分支（F2）實未測；amountDigit 雖覆蓋但 cap 斷言恆真（F4）等於 clamp 邊界未真正驗到。換言之 action-name 覆蓋 10/12 正確，但『路徑/分支覆蓋』實質低於此數字。原審查員覆蓋率清單列的 5 條未覆蓋關鍵路徑全部我獨立重現屬實，且其中第 5 條（task self-heal 重載迴圈）我已升格為正式 missedFinding（原文僅在清單口頭帶過、未進 JSON findings）。整體統計合理，無虛報。

---

