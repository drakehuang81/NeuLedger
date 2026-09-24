# 資料完整性 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修掉七條會讓帳目變成錯的、或讓 App 直接 crash 的資料完整性缺口——最重要的是讓週期交易的自動補記變成**冪等**操作。

**Architecture:** 核心是給 `Transaction` 加上「來源範本 id + 該期到期日」兩個欄位，讓自動補記的交易有可辨識的來源；`tick` 在記帳前先查這一期是否已經存在，把「記下交易」與「寫回進度」之間的非原子視窗從「會重複入帳」降級成「會重跑一次查詢」。其餘六條分成三組：**多裝置同步的 crash 防護**（五處 `Dictionary(uniqueKeysWithValues:)` 會在重複 id 時直接 trap）、**容器生命週期**（切換 iCloud 或抹除資料後，依賴快取仍指向舊 container；抹除後預設分類不會重新 seed）、**刪除連鎖**（刪分類與封存／刪除帳戶都留下指向不存在實體的孤兒引用）。

**Tech Stack:** Swift 6、TCA 1.23.2、swift-dependencies、SwiftData（`SD*` models + `SwiftDataStore`，CloudKit mirroring 中）、Swift Testing。

**Spec:** `docs/audits/2026-09-23-health-audit/02-application-core.md` 的 **A1、A3、A4、A6、A7、A12**，以及 `docs/superpowers/plans/2026-09-24-recurring-transactions.md` 收尾時全分支 review 提出的 **materialise 非冪等**（該 PR 的 PR body「Not in this PR」第 1 項）。**這些是 binding spec，每個 Task 開工前先讀對應條目。**

## Global Constraints

- Features 層**不得** `import SwiftData`；持久化一律經 Client / Adapter。
- `SwiftDataStore` 是**唯一**可以取用 `\.modelContainer` 的型別（`docs/architecture.md` §4.2）。
- 顏色與字體一律走 `Color.Design` / `Font.Design` gateway。
- 每顆 commit subject **結尾加 `[ci skip]`**；PR 標題不加。
- 新增 effect 一律 `.run(operation:catch:)`，沿用既有錯誤形狀（`loadError`/`loadFailed`、`actionError`/`actionFailed`）。
- 本 PR **不新增** localization key。`CoreError.operationDenied(String)` 帶的是英文開發訊息，沿用既有做法（帳戶刪除守衛就是這樣）。
- 新增的 SwiftData 欄位**必須是 optional 或有預設值**（CloudKit 要求），屬 lightweight migration，**不要**引入 `VersionedSchema` / `MigrationPlan`（專案沒有這套）。
- 不得 `git push`、不得 force push、**不得 `git stash`**。
- 環境：全域 `xcode-select` 指向未授權的 Xcode，所有 `xcodebuild` / `git` / `python3` 前面都要加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`；**不得** `sudo` 或 `xcode-select`。
- **完整 test scheme 由 controller 執行，implementer 只跑 `-only-testing:` 的聚焦 suite**（完整 scheme 超過單次指令 10 分鐘上限會被轉背景，subagent 收不到通知會卡死）。兩個 xcodebuild 不得重疊。
- 測試數以不重複測試名計算：`grep -oE "Test case '[^']+' passed" LOG | sort -u | wc -l`。平行 clone 會把輸出行切斷，數字對不上時用 `comm` 比對名稱，不要寫「浮動」。
- 分支起點的基準：**863 條**不重複測試（developer @ 5e3e3ce）。

## Rulings（開工前已裁定，實作時不要重開）

- **R1（使用者裁定）刪除分類**：有**預算**引用就擋下來（`operationDenied`），只有**交易**引用就清掉引用（那些交易變成「無分類」）。理由：預算被孤兒化會永久壞掉（永遠算 0 卻仍顯示），交易只是少一個標記。
- **R2（使用者裁定）封存帳戶**：指向它的週期範本一律**自動暫停**（`isActive = false`）並取消提醒。刪除帳戶時則**擋下來**（守衛加上週期範本檢查）。
- **R3 冪等的實作形狀**：`Transaction` 加 `sourceTemplateId: RecurringTransaction.ID?` 與 `sourcePeriodDueDate: Date?`。兩者都 optional，使用者手動記的交易維持 nil。`tick` 在每一期記帳前先查「這個範本的這一期是否已存在」，存在就跳過該期但仍推進游標。**不用** deterministic UUID——那只有去重、沒有來源可追溯，而 spec 明確要的是可辨識。
- **R4 去重查詢的成本**：每次 tick 開頭做**一次** predicate fetch 取出所有 `sourceTemplateId != nil` 的交易，建成 `Set`，迴圈內只查記憶體。不要每一期都打一次 DB。
- **R5 容器指向**：用一層 box 間接（`final class ModelContainerBox`），`DependencyValues.modelContainer` 的 getter/setter 保持原樣當 facade，**只有 `SwiftDataStore` 改成依賴 box**。這樣 44 處測試的 `$0.modelContainer = container` 完全不用動。
- **R6 已存在的重複資料不在本 PR 範圍**：本 PR 只防止「未來產生重複」與「遇到重複不 crash」。掃描並合併既有重複資料是另一張單。

---

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `Features/Sources/Domain/Entities/Transaction.swift` | 修改 | 加來源範本 id 與期別 |
| `Features/Sources/Core/Persistence/Models/SDTransaction.swift` | 修改 | 兩個 optional 欄位 |
| `Features/Sources/Core/Mappers/SDTransaction+Mapping.swift` | 修改 | 三個方向帶上新欄位 |
| `Features/Sources/Core/Persistence/SwiftDataStore.swift` | 修改 | 新增 predicate fetch；改用 box 取容器 |
| `Features/Sources/Core/Persistence/ModelContainerKey.swift` | 修改 | box 間接層 |
| `Features/Sources/Core/Persistence/PersistenceBootstrap.swift` | 修改 | 共用 box、`seedIfNeeded` 改 internal |
| `Features/Sources/Core/Adapters/CloudKitSyncAdapter+Live.swift` | 修改 | 換 container 時同步 box |
| `Features/Sources/Application/Platform/PlatformClient+Live.swift` | 修改 | 抹除後重新 seed、換 container 時同步 box |
| `Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift` | 修改 | tick 去重、寫入來源欄位 |
| `Features/Sources/Application/Ledger/LedgerClient+Live.swift` | 修改 | 兩處 Dictionary、setupAccounts 吞錯、帳戶刪除／封存連鎖 |
| `Features/Sources/Application/Ledger/LedgerClient+LiveCatalog.swift` | 修改 | 刪除分類的連鎖 |
| `Features/Sources/Application/Insights/InsightsClient+Live.swift` | 修改 | 兩處 Dictionary |
| `docs/architecture.md` | 修改 | §4.2 容器取用規則補充 box |

測試檔（全部既有，除非註明）：`CoreTests/Mappers/SDTransactionMappingTests.swift`、`CoreTests/Clients/LedgerClientRecurringTests.swift`、`CoreTests/Clients/LedgerClientLiveTests.swift`、`CoreTests/Clients/LedgerClientCatalogTests.swift`（若不存在則**新建**）、`CoreTests/Clients/PlatformClientLiveTests.swift`、`CoreTests/Persistence/SwiftDataStoreTests.swift`（若不存在則**新建**）、`CoreTests/Clients/InsightsClientLiveTests.swift`。

---

## Task 1：Domain + Core — 交易帶上來源範本與期別（spec：materialise 非冪等，資料基礎）

**Files:**
- Modify: `Features/Sources/Domain/Entities/Transaction.swift`
- Modify: `Features/Sources/Core/Persistence/Models/SDTransaction.swift`
- Modify: `Features/Sources/Core/Mappers/SDTransaction+Mapping.swift`
- Test: `NeuLedgerTests/Tests/CoreTests/Mappers/SDTransactionMappingTests.swift`

**Interfaces:**
- Produces：`Transaction.sourceTemplateId: RecurringTransaction.ID?`、`Transaction.sourcePeriodDueDate: Date?`；`Transaction.init` 的兩個新參數**加在參數表最後且都有預設值 `nil`**（既有呼叫端極多，不得破壞）。Task 2 依賴這兩個欄位能往返持久層。
- Consumes：無。

- [ ] **Step 1: 寫失敗測試**

加到 `SDTransactionMappingTests.swift`（沿用該檔既有的 in-memory context 建法）：

```swift
    @Test("the recurring source fields round-trip through the SwiftData model")
    func testRecurringSourceFieldsRoundTrip() throws {
        let templateId = UUID()
        let due = Date(timeIntervalSince1970: 1_767_139_200)
        let domain = Transaction(
            id: UUID(), amount: 18_000, date: due,
            note: "rent", categoryId: nil, accountId: UUID().uuidString,
            toAccountId: nil, type: .expense, tags: [],
            aiSuggested: false, createdAt: due, updatedAt: due,
            sourceTemplateId: templateId, sourcePeriodDueDate: due
        )
        let model = SDTransaction.from(domain, context: context)
        #expect(model.sourceTemplateId == templateId)
        #expect(model.sourcePeriodDueDate == due)

        let back = model.toDomain()
        #expect(back.sourceTemplateId == templateId)
        #expect(back.sourcePeriodDueDate == due)
    }

    @Test("a manually recorded transaction keeps both source fields nil")
    func testManualTransactionHasNoSource() throws {
        let domain = Transaction(
            amount: 120, date: Date(), accountId: UUID().uuidString, type: .expense
        )
        #expect(domain.sourceTemplateId == nil)
        #expect(domain.sourcePeriodDueDate == nil)

        let model = SDTransaction.from(domain, context: context)
        #expect(model.toDomain().sourceTemplateId == nil)
        #expect(model.toDomain().sourcePeriodDueDate == nil)
    }

    @Test("applyChanges carries the source fields")
    func testApplyChangesCarriesSource() throws {
        var domain = Transaction(
            amount: 1, date: Date(), accountId: UUID().uuidString, type: .expense
        )
        let model = SDTransaction.from(domain, context: context)

        let templateId = UUID()
        let due = Date(timeIntervalSince1970: 1_767_139_200)
        domain.sourceTemplateId = templateId
        domain.sourcePeriodDueDate = due
        model.applyChanges(from: domain, context: context)

        #expect(model.sourceTemplateId == templateId)
        #expect(model.sourcePeriodDueDate == due)
    }
