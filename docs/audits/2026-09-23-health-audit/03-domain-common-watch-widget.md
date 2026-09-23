# NeuLedger 邊緣模組體檢報告

範圍：Domain / Common / WatchFeatures（SPM target）＋ xcodeproj 內 `Shared/`、`NeuLedgerWidget/`、`NeuLedgerWatchComplication/`、`NeuLedger/`（app 進入點）＋ 三份 `Localizable.xcstrings`。

方法說明：本次審查為**親自逐檔讀碼**（未派 subagent，依 team lead 指示）。所有引用均已實際開檔確認，行號可能因後續改動而漂移，但內容於審查當下（2026-09-23）皆為第一手驗證。`xcodebuild`／`git`／`python3` 在本環境因 Xcode license 未同意而全數無法執行，改以 `grep`/`rg`/`ast-grep` 靜態核對。

---

## A. 潛在 bug（依嚴重度排序）

### A1. Watch 記帳送出失敗時完全無感知，UI 一律顯示成功 — 嚴重度 High
- 位置：
  - `Features/Sources/WatchFeatures/Record/WatchRecordFeature.swift:183-186`（`confirmTapped`：`try? await ledgerClient.record(transaction)` 後不論成敗都送出 `.draftSent`）
  - `Features/Sources/WatchFeatures/Clients/WatchLedgerClient.swift:66-77`（`watchLive.record` 本身完全不 `throw`）
  - `Features/Sources/WatchFeatures/Connectivity/WatchSessionGateway.swift:27-33`（`send(draft:)` 是 `guard let data = try? JSONEncoder().encode(draft) else { return }` 與 `guard WCSession.isSupported() else { return }`，編碼失敗或 WCSession 不可用時直接靜默 return，呼叫端拿不到任何錯誤）
- 觸發：`WCSession.isSupported()` 為 false（極少見但非不可能，例如某些測試/模擬情境）、或 session 尚未 `activate()` 時使用者在錶上按下「確認」。
- 結果：`WatchRecordFeature` 立刻清空 draft、跳回分類頁，使用者以為已記帳，但該筆交易從未離開手錶，也沒有任何重試或錯誤提示機制。`TransactionDraft.id` 的 dedup 機制（`ProcessedDraftIdsStore.swift:22-38`＋`WatchSessionDelegate.swift:46-47`）確實有正確串接，但那只保護「WatchConnectivity 重複派送同一筆」，不解決「這次送出根本沒發生」的情境。
- 修法：`WatchLedgerClient.record` 改為在 encode/session 不可用時真的 `throw`；`WatchRecordFeature.confirmTapped` 依失敗結果保留 draft 並顯示錯誤（沿用「有隱性依賴的送出動作要能重試」的既有規則）。— 工作量 M

### A2. `NeuLedgerWatchComplication` 完全沒有走本地化，恆顯示繁體中文 — 嚴重度 Medium
- 位置：`NeuLedgerWatchComplication/NeuLedgerWatchComplication.swift:62,77,80,87,90,93,101,120,121`
- 觸發：任何情況下（包含系統語言設為英文）顯示手錶複雜功能（Complication）。
- 結果：`Text("今日")`、`Text("月")`、`Text("今日支出")`、`Text("\(entry.todayCount) 筆交易")`、`.configurationDisplayName("今日支出")`、`.description("顯示今日累計支出與本月預算進度。")` 等全部是硬編碼字串，未使用 `String(localized:)`／`LocalizedStringKey`，違反 CLAUDE.md「所有 user-facing 字串必須本地化」規則。`NeuLedgerWatchComplication/` 目錄下也**沒有**任何 `Localizable.xcstrings`（對照主 app／Widget／Watch app 三個都有）。同時 `Text("NT$ \(displayAmount)")`（line 90,101）又是一處新的「NT$ 硬切字串」重複點。
- 修法：新增 `NeuLedgerWatchComplication/Localizable.xcstrings`，把 9 處字串改走 `String(localized:)`。— 工作量 S

