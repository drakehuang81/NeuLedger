import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("LedgerClient Domain Tests")
struct LedgerClientTests {

    @Test("LedgerClient testValue is accessible via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.ledgerClient) var client
        #expect(true, "LedgerClient injected successfully")
    }

    // MARK: - Transactions

    @Test("record / update / delete mock override")
    func testTransactionMutationsMock() async throws {
        try await withDependencies {
            $0.ledgerClient.record = { _ in }
            $0.ledgerClient.update = { _ in }
            $0.ledgerClient.delete = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            try await client.record(Self.sampleTransaction)
            try await client.update(Self.sampleTransaction)
            try await client.delete(Self.sampleTransaction.id)
        }
    }

    @Test("fetch mock override")
    func testFetchMock() async throws {
        let enriched = EnrichedTransaction(transaction: Self.sampleTransaction)
        try await withDependencies {
            $0.ledgerClient.fetch = { _ in enriched }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let result = try await client.fetch(Self.sampleTransaction.id)
            #expect(result == enriched)
        }
    }

    @Test("listRecent / listAll / search mock override")
    func testTransactionReadsMock() async throws {
        let enriched = EnrichedTransaction(transaction: Self.sampleTransaction)
        try await withDependencies {
            $0.ledgerClient.listRecent = { _ in [enriched] }
            $0.ledgerClient.listAll = { _ in [enriched] }
            $0.ledgerClient.search = { _ in [enriched] }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let recent = try await client.listRecent(10)
            let all = try await client.listAll(TransactionFilter())
            let searched = try await client.search("coffee")
            #expect(recent == [enriched])
            #expect(all == [enriched])
            #expect(searched == [enriched])
        }
    }

    // MARK: - Accounts

    @Test("setupAccounts / createAccount / updateAccount mock override")
    func testAccountWritesMock() async throws {
        try await withDependencies {
            $0.ledgerClient.setupAccounts = { _ in }
            $0.ledgerClient.createAccount = { _ in }
            $0.ledgerClient.updateAccount = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            try await client.setupAccounts([Self.sampleAccount])
            try await client.createAccount(Self.sampleAccount)
            try await client.updateAccount(Self.sampleAccount)
        }
    }

    @Test("archiveAccount / unarchiveAccount / deleteAccount mock override")
    func testAccountLifecycleMock() async throws {
        try await withDependencies {
            $0.ledgerClient.archiveAccount = { _ in }
            $0.ledgerClient.unarchiveAccount = { _ in }
            $0.ledgerClient.deleteAccount = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            try await client.archiveAccount(Self.sampleAccount.id)
            try await client.unarchiveAccount(Self.sampleAccount.id)
            try await client.deleteAccount(Self.sampleAccount.id)
        }
    }

    @Test("listAccounts / listActiveAccounts mock override")
    func testAccountReadsMock() async throws {
        try await withDependencies {
            $0.ledgerClient.listAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.listActiveAccounts = { [Self.sampleAccount] }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let all = try await client.listAccounts()
            let active = try await client.listActiveAccounts()
            #expect(all == [Self.sampleAccount])
            #expect(active == [Self.sampleAccount])
        }
    }

    @Test("balance / balances mock override")
    func testBalancesMock() async throws {
        try await withDependencies {
            $0.ledgerClient.balance = { _ in 1234 }
            $0.ledgerClient.balances = { [Self.sampleAccount.id: 1234] }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let single = try await client.balance(Self.sampleAccount.id)
            let all = try await client.balances()
            #expect(single == 1234)
            #expect(all == [Self.sampleAccount.id: 1234])
        }
    }

    @Test("defaultAccountId / setDefaultAccountId mock override")
    func testDefaultAccountIdMock() {
        withDependencies {
            $0.ledgerClient.defaultAccountId = { "acc-1" }
            $0.ledgerClient.setDefaultAccountId = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            #expect(client.defaultAccountId() == "acc-1")
            client.setDefaultAccountId(nil)
        }
    }

    // MARK: - Catalog

    @Test("listCategories / createCategory / updateCategory / deleteCategory mock override")
    func testCategoryMock() async throws {
        try await withDependencies {
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.ledgerClient.createCategory = { _ in }
            $0.ledgerClient.updateCategory = { _ in }
            $0.ledgerClient.deleteCategory = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let categories = try await client.listCategories(.expense)
            #expect(categories == [Self.sampleCategory])
            try await client.createCategory(Self.sampleCategory)
            try await client.updateCategory(Self.sampleCategory)
            try await client.deleteCategory(Self.sampleCategory.id)
        }
    }

