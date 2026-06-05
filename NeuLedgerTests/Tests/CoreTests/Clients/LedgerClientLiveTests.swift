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
        #expect(results.allSatisfy { $0.transaction.accountId == acc1 })

        results = try await sut.listAll(TransactionFilter(tagIds: [tag1.id]))
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.transaction.tags.contains { $0.id == tag1.id } })

        results = try await sut.listAll(TransactionFilter(types: [.income]))
        #expect(results.count == 1)
        #expect(results.first?.transaction.type == .income)

        results = try await sut.listAll(TransactionFilter(dateRange: now.addingTimeInterval(-86400*1.5)...now.addingTimeInterval(86400)))
        #expect(results.count == 2)
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