### A3. `CarrierManagementView` 條碼產生失敗時整段畫面消失、無任何 fallback — 嚴重度 Medium
- 位置：`Features/Sources/Features/CarrierManagement/CarrierManagementView.swift:241-254`（`if let barcodeImage = generateBarcode(from: carrier.barcode) { Image(...) }`，**沒有 else 分支**）；`generateBarcode`（同檔 289 行起）用 `string.data(using: .ascii)`，非 ASCII 字元會回傳 `nil`。
- 觸發：`carrier.barcode` 含任何非 ASCII 字元（例如誤貼中文、全形符號）時。
- 結果：整個條碼卡片區塊直接消失，使用者看到的是一段留白，沒有錯誤訊息也沒有原始文字可供手動輸入。對照 Watch 端的同等元件 `Features/Sources/WatchFeatures/Carrier/CarrierBarcodeView.swift:50-65` 有正確處理：`Code128.modules(for:)` 回傳 nil 時會 fallback 顯示可辨識的文字（"Encoder rejected the stored barcode... degrade to a code the clerk can key in by hand"）。iOS 主 App 端明顯少了這層保護。`NeuLedgerWidget/CarrierWidget.swift:171-182` 則有 `else { Text(carrier.barcode) }` 的正確 fallback，三套實作中唯獨 `CarrierManagementView` 沒做。
- 修法：比照 `CarrierWidget.swift` 補上 `else { Text(carrier.barcode) }` fallback。— 工作量 S

### A4. `String.parsedAmountDecimal` 對全形數字／帶 "NT$" 前綴字串解析失敗，回退為誤導性驗證錯誤 — 嚴重度 Low
- 位置：`Features/Sources/Common/Extensions/String+Parsing.swift:5-30`；唯一呼叫端 `Features/Sources/Features/Dashboard/AddTransactionFeature.swift:243-247`
- 觸發：使用者用中文輸入法打出全形數字（如「１２３」），或貼上含 "NT$" 前綴的金額字串。
- 結果：`NumberFormatter.number(from:)`（`.decimal` style）與 fallback 的 `Decimal(string:)` 都只認得 ASCII 數字，兩者都會回傳 `nil`；`parsedAmountDecimal ?? 0` 讓金額變成 `0`，`AddTransactionFeature.saveTapped`（line 244）判斷 `amountValue <= 0` 後顯示「金額為必填」的 inline 錯誤——**不會造成資料錯誤**（有攔住），但錯誤訊息會誤導使用者以為自己沒輸入，而非「輸入格式看不懂」。
- 修法：`parsedAmountDecimal` 內用 `String(format:)`/`applyingTransform(.fullwidthToHalfwidth, reverse: false)` 先正規化全形數字，並在 normalize 清單中加入 `"NT$"`/`"NT"` 前綴移除。— 工作量 S

---

## B. 架構 / 繞路 / 死碼（依價值排序）

