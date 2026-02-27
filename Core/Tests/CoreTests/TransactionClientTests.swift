import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("TransactionClient Integration Tests")
struct TransactionClientTests {
    var container: ModelContainer
    var context: ModelContext
    
    var sut: TransactionClient

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
        self.context = ModelContext(_container)
        
        let testDatabaseClient = DatabaseClient(modelContainer: { _container })
        
        self.sut = withDependencies {
            $0.databaseClient = testDatabaseClient
        } operation: {
            TransactionClient.liveValue
        }
    }

    @Test("Add transaction")
    func testAddTransaction() async throws {
        let tag = Tag(id: UUID(), name: "Travel", color: "#FFF")
        let transaction = Transaction(
            id: UUID(),
            amount: 1500,
            date: Date(),
            note: "Flight tickets",
            categoryId: UUID(),
            accountId: UUID(),
            toAccountId: nil,
            type: .expense,
            tags: [tag],
            aiSuggested: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await sut.add(transaction)
        
        let fetched = try await sut.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.amount == 1500)
        #expect(fetched.first?.note == "Flight tickets")
        #expect(fetched.first?.tags.count == 1)
        #expect(fetched.first?.tags.first?.name == "Travel")
    }
    
    @Test("Fetch all transactions sorted by date descending")
    func testFetchAllTransactions() async throws {
        let now = Date()
        let t1 = Transaction(id: UUID(), amount: 100, date: now.addingTimeInterval(-86400), note: "Yesterday", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: now, updatedAt: now)
        let t2 = Transaction(id: UUID(), amount: 200, date: now, note: "Today", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: now, updatedAt: now)
        
        try await sut.add(t1)
        try await sut.add(t2)
        
        let fetched = try await sut.fetchAll()
        #expect(fetched.count == 2)
        #expect(fetched[0].note == "Today")
        #expect(fetched[1].note == "Yesterday")
    }

    @Test("Fetch recent transactions with limit")
    func testFetchRecent() async throws {
        for i in 0..<25 {
            let t = Transaction(
                id: UUID(), amount: Decimal(i), date: Date(timeIntervalSince1970: TimeInterval(i * 1000)),
                note: "Note \(i)", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
            )
            try await sut.add(t)
        }
        
        // Should limit to 20
        let recent = try await sut.fetchRecent()
        #expect(recent.count == 20)
        
        // The most recent (highest date) should be first
        #expect(recent.first?.amount == 24.0)
    }

    @Test("Fetch transactions by filter criteria")
    func testFetchWithFilter() async throws {
        let cat1 = UUID()
        let cat2 = UUID()
        let acc1 = UUID()
        let acc2 = UUID()
        let tag1 = Tag(id: UUID(), name: "Tag 1", color: "#FFF")
        let now = Date()
        
        let t1 = Transaction(id: UUID(), amount: 100, date: now.addingTimeInterval(-86400*2), note: "A", categoryId: cat1, accountId: acc1, toAccountId: nil, type: .expense, tags: [tag1], aiSuggested: false, createdAt: now, updatedAt: now)
        let t2 = Transaction(id: UUID(), amount: 200, date: now.addingTimeInterval(-86400), note: "B", categoryId: cat1, accountId: acc2, toAccountId: nil, type: .income, tags: [], aiSuggested: false, createdAt: now, updatedAt: now)
        let t3 = Transaction(id: UUID(), amount: 300, date: now, note: "C", categoryId: cat2, accountId: acc1, toAccountId: nil, type: .expense, tags: [tag1], aiSuggested: false, createdAt: now, updatedAt: now)
        
        try await sut.add(t1)
        try await sut.add(t2)
        try await sut.add(t3)
        
        // 1. Filter by Category
        var filter = TransactionFilter(categoryIds: [cat1])
        var results = try await sut.fetch(filter)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.categoryId == cat1 })
        
        // 2. Filter by Account
        filter = TransactionFilter(accountIds: [acc1])
        results = try await sut.fetch(filter)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.accountId == acc1 })
        
        // 3. Filter by Tag
        filter = TransactionFilter(tagIds: [tag1.id])
        results = try await sut.fetch(filter)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.tags.contains(where: { $0.id == tag1.id }) })
        
        // 4. Filter by Type
        filter = TransactionFilter(types: [.income])
        results = try await sut.fetch(filter)
        #expect(results.count == 1)
        #expect(results.first?.type == .income)
        
        // 5. Date Range
        filter = TransactionFilter(dateRange: now.addingTimeInterval(-86400*1.5)...now.addingTimeInterval(86400))
        results = try await sut.fetch(filter)
        #expect(results.count == 2) // t2, t3
    }
    
    @Test("Search transactions by note text")
    func testSearchTransactions() async throws {
        let t1 = Transaction(id: UUID(), amount: 100, date: Date(), note: "Sushi dinner", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        let t2 = Transaction(id: UUID(), amount: 200, date: Date(), note: "Taxi to airport", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        let t3 = Transaction(id: UUID(), amount: 300, date: Date(), note: "Buying dinner ingredients", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date())
        
        try await sut.add(t1)
        try await sut.add(t2)
        try await sut.add(t3)
        
        // Case-insensitive search
        let results = try await sut.search("DINNER")
        #expect(results.count == 2)
        #expect(results.contains(where: { $0.id == t1.id }))
        #expect(results.contains(where: { $0.id == t3.id }))
    }

    @Test("Update transaction fields correctly")
    func testUpdateTransaction() async throws {
        let transaction = Transaction(
            id: UUID(), amount: 100, date: Date(), note: "Old Note", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        )
        try await sut.add(transaction)
        
        let newCat = UUID()
        let updatedTransaction = Transaction(
            id: transaction.id, amount: 250, date: transaction.date, note: "New Note", categoryId: newCat, accountId: transaction.accountId, toAccountId: nil, type: .expense, tags: [], aiSuggested: true, createdAt: transaction.createdAt, updatedAt: Date()
        )
        
        try await sut.update(updatedTransaction)
        let results = try await sut.fetchAll()
        
        #expect(results.first?.amount == 250)
        #expect(results.first?.note == "New Note")
        #expect(results.first?.categoryId == newCat)
        #expect(results.first?.aiSuggested == true)
    }
    
    @Test("Delete transaction removes from database")
    func testDeleteTransaction() async throws {
        let transaction = Transaction(
            id: UUID(), amount: 100, date: Date(), note: "Delete me", categoryId: UUID(), accountId: UUID(), toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        )
        try await sut.add(transaction)
        
        #expect(try await sut.fetchAll().count == 1)
        
        try await sut.delete(transaction.id)
        
        #expect(try await sut.fetchAll().isEmpty)
    }
}
