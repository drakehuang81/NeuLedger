import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

/// Integration tests for `LedgerClient.liveValue` — Transactions + Accounts
/// sections (step 5a2 internalisation). Mirrors the equivalent cases from
/// `TransactionClientTests` and `AccountClientTests`, now driven through the
/// consolidated client backed by an in-memory SwiftData container.
///
/// Only the internalised sections (Transactions, Accounts) are exercised here;
/// Catalog/Recurring/Export still delegate and are covered by their own suites.
@Suite("LedgerClient Live (Transactions + Accounts) Integration Tests")
struct LedgerClientLiveTests {
    let container: ModelContainer
    let sut: LedgerClient

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
            // task-7：`archiveAccount`/`deleteAccount` 現在會查詢週期範本
            // （見下方 Accounts × Recurring 區塊），schema 沒登記這個型別的話
            // `recurringStore.fetchAll()` 會直接 crash，不是回傳空陣列。
            SDRecurringTransaction.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container

        let testPersistenceBootstrap = PersistenceBootstrap(modelContainer: { _container })

        self.sut = withDependencies {
            $0.persistenceBootstrap = testPersistenceBootstrap
            $0.modelContainer = _container
            // Silence the budget post-condition so record/update don't reach
            // into PlanningClient's live store reads — behaviour of that
            // invariant is covered separately by PlanningClientEvaluateTests.
            $0.planningClient.evaluateAfterTransaction = { _ in }
        } operation: {
            LedgerClient.liveValue
        }
    }

    // MARK: - Transactions

    @Test("record persists a transaction with its tags")
    func testRecordTransaction() async throws {
        let tag = Tag(id: UUID(), name: "Travel", color: "#FFF")
        let transaction = Transaction(
            id: UUID(), amount: 1500, date: Date(), note: "Flight tickets",
            categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [tag], aiSuggested: false,
            createdAt: Date(), updatedAt: Date()
        )

        try await sut.record(transaction)

        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.count == 1)
        #expect(rows.first?.transaction.amount == 1500)
        #expect(rows.first?.transaction.note == "Flight tickets")
        #expect(rows.first?.transaction.tags.first?.name == "Travel")
    }

    /// Seed a category straight into the container (bypassing the still-delegating
    /// `createCategory`) so the Transactions enrichment join has something to
    /// resolve against.
    private func seedCategory(_ category: Domain.Category) async throws {
        let store = CategoryStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(category)
        }
    }

    @Test("listRecent enriches with category and account and respects limit")
    func testListRecentEnrichmentAndLimit() async throws {
        let categoryId = UUID()
        let accountId = UUID().uuidString
        let category = Domain.Category(
            id: categoryId, name: "Food", icon: "fork.knife", color: "#FF0000",
            type: .expense, sortOrder: 0, isDefault: false
        )
        let account = Account(
            id: accountId, name: "Cash", type: .cash, icon: "banknote",
            color: "#00FF00", sortOrder: 0, isArchived: false, createdAt: Date()
        )
        // Seed catalog/account directly through the store so enrichment can join.
        try await seedCategory(category)
        try await sut.createAccount(account)

        for i in 0..<25 {
            let t = Transaction(
                id: UUID(), amount: Decimal(i),
                date: Date(timeIntervalSince1970: TimeInterval(i * 1000)),
                note: "Note \(i)", categoryId: categoryId, accountId: accountId,
                toAccountId: nil, type: .expense, tags: [], aiSuggested: false,
                createdAt: Date(), updatedAt: Date()
            )
            try await sut.record(t)
        }

        let recent = try await sut.listRecent(20)
        #expect(recent.count == 20)
        #expect(recent.first?.transaction.amount == 24)
        #expect(recent.first?.category?.name == "Food")
        #expect(recent.first?.account?.name == "Cash")
    }

    @Test("listAll applies every filter dimension")
    func testListAllFilters() async throws {
        let cat1 = UUID(); let cat2 = UUID()
        let acc1 = UUID().uuidString; let acc2 = UUID().uuidString
        let tag1 = Tag(id: UUID(), name: "Tag 1", color: "#FFF")
        let now = Date()

        let t1 = Transaction(id: UUID(), amount: 100, date: now.addingTimeInterval(-86400*2), note: "A", categoryId: cat1, accountId: acc1, toAccountId: nil, type: .expense, tags: [tag1], aiSuggested: false, createdAt: now, updatedAt: now)
        let t2 = Transaction(id: UUID(), amount: 200, date: now.addingTimeInterval(-86400), note: "B", categoryId: cat1, accountId: acc2, toAccountId: nil, type: .income, tags: [], aiSuggested: false, createdAt: now, updatedAt: now)
        let t3 = Transaction(id: UUID(), amount: 300, date: now, note: "C", categoryId: cat2, accountId: acc1, toAccountId: nil, type: .expense, tags: [tag1], aiSuggested: false, createdAt: now, updatedAt: now)

        try await sut.record(t1)
        try await sut.record(t2)
        try await sut.record(t3)

        var results = try await sut.listAll(TransactionFilter(categoryIds: [cat1]))
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.transaction.categoryId == cat1 })

        results = try await sut.listAll(TransactionFilter(accountIds: [acc1]))
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.transaction.involves(account: acc1) })

        results = try await sut.listAll(TransactionFilter(tagIds: [tag1.id]))
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.transaction.tags.contains { $0.id == tag1.id } })

        results = try await sut.listAll(TransactionFilter(types: [.income]))
        #expect(results.count == 1)
        #expect(results.first?.transaction.type == .income)

        results = try await sut.listAll(TransactionFilter(dateRange: now.addingTimeInterval(-86400*1.5)...now.addingTimeInterval(86400)))
        #expect(results.count == 2)
    }

    @Test("listAll(accountIds:) includes transfers INTO the account — same semantics as balance")
    func testListAllAccountFilterIncludesIncomingTransfers() async throws {
        let accA = UUID().uuidString
        let accB = UUID().uuidString
        let out = Transaction(amount: 100, date: Date(), accountId: accA, type: .expense)
        let transferIn = Transaction(amount: 500, date: Date(), accountId: accB, toAccountId: accA, type: .transfer)
        let unrelated = Transaction(amount: 50, date: Date(), accountId: accB, type: .expense)
        try await sut.record(out)
        try await sut.record(transferIn)
        try await sut.record(unrelated)

        let results = try await sut.listAll(TransactionFilter(accountIds: [accA]))
        #expect(Set(results.map(\.transaction.id)) == Set([out.id, transferIn.id]))
    }

    @Test("balance folds signedEffect: income +, expense −, transfer out −, transfer in +")
    func testBalanceSignedEffect() async throws {
        let accA = UUID().uuidString
        let accB = UUID().uuidString
        try await sut.record(Transaction(amount: 1000, date: Date(), accountId: accA, type: .income))
        try await sut.record(Transaction(amount: 300, date: Date(), accountId: accA, type: .expense))
        try await sut.record(Transaction(amount: 200, date: Date(), accountId: accA, toAccountId: accB, type: .transfer))
        try await sut.record(Transaction(amount: 50, date: Date(), accountId: accB, type: .expense))

        #expect(try await sut.balance(accA) == 500)
        #expect(try await sut.balance(accB) == 150)
    }

    @Test("search matches note text case-insensitively")
    func testSearch() async throws {
        let t1 = Transaction(id: UUID(), amount: 100, date: Date(), note: "Sushi dinner", categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        let t2 = Transaction(id: UUID(), amount: 200, date: Date(), note: "Taxi to airport", categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        let t3 = Transaction(id: UUID(), amount: 300, date: Date(), note: "Buying dinner ingredients", categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())

        try await sut.record(t1)
        try await sut.record(t2)
        try await sut.record(t3)

        let results = try await sut.search("DINNER")
        #expect(results.count == 2)
        #expect(results.contains { $0.transaction.id == t1.id })
        #expect(results.contains { $0.transaction.id == t3.id })
    }

    @Test("fetch returns a single enriched transaction by id")
    func testFetchById() async throws {
        let id = UUID()
        let t = Transaction(id: id, amount: 42, date: Date(), note: "Lookup", categoryId: nil, accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        try await sut.record(t)

        let found = try await sut.fetch(id)
        #expect(found?.transaction.id == id)
        #expect(found?.transaction.amount == 42)

        let missing = try await sut.fetch(UUID())
        #expect(missing == nil)
    }

    @Test("update mutates the persisted transaction")
    func testUpdateTransaction() async throws {
        let id = UUID()
        let t = Transaction(id: id, amount: 100, date: Date(), note: "Old Note", categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        try await sut.record(t)

        let newCat = UUID()
        let updated = Transaction(id: id, amount: 250, date: t.date, note: "New Note", categoryId: newCat, accountId: t.accountId, toAccountId: nil, type: .expense, tags: [], aiSuggested: true, createdAt: t.createdAt, updatedAt: Date())
        try await sut.update(updated)

        let row = try await sut.fetch(id)
        #expect(row?.transaction.amount == 250)
        #expect(row?.transaction.note == "New Note")
        #expect(row?.transaction.categoryId == newCat)
        #expect(row?.transaction.aiSuggested == true)
    }

    @Test("delete removes the transaction")
    func testDeleteTransaction() async throws {
        let id = UUID()
        let t = Transaction(id: id, amount: 100, date: Date(), note: "Delete me", categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        try await sut.record(t)
        #expect(try await sut.listAll(TransactionFilter()).count == 1)

        try await sut.delete(id)
        #expect(try await sut.listAll(TransactionFilter()).isEmpty)
    }

    @Test("duplicate category ids from CloudKit do not crash enrichment")
    func testDuplicateCategoriesDoNotCrash() async throws {
        // 直接經 store 寫入兩筆同 id 的分類，模擬兩台裝置各自冷啟動 seed 出
        // 預設分類、之後開啟 iCloud 同步而在同一台裝置上留下重複 id 的結果
        // （spec A4）。`SwiftDataStore.add` 不做 id 去重檢查，這個情境在正式
        // 環境確實會發生。
        let duplicatedId = UUID()
        let store = CategoryStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(
                Domain.Category(id: duplicatedId, name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
            )
            try await store.add(
                Domain.Category(id: duplicatedId, name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
            )
        }

        try await sut.record(
            Transaction(amount: 100, date: Date(), categoryId: duplicatedId,
                        accountId: UUID().uuidString, type: .expense)
        )

        // 沒有修法時這一行會在 enrich() 內的
        // Dictionary(uniqueKeysWithValues:) 直接 trap
        // （Fatal error: Duplicate values for key），讓整個測試程序掛掉而不是
        // 回傳普通的 FAIL。
        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.count == 1)
    }

    // MARK: - Accounts

    @Test("createAccount persists and listAccounts returns it")
    func testCreateAndListAccounts() async throws {
        let account = Account(id: UUID().uuidString, name: "Test Bank", type: .bank, icon: "building.2", color: "#00FF00", sortOrder: 0, isArchived: false, createdAt: Date())
        try await sut.createAccount(account)

        let accounts = try await sut.listAccounts()
        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "Test Bank")
    }

    @Test("listActiveAccounts filters out archived accounts")
    func testListActiveAccounts() async throws {
        let active = Account(id: UUID().uuidString, name: "Active", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date())
        let archived = Account(id: UUID().uuidString, name: "Archived", type: .bank, icon: "b", color: "#000", sortOrder: 1, isArchived: true, createdAt: Date())
        try await sut.createAccount(active)
        try await sut.createAccount(archived)

        #expect(try await sut.listAccounts().count == 2)
        let activeOnly = try await sut.listActiveAccounts()
        #expect(activeOnly.count == 1)
        #expect(activeOnly.first?.id == active.id)
    }

    @Test("updateAccount mutates fields")
    func testUpdateAccount() async throws {
        let id = UUID().uuidString
        let account = Account(id: id, name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date())
        try await sut.createAccount(account)

        let updated = Account(id: id, name: "Updated Bank", type: .bank, icon: "building.2", color: "#000", sortOrder: 1, isArchived: false, createdAt: account.createdAt)
        try await sut.updateAccount(updated)

        let fetched = try await sut.listAccounts().first
        #expect(fetched?.name == "Updated Bank")
        #expect(fetched?.icon == "building.2")
        #expect(fetched?.sortOrder == 1)
    }

    @Test("archiveAccount flips the flag, unarchiveAccount restores it")
    func testArchiveUnarchiveAccount() async throws {
        let id = UUID().uuidString
        let account = Account(id: id, name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date())
        try await sut.createAccount(account)

        try await sut.archiveAccount(id)
        #expect(try await sut.listActiveAccounts().isEmpty)
        #expect(try await sut.listAccounts().first?.isArchived == true)

        try await sut.unarchiveAccount(id)
        #expect(try await sut.listActiveAccounts().count == 1)
        #expect(try await sut.listAccounts().first?.isArchived == false)
    }

    @Test("archiveAccount throws notFound for an unknown id")
    func testArchiveUnknownAccountThrows() async throws {
        await #expect(throws: CoreError.self) {
            try await sut.archiveAccount(UUID().uuidString)
        }
    }

    @Test("unarchiveAccount throws notFound for an unknown id")
    func testUnarchiveUnknownAccountThrows() async throws {
        await #expect(throws: CoreError.self) {
            try await sut.unarchiveAccount(UUID().uuidString)
        }
    }

    @Test("deleteAccount removes an account with no linked transactions")
    func testDeleteAccount() async throws {
        let id = UUID().uuidString
        let account = Account(id: id, name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date())
        try await sut.createAccount(account)

        try await sut.deleteAccount(id)
        #expect(try await sut.listAccounts().isEmpty)
    }

    @Test("deleteAccount is denied when transactions reference the account")
    func testDeleteAccountWithLinkedTransactionsThrows() async throws {
        let id = UUID().uuidString
        let account = Account(id: id, name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date())
        try await sut.createAccount(account)
        try await sut.record(Transaction(id: UUID(), amount: 10, date: Date(), note: nil, categoryId: nil, accountId: id, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))

        await #expect(throws: CoreError.self) {
            try await sut.deleteAccount(id)
        }
        #expect(try await sut.listAccounts().count == 1)
    }

    // MARK: - Accounts × Recurring（task-7 / spec A7，裁定 R2）
    //
    // 週期交易現在會自動入帳（spec A2/A3），所以「封存/刪除帳戶」與「指向它的
    // 週期範本」之間的殘留狀態不再只是資料整潔問題——指向已封存帳戶的範本會
    // 持續往一個使用者已經收起來的帳戶記帳。裁定：封存時自動暫停範本並取消
    // 提醒；刪除時把範本加進既有的「有交易就擋」守衛。兩種情況都要清掉指向
    // 該帳戶的「預設帳戶」設定（iOS 端的 `.defaultAccountId` 與 Watch 端的
    // `.watchDefaultAccountId`——兩者其實是同一顆 `userSettingsAdapter` 上的
    // 不同 key，不需要動 `PlatformClient+Live.swift`）。

    /// 記錄每一通經 `syncRecurringReminder` 路由的取消呼叫。用來證明
    /// `archiveAccount` 暫停範本時重用了 `makeSyncRecurringReminder` 這顆共用
    /// 出口（`isActive == false` 會內部呼叫 `cancelRecurringReminder`），而不是
    /// 自己另外散開一條取消呼叫。（fix round 1 / J4：先前這裡還多帶了一個沒有
    /// 任何測試斷言的 `scheduled` 記錄——`createRecurring` 建範本時一定會呼叫
    /// `scheduleRecurringReminder`，但這個 suite 不驗證排程本身，只驗證暫停時
    /// 的取消，所以拿掉了那段沒用到的記錄，只留下真正被斷言的 `cancelled`。）
    final class ReminderSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _cancelled: [RecurringTransaction.ID] = []
        func recordCancel(_ id: RecurringTransaction.ID) { lock.lock(); _cancelled.append(id); lock.unlock() }
        var cancelled: [RecurringTransaction.ID] { lock.lock(); defer { lock.unlock() }; return _cancelled }
    }

    /// 有狀態的 `userSettingsAdapter` 假物件。suite 預設的 `testValue` 是無狀態
    /// 的（`setString` 是 no-op、`string` 永遠回傳該 key 的 `defaultValue`），
    /// 沒辦法驗證「寫入後讀回」——這裡需要真的驗證 `.defaultAccountId` /
    /// `.watchDefaultAccountId` 被清成空字串。
    final class UserSettingsSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: String] = [:]
        func string(_ key: SettingsKey<String>) -> String {
            lock.lock(); defer { lock.unlock() }
            return storage[key.rawValue] ?? key.defaultValue
        }
        func setString(_ value: String, _ key: SettingsKey<String>) {
            lock.lock(); storage[key.rawValue] = value; lock.unlock()
        }
    }

    /// 建一顆共用同一個 in-memory `container` 的獨立 `LedgerClient.liveValue`，
    /// 把 `notificationAdapter` 的提醒呼叫導向 spy（不導向的話，`createRecurring`
    /// 的排程呼叫與 `archiveAccount` 暫停範本後的取消呼叫會打中
    /// `@DependencyClient` 沒有預設值的 unimplemented 版本而讓測試失敗），並把
    /// `userSettingsAdapter` 換成上面的有狀態假物件。suite 既有的 `sut`（頂端
    /// `init()`）維持不動、不覆寫這兩顆依賴——現有測試都沒有觸及週期範本或預設
    /// 帳戶讀寫，不需要也不應該被這裡的變動影響。
    private func makeClient(
        reminders: ReminderSpy = ReminderSpy(),
        settings: UserSettingsSpy = UserSettingsSpy()
    ) -> LedgerClient {
        withDependencies {
            $0.persistenceBootstrap = PersistenceBootstrap(modelContainer: { container })
            $0.modelContainer = container
            $0.planningClient.evaluateAfterTransaction = { _ in }
            // createRecurring/updateRecurring 建立啟用中範本一定會排程一次，
            // 只要不打中 @DependencyClient 的 unimplemented 版本即可，這個
            // suite 不斷言排程本身（見 ReminderSpy 上的 J4 說明）。
            $0.notificationAdapter.scheduleRecurringReminder = { _, _, _, _ in }
            $0.notificationAdapter.cancelRecurringReminder = { id in reminders.recordCancel(id) }
            $0.userSettingsAdapter.string = { settings.string($0) }
            $0.userSettingsAdapter.setString = { settings.setString($0, $1) }
        } operation: {
            LedgerClient.liveValue
        }
    }

    private func makeTemplate(
        accountId: Account.ID,
        toAccountId: Account.ID? = nil,
        amount: Decimal = 100,
        type: TransactionType = .expense,
        isActive: Bool = true
    ) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(), amount: amount, note: nil, categoryId: nil,
            accountId: accountId, toAccountId: toAccountId, type: type, tags: [],
            frequency: .monthly, nextDueDate: Date(), isActive: isActive, createdAt: Date()
        )
    }

    @Test("archiving an account pauses the recurring templates that point at it and leaves others alone")
    func testArchiveAccountPausesItsTemplates() async throws {
        let accountId = UUID().uuidString
        let otherAccountId = UUID().uuidString
        let reminders = ReminderSpy()
        let client = makeClient(reminders: reminders)

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createAccount(Account(id: otherAccountId, name: "Other", type: .bank, icon: "b", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date()))

        let template1 = makeTemplate(accountId: accountId)
        let template2 = makeTemplate(accountId: accountId, amount: 200)
        let otherTemplate = makeTemplate(accountId: otherAccountId, amount: 50)
        try await client.createRecurring(template1)
        try await client.createRecurring(template2)
        try await client.createRecurring(otherTemplate)

        try await client.archiveAccount(accountId)

        let templates = try await client.listRecurring()
        #expect(templates.filter { $0.accountId == accountId }.allSatisfy { !$0.isActive },
                "指向已封存帳戶的範本必須被暫停")
        #expect(templates.first { $0.accountId == otherAccountId }?.isActive == true,
                "不相關的範本不得被動到")

        // 提醒取消重用 syncRecurringReminder 這顆共用出口（不是另外散開一條
        // cancelRecurringReminder 呼叫）——兩個被暫停的範本都該收到取消。
        #expect(Set(reminders.cancelled) == Set([template1.id, template2.id]))
        #expect(!reminders.cancelled.contains(otherTemplate.id))
    }

    @Test("archiving an account pauses a transfer template that only names it as the destination (fix round 1 / J1)")
    func testArchiveAccountPausesTransferTemplateTargetingItAsDestination() async throws {
        let accountId = UUID().uuidString
        let sourceAccountId = UUID().uuidString
        let reminders = ReminderSpy()
        let client = makeClient(reminders: reminders)

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createAccount(Account(id: sourceAccountId, name: "Source", type: .cash, icon: "b", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date()))

        // 轉帳範本的 accountId 是轉出方（sourceAccountId），accountId 完全不等於
        // 目標帳戶——只有 toAccountId 指著它。原本只查 accountId 的 filter 會
        // 整個漏掉這個範本。
        let transferTemplate = makeTemplate(accountId: sourceAccountId, toAccountId: accountId, amount: 300, type: .transfer)
        try await client.createRecurring(transferTemplate)

        try await client.archiveAccount(accountId)

        let paused = try await client.listRecurring().first { $0.id == transferTemplate.id }
        #expect(paused?.isActive == false, "只被轉帳範本當作目的帳戶的帳戶被封存時，該範本也必須被暫停")
        #expect(reminders.cancelled.contains(transferTemplate.id))
    }

    @Test("archiveAccount leaves the account unarchived when the pause loop fails partway through (fix round 2 / J2)")
    func testArchiveAccountLeavesAccountUnarchivedWhenPauseLoopFailsPartway() async throws {
        let accountId = UUID().uuidString
        let template1 = makeTemplate(accountId: accountId)
        let template2 = makeTemplate(accountId: accountId, amount: 200)

        // 注入點：`archiveAccount` 暫停迴圈裡每個項目是
        // `recurringStore.update(template)` 先跑、`syncRecurringReminder(template)`
        // 後跑，而後者對一個已經 `isActive == false` 的範本一定落進
        // `cancelRecurringReminder` 分支。所以「第一個項目的取消回呼」精確落在
        // 「第一個已提交、第二個還沒被 update」這個時間點——不需要製造任何真正
        // 的併發。`templateStore` 直接拿來在那個回呼裡把「另一個還沒被處理的
        // 範本」的 SD row 刪掉，讓第二次 `recurringStore.update` 找不到對應的
        // row 而丟 `CoreError.notFound`，藉此模擬迴圈跑到一半失敗。
        let templateStore = withDependencies {
            $0.modelContainer = container
        } operation: {
            RecurringTransactionStore()
        }

        // 不用 makeClient——它的 cancelRecurringReminder 是固定閉包，這裡需要
        // 這個特製版本。
        let client = withDependencies {
            $0.persistenceBootstrap = PersistenceBootstrap(modelContainer: { container })
            $0.modelContainer = container
            $0.planningClient.evaluateAfterTransaction = { _ in }
            $0.notificationAdapter.scheduleRecurringReminder = { _, _, _, _ in }
            $0.notificationAdapter.cancelRecurringReminder = { id in
                // 不用猜哪個先跑，對稱處理即可：把「不是這次被取消的那個」
                // 範本的 row 刪掉，讓迴圈跑到它時失敗。
                let otherId = id == template1.id ? template2.id : template1.id
                try? await templateStore.delete(id: otherId)
            }
        } operation: {
            LedgerClient.liveValue
        }

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createRecurring(template1)
        try await client.createRecurring(template2)

        await #expect(throws: CoreError.self) {
            try await client.archiveAccount(accountId)
        }

        // J2 的核心：終態（isArchived）寫在暫停迴圈之後，中途失敗不該留下
        // 「已封存」的帳戶——使用者只要重新按一次「封存」就能補跑，不會卡進
        // 「已封存但選單只有取消封存/刪除、沒有再封存一次」的死角。
        let account = try await client.listAccounts().first { $0.id == accountId }
        #expect(account?.isArchived == false, "暫停迴圈中途失敗時，帳戶不該被標成已封存")

        // 鑑別力：至少一個範本真的被暫停了，證明真的是跑到一半才失敗，不是
        // 整批都沒跑——否則就算 isArchived 被誤移回迴圈前面，這條測試也可能
        // 誤綠。
        let remaining = try await client.listRecurring()
        #expect(remaining.contains { $0.isActive == false },
                "至少一個範本應該已經被暫停過，證明迴圈真的跑到一半才失敗")
    }

    @Test("deleting an account a recurring template points at is denied")
    func testDeleteAccountWithTemplateIsDenied() async throws {
        let accountId = UUID().uuidString
        let client = makeClient()

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createRecurring(makeTemplate(accountId: accountId))

        await #expect(throws: CoreError.self) {
            try await client.deleteAccount(accountId)
        }
        // 擋下來之後帳戶還在——跟既有「有交易就擋」的行為（testDeleteAccountWithLinkedTransactionsThrows）對稱。
        #expect(try await client.listAccounts().count == 1)
    }

    @Test("deleting an account a transfer template only names as the destination is denied (fix round 1 / J1)")
    func testDeleteAccountWithTransferTemplateTargetingItAsDestinationIsDenied() async throws {
        let accountId = UUID().uuidString
        let sourceAccountId = UUID().uuidString
        let client = makeClient()

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createAccount(Account(id: sourceAccountId, name: "Source", type: .cash, icon: "b", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date()))
        try await client.createRecurring(makeTemplate(accountId: sourceAccountId, toAccountId: accountId, amount: 300, type: .transfer))

        await #expect(throws: CoreError.self) {
            try await client.deleteAccount(accountId)
        }
        #expect(try await client.listAccounts().count == 2)
    }

    @Test("deleting an account whose templates were already paused by archiving is still denied (fix round 1 / J3)")
    func testDeleteAccountStillDeniedAfterItsTemplatesWerePaused() async throws {
        // 使用者照 UI 引導先封存（範本被自動暫停）、再嘗試刪除——守衛必須連
        // 已暫停的範本也擋，因為它一旦被重新啟用就會立刻往不存在的帳戶記帳
        // （跟 Task 6「連停用的預算也要擋刪除分類」同一個道理）。這條測試釘住
        // 「封存之後刪除仍被擋」這個兩個裁定交互作用出的行為，避免後人以為
        // 「範本反正已經暫停了，擋它沒意義」而順手放寬守衛。
        let accountId = UUID().uuidString
        let client = makeClient()

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createRecurring(makeTemplate(accountId: accountId))

        try await client.archiveAccount(accountId)
        let paused = try await client.listRecurring().first
        #expect(paused?.isActive == false, "前置條件：範本應已被封存動作暫停")

        await #expect(throws: CoreError.self) {
            try await client.deleteAccount(accountId)
        }
        #expect(try await client.listAccounts().count == 1)
    }

    @Test("deleting an account with no linked templates still succeeds")
    func testDeleteAccountWithNoTemplatesSucceeds() async throws {
        let accountId = UUID().uuidString
        let otherAccountId = UUID().uuidString
        let client = makeClient()

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        // 一個指向「別的」帳戶的範本不該影響這次刪除。
        try await client.createRecurring(makeTemplate(accountId: otherAccountId))

        try await client.deleteAccount(accountId)
        #expect(try await client.listAccounts().isEmpty)
    }

    @Test("archiving the default account clears both the iOS and Watch stored defaults")
    func testDefaultAccountIsClearedOnArchive() async throws {
        let accountId = UUID().uuidString
        let otherAccountId = UUID().uuidString
        let settings = UserSettingsSpy()
        let client = makeClient(settings: settings)

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await client.createAccount(Account(id: otherAccountId, name: "Other", type: .bank, icon: "b", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date()))
        client.setDefaultAccountId(accountId)
        // Watch 端沒有經由這個 Client 寫入的 API（那是 PlatformClient 的事），
        // 但兩者共用同一顆 userSettingsAdapter，直接戳 key 模擬 Watch 已經存了值。
        settings.setString(accountId, .watchDefaultAccountId)
        #expect(client.defaultAccountId() == accountId)

        try await client.archiveAccount(accountId)

        #expect(client.defaultAccountId() == nil, "封存後預設帳戶必須被清成 nil")
        #expect(settings.string(.watchDefaultAccountId) == "", "Watch 端的預設帳戶設定也必須被清掉")

        // 反向斷言：封存一個「不是」預設帳戶的帳戶，不該動到既有的預設帳戶設定。
        client.setDefaultAccountId(otherAccountId)
        let thirdId = UUID().uuidString
        try await client.createAccount(Account(id: thirdId, name: "Third", type: .bank, icon: "c", color: "#111", sortOrder: 2, isArchived: false, createdAt: Date()))
        try await client.archiveAccount(thirdId)
        #expect(client.defaultAccountId() == otherAccountId)
    }

    @Test("deleting the default account clears both the iOS and Watch stored defaults")
    func testDefaultAccountIsClearedOnDelete() async throws {
        let accountId = UUID().uuidString
        let settings = UserSettingsSpy()
        let client = makeClient(settings: settings)

        try await client.createAccount(Account(id: accountId, name: "Target", type: .bank, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        client.setDefaultAccountId(accountId)
        settings.setString(accountId, .watchDefaultAccountId)

        try await client.deleteAccount(accountId)

        #expect(client.defaultAccountId() == nil, "刪除後預設帳戶必須被清成 nil")
        #expect(settings.string(.watchDefaultAccountId) == "", "Watch 端的預設帳戶設定也必須被清掉")
    }

    @Test("balance aggregates income, expense, and both transfer directions")
    func testBalance() async throws {
        let accountId = UUID().uuidString
        let otherId = UUID().uuidString
        let categoryId = UUID()
        try await sut.createAccount(Account(id: accountId, name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))

        try await sut.record(Transaction(id: UUID(), amount: 500, date: Date(), note: "", categoryId: categoryId, accountId: accountId, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))
        try await sut.record(Transaction(id: UUID(), amount: 1000, date: Date(), note: "", categoryId: categoryId, accountId: accountId, toAccountId: nil, type: .income, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))
        try await sut.record(Transaction(id: UUID(), amount: 200, date: Date(), note: "", categoryId: categoryId, accountId: otherId, toAccountId: accountId, type: .transfer, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))
        try await sut.record(Transaction(id: UUID(), amount: 100, date: Date(), note: "", categoryId: categoryId, accountId: accountId, toAccountId: otherId, type: .transfer, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))

        #expect(try await sut.balance(accountId) == 600)
    }

    @Test("balances returns per-active-account aggregates and skips archived accounts")
    func testBalances() async throws {
        let a1 = UUID().uuidString
        let a2 = UUID().uuidString
        let archived = UUID().uuidString
        try await sut.createAccount(Account(id: a1, name: "A1", type: .cash, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()))
        try await sut.createAccount(Account(id: a2, name: "A2", type: .cash, icon: "b", color: "#FFF", sortOrder: 1, isArchived: false, createdAt: Date()))
        try await sut.createAccount(Account(id: archived, name: "Old", type: .cash, icon: "c", color: "#FFF", sortOrder: 2, isArchived: true, createdAt: Date()))

        try await sut.record(Transaction(id: UUID(), amount: 300, date: Date(), note: "", categoryId: nil, accountId: a1, toAccountId: nil, type: .income, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))
        try await sut.record(Transaction(id: UUID(), amount: 50, date: Date(), note: "", categoryId: nil, accountId: a2, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))

        let balances = try await sut.balances()
        #expect(balances[a1] == 300)
        #expect(balances[a2] == -50)
        #expect(balances[archived] == nil)
    }

    @Test("setupAccounts inserts new accounts and skips ids that already exist")
    func testSetupAccountsInsertsAndDeduplicates() async throws {
        let existing = Account(id: UUID().uuidString, name: "Existing", type: .cash, icon: "a", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date())
        try await sut.createAccount(existing)

        let fresh = Account(id: UUID().uuidString, name: "Fresh", type: .bank, icon: "b", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date())
        // Pass both the already-persisted account and a new one; only the new
        // one should be inserted (no duplicate of `existing`).
        try await sut.setupAccounts([existing, fresh])

        let all = try await sut.listAccounts()
        #expect(all.count == 2)
        #expect(all.contains { $0.id == existing.id })
        #expect(all.contains { $0.id == fresh.id })
    }

    /// Records every `setBool` key written through `userSettingsAdapter`.
    /// Synchronous (lock-protected) so the non-async `setBool` closure records
    /// on the calling thread — a deferred actor `Task` could let the negative
    /// assertion pass before a regression's write was observed.
    final class BoolWriteSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _keys: [String] = []
        func record(_ key: String) {
            lock.lock(); _keys.append(key); lock.unlock()
        }
        var keys: [String] {
            lock.lock(); defer { lock.unlock() }
            return _keys
        }
    }

    @Test("setupAccounts no longer writes the hasCompletedOnboarding flag (behaviour micro-adjustment)")
    func testSetupAccountsDoesNotWriteOnboardingFlag() async throws {
        let spy = BoolWriteSpy()
        let testPersistenceBootstrap = PersistenceBootstrap(modelContainer: { container })

        // Build a dedicated client whose userSettingsAdapter spies on setBool,
        // so we can assert the old cross-domain `.hasCompletedOnboarding` write
        // (formerly in AccountClient+Live.setupAccounts) is gone. The flag now
        // belongs to Platform and OnboardingFeature sets it explicitly.
        let spyClient = withDependencies {
            $0.persistenceBootstrap = testPersistenceBootstrap
            $0.modelContainer = container
            $0.planningClient.evaluateAfterTransaction = { _ in }
            $0.userSettingsAdapter.setBool = { _, key in
                spy.record(key.rawValue)
            }
        } operation: {
            LedgerClient.liveValue
        }

        let account = Account(id: UUID().uuidString, name: "Fresh", type: .bank, icon: "b", color: "#000", sortOrder: 0, isArchived: false, createdAt: Date())
        try await spyClient.setupAccounts([account])

        #expect(!spy.keys.contains(SettingsKey<Bool>.hasCompletedOnboarding.rawValue))
        // And the account itself was still inserted.
        #expect(try await spyClient.listAccounts().count == 1)
    }

    // MARK: - Catalog (Categories)

    @Test("createCategory persists and listCategories returns it sorted")
    func testCreateAndListCategories() async throws {
        let income = Domain.Category(id: UUID(), name: "Salary", icon: "dollarsign", color: "#0F0", type: .income, sortOrder: 1, isDefault: false)
        let expense = Domain.Category(id: UUID(), name: "Food", icon: "fork.knife", color: "#F00", type: .expense, sortOrder: 0, isDefault: false)
        try await sut.createCategory(income)
        try await sut.createCategory(expense)

        let all = try await sut.listCategories(nil)
        #expect(all.count == 2)
        // Sorted by sortOrder ascending.
        #expect(all.first?.name == "Food")
    }

    @Test("listCategories filters by transaction type")
    func testListCategoriesByType() async throws {
        let income = Domain.Category(id: UUID(), name: "Salary", icon: "dollarsign", color: "#0F0", type: .income, sortOrder: 0, isDefault: false)
        let expense = Domain.Category(id: UUID(), name: "Food", icon: "fork.knife", color: "#F00", type: .expense, sortOrder: 1, isDefault: false)
        try await sut.createCategory(income)
        try await sut.createCategory(expense)

        let expenses = try await sut.listCategories(.expense)
        #expect(expenses.count == 1)
        #expect(expenses.first?.type == .expense)
    }

    @Test("updateCategory mutates the persisted category")
    func testUpdateCategory() async throws {
        let id = UUID()
        try await sut.createCategory(Domain.Category(id: id, name: "Old", icon: "a", color: "#F00", type: .expense, sortOrder: 0, isDefault: false))

        try await sut.updateCategory(Domain.Category(id: id, name: "New", icon: "b", color: "#00F", type: .expense, sortOrder: 2, isDefault: false))

        let fetched = try await sut.listCategories(nil).first
        #expect(fetched?.name == "New")
        #expect(fetched?.icon == "b")
        #expect(fetched?.sortOrder == 2)
    }

    @Test("deleteCategory removes a non-default category")
    func testDeleteCategory() async throws {
        let id = UUID()
        try await sut.createCategory(Domain.Category(id: id, name: "Temp", icon: "a", color: "#F00", type: .expense, sortOrder: 0, isDefault: false))
        #expect(try await sut.listCategories(nil).count == 1)

        try await sut.deleteCategory(id)
        #expect(try await sut.listCategories(nil).isEmpty)
    }

    @Test("deleteCategory is denied for a default category")
    func testDeleteDefaultCategoryThrows() async throws {
        let id = UUID()
        try await sut.createCategory(Domain.Category(id: id, name: "Default", icon: "a", color: "#F00", type: .expense, sortOrder: 0, isDefault: true))

        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(id)
        }
        // Still present after the denied delete.
        #expect(try await sut.listCategories(nil).count == 1)
    }

    @Test("deleteCategory throws notFound for an unknown id")
    func testDeleteUnknownCategoryThrows() async throws {
        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(UUID())
        }
    }

    // MARK: - Catalog (Tags)

    @Test("createTag persists and listTags returns it sorted by name")
    func testCreateAndListTags() async throws {
        try await sut.createTag(Tag(id: UUID(), name: "Zebra", color: "#000"))
        try await sut.createTag(Tag(id: UUID(), name: "Apple", color: "#FFF"))

        let tags = try await sut.listTags()
        #expect(tags.count == 2)
        // Sorted by name ascending.
        #expect(tags.first?.name == "Apple")
    }

    @Test("updateTag mutates the persisted tag")
    func testUpdateTag() async throws {
        let id = UUID()
        try await sut.createTag(Tag(id: id, name: "Old", color: "#000"))

        try await sut.updateTag(Tag(id: id, name: "New", color: "#FFF"))

        let fetched = try await sut.listTags().first
        #expect(fetched?.name == "New")
        #expect(fetched?.color == "#FFF")
    }

    @Test("deleteTag removes the tag")
    func testDeleteTag() async throws {
        let id = UUID()
        try await sut.createTag(Tag(id: id, name: "Temp", color: "#000"))
        #expect(try await sut.listTags().count == 1)

        try await sut.deleteTag(id)
        #expect(try await sut.listTags().isEmpty)
    }

    @Test("deleteTag disassociates the tag from every linked transaction")
    func testDeleteTagDisassociatesFromTransactions() async throws {
        let tagId = UUID()
        let tag = Tag(id: tagId, name: "Travel", color: "#00F")
        try await sut.createTag(tag)

        let txId = UUID()
        try await sut.record(Transaction(id: txId, amount: 100, date: Date(), note: "Flight", categoryId: nil, accountId: UUID().uuidString, toAccountId: nil, type: .expense, tags: [tag], aiSuggested: false, createdAt: Date(), updatedAt: Date()))
        // Sanity: the transaction carries the tag.
        #expect(try await sut.fetch(txId)?.transaction.tags.contains { $0.id == tagId } == true)

        try await sut.deleteTag(tagId)

        // The transaction survives, but no longer references the deleted tag.
        let row = try await sut.fetch(txId)
        #expect(row != nil)
        #expect(row?.transaction.tags.contains { $0.id == tagId } == false)
    }

    // MARK: - Export

    @Test("exportCSV writes a header plus one row per transaction with resolved names")
    func testExportCSV() async throws {
        let categoryId = UUID()
        let accountId = UUID().uuidString
        try await sut.createCategory(Domain.Category(id: categoryId, name: "Food", icon: "fork.knife", color: "#F00", type: .expense, sortOrder: 0, isDefault: false))
        try await sut.createAccount(Account(id: accountId, name: "Cash", type: .cash, icon: "banknote", color: "#0F0", sortOrder: 0, isArchived: false, createdAt: Date()))

        try await sut.record(Transaction(id: UUID(), amount: 250, date: Date(timeIntervalSince1970: 0), note: "Lunch", categoryId: categoryId, accountId: accountId, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))

        let url = try await sut.exportCSV()
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2) // header + 1 transaction
        // Expense amounts are negated; account/category names resolved.
        #expect(contents.contains("-250"))
        #expect(contents.contains("Cash"))
    }

    @Test("exportCSV escapes fields containing commas per RFC 4180")
    func testExportCSVEscaping() async throws {
        let accountId = UUID().uuidString
        try await sut.createAccount(Account(id: accountId, name: "Cash", type: .cash, icon: "banknote", color: "#0F0", sortOrder: 0, isArchived: false, createdAt: Date()))

        try await sut.record(Transaction(id: UUID(), amount: 100, date: Date(timeIntervalSince1970: 0), note: "Lunch, dinner", categoryId: nil, accountId: accountId, toAccountId: nil, type: .income, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()))

        let url = try await sut.exportCSV()
        let contents = try String(contentsOf: url, encoding: .utf8)
        // The note containing a comma must be wrapped in quotes.
        #expect(contents.contains("\"Lunch, dinner\""))
    }
}