### B1. `AnalysisFeature` 完全繞過 `InsightsClient`，在 Reducer 內自行重算分類佔比／每日趨勢／預算進度 — 價值 High
- 位置：`Features/Sources/Features/Analysis/AnalysisFeature.swift:115-221`（`.loadData` 直接 `ledger.listAll(filter)` 抓原始交易，手動 reduce 出 `categoryTotals`/`proportions`/`dailyTotals`/`trends`）與 `computeBudgetMetrics`（同檔 283 行起，直接呼叫 `planningClient.listActive()` + `ledger` 自算，不叫 `insightsClient.budgetGauges`）。
- 現況：`Domain/Clients/InsightsClient.swift` 已宣告 `categoryProportions`/`dailyBars`/`budgetGauges`，`Application/Insights/InsightsClient+Live.swift:125-148` 也已經把它們接到 `Core/Analytics/TransactionAnalyticsKernel.swift`（`dailyBars` line 172、`categoryProportions` line 200、`budgetGauges` line 240）——但整個 codebase 裡，`AnalysisFeature` 是唯一「應該用」這三個方法的畫面，卻完全不用；`insightsClient` 在這個 Reducer 裡只被拿來呼叫 `isAIAvailable()`/`generateAIInsight()`（line 184,195）。對照組：`DashboardFeature.swift:413,468,482` 有正確呼叫 `insightsClient.weeklySparkline`/`.generateInsights`/`.todayStats`，證明這個繞路是 Analysis 畫面獨有，不是全域慣例。
- 為什麼繞：合理推測是 Analysis 畫面開發時間早於／晚於 Client 整併，兩邊各自長出一份聚合邏輯後沒有回頭收斂。
- 影響：這正是已知問題「AnalysisFeature 分類佔比名稱用原始 seed 英文名」的根因——`categoryMap`（line 148-151）直接用 `$0.name`，沒有走 `Category.localizedName`；而且**同一個根因也影響 dailyTrends 與 budgetGauges**，不只是名稱顯示，兩份聚合邏輯（Kernel vs. Reducer 手算）未來只要 Kernel 修了帳戶篩選方向（已知問題：`weeklySpending`/`budgetGauges` 單向 vs. `Transaction.involves(account:)` 雙向）而 Analysis 畫面沒同步改，就會出現「同一頁三個統計卡對不上」的新 bug。
- 該怎麼做：把 `.loadData` 改成呼叫 `insightsClient.categoryProportions(range:)`/`.dailyBars(range:)`/`.budgetGauges(accountId:)`，刪掉 Reducer 內的手算聚合。— 工作量 M（現有 PR B/PR C 待辦剛好可以合併處理此項）

### B2. `Shared/WidgetAppGroup.swift` 舊版單一載具讀寫函式 + `WidgetSyncAdapter.syncCarrier`/`.clearCarrier` 全數是死碼 — 價值 Medium
- 位置：
  - `Shared/WidgetAppGroup.swift:31-69`（`readCarrier()`/`writeCarrier(...)`/`clearCarrier()`，皆標註「Legacy... kept for backward compat」）
  - `Features/Sources/Domain/Adapters/WidgetSyncAdapter.swift:14-18`（`syncCarrier`/`clearCarrier` 介面）
  - `Features/Sources/Core/Adapters/WidgetSyncAdapter+Live.swift:26-41`（對應 Live 實作）
- 確認方式：全 repo `grep -rn "WidgetAppGroup.readCarrier\|WidgetAppGroup.writeCarrier\|WidgetAppGroup.clearCarrier"` 與 `widgetSyncAdapter.syncCarrier\|.clearCarrier` 呼叫點皆為零。`Features/Sources/Application/Carrier/CarrierClient+Live.swift:27,32,37,42` 四個呼叫點全部走 `syncAllCarriers`（新版清單 API），完全沒人叫舊版單一載具 API。
- 該怎麼做：確認沒有其他外部依賴後，整批刪除 `WidgetAppGroup` 的 legacy 四個 key／三個函式，以及 `WidgetSyncAdapter.syncCarrier`/`.clearCarrier` 介面與 Live 實作。— 工作量 S

### B3. `Common/Components/GlassCard.swift` 零使用者，功能與 `GlassContainer`（27 個使用點）高度重疊 — 價值 Medium
- 位置：`Features/Sources/Common/Components/GlassCard.swift`（全檔，僅自身 `#Preview` 引用）vs. `Features/Sources/Common/Components/GlassContainer.swift`
- 確認方式：`grep -rn "\bGlassCard\b" Features/Sources/Features Features/Sources/WatchFeatures` 全 repo 零匹配（含 NeuLedgerWidget/NeuLedgerWatchComplication，因該二 target 未連結 Features package，見 B7）；`GlassContainer` 則有 27 個外部引用。
- 兩者都是「玻璃擬態容器＋可調圓角＋`.glassEffect(Glass.clear...tint(...))`」，差別只在 `GlassCard` 固定用 `VStack(spacing:16)+padding(20)+tint(.background)`，`GlassContainer` 可調 padding/isInteractive/tint(.surface)。屬於典型「新元件長出來取代舊元件，舊的忘記刪」。
- 該怎麼做：刪除 `GlassCard.swift`（若刻意保留給未來場景，至少加上至少一個真實呼叫點或標註 deprecated）。— 工作量 S