```

若該測試檔沒有現成的 `context` helper，照它既有測試的寫法在每個 test 內自行建立 in-memory `ModelContext`。若整個檔案不存在，**新建**並比照 `SDRecurringTransactionMappingTests.swift` 的結構。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/SDTransactionMappingTests 2>&1 | tail -40
```
Expected: 編譯失敗，`extra argument 'sourceTemplateId' in call`。

- [ ] **Step 3: 加 Domain 欄位**

`Transaction.swift`：欄位加在 `updatedAt` 之後：

```swift
    /// The date and time when this record was last modified.
    public var updatedAt: Date

    /// 產生這筆交易的週期範本 id；使用者手動記的交易為 `nil`。
    ///
    /// 與 `sourcePeriodDueDate` 一起讓自動補記變成**可辨識、可去重**的操作：
    /// `tick` 在記帳前先查「這個範本的這一期是否已存在」，所以「記下交易」與
    /// 「寫回進度」之間當掉時，下一次補記不會把同一期再記一遍。
    public var sourceTemplateId: RecurringTransaction.ID?

    /// 這筆交易對應的是該範本的哪一期（該期的到期日）；手動記的交易為 `nil`。
    public var sourcePeriodDueDate: Date?
```

`init` 的參數表**尾端**加兩個有預設值的參數（順序：`sourceTemplateId` 在前），並在 body 尾端賦值：

```swift
        updatedAt: Date = Date(),
        sourceTemplateId: RecurringTransaction.ID? = nil,
        sourcePeriodDueDate: Date? = nil
    ) {
        // ……既有賦值……
        self.sourceTemplateId = sourceTemplateId
        self.sourcePeriodDueDate = sourcePeriodDueDate
    }
```

**注意：** `init` 目前可能有多個多載或預設值順序，請先讀完整個 init 再改；**兩個新參數一定要在最後且都有預設值**，否則全 repo 數十處呼叫端會編譯失敗（那些檔案不在你的白名單內）。

- [ ] **Step 4: 加 SwiftData 欄位**

`SDTransaction.swift`：欄位加在 `updatedAt` 之後（**維持 optional、不給非 nil 預設值**）：

