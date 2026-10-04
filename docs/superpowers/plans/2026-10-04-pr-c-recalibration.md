# PR C 開工前校正（2026-10-04）

對象：`docs/superpowers/plans/2026-09-22-cross-domain-aggregation.md` 的 **Task 8–14**（PR C）。

計劃寫於 2026-09-22；至今 `developer` 落地 #39–#48 共十個 PR，外加本機兩顆
（Watch haptic）。本文查證 PR C 的每一條前提是否仍成立。

## 結論：計劃仍然準確，唯一的真實風險是行號

逐一查過七個 task 的 `Produces` 符號與 `Files` 前提，**沒有任何一條前提被推翻**。

特別值得記的是：計劃**已經把當時的既有實作寫進去了**，不是假設從零開始。開工前
若只讀 task 標題，很容易誤判成「這些已經做完了」而跳過：

| Task | 標題讀起來像 | 計劃其實已知 |
|---|---|---|
| 9 | 要新建金額解析 | 已知 `String.parsedAmountDecimal` 存在（提及 4 次），要做的是把 Budget / Recurring 兩處改用它 |
| 10 | 要新建條碼元件 | 已知 `Code128BarcodeView` 在 Common（2 次）、`barcodeFormatHint` 是 `AddEditCarrierView` 的 private func（8 次），要做的是集中到 `CarrierType` 並讓 iOS 改用 |
| 11 | 要新建在地化 | 已知 `Category+Localized.swift` 與 `seedLocalizationMap`（3 次），要做的是公開成 static func 並加 seed 守門測試 |
| 13 | 要收回兩個匯出 | 已知 `exportCSV` 已在 `LedgerClient` / `LedgerClient+LiveExport.swift`（10 次），要做的只有 `exportJSON` |

## 行號偏移（唯一需要處理的）

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