### B4. `Common/Components/AvatarBadge.swift`、`LedgerCutIcon.swift` 零使用者 — 價值 Low
- 位置：`Features/Sources/Common/Components/AvatarBadge.swift`、`Features/Sources/Common/Components/LedgerCutIcon.swift`
- 確認方式：同 B3 方法，全 repo（含 Widget/Complication/Watch app target）零外部引用，僅自身 `#Preview`。
- 該怎麼做：確認產品側無近期規劃後刪除，或補上呼叫點。— 工作量 S

### B5. 多處真實 UI 程式碼直接用 `Color.white`/`Color.black`/隱式 `.white`/`.black` 繞過 `Color.Design` gateway（非 `#Preview`） — 價值 Medium
- 位置（已逐一排除 `#Preview` 區塊，以下皆為正式畫面程式碼）：
  - `Features/Sources/Features/Analysis/AIAssistant/AIAssistantCardView.swift:199`（`message.role == .user ? Color.white : Color.Design.textPrimary`）
  - `Features/Sources/Features/Analysis/Sections/KPIStrip.swift:95`（`.shadow(color: Color.black.opacity(0.04), ...)`）
  - `Features/Sources/Common/Components/AppIconBadge.swift:40,42`（`Color.white.opacity(0.18)` stroke、`Color.black.opacity(0.18)` shadow）
  - `Features/Sources/Common/Components/LoadingView.swift:43-47`（`isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)`，同檔前兩行卻正確走 `Color.Design.*`，同一元件內不一致）
  - `Features/Sources/Common/Components/BudgetGauge.swift:88`（`.shadow(color: Color.black.opacity(0.05), ...)`）
  - `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift:250-251`（`.background(.white, in:...)` 與 `.shadow(color: .black.opacity(0.08), ...)`，隱式 member 語法，`ast-grep -p 'Color(red: $$$)'` 這類 pattern 抓不到，須用 `.white`/`.black` 純文字比對才找得到）
- 說明：`ast-grep --lang swift -p 'Color(hexLiteral: $$$)'` 與 `-p 'Color(red: $$$)'` 兩個 pattern 全 repo 只在 `Color+extension.swift` 本身出現（gateway 未被「建構式」層級繞過），但上面這些是「引用系統色 case」層級的繞路，CLAUDE.md 明文禁止（"No exceptions. Do not hardcode #000000 / #FFFFFF literals in views"），語意上等同違規。
- 該怎麼做：在 `Color.Design` 補一個 `shadowColor`/`overlayLight`/`overlayDark` 之類的 token，把上述 6 處改過去。— 工作量 S-M

### B6. `Currency.decimalPlaces` 只被自己的單元測試呼叫，生產程式碼從未讀取 — 價值 Low
- 位置：`Features/Sources/Domain/Enums/Currency.swift`（`decimalPlaces` 屬性）；唯一呼叫者 `NeuLedgerTests/Tests/DomainTests/Enums/CurrencyTests.swift:12`
- 說明：實際的 TWD 無小數位規則是在 `Features/Sources/Common/Extensions/Decimal+Currency.swift:9-10` 用 `formatter.maximumFractionDigits = 0`／`minimumFractionDigits = 0` 硬寫死的，完全沒有讀 `Currency.TWD.decimalPlaces`。等於這條 Domain API 存在的唯一理由是讓測試「看起來」在測試貨幣規則，但格式化程式碼跟它完全脫鉤——之後如果要支援第二種貨幣，改 `decimalPlaces` 不會讓任何實際格式化行為改變，容易造成誤解。
- 該怎麼做：讓 `Decimal+Currency.twdFormatted` 改讀 `Currency.TWD.decimalPlaces`，或如果確定永遠只有 TWD，直接刪掉這個屬性與其測試。— 工作量 S

