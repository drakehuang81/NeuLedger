# PR C 開工前校正（2026-10-04）

對象：`docs/superpowers/plans/2026-09-22-cross-domain-aggregation.md` 的 **Task 8–14**（PR C）。

計劃寫於 2026-09-22；至今 `developer` 落地 #39–#48 共十個 PR，外加本機兩顆
（Watch haptic）。本文查證 PR C 的每一條前提是否仍成立。

## 結論：計劃的內容仍然準確，失效的是座標與指令

逐一查過七個 task 的 `Produces` 符號與 `Files` 前提，**沒有任何一條前提被推翻**。
需要處理的有兩項，都不是前提問題：**行號已偏移**、**Step 7 的 commit 指令帶著已廢止的
skip 標記**。

特別值得記的是：計劃**已經把當時的既有實作寫進去了**，不是假設從零開始。開工前
若只讀 task 標題，很容易誤判成「這些已經做完了」而跳過：

| Task | 標題讀起來像 | 計劃其實已知 |
|---|---|---|
| 9 | 要新建金額解析 | 已知 `String.parsedAmountDecimal` 存在（提及 4 次），要做的是把 Budget / Recurring 兩處改用它 |
| 10 | 要新建條碼元件 | 已知 `Code128BarcodeView` 在 Common（2 次）、`barcodeFormatHint` 是 `AddEditCarrierView` 的 private func（8 次），要做的是集中到 `CarrierType` 並讓 iOS 改用 |
| 11 | 要新建在地化 | 已知 `Category+Localized.swift` 與 `seedLocalizationMap`（3 次），要做的是公開成 static func 並加 seed 守門測試 |
| 13 | 要收回兩個匯出 | 已知 `exportCSV` 已在 `LedgerClient` / `LedgerClient+LiveExport.swift`（10 次），要做的只有 `exportJSON` |

## 風險一：行號偏移

PR C 引用 48 個檔案，其中 **15 個**自 2026-09-22 起被改過。**8 個同時有行號引用**，
那些行號一律已失效：

| 改動次數 | 檔案 |
|---|---|
| 10 | `Features/Sources/Application/Ledger/LedgerClient+Live.swift` |
| 6 | `Features/Sources/Core/Persistence/PersistenceBootstrap.swift` |
| 2 | `Features/Sources/WatchFeatures/Record/ConfirmView.swift` |
| 2 | `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormFeature.swift` |
| 2 | `Features/Sources/Domain/Clients/LedgerClient.swift` |
| 1 | `NeuLedgerTests/Tests/FeaturesTests/SettingsFeatureTests.swift` |
| 1 | `Features/Sources/Features/RecurringTransactions/RecurringTransactionFormView.swift` |
| 1 | `Features/Sources/Features/BudgetManagement/BudgetFormFeature.swift` |

另有 7 個被改過但計劃沒引用行號，只需確認內容：
`LedgerClientLiveTests.swift`(7)、`RecurringTransactionFormFeatureTests.swift`(2)、
`CarrierManagementView.swift`(2)、`CarrierWidget.swift`(1)、
`BudgetFormFeatureTests.swift`(1)、`KPIStrip.swift`(1)、`WidgetSyncAdapter+Live.swift`(1)。

**派工規則**：PR C 的 subagent prompt **不要轉述計劃裡的行號**，改用符號定位
（`grep -n "case .saveTapped"`、`grep -n "func makeExportCSV"`）。計劃的程式碼內容
仍然可信，只有座標失效。

`ConfirmView.swift` 要特別小心：Task 8（`:34, 75-80`）和 Task 11（`:30`）都指向它，
而 2026-10-04 的 Watch haptic 改動在該檔案加了一個 `onChange` 區塊。

## 風險二：計劃裡的 commit 指令全部帶著已廢止的 skip 標記

PR C 的七個 task，每個 Step 7 都有一行 `git commit -m "... [ci skip]"`。**七個全部帶
那個標記**，而它在 2026-10-03（PR #47）就被廢止了——CI 意圖現在靠分支前綴表達
（`feature/*` / `fix/*` 不觸發、`PR/*` 觸發一次）。

照抄的後果有兩層：

1. 標記已經不是現行規則，留著只會讓 commit 訊息與 CLAUDE.md 矛盾。
2. **更糟的是 Xcode Cloud 做的是字串比對，不分辨「使用」與「談論」**——訊息裡只要
   出現那個完整字串就會跳過建置。這個陷阱 2026-10-03 已經踩過一次（自己的 commit
   訊息提到它，CI 就不觸發了，只能疊一顆乾淨的觸發 commit 補救，因為本專案禁止
   force push）。

**派工規則**：PR C 的 commit 訊息自己寫，不要轉述計劃 Step 7 的 `git commit` 指令。
推送前用 CLAUDE.md 的檢查指令確認 HEAD 乾淨。

## 計劃引用但不存在的 11 個檔案 — 這是正常的

全部都是 task 自己要 Create 或 Move 的目標，不是失效的前提：

`Common/Extensions/CarrierType+UI.swift`、`Common/Extensions/Date+Relative.swift`、
`Common/Extensions/Decimal+Budget.swift`（Task 8 的 Move 目標）、`Domain/AppGroup.swift`、
`Domain/Entities/CarrierType+Display.swift`、
`Domain/Entities/RecurringTransaction+MonthlyEquivalent.swift`、
`CommonTests/DecimalPerPeriodBreakdownTests.swift`（Move 目標）、
`CoreTests/WidgetSyncAdapterLiveTests.swift`、`DomainTests/AppGroupTests.swift`、
`DomainTests/Entities/CarrierTypeDisplayTests.swift`、
`DomainTests/Entities/RecurringTransactionMonthlyEquivalentTests.swift`。

## ledger 不存在

`.superpowers/sdd/2026-09-22-cross-domain-aggregation/` 已不在這個 checkout
（gitignored，可能被清掉）。Task 1–7 已隨 PR A/B merge 完成，所以重建的 ledger
只需從 Task 8 開始記。

## 驗收基準（2026-10-04 實測，xcresult 數字）

| 平台 | 數字 |
|---|---|
| iOS 27.0 | 942 / 0 |
| iOS 26.5 | 942 / 0 |
| watchOS 27.0 | 57 / 0（含 Watch haptic 的 2 條新測試） |

**只看 xcresult**：`xcodebuild` 的 exit code 與 `grep -c "' passed"` 都實證會說謊
（前者會在 xcresult 為 `Failed` 時回 0，後者跨平行 clone 重複計數）。

已知的兩個紅燈與 PR C 無關，不要誤認成回歸：
- **issue #49** — Xcode Cloud 上 `xcodebuild` 自身 SIGTRAP，CI 必紅
- **issue #50** — host app 在測試行程撞 unimplemented dependency，讓完整 scheme
  隨機報 `Failed`（942 條仍全過）