```swift
    /// 產生這筆交易的週期範本 id；手動記的交易為 nil。
    /// CloudKit 要求新增欄位必須 optional：維持 `UUID?`。
    var sourceTemplateId: UUID?

    /// 對應該範本的哪一期（該期到期日）；手動記的交易為 nil。
    var sourcePeriodDueDate: Date?
```

`init` 參數表尾端加 `sourceTemplateId: UUID? = nil, sourcePeriodDueDate: Date? = nil`，body 尾端賦值。

- [ ] **Step 5: 改 mapper 三個方向**

`SDTransaction+Mapping.swift`：`toDomain()`、`from(_:context:)`、`applyChanges(from:context:)` 三處都帶上這兩個欄位（直接傳遞，**不做任何回填**——手動交易本來就該是 nil）。

- [ ] **Step 6: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（3 條新測試）。

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Domain Features/Sources/Core NeuLedgerTests/Tests/CoreTests
git commit -m "feat(domain): record which recurring template and period produced a transaction [ci skip]"
```

---

## Task 2：Core + Application — 自動補記變成冪等（spec：materialise 非冪等）

**Files:**
- Modify: `Features/Sources/Core/Persistence/SwiftDataStore.swift`
- Modify: `Features/Sources/Application/Ledger/LedgerClient+LiveRecurring.swift`
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift`（組裝新參數）
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientRecurringTests.swift`

**Interfaces:**
- Consumes：Task 1 的兩個欄位。
- Produces：`SwiftDataStore.fetchAll(where:sortBy:)`；`makeTick` 多一個 `alreadyMaterialised` 參數。

**這個 task 要修的問題：** `tick` 的迴圈裡「記下交易」與「寫回推進後的到期日」是兩個不同 `ModelContext` 的操作、不是原子的。中間當掉或寫入拋錯，交易留在資料庫、游標沒前進，下一次 tick 會把同一期**再記一遍**。而在 Task 1 之前，交易沒有任何欄位指回它來自哪個範本，所以這種重複帳事後認不出來也清不掉。

- [ ] **Step 1: 寫失敗測試**

加到 `LedgerClientRecurringTests.swift`（沿用該 suite 既有的 `sut` / `spy` / `fixedNow` / `makeTemplate` / `monthsBefore`）：

```swift
    // MARK: - 補記的冪等性

    @Test("tick stamps the source template and period onto what it records")
    func testTickStampsSourceOnMaterialisedTransactions() async throws {
        let start = monthsBefore(1)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        _ = try await sut.tick()

        let txns = try await sut.listAll(TransactionFilter())
        #expect(txns.isEmpty == false)
        for row in txns {
            #expect(row.transaction.sourceTemplateId == template.id)
            #expect(row.transaction.sourcePeriodDueDate != nil)
        }
    }

    @Test("a period that was already recorded is not recorded again when the cursor did not advance")
    func testTickSkipsAnAlreadyRecordedPeriod() async throws {
        // 模擬「交易已寫入、游標沒前進」的當掉視窗：先跑一次 tick，
        // 再把範本的 nextDueDate 手動倒回去，然後重跑 tick。
        let start = monthsBefore(1)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        let first = try await sut.tick()
        let afterFirst = try await sut.listAll(TransactionFilter()).count
        #expect(first > 0)

        // 把游標倒回原點，等同於「寫回進度那一步沒有成功」。
        var rewound = try await sut.listRecurring().first { $0.id == template.id }!
        rewound.nextDueDate = start
        try await sut.updateRecurring(rewound)

        let second = try await sut.tick()

        #expect(second == 0, "同一期不得被重複補記")
        #expect(try await sut.listAll(TransactionFilter()).count == afterFirst,
                "交易總數不得增加")
    }

    @Test("a manually recorded transaction never blocks a materialisation")
    func testManualTransactionsDoNotBlockMaterialisation() async throws {
        // 使用者自己在同一天記了一筆一模一樣的帳，不該讓 tick 誤判為已補記。
        let start = monthsBefore(1)
        var template = makeTemplate(nextDueDate: start, frequency: .monthly)
        template.anchorDate = start
        try await sut.createRecurring(template)

        try await sut.record(
            Transaction(
                amount: 1200, date: start, note: "Rent",
                accountId: template.accountId, type: .expense
            )
        )

        let count = try await sut.tick()
        #expect(count > 0, "手動記的交易沒有來源欄位，不得被當成已補記")
    }
```

`sut.record` 的實際方法名以 `LedgerClient` 的介面為準（可能是 `record` 或 `recordTransaction`），照實際簽章調整。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/LedgerClientRecurringTests 2>&1 | tail -40
```
Expected: `testTickStampsSourceOnMaterialisedTransactions` 與 `testTickSkipsAnAlreadyRecordedPeriod` 兩條 FAIL。

- [ ] **Step 3: 加 predicate fetch**

`SwiftDataStore.swift`，加在既有 `fetchAll(sortBy:)` 之後：

```swift
    /// Returns the Domain values matching an SD-side predicate.
    ///
    /// 給「需要用 SD 欄位過濾、但不想把整張表讀進記憶體」的呼叫端用
    /// （例如週期補記的去重查詢只要 `sourceTemplateId != nil` 的那些）。
    public func fetchAll(
        where predicate: Predicate<SD>,
        sortBy descriptors: [SortDescriptor<SD>] = []
    ) async throws -> [Domain] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SD>(predicate: predicate, sortBy: descriptors)
        return try context.fetch(descriptor).map { $0.toDomain() }
    }
```

- [ ] **Step 4: tick 寫入來源欄位並去重**

`LedgerClient+LiveRecurring.swift`：

先在檔案內加一個小型的 key 型別（放在 `extension LedgerClient` 之外、`RecurringTickGate` 附近）：

```swift
/// 「某個範本的某一期」的識別鍵，用來判斷這一期是否已經補記過。
struct MaterialisedPeriod: Hashable, Sendable {
    let templateId: UUID
    let dueDate: Date
}
```

`makeTick` 加第四個參數 `alreadyMaterialised`：

```swift
    static func makeTick(
        _ store: RecurringTransactionStore,
        _ recordTransaction: @escaping @Sendable (Transaction) async throws -> Void,
        _ syncReminder: @escaping @Sendable (RecurringTransaction) async throws -> Void,
        _ alreadyMaterialised: @escaping @Sendable () async throws -> Set<MaterialisedPeriod>
    ) -> @Sendable () async throws -> Int {
```