### B7. Code128 三套獨立實作，根因是 `NeuLedgerWidget` target 完全沒有連結 Features SPM package — 價值 Medium（既有 backlog 項目，補充根因）
- 位置：
  - `Features/Sources/Common/Components/Code128.swift` + `Code128BarcodeView.swift`（純 Swift 編碼＋Canvas 畫圖）——唯一呼叫者是 `Features/Sources/WatchFeatures/Carrier/CarrierBarcodeView.swift:32-34`
  - `Features/Sources/Features/CarrierManagement/CarrierManagementView.swift:289-`（自己的 `generateBarcode(from:)`，用 `CIFilter.code128BarcodeGenerator()`）
  - `NeuLedgerWidget/CarrierWidget.swift:72-87`（幾乎一模一樣的 `CIFilter` 版 `generateBarcode(from:)`，明顯是複製貼上）
- 根因（新發現）：`NeuLedger.xcodeproj/project.pbxproj` 中 `NeuLedgerWidget` target 的 `packageProductDependencies = ()` 是**空的**——Widget extension 完全沒有連結 `Features`/`Core`/`Domain`/`Common` 任何一個 package product，因此 `NeuLedgerWidget/CarrierWidget.swift` 物理上就是**無法** `import Common` 去重用 `Code128.swift`，也無法 `import Domain` 用 `Carrier`/`CarrierType`（這也是為什麼 `Shared/WidgetAppGroup.swift` 要自己定義一份 `CarrierEntry` DTO 而不是重用 `Domain.Carrier`——同一個 target 邊界限制）。
- 該怎麼做：既有 backlog 若要真正合併三套實作，正確做法不是「讓 Widget import Common」（會連帶拉進整包 Domain/TCA 依賴，extension 體積/啟動時間有代價），而是把 `Code128.swift`（零外部依賴的純 Swift 檔）移進 `Shared/` 目錄，透過 Xcode 的 file-system-synchronized group 機制讓三個 target（`NeuLedger`／`NeuLedgerWidget`／`WatchFeatures` 若比照）都能編譯到同一份原始碼，而非透過 package 連結。— 工作量 M

### B8. `NeuLedger/NeuLedgerApp.swift` 說明註解指向不存在的檔案路徑 — 價值 Low
- 位置：`NeuLedger/NeuLedgerApp.swift:17-18`（"要尋找 App 進入點，請前往：`Features/Sources/Features/RootView.swift`"）
- 現況：該檔案不存在；實際 `@main` 定義在 `Features/Sources/Features/AppView.swift:14-15`。
- 該怎麼做：更新註解路徑。— 工作量 S

### B9. `Account.ID` 是 `String`，其餘 entity（`Transaction`/`Category`/`Tag`/`Budget`/`Carrier`/`RecurringTransaction`）id 皆為 `UUID` — 價值 Low-Medium
- 位置：`Features/Sources/Domain/Entities/Account.swift:24`（`public let id: String`，預設 `UUID().uuidString`）vs. 其餘 entity 一律 `public let id: UUID`
- 說明：搜尋全 repo 沒找到任何「把 `Account.ID` 當 `UUID` 字串轉換」的地方（`grep "Account.ID" | grep "UUID("` 零匹配），目前**未觀察到實際 crash 或資料錯誤案例**，屬於一致性建議而非已發現的 bug。潛在風險是未來任何新寫的程式碼如果「順手」對 `Account.ID` 做 `UUID(uuidString:)` 轉換就會在執行期靜默失敗（回傳 `nil`）。
- 該怎麼做：若無歷史包袱（如已上線帳戶 ID 都已是 UUID 字串格式），可評估統一成 `UUID`；否則至少在 `Account.swift` 補一句文件註解說明「刻意採用 String，因為 Watch App Group / Widget DTO 需要跨 target 的簡單可序列化 key，不要嘗試轉 UUID」。— 工作量 L（若要真的改型別，牽動所有讀寫路徑）／S（若只是補文件）

