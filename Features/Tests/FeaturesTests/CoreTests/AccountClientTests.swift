import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("AccountClient Integration Tests")
struct AccountClientTests {
    var container: ModelContainer
    var context: ModelContext
    
    // System under test
    var sut: AccountClient
    var transactionClient: TransactionClient

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
        
        // Inject test DatabaseClient into the clients
        self.sut = withDependencies {
            $0.databaseClient = testDatabaseClient
        } operation: {
            AccountClient.liveValue
        }
        
        self.transactionClient = withDependencies {
            $0.databaseClient = testDatabaseClient
        } operation: {
            TransactionClient.liveValue
        }
    }

    @Test("Add account")
    func testAddAccount() async throws {
        let newAccount = Account(
            id: UUID(),
            name: "Test Bank",
            type: .bank,
            icon: "building.2",
            color: "#00FF00",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date()
        )
        
        try await sut.add(newAccount)
        
        let accounts = try await sut.fetchAll()
        #expect(accounts.count == 1)
        #expect(accounts.first?.id == newAccount.id)
        #expect(accounts.first?.name == "Test Bank")
    }
    
    @Test("Fetch active accounts filters out archived accounts")
    func testFetchActiveAccounts() async throws {
        let activeAccount = Account(
            id: UUID(), name: "Active Bank", type: .bank, icon: "active", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()
        )
        let archivedAccount = Account(
            id: UUID(), name: "Archived Bank", type: .bank, icon: "archived", color: "#000", sortOrder: 1, isArchived: true, createdAt: Date()
        )
        
        try await sut.add(activeAccount)
        try await sut.add(archivedAccount)
        
        let allAccounts = try await sut.fetchAll()
        #expect(allAccounts.count == 2)
        
        let activeAccounts = try await sut.fetchActive()
        #expect(activeAccounts.count == 1)
        #expect(activeAccounts.first?.id == activeAccount.id)
    }

    @Test("Update account properties")
    func testUpdateAccount() async throws {
        let account = Account(
            id: UUID(), name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()
        )
        try await sut.add(account)
        
        let updatedAccount = Account(
            id: account.id, name: "Updated Bank", type: .bank, icon: "building.2", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date()
        )
        try await sut.update(updatedAccount)
        
        let fetchedAccount = try await sut.fetchAll().first
        #expect(fetchedAccount?.name == "Updated Bank")
        #expect(fetchedAccount?.icon == "building.2")
        #expect(fetchedAccount?.color == "#000")
        #expect(fetchedAccount?.sortOrder == 1)
    }

    @Test("Archive account")
    func testArchiveAccount() async throws {
        let account = Account(
            id: UUID(), name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()
        )
        try await sut.add(account)
        
        try await sut.archive(account.id)
        
        let activeAccounts = try await sut.fetchActive()
        #expect(activeAccounts.isEmpty)
        
        let allAccounts = try await sut.fetchAll()
        #expect(allAccounts.first?.isArchived == true)
        
        // Unarchive using update
        var modifiedAccount = account
        modifiedAccount.isArchived = false
        try await sut.update(modifiedAccount)
        let activeAccountsRetry = try await sut.fetchActive()
        #expect(activeAccountsRetry.count == 1)
    }
    
    @Test("Delete account removes from database")
    func testDeleteAccount() async throws {
        let account = Account(
            id: UUID(), name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()
        )
        try await sut.add(account)
        
        try await sut.delete(account.id)
        
        let accounts = try await sut.fetchAll()
        #expect(accounts.isEmpty)
    }
    
    @Test("Compute balance correctly aggregates transactions")
    func testComputeBalance() async throws {
        let accountId = UUID()
        let anotherAccountId = UUID()
        let categoryId = UUID()
        
        let account = Account(
            id: accountId, name: "Test Bank", type: .bank, icon: "building", color: "#FFF", sortOrder: 0, isArchived: false, createdAt: Date()
        )
        try await sut.add(account)
        
        // 1. Expense: -500
        try await transactionClient.add(Transaction(
            id: UUID(), amount: Decimal(500), date: Date(), note: "", categoryId: categoryId,
            accountId: accountId, toAccountId: nil, type: .expense, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        ))
        
        // 2. Income: +1000
        try await transactionClient.add(Transaction(
            id: UUID(), amount: Decimal(1000), date: Date(), note: "", categoryId: categoryId,
            accountId: accountId, toAccountId: nil, type: .income, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        ))
        
        // 3. Transfer In: +200
        try await transactionClient.add(Transaction(
            id: UUID(), amount: Decimal(200), date: Date(), note: "", categoryId: categoryId,
            accountId: anotherAccountId, toAccountId: accountId, type: .transfer, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        ))
        
        // 4. Transfer Out: -100
        try await transactionClient.add(Transaction(
            id: UUID(), amount: Decimal(100), date: Date(), note: "", categoryId: categoryId,
            accountId: accountId, toAccountId: anotherAccountId, type: .transfer, tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        ))
        
        // Total expected balance: -500 + 1000 + 200 - 100 = 600
        let balance = try await sut.computeBalance(accountId)
        #expect(balance == 600)
    }
}