在 `runTick` 開頭、取得 `due` 之後，**取一次**已補記集合（plan R4：一次查詢，不要每期都打 DB）：

```swift
            // 已經補記過的期數：中途當掉會留下「交易已寫入、游標沒前進」的狀態，
            // 下一次 tick 必須跳過那些期，否則同一期會被記兩遍（spec：materialise 非冪等）。
            let recorded = try await alreadyMaterialised()
```

迴圈內，在建立 `Transaction` 之前先判斷；建立時帶上來源欄位：

```swift
                    if dueDate >= earliest {
                        let period = MaterialisedPeriod(templateId: cursor.id, dueDate: dueDate)
                        if recorded.contains(period) {
                            // 這一期上次已經記進去了，只是游標沒來得及前進。
                            // 跳過記帳但仍要推進，否則會永遠卡在這一期。
                            cursor.nextDueDate = advanced
                            try await store.update(cursor)
                            continue
                        }

                        let tx = Transaction(
                            // ……既有欄位不變……
                            createdAt: today,
                            updatedAt: today,
                            sourceTemplateId: cursor.id,
                            sourcePeriodDueDate: dueDate
                        )
                        try await recordTransaction(tx)
                        materialised += 1
                        cursor.nextDueDate = advanced
                        try await store.update(cursor)
                    } else {
                        cursor.nextDueDate = advanced
                    }
```

**注意：** `continue` 會跳過 while 迴圈剩下的部分，請確認迴圈尾端沒有其他必須執行的邏輯（目前沒有，推進與落地都已在分支內完成）；若有，改用 if/else 而不是 `continue`。

- [ ] **Step 5: 組裝**

`LedgerClient+Live.swift`：在 `syncRecurringReminder` 附近加一個查詢 closure，然後傳進 `makeTick`：

```swift
        let alreadyMaterialisedPeriods: @Sendable () async throws -> Set<MaterialisedPeriod> = {
            // 只取自動補記產生的交易（手動記的兩個欄位都是 nil），避免把整張交易表讀進來。
            let rows = try await transactionStore.fetchAll(
                where: #Predicate<SDTransaction> { $0.sourceTemplateId != nil }
            )
            return Set(rows.compactMap { tx in
                guard let templateId = tx.sourceTemplateId,
                      let due = tx.sourcePeriodDueDate else { return nil }
                return MaterialisedPeriod(templateId: templateId, dueDate: due)
            })
        }
```

`tick:` 那一行改成 `Self.makeTick(recurringStore, recordTransaction, syncRecurringReminder, alreadyMaterialisedPeriods)`。

**若 `#Predicate` 對 optional `UUID?` 的 `!= nil` 比較編譯不過**（SwiftData 對 optional 的 predicate 支援有坑），改用 `$0.sourcePeriodDueDate != nil` 或退回 `fetchAll()` 後在記憶體過濾，並**在報告裡說明退回的原因**——正確性優先於查詢效率。

- [ ] **Step 6: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS（3 條新測試 + 既有 17 條）。

- [ ] **Step 7: 突變驗證（必做）**

把 Step 4 的 `if recorded.contains(period)` 整段暫時拿掉，重跑同一個 suite，確認 `testTickSkipsAnAlreadyRecordedPeriod` **變紅**；再還原確認轉綠。把兩次輸出摘要寫進報告。這是證明去重真的有保護力的唯一方法。

- [ ] **Step 8: Commit**

```bash
git add Features/Sources NeuLedgerTests
git commit -m "fix(recurring): skip periods that were already recorded so a crash cannot duplicate them [ci skip]"
```

---

## Task 3：Application — 重複 id 不再直接 crash（spec：A4、A12）

**Files:**
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift:93,94,171`
- Modify: `Features/Sources/Application/Insights/InsightsClient+Live.swift:133,144`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientLiveTests.swift`

**這個 task 要修的問題：** 兩台裝置各自冷啟動時會各自 seed 出 14 筆預設分類；之後開啟 iCloud 同步，同一台裝置就會有兩筆 id 相同的 `SDCategory`。此時 `Dictionary(uniqueKeysWithValues:)` **直接 trap**（`Fatal error: Duplicate values for key`），而那是 `listRecent` / `listAll` / `search` / `fetch` 的共同路徑——**Dashboard 一開就 crash，使用者無法自行恢復**。同一份專案裡 `LedgerClient+LiveExport.swift:25,29` 已經用了安全寫法，只是沒推廣。

順帶修 A12：`setupAccounts` 把 `fetchAll` 的錯誤吞成空陣列，導致「已存在就跳過」的去重完全失效、所有帳戶被重新插入，接著就踩到上面的 trap。

- [ ] **Step 1: 寫失敗測試**

加到 `LedgerClientLiveTests.swift`（沿用該檔既有的 in-memory container / sut 建法）：

```swift
    @Test("duplicate category ids from CloudKit do not crash enrichment")
    func testDuplicateCategoriesDoNotCrash() async throws {
        // 直接經 store 寫入兩筆同 id 的分類，模擬兩台裝置各自 seed 後同步的結果。
        let duplicatedId = UUID()
        let store = CategoryStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(Domain.Category(id: duplicatedId, name: "Food", isDefault: true))
            try await store.add(Domain.Category(id: duplicatedId, name: "Food", isDefault: true))
        }

        try await sut.record(
            Transaction(amount: 100, date: Date(), categoryId: duplicatedId,
                        accountId: UUID().uuidString, type: .expense)
        )

        // 沒有修法時這一行會 trap（Fatal error: Duplicate values for key），整個測試程序掛掉。
        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.count == 1)
    }

    @Test("setupAccounts surfaces a read failure instead of re-inserting every account")
    func testSetupAccountsDoesNotSwallowReadFailure() async throws {
        // 具體作法依既有 fixture 決定：讓 accountStore 的讀取失敗，
        // 斷言 setupAccounts 會拋出，而不是安靜地把帳戶再插一遍。
    }
```