### B10. `@DependencyClient` 預設值裡藏著「看似合理」的假成功值，測試忘記覆寫會靜默通過 — 價值 Medium
- 位置（5 個代表性案例，逐一讀碼確認）：
  - `Features/Sources/Domain/Clients/LedgerClient.swift:28-30`：`listRecent`/`listAll`/`search` 預設 `{ _ in [] }`——這三個是最多 Feature 依賴的讀取方法，忘記在 `TestStore` 覆寫時，Reducer 會拿到「空列表」而非觸發 unimplemented 警告，測試容易在「假裝測了有資料的情境」時其實一直在測空清單。
  - `Features/Sources/Domain/Clients/CaptureClient.swift:34`：`isAvailable = { false }`
  - `Features/Sources/Domain/Clients/InsightsClient.swift:63`：`isAIAvailable = { false }`
  - `Features/Sources/Domain/Clients/PlanningClient.swift:50`：`warningEnabled = { false }`
  - `Features/Sources/Domain/Clients/PlatformClient.swift:38`：`hasCompletedOnboarding = { false }`
- 說明：這是 `docs/architecture.md` §10 已經寫下的規則本身指出的陷阱類型（"`@DependencyClient` 預設值是 production fallback，`testValue` 保持 unimplemented"），但目前這些屬性因為有手寫 `= { ... }` 預設值，等於**繞過**了 `@DependencyClient` macro 原本「沒覆寫就 fail」的保護——這不是新規則違反，而是把規則書裡描述的抽象風險，實際列出目前 codebase 裡命中這個陷阱形狀最明顯的具體位置，供之後寫測試時特別注意。
- 該怎麼做：非必要不需要全部拿掉（有些是合理的「安全預設」），但至少在測試撰寫指引裡標注這 5+ 個屬性是「容易忘記覆寫又不會報錯」的高風險項。— 工作量 S（文件化）

---

## C. 已知問題確認（一行一項，僅列本次實際重新讀碼驗證過的項目）

- `TransactionAnalyticsKernel.weeklySpending`（`Core/Analytics/TransactionAnalyticsKernel.swift:41`）與 `budgetGauges`（同檔 254 行）帳戶篩選仍是單向 `tx.accountId == id`，`detailStats`（同檔 103 行）仍用 `cal.dateInterval(of: .month, for:)` 硬寫月——**仍存在**。
- `WatchSessionDelegate`（`Core/Adapters/Watch/WatchSessionDelegate.swift:31-33`）入站記帳仍直寫 `TransactionStore().add(transaction)`，繞過 `ledgerClient.record` 的 invariant——**仍存在**（懸而未決的產品決策，未變動）。
- `Core/Adapters/Watch/WatchMidnightTimer` 仍是死碼——全 repo `grep "WatchMidnightTimer("` 零建構呼叫，**仍存在**。
- Domain 的 `#if canImport(FoundationModels)`（`CaptureClient.swift:1`、`AIAdapter.swift:1`、`CategorySuggestions.swift:1`、`ExtractedTransaction.swift:1`）四處皆未加 `&& !os(watchOS)`——**仍存在**。
- `AnalysisFeature` 分類佔比名稱用原始 seed 英文名（`categoryMap` 直接用 `$0.name`，未走 `Category.localizedName`，`Features/Sources/Features/Analysis/AnalysisFeature.swift:148-151,159`）——**仍存在**；本次審查發現根因是整個方法都繞過 `InsightsClient`（見 B1），影響範圍比「僅分類名稱」更大。
- 跨領域聚合 backlog「Code128 三套渲染」——**仍存在**，本次補充根因（B7：Widget target 無 package 依賴）。
- 跨領域聚合 backlog「`parsedAmountDecimal` 只有 `AddTransaction` 一處使用」——**仍存在**（`grep` 全 repo 確認唯一呼叫點是 `AddTransactionFeature.swift:243`）。
- 跨領域聚合 backlog「`"NT$"` 切字串重複」——本次額外發現新增例：`Decimal+Currency.swift:8`（`currencySymbol = "NT$"`）與 `NeuLedgerWatchComplication.swift:90,101`（`Text("NT$ \(displayAmount)")`），連同已知的 3 處，實際數量比 backlog 估計的多。