    @Test("listTags / createTag / updateTag / deleteTag mock override")
    func testTagMock() async throws {
        try await withDependencies {
            $0.ledgerClient.listTags = { [Self.sampleTag] }
            $0.ledgerClient.createTag = { _ in }
            $0.ledgerClient.updateTag = { _ in }
            $0.ledgerClient.deleteTag = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let tags = try await client.listTags()
            #expect(tags == [Self.sampleTag])
            try await client.createTag(Self.sampleTag)
            try await client.updateTag(Self.sampleTag)
            try await client.deleteTag(Self.sampleTag.id)
        }
    }

    // MARK: - Recurring

    @Test("listRecurring / createRecurring / updateRecurring / deleteRecurring mock override")
    func testRecurringMock() async throws {
        try await withDependencies {
            $0.ledgerClient.listRecurring = { [Self.sampleRecurring] }
            $0.ledgerClient.createRecurring = { _ in }
            $0.ledgerClient.updateRecurring = { _ in }
            $0.ledgerClient.deleteRecurring = { _ in }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let recurring = try await client.listRecurring()
            #expect(recurring == [Self.sampleRecurring])
            try await client.createRecurring(Self.sampleRecurring)
            try await client.updateRecurring(Self.sampleRecurring)
            try await client.deleteRecurring(Self.sampleRecurring.id)
        }
    }

    @Test("tick mock override")
    func testTickMock() async throws {
        try await withDependencies {
            $0.ledgerClient.tick = { }
        } operation: {
            @Dependency(\.ledgerClient) var client
            try await client.tick()
        }
    }

    // MARK: - Export

    @Test("exportCSV mock override")
    func testExportCSVMock() async throws {
        let url = URL(fileURLWithPath: "/tmp/ledger.csv")
        try await withDependencies {
            $0.ledgerClient.exportCSV = { url }
        } operation: {
            @Dependency(\.ledgerClient) var client
            let result = try await client.exportCSV()
            #expect(result == url)
        }
    }

    // MARK: - Fixtures

    static let sampleAccount = Account(
        id: "acc-1",
        name: "Cash",
        type: .cash,
        icon: "banknote",
        color: "#FF9500",
        sortOrder: 0,
        isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    static let sampleCategory = Category(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
        name: "Food",
        icon: "fork.knife",
        color: "#FF3B30",
        type: .expense,
        sortOrder: 0,
        isDefault: true
    )

    static let sampleTag = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        name: "Work",
        color: "#34C759"
    )

    static let sampleTransaction = Transaction(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000E1")!,
        amount: 100,
        date: Date(timeIntervalSince1970: 0),
        note: "Lunch",
        categoryId: sampleCategory.id,
        accountId: sampleAccount.id,
        toAccountId: nil,
        type: .expense,
        tags: [],
        aiSuggested: false,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let sampleRecurring = RecurringTransaction(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000F1")!,
        amount: 500,
        note: "Rent",
        categoryId: sampleCategory.id,
        accountId: sampleAccount.id,
        toAccountId: nil,
        type: .expense,
        tags: [],
        frequency: .monthly,
        nextDueDate: Date(timeIntervalSince1970: 0),
        isActive: true,
        createdAt: Date(timeIntervalSince1970: 0)
    )
}

/// Entity-level behaviour for `RecurringTransaction` — preserved when the
/// standalone `RecurringTransactionClient` (and its Domain test suite) was
/// retired in favour of `LedgerClient`. Covers Codable round-trip and the
/// `nextDate(after:)` advance for every `BudgetPeriod` frequency.
@Suite("RecurringTransaction Entity Tests")
struct RecurringTransactionEntityTests {

    @Test("RecurringTransaction Codable round-trip preserves all fields")
    func testCodableRoundTrip() throws {
        let base = Date(timeIntervalSince1970: 0)
        let original = RecurringTransaction(
            id: UUID(), amount: 5000, note: "月租",
            categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurringTransaction.self, from: data)
        #expect(decoded == original)
    }

    @Test("nextDate weekly advances by 7 days")
    func testNextDateWeekly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .weekly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: base)!
        #expect(next == expected)
    }

    @Test("nextDate monthly advances by 1 month")
    func testNextDateMonthly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .monthly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: base)!
        #expect(next == expected)
    }

    @Test("nextDate yearly advances by 1 year")
    func testNextDateYearly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .yearly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .year, value: 1, to: base)!
        #expect(next == expected)
    }
}
