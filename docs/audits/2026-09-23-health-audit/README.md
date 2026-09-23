# 2026-09-23 全面體檢：潛在 bug 與架構繞路（彙整）

三個唯讀 reviewer 平行掃 Features / Application+Core / Domain+Common+Watch+Widget，排除稽核前已知的 15 條（`00-known-issues-before-audit.md`）。以下是彙整後的優先序；每條在對應報告有 file:line、觸發情境與修法。標「✔ 已驗」表示 controller 親自讀碼確認過。

## Tier 1 — 上線前必修（資料遺失 / 卡死 / 誤導）

| # | 問題 | 來源 | 工作量 |
|---|---|---|---|
| 1 | 週期交易永遠不會自動入帳：`ledgerClient.tick()` production 零呼叫；到期提醒是一次性通知，滑掉就永久停擺，管理頁仍顯示「啟用中」 ✔ | Core A2 / B5 | M |
| 2 | 刪除交易後 5 秒內滑掉 sheet，Undo 計時器隨 child effect 被取消，`ledger.delete` 從未執行 ✔ | Features A2 | S–M |
| 3 | 記帳儲存失敗完全靜默（`AddTransactionFeature.saveTapped` 無 catch）→ 使用者重按造成重複記帳 ✔ | Features A1 | S |
| 4 | Onboarding `setupAccounts` 失敗永久卡在最後一頁、無重試 ✔ | Features A3 | S |
| 5 | `AppFeature` 讀 onboarding 狀態失敗永久卡 splash ✔ | Features A4 | S |
| 6 | 全 Features 共 28 處 `.run` 無 catch，12 處在寫入主路徑（交易列表六條、三張 AddEdit、四個管理清單） | Features A6 / A10 | M（一起補） |
| 7 | Dashboard 的 InsightCarousel 顯示三筆寫死的假數字（「本週省下 NT$ 3,200」「餐飲 NT$ 8,400」「儲蓄率達標」）✔ | Core B9 | S（先隱藏） |
| 8 | 多裝置 CloudKit 同步後重複的預設分類讓 `Dictionary(uniqueKeysWithValues:)` 直接 trap（5 處），Dashboard 一開就 crash ✔ | Core A4 | S（`uniquingKeysWith`）+ M（seed 去重） |
| 9 | 「抹除所有資料」後預設分類永遠回不來：`seedIfNeeded` 只在 static 初始化跑一次 ✔ | Core A1 | S–M |
| 10 | 開 iCloud 同步 / 抹除後，`\.modelContainer` 被 swift-dependencies 快取仍指舊 container，寫入落到舊庫直到重啟 ✔ | Core A3 | M |

## Tier 2 — 真實 bug，可上線後修

| # | 問題 | 來源 | 工作量 |
|---|---|---|---|
| 11 | 刪分類不清引用：交易 / 預算留下孤兒 `categoryId`；刪 / 封存帳戶不清預設帳戶設定與週期範本 | Core A6 / A7 | M |
| 12 | 暫停週期交易（`isActive=false`）提醒沒取消反而重排 | Core A5 | S |
| 13 | 月底週期交易到期日逐月往前漂（31→28→28…，從當前到期日 +1 月） | Core A10 | S |
| 14 | Watch 入站草稿先標記去重再 `try?` 寫入，失敗即永久遺失 | Core A8 | S |
| 15 | 「Widget 顯示的載具」設定沒有傳到 Widget | Core A9 | S–M |
| 16 | 一開始搜尋，已套用的篩選條件整組失效 | Features A7 | S |
| 17 | Dashboard 與交易分頁互不同步（一邊改另一邊不刷新） | Features A8 | S–M |
| 18 | 關掉 AI 輸入列後遲到的擷取結果仍彈出新增頁 | Features A9 | S |
| 19 | 分析頁快速切換期間顯示錯誤資料、載入失敗無提示 | Features A11 | S |
| 20 | 手動 iCloud 同步失敗仍顯示「同步成功」 | Features A12 | S |
| 21 | 冷啟動期間收到的 deep link / 週期交易確認被丟棄 | Features A5 | M |
| 22 | Transactions 列不顯示分類（只有 note / 類型）；Analysis 分類名未本地化 | 已知 / PR B | S / PR B |
| 23 | `NeuLedgerWatchComplication` 整個 target 沒有本地化（9 處硬編中文） | Edges A2 | S |
| 24 | 載具條碼產生失敗整段畫面消失無 fallback | Edges A3 | S |
| 25 | Watch 記帳送出失敗（未配對 / 未啟用）UI 一律當成功 | Edges A1（`transferUserInfo` 會排隊，實務多為未配對情境，判 Med） | S |
| 26 | `setupAccounts` 讀取失敗被吞 → 重複插入帳戶 | Core A12 | S |