`Domain.Category` 的 init 簽章以實際為準。第二條測試若在現有注入點下造不出「讀取失敗」的情境（`accountStore` 是直接建構的具體 store），**如實回報並改成只驗證 `try?` 已改成 `try`（讀程式碼即可），不要硬寫假測試**。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/LedgerClientLiveTests 2>&1 | tail -40
```
Expected: `testDuplicateCategoriesDoNotCrash` 讓測試程序 crash 或 FAIL。

- [ ] **Step 3: 五處 Dictionary 全部改安全寫法**

一律改成 `Dictionary(_:uniquingKeysWith: { first, _ in first })`，與 `LedgerClient+LiveExport.swift:25` 的既有寫法一致：

- `LedgerClient+Live.swift:93` `categoryById`
- `LedgerClient+Live.swift:94` `accountById`
- `LedgerClient+Live.swift:171` `setupAccounts` 的 `dictionary`
- `InsightsClient+Live.swift:133` `categoryProportions` 的 `names`
- `InsightsClient+Live.swift:144` `budgetGauges` 的 `names`

每一處都補一行註解說明為什麼（多裝置 CloudKit 同步可能產生同 id 的兩筆列，取第一筆）。

- [ ] **Step 4: setupAccounts 不再吞錯**

`LedgerClient+Live.swift:167-169`：

```swift
                // 讀不到既有帳戶就直接往上拋——吞成空陣列會讓下面的去重完全失效，
                // 把所有帳戶再插一遍，接著就踩到重複 id 的問題（spec A12）。
                let existing = try await accountStore.fetchAll(
                    sortBy: [SortDescriptor(\.sortOrder)]
                )
```

- [ ] **Step 5: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS。

- [ ] **Step 6: 確認沒有殘留**

```bash
grep -rn "uniqueKeysWithValues" Features/Sources --include="*.swift"
```
Expected: 零輸出。

- [ ] **Step 7: Commit**

```bash
git add Features/Sources NeuLedgerTests
git commit -m "fix(sync): tolerate duplicate ids from CloudKit instead of trapping, and stop swallowing the account read failure [ci skip]"
```

---

## Task 4：Core — 切換容器後依賴不再指向舊 container（spec：A3）

**Files:**
- Modify: `Features/Sources/Core/Persistence/ModelContainerKey.swift`
- Modify: `Features/Sources/Core/Persistence/PersistenceBootstrap.swift`
- Modify: `Features/Sources/Core/Persistence/SwiftDataStore.swift`
- Modify: `Features/Sources/Core/Adapters/CloudKitSyncAdapter+Live.swift:23`
- Modify: `Features/Sources/Application/Platform/PlatformClient+Live.swift:167`
- Modify: `docs/architecture.md`（§4.2）
- Test: `NeuLedgerTests/Tests/CoreTests/Persistence/SwiftDataStoreTests.swift`（不存在則新建）

**這個 task 要修的問題：** `\.modelContainer` 的 `liveValue` 雖然是 computed property，但 swift-dependencies 以 key 型別為單位快取解析結果，首次解析後就固定住那個 `ModelContainer` 實例。開啟 iCloud 同步（`switchToCloudContainer`）或抹除資料只換掉 `PersistenceBootstrap.container` 這個 static var，**已快取的依賴不會更新**，於是這一輪 App 生命週期內新增的資料都不會被 CloudKit 上傳，要等下次冷啟動。

**R5：用 box 間接，`DependencyValues.modelContainer` 的 getter/setter 保持原樣當 facade，只有 `SwiftDataStore` 改成依賴 box。** 44 處測試的 `$0.modelContainer = container` 完全不用動。

- [ ] **Step 1: 寫失敗測試**

新建（或加到）`NeuLedgerTests/Tests/CoreTests/Persistence/SwiftDataStoreTests.swift`：

```swift
import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("SwiftDataStore container indirection")
struct SwiftDataStoreContainerTests {

    @Test("a store writes into the container the box currently points at")
    func testStoreFollowsTheBox() async throws {
        let schema = Schema([SDAccount.self])
        let first = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let second = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let box = ModelContainerBox(first)

        try await withDependencies {
            $0.modelContainerBox = box
        } operation: {
            let store = SwiftDataStore<Account, SDAccount>()
            try await store.add(Self.sampleAccount)
            #expect(try await store.fetchAll().count == 1)

            // 換掉 box 的內容（等同 switchToCloudContainer / wipeAllSyncData 做的事）
            box.container = second
            #expect(try await store.fetchAll().isEmpty,
                    "換過容器之後，store 必須讀寫新的容器")
        }
    }

    private static var sampleAccount: Account {
        Account(name: "Cash", type: .cash, icon: "banknote", color: "#FFFFFF")
    }
}
```

`Account.init` 的 `icon` 與 `color` **沒有預設值**，一定要給（`Features/Sources/Domain/Entities/Account.swift:49-58`）；`type` 的實際 case 名以 `AccountType` 為準。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/SwiftDataStoreContainerTests 2>&1 | tail -40
```
Expected: 編譯失敗，`cannot find 'ModelContainerBox' in scope`。

- [ ] **Step 3: 加 box 與新的 dependency key**

`ModelContainerKey.swift` 整檔改成：

```swift
import Foundation
import SwiftData
import Dependencies

/// 持有目前使用中的 `ModelContainer`。
///
/// 為什麼要這一層間接：swift-dependencies 以 key 型別為單位快取解析結果，所以
/// 即使 `liveValue` 是 computed property，第一次解析之後就固定住那個
/// `ModelContainer` 實例。切換 iCloud 同步或抹除資料只換掉
/// `PersistenceBootstrap.container`，已快取的依賴不會更新——這一輪 App 生命週期
/// 內新增的資料就不會被 CloudKit 上傳（spec A3）。改成快取這個 **box**，換的是
/// box 的內容而不是 box 本身，取用端就一定拿得到當下的容器。
public final class ModelContainerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _container: ModelContainer

    public init(_ container: ModelContainer) { self._container = container }

    public var container: ModelContainer {
        get { lock.lock(); defer { lock.unlock() }; return _container }
        set { lock.lock(); _container = newValue; lock.unlock() }
    }
}

public extension DependencyValues {
    /// 目前使用中的 `ModelContainer`。
    ///
    /// **Access scope:** only `SwiftDataStore` may depend on this. See
    /// `docs/architecture.md` §4.2. 讀取端請改用 `modelContainerBox`——
    /// 這個 facade 只是為了讓既有的 `$0.modelContainer = container` 覆寫寫法繼續有效。
    var modelContainer: ModelContainer {
        get { self[ModelContainerBoxKey.self].container }
        set { self[ModelContainerBoxKey.self] = ModelContainerBox(newValue) }
    }

    /// `SwiftDataStore` 取用容器的唯一入口。
    var modelContainerBox: ModelContainerBox {
        get { self[ModelContainerBoxKey.self] }
        set { self[ModelContainerBoxKey.self] = newValue }
    }
}

private enum ModelContainerBoxKey: DependencyKey {
    static var liveValue: ModelContainerBox { PersistenceBootstrap.containerBox }
    static var testValue: ModelContainerBox { ModelContainerBox(PersistenceBootstrap.testContainer) }
}
```