---

## D. 檢查過但沒問題的面向

- `TransactionFilter`（`Domain/Entities/TransactionFilter.swift`）文件註解與 `TransactionFilter+Matching.matches(_:)`（`TransactionFilter+Matching.swift:7-28`）實作語意完全一致：`nil` 不篩、各維度 AND、`accountIds` 雙向比對、`searchText` 空字串不篩，皆有對應程式碼佐證，沒有文件與實作不符的情況。
- `Budget.evaluate`（`Domain/Entities/Budget.swift:66-80`）與 `Budget+Spending.swift` 內所有方法純函數、無 `Date()`/`Calendar.current` 隱性依賴；全 Domain target 搜尋 `Calendar.current` 零匹配，`Date()` 只出現在 entity `init` 的預設參數值（如 `createdAt: Date = Date()`），皆可由呼叫端覆寫，不影響可測試性。
- `RecurringTransaction.nextDate(after:calendar:)`（`Domain/Entities/RecurringTransaction.swift:33-35`）雖有 `calendar: Calendar = .current` 預設參數，但為可覆寫的顯式參數，非隱藏依賴。
- `WatchContextSnapshot`/`TransactionDraft`/`Carrier`/`Transaction` 的 `Codable` 相容性：`WatchContextSnapshot.carriers`（`WatchContextSnapshot.swift:42`）已正確設計成 `[Carrier]?`（optional，合成 `Decodable` 會自動用 `decodeIfPresent`），文件註解明確說明「Optional so legacy cached JSON keeps decoding」，是正確的向後相容範例；其餘欄位皆非 optional 但目前沒有發現「新增非 optional 欄位破壞舊資料」的實例。
- `WatchCacheStore`（`Persistence/WatchCacheStore.swift`）與 `WatchSessionGateway`（`Connectivity/WatchSessionGateway.swift`）的 `NSLock` 使用正確：讀寫皆在鎖保護內，`save()` 特別把 `NotificationCenter.post` 移到 `unlock()` 之後才呼叫（避免在鎖內重入），沒有發現遺漏鎖保護的路徑。
- `WatchRecordFeature.task` / `WatchCarrierFeature.task` 的 `for await ... in NotificationCenter.default.notifications(named:)` 長駐迴圈都透過標準 TCA `.task { await store.send(.task).finish() }` 綁定（`WatchRootView.swift:27`、`WatchCarrierView.swift:37`），生命週期跟隨 View 消失自動取消，沒有發現迴圈洩漏。
- `TransactionDraft.id` 的 dedup 設計確實有被 iPhone 端使用（`ProcessedDraftIdsStore.contains`/`.mark` 在 `WatchSessionDelegate.parse` 中被正確呼叫），並非空頭文件——但 Watch 端目前沒有任何「重送同一個 id」的重試路徑會用到這個保護（見 A1）。
- Complication timeline 更新時機：`WatchSessionGateway.handleContext`（`WatchSessionGateway.swift:35-40`）在每次收到新 snapshot 時明確呼叫 `WidgetCenter.shared.reloadAllTimelines()`，`TodayExpenseProvider` 本身 `policy: .never`（`NeuLedgerWatchComplication.swift:23`），設計上依賴這個 explicit reload，機制完整、未發現「記帳後 Complication 沒更新」的漏洞。
- App 進入點啟動順序：`CrashReportingBootstrap.start()`（`Core/Adapters/CrashReporting/CrashReportingBootstrap.swift:28-30`）與 `WatchBootstrap.start()`（`Core/Adapters/Watch/WatchBootstrap.swift:22-24`）皆有 `guard !started else { return }` 保護，重複呼叫是 no-op；`PersistenceBootstrap.container`（`Core/Persistence/PersistenceBootstrap.swift:74-92`）是 `static var` 搭配閉包初始化，Swift runtime 保證第一次被任何路徑觸碰時才執行且只執行一次（含 `seedIfNeeded`），因此不管是 UI 啟動流程還是 Watch 背景送達的入站交易先觸發 SwiftData，seeding 都會在第一次資料寫入前完成，沒有發現「Watch 資料比 seeding 先到」的競態。
- `NeuLedgerWidget/Localizable.xcstrings` 涵蓋該 target 用到的全部 17 個 key（`widget_carrier_*` ×8、`widget_voice_*` ×3、`carrier_entity_type_name`、`carrier_intent_*` ×3、`carrier_type_*` ×2），逐一 grep 確認皆存在。
- `VoiceWidget`（`NeuLedgerWidget/VoiceWidget.swift`）確認**未**被註冊進 `NeuLedgerWidgetBundle`（`NeuLedgerWidgetBundle.swift:10` 明確註解掉），與既有記憶「VoiceWidget Phase 2 待辦」狀態一致；唯一補充：其內部 `accountName: "現金帳戶"`（`VoiceWidget.swift:16,20,24`）是硬編碼中文，若未來啟用需一併補本地化。
- `CarrierWidget`（`NeuLedgerWidget/CarrierWidget.swift`）placeholder/redaction 邏輯正確：`isPlaceholder` 判斷 `redactionReasons.contains(.placeholder)` 後改顯示中性灰色方塊而非真實條碼（line 165-170）；因該 widget 只 `supportedFamilies([.systemMedium])`（非鎖定畫面 family），無鎖屏隱私外洩疑慮。
- `NeuLedgerWidget` target 的 `packageProductDependencies` 為空（確認於 `project.pbxproj`），代表 Widget extension 完全未連結 Features SPM package，是 Code128/CarrierEntry 各自為政（B7）的根本原因，非隨意繞路。