## Tier 3 — 架構繞路 / 重複 / 死碼（依價值）

| # | 問題 | 來源 | 建議 |
|---|---|---|---|
| 27 | `AnalysisFeature` 在 reducer 重算 Insights 已有的三個投影，那三個 endpoint 是死碼 | Features B1 / Edges B1 | PR B（計劃 Task 6-7） |
| 28 | 設定頁自刻 CSV 匯出，`ledger.exportCSV` 有實作與測試卻零呼叫；固定 temp 路徑違反 §9 | Features B2 / B3 | PR C Task 13 |
| 29 | `PlatformClient+Live` 同時踩三條分層規則（直碰 store / adapter 互呼 / 雜物袋） | Core B1 | M，拆回各 context |
| 30 | `WatchContextBuilder`（Infrastructure）反向依賴兩個 Client | Core B2 | M |
| 31 | `evaluateAfterTransaction` 每筆記帳全表掃描，參數沒用 | Core B6 | S–M |
| 32 | 每次 SwiftData save 都重建全量 Watch 快照，沒配 Watch 也做 | Core B7 | S |
| 33 | `InsightsClient+Live` 繞過 `aiAdapter` 自建 `LanguageModelSession`；用 `persistenceBootstrap` 當 `\.modelContainer` 後門 | Core B3 / B8 | S |
| 34 | `ledger.search` 是第二條查詢路徑，`TransactionFilter.searchText` 沒人用 | Features B5 | S |
| 35 | 時間 / 亂數依賴注入全層不一致（一半 reducer 用裸 `Date()`） | Features B7 | M |
| 36 | 九張表單錯誤處理各做各的 | Features B9 | M（與 #6 一起） |
| 37 | Widget 載具同步：legacy 單載具 API 全死碼 + DTO 重複；Code128 三套根因是 Widget 沒連 SPM package | Core B4 / Edges B2 / B7 | PR C Task 14 |
| 38 | 死碼：`WatchMidnightTimer`、`GlassCard`、`AvatarBadge`、`LedgerCutIcon`、`Currency.decimalPlaces`、`SDRecurringTransaction.tagIds`（寫入即丟）、`InsightsClient` 三 endpoint | 各報告 | S，刪 |
| 39 | `Color.white` / `.black` 繞過 gateway（非 Preview）；`Account.ID` 是 String 其餘 UUID；`@DependencyClient` 預設值藏假成功 | Edges B5 / B9 / B10 | S / L / S |
| 40 | `budgetGauges` N+1；`SettingsFeature.defaultAccountSelected` 身兼載入與選取；硬編中文三處 | Core B10 / Features B12 / B11 | S |

## 建議的 PR 切法

1. **穩定性 PR**（#2–#6、#36）：抽一個共用的 effect 錯誤形狀（`AddEditCarrierFeature` 已有正確寫法），28 處補 catch + inline 錯誤，delete-window 責任上移 parent，splash 失敗 fallback 到 onboarding，onboarding 失敗可重試。
2. **週期交易 PR**（#1、#12、#13、#21）：決定 `tick` 的觸發點（App 前景 + `BGAppRefreshTask`），暫停即取消提醒，到期日以原始日錨定。
3. **資料完整性 PR**（#8–#11、#14、#26）：`uniquingKeysWith` 五處、seed 去重與可重跑、container 切換後刷新依賴、刪除連鎖。
4. **假資料 / 同步 PR**（#7、#15–#20、#22 前半）：隱藏假洞察、Dashboard↔Transactions 刷新、Transactions 列帶分類。
5. 既定的 PR B、PR C 照計劃。

## 驗證覆蓋範圍（三份報告的 D 節）

本地化 key：Widget 17 個、Watch 7 個、主 app 抽查全部存在，無缺漏。分層規則（Feature 不 import SwiftData、不注入 Adapter、Client→Client 只有一條白名單）、Font gateway 全數通過。