- [ ] **Step 4: `PersistenceBootstrap` 暴露共用 box**

在 `PersistenceBootstrap` 內，把既有的 `nonisolated(unsafe) public static var container: ModelContainer` 改成由 box 支撐，**保持 `container` 這個名字可讀可寫**（其他地方在用）：

```swift
    /// 整個 process 共用的容器 box；換容器時改的是它的內容（spec A3）。
    nonisolated(unsafe) public static let containerBox: ModelContainerBox = {
        ModelContainerBox(makeInitialContainer())
    }()

    nonisolated(unsafe) public static var container: ModelContainer {
        get { containerBox.container }
        set { containerBox.container = newValue }
    }
```

`makeInitialContainer()` 就是把既有 `static var container` 那個 lazy initializer 的內容（含 `seedIfNeeded` 呼叫）搬進一個 private static func。**行為不要改**，只是搬家。

- [ ] **Step 5: `SwiftDataStore` 改成依賴 box**

```swift
    @Dependency(\.modelContainerBox) private var containerBox

    private var container: ModelContainer { containerBox.container }
```
其餘五個方法完全不動（它們都是用 `ModelContext(container)`）。

- [ ] **Step 6: 換容器的兩處改成換 box 內容**

`CloudKitSyncAdapter+Live.swift:23` 與 `PlatformClient+Live.swift:167` 的 `PersistenceBootstrap.container = xxx` 因為 Step 4 的 setter 已經寫進 box，**不需要改**——但請各補一行註解說明「這一行現在會更新共用 box，所有 `SwiftDataStore` 立即跟上」，並確認沒有其他地方是直接改 box 以外的狀態。

- [ ] **Step 7: 跑測試確認通過 + 更新文件**

同 Step 2 的指令。Expected: PASS。

`docs/architecture.md` §4.2 補一段：容器經 `ModelContainerBox` 間接持有，`SwiftDataStore` 依賴 box 而非容器本身，切換容器時更新 box 內容即可讓所有 store 立即跟上。

- [ ] **Step 8: Commit**

```bash
git add Features/Sources NeuLedgerTests docs/architecture.md
git commit -m "fix(persistence): route stores through a container box so switching iCloud takes effect immediately [ci skip]"
```

---

## Task 5：Core — 抹除資料後預設分類會回來（spec：A1）

**Files:**
- Modify: `Features/Sources/Core/Persistence/PersistenceBootstrap.swift:221-222`（`seedIfNeeded` 的可見度）
- Modify: `Features/Sources/Application/Platform/PlatformClient+Live.swift:139-176`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/PlatformClientLiveTests.swift`

**這個 task 要修的問題：** 設定頁「抹除所有資料」會刪掉 14 筆預設分類，接著重建 container 並指派給 `PersistenceBootstrap.container`。程式碼註解宣稱「so the next `seedIfNeeded` runs」，但 `seedIfNeeded` 是 private 且只在兩個 static lazy initializer 內被呼叫，那些在 process 生命週期中早已執行完畢。**使用者被導回 onboarding、建完帳戶進入記帳頁，分類清單是空的**，直到下次冷啟動才恢復。

- [ ] **Step 1: 寫失敗測試**

加到 `PlatformClientLiveTests.swift`：

```swift
    @Test("wiping all data re-seeds the default categories")
    func testWipeReseedsDefaultCategories() async throws {
        let container = try freshContainer()
        // 先確認種子分類存在（依該檔既有 helper 建 sut）
        let client = sut(container: container)
        try await client.wipeAllSyncData()

        let store = CategoryStore()
        let categories = try await withDependencies {
            $0.modelContainer = PersistenceBootstrap.container
        } operation: {
            try await store.fetchAll()
        }
        #expect(categories.isEmpty == false, "抹除後必須重新 seed，否則使用者的分類清單是空的")
        #expect(categories.contains { $0.isDefault })
    }
```

這條測試會動到 `PersistenceBootstrap.container` 這個 process 全域狀態。**若該 suite 沒有辦法安全地隔離這件事**（例如會影響同 suite 其他測試），就改成標記整個 suite `.serialized`，並在報告裡說明；必要時把斷言縮小到「`seedIfNeeded` 被呼叫過」這個可觀察事實。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/PlatformClientLiveTests 2>&1 | tail -40
```
Expected: 新測試 FAIL（分類是空的）。

- [ ] **Step 3: `seedIfNeeded` 改 internal**

`PersistenceBootstrap.swift:221`：把 `private extension PersistenceBootstrap` 改成 `extension PersistenceBootstrap`，並給 `seedIfNeeded` 明確的 `static func`（internal 即可，不需要 public——呼叫端 `PlatformClient+Live.swift` 在同一個 `Core` target 內）。補一行註解說明它現在有第三個呼叫點（抹除資料後）。

- [ ] **Step 4: 抹除後顯式重新 seed**

`PlatformClient+Live.swift`：在重建 `localContainer` 並指派給 `PersistenceBootstrap.container` 之後（約 `:167`），加：

```swift
                    PersistenceBootstrap.container = localContainer
                    // 重新指派 container 不會觸發任何 seeding——`seedIfNeeded` 只在
                    // static lazy initializer 內被呼叫，那些在 process 生命週期中早已
                    // 跑完。不顯式呼叫的話，使用者抹除資料後分類清單會是空的，
                    // 直到下次冷啟動才恢復（spec A1）。
                    PersistenceBootstrap.seedIfNeeded(in: ModelContext(localContainer))
```

同時把原本那句宣稱「so the next `seedIfNeeded` runs」的錯誤註解刪掉或改對。