---

## E. 本地化 key 缺漏清單

**本次窮舉結果：三個 target 均無缺漏 key。**

- `NeuLedgerWidget` target：程式碼中用到的 17 個 key（`widget_carrier_deleted_body`、`widget_carrier_placeholder_name`、`widget_carrier_deleted_cta`、`widget_carrier_description`、`widget_carrier_display_name`、`widget_carrier_empty_cta`、`widget_carrier_empty`、`widget_carrier_stale_warning`、`widget_voice_description`、`widget_voice_display_name`、`widget_voice_title`、`carrier_entity_type_name`、`carrier_intent_title`、`carrier_intent_description`、`carrier_intent_parameter_title`、`carrier_type_phone_barcode`、`carrier_type_citizen_cert`）在 `NeuLedgerWidget/Localizable.xcstrings` 中全數存在。
- `NeuLedgerWatch Watch App` target：`Features/Sources/WatchFeatures/` 內用到的全部 7 個 key（`watch_cancel_button`、`watch_carrier_empty_hint`、`watch_carrier_syncing_hint`、`watch_carrier_title`、`watch_category_empty_hint`、`watch_confirm_button`、`watch_record_title`）在 `"NeuLedgerWatch Watch App/Localizable.xcstrings"` 中全數存在，且抽查 `en`/`zh-Hant` 兩語言的 `stringUnit.state` 皆為 `translated`（非空翻譯）。這是 team lead 原始任務標記的重點項目，**結果乾淨，沒有找到缺漏**。
- 主 app（`NeuLedger/Resources/Localizable.xcstrings`）：交叉確認 `carrier_type_phone_barcode`/`carrier_type_citizen_cert`（因 `Shared/WidgetAppGroup.swift` 也編進 `NeuLedger` 主 app target，見 B7 說明）同樣存在，未做窮舉（team lead 指示僅需交叉確認格式）。
- 例外說明：`NeuLedgerWatchComplication/` target **完全沒有** `Localizable.xcstrings` 檔案，也沒有任何 `String(localized:)` 呼叫——這不是「有 catalog 但缺 key」的情況，而是整個 target 從未嘗試本地化，已列在 **A2** 作為獨立發現，不計入本節的 key 缺漏清單。