- [ ] **Step 5: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources NeuLedgerTests
git commit -m "fix(persistence): re-seed the default categories after wiping all data [ci skip]"
```

---

## Task 6：Application — 刪除分類的連鎖（spec：A6，裁定 R1）

**Files:**
- Modify: `Features/Sources/Application/Ledger/LedgerClient+LiveCatalog.swift:46-60`
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift`（`deleteCategory` 的組裝，要多傳 store）
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientCatalogTests.swift`（不存在則新建）

**這個 task 要修的問題：** `makeDeleteCategory` 只擋 `isDefault`，之後是純 store delete。`SDTransaction.categoryId` 與 `SDBudget.categoryId` 都是裸 `UUID?`、沒有 `@Relationship`，不會被連帶清空。後果：交易顯示空白分類、CSV 匯出該欄變空、**預算永遠算 0 卻仍出現在畫面上**。

**裁定 R1（使用者決定）：有預算引用就擋下來，只有交易引用就清掉引用。**

- [ ] **Step 1: 寫失敗測試**

**`LedgerClientCatalogTests.swift` 不存在，要新建。** 結構直接照抄 `LedgerClientLiveTests.swift:17-47` 的 `init()`（in-memory `ModelContainer` + `withDependencies` 組出 `sut: LedgerClient`），schema 記得含 `SDCategory`、`SDBudget`、`SDTransaction`、`SDAccount`、`SDTag`。同檔 `:70-78` 的 `seedCategory(_:)` helper 也一併照抄（它用 `CategoryStore()` + `withDependencies { $0.modelContainer = container }` 直接寫入，繞過 client 的守衛，正是建 fixture 需要的）。

```swift
    private static func customCategory(id: UUID) -> Domain.Category {
        // isDefault: false —— 預設分類本來就不能刪，那是另一條測試
        Domain.Category(id: id, name: "Coffee", isDefault: false)
    }

    private static func expense(categoryId: UUID?, accountId: String) -> Transaction {
        Transaction(amount: 120, date: Date(), categoryId: categoryId,
                    accountId: accountId, type: .expense)
    }

    @Test("deleting a category that a budget points at is denied")
    func testDeleteCategoryWithBudgetIsDenied() async throws {
        let categoryId = UUID()
        try await seedCategory(Self.customCategory(id: categoryId))
        let budgetStore = BudgetStore()
        try await withDependencies { $0.modelContainer = container } operation: {
            try await budgetStore.add(Self.budget(categoryId: categoryId))
        }

        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(categoryId)
        }
        #expect(try await sut.listCategories(nil).contains { $0.id == categoryId },
                "被擋下來的刪除不得動到分類本身")
    }

    @Test("deleting a category clears it from the transactions that referenced it")
    func testDeleteCategoryClearsTransactionReferences() async throws {
        let categoryId = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: categoryId))
        try await sut.record(Self.expense(categoryId: categoryId, accountId: accountId))
        try await sut.record(Self.expense(categoryId: categoryId, accountId: accountId))

        try await sut.deleteCategory(categoryId)

        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.count == 2, "交易不得被連帶刪除")
        #expect(rows.allSatisfy { $0.transaction.categoryId == nil },
                "引用必須被清掉，不能留下指向不存在分類的孤兒 id")
        #expect(try await sut.listCategories(nil).contains { $0.id == categoryId } == false)
    }

    @Test("a transaction that uses a different category is untouched")
    func testDeleteCategoryLeavesOtherTransactionsAlone() async throws {
        let doomed = UUID()
        let kept = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: doomed))
        try await seedCategory(Domain.Category(id: kept, name: "Rent", isDefault: false))
        try await sut.record(Self.expense(categoryId: doomed, accountId: accountId))
        try await sut.record(Self.expense(categoryId: kept, accountId: accountId))

        try await sut.deleteCategory(doomed)

        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.filter { $0.transaction.categoryId == kept }.count == 1,
                "不相關的交易不得被清掉分類")
    }

    @Test("deleting a default category is still denied")
    func testDeleteDefaultCategoryStillDenied() async throws {
        let categoryId = UUID()
        try await seedCategory(Domain.Category(id: categoryId, name: "Food", isDefault: true))
        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(categoryId)
        }
    }
```

`Domain.Category` 與 `Budget` 的 init 簽章以實際為準（`Self.budget(categoryId:)` 請照 `Budget` 的必填欄位補齊，`isActive: true`）。`sut.record` 的方法名若不同，照 `LedgerClient` 的介面調整。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/LedgerClientCatalogTests 2>&1 | tail -40
```

- [ ] **Step 3: 實作連鎖**

`LedgerClient+LiveCatalog.swift` 的 `makeDeleteCategory` 改成多收兩個 store：

```swift
    static func makeDeleteCategory(
        _ store: CategoryStore,
        _ budgetStore: BudgetStore,
        _ transactionStore: TransactionStore
    ) -> @Sendable (Domain.Category.ID) async throws -> Void {
        { id in
            guard let existing = try await store.fetch(id: id) else {
                throw CoreError.notFound("SDCategory")
            }
            guard !existing.isDefault else {
                throw CoreError.operationDenied(
                    "Cannot delete default category '\(existing.name)'"
                )
            }

            // 預算被孤兒化會永久壞掉——永遠算出 0 支出卻仍顯示在畫面上，
            // 使用者看不出原因。所以擋下來，要求先處理預算（plan R1）。
            let linkedBudgets = try await budgetStore.fetchAll().filter { $0.categoryId == id }
            guard linkedBudgets.isEmpty else {
                throw CoreError.operationDenied(
                    "Cannot delete category '\(existing.name)' while \(linkedBudgets.count) budget(s) still use it; delete those budgets first."
                )
            }

            // 交易只是少一個標記，清掉引用即可（plan R1），
            // 但一定要清——留下指向不存在分類的 id 會讓畫面空白、CSV 匯出空欄。
            let affected = try await transactionStore.fetchAll().filter { $0.categoryId == id }
            for var transaction in affected {
                transaction.categoryId = nil
                try await transactionStore.update(transaction)
            }

            try await store.delete(id: id)
        }
    }
```

`LedgerClient+Live.swift` 的組裝那一行補上兩個 store。

**效能備註：** `transactionStore.fetchAll()` 會把整張交易表讀進來。Task 2 已經加了 `fetchAll(where:)`，**優先改用 predicate**（`#Predicate<SDTransaction> { $0.categoryId == id }`）；若 optional 比較編譯不過，退回 `fetchAll()` 並在報告裡說明。

- [ ] **Step 4: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Features/Sources NeuLedgerTests
git commit -m "fix(catalog): deny deleting a category a budget uses and clear it from transactions [ci skip]"
```

---

## Task 7：Application — 帳戶封存／刪除的連鎖（spec：A7，裁定 R2）

**Files:**
- Modify: `Features/Sources/Application/Ledger/LedgerClient+Live.swift:193-215`
- Test: `NeuLedgerTests/Tests/CoreTests/Clients/LedgerClientLiveTests.swift`

**這個 task 要修的問題：** 三處殘留無人清理——`defaultAccountId` 設定仍指向已刪／已封存帳戶（iOS 端沒有任何等價守衛，直接回傳死 id）、`watchDefaultAccountId` 同理、`SDRecurringTransaction.accountId` 指向已刪帳戶。`deleteAccount` 的守衛只檢查交易，沒檢查週期範本。**週期交易現在會自動入帳**，所以指向已封存帳戶的範本會持續記帳到一個使用者已經收起來的帳戶。

**裁定 R2（使用者決定）：封存時自動暫停指向它的週期範本並取消提醒；刪除時把週期範本加進守衛擋下來。**

- [ ] **Step 1: 寫失敗測試**

```swift
    @Test("archiving an account pauses the recurring templates that point at it")
    func testArchiveAccountPausesItsTemplates() async throws {
        // 建帳戶 A + 兩個指向 A 的啟用中範本 + 一個指向別的帳戶的範本
        try await sut.archiveAccount(accountId)

        let templates = try await sut.listRecurring()
        #expect(templates.filter { $0.accountId == accountId }.allSatisfy { !$0.isActive },
                "指向已封存帳戶的範本必須被暫停")
        #expect(templates.first { $0.accountId == otherAccountId }?.isActive == true,
                "不相關的範本不得被動到")
    }

    @Test("deleting an account a recurring template points at is denied")
    func testDeleteAccountWithTemplateIsDenied() async throws {
        await #expect(throws: CoreError.self) {
            try await sut.deleteAccount(accountId)
        }
    }

    @Test("archiving or deleting the default account clears the stored default")
    func testDefaultAccountIsClearedOnArchive() async throws {
        // 先把 accountId 設成預設帳戶，封存後斷言設定被清成 nil
    }
```

`defaultAccountId` 的讀寫路徑請先確認（`LedgerClient+Live.swift` 檔頭註解提到它走 `\.userSettingsAdapter` 的 `.defaultAccountId` key）；測試覆寫 `userSettingsAdapter` 即可。

- [ ] **Step 2: 跑測試確認失敗**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/LedgerClientLiveTests 2>&1 | tail -40
```

- [ ] **Step 3: 封存時暫停範本 + 清預設帳戶**

`archiveAccount` 改成：

```swift
            archiveAccount: { id in
                guard var existing = try await accountStore.fetch(id: id) else {
                    throw CoreError.notFound("SDAccount")
                }
                existing.isArchived = true
                try await accountStore.update(existing)

                // 週期交易現在會自動入帳，指向已封存帳戶的範本會持續往一個
                // 使用者已經收起來的帳戶記帳——一律暫停並取消提醒（plan R2）。
                let linked = try await recurringStore.fetchAll().filter {
                    $0.accountId == id && $0.isActive
                }
                for var template in linked {
                    template.isActive = false
                    try await recurringStore.update(template)
                    await notificationAdapter.cancelRecurringReminder(template.id)
                }

                try await clearDefaultAccountIfNeeded(id)
            },
```

`clearDefaultAccountIfNeeded` 是本 task 新增的小 helper（放在同檔 `extension LedgerClient` 內），把 `.defaultAccountId` 與 `watchDefaultAccountId` 兩個設定裡等於該 id 的值清成 nil。實際的 key 名稱與讀寫 API 請照 `userSettingsAdapter` 的既有用法。

**注意：** `archiveAccount` 目前的組裝可能沒有拿到 `recurringStore` 與 `notificationAdapter`，需要在 `LedgerClient+Live.swift` 的組裝處補上。

- [ ] **Step 4: 刪除的守衛加上週期範本**

`deleteAccount` 的既有交易守衛之後，加：

```swift
                let linkedTemplates = try await recurringStore.fetchAll().filter {
                    $0.accountId == id
                }
                guard linkedTemplates.isEmpty else {
                    throw CoreError.operationDenied(
                        "Cannot delete account with \(linkedTemplates.count) recurring template(s); archive it instead."
                    )
                }
```
刪除成功後也要呼叫 `clearDefaultAccountIfNeeded(id)`。

- [ ] **Step 5: 跑測試確認通過**

同 Step 2 的指令。Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources NeuLedgerTests
git commit -m "fix(accounts): pause recurring templates on archive and stop leaving dead default-account ids [ci skip]"
```

---

## 收尾檢查（全部 Task 完成後）

- [ ] `grep -rn "uniqueKeysWithValues" Features/Sources --include="*.swift"` 零輸出。
- [ ] `grep -rn "Dependency(\\.modelContainer)" Features/Sources --include="*.swift"` 只剩註解，沒有實際取用（`SwiftDataStore` 改用 box）。
- [ ] CLAUDE.md 的五條 ast-grep 架構稽核全部通過。
- [ ] 完整 scheme exit=0、0 failed（由 controller 跑）。
- [ ] 全分支 review（最強模型）→ 有發現就一輪 fix → re-review。

## 不在本 PR（已記錄，PR body 要寫）

- **掃描並合併既有的重複資料**（R6）：本 PR 只防止未來產生重複、遇到重複不 crash。已經同步出兩筆同 id 分類的使用者，重複列仍在。
- **「逐期落地」沒有測試釘住**：作法已知（`planningClient.evaluateAfterTransaction` 可注入且 async，在第二期的呼叫上懸停，再斷言進度恰好前進一期）。
- **閘門沒有存活性逃生口**；**tick 失敗與被補記窗略過的期數對使用者靜默**。
- **假洞察**（Dashboard 顯示三筆寫死假數字）、**Dashboard ↔ Transactions 不同步**、**PR B / PR C**。
