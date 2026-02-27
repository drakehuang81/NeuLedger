import Testing
import SwiftData
import Foundation
@testable import Core
import Domain

@Suite("DefaultDataSeeder Tests")
struct DefaultDataSeederTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        // Use an empty in-memory container
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("Seeder seeds initial data when database is empty")
    func testSeedingInitialData() throws {
        // Arrange
        let initialCategoriesCount = try context.fetchCount(FetchDescriptor<SDCategory>())
        #expect(initialCategoriesCount == 0)

        // Act
        // Call seed method manually, which is similar to what DatabaseClient does
        DefaultDataSeeder.seed(in: context)

        // Assert
        let categories = try context.fetch(FetchDescriptor<SDCategory>())
        let accounts = try context.fetch(FetchDescriptor<SDAccount>())
        
        // 9 expense + 5 income = 14 categories
        #expect(categories.count == 14)
        
        let expenseCategories = categories.filter { $0.type == TransactionType.expense.rawValue }
        let incomeCategories = categories.filter { $0.type == TransactionType.income.rawValue }
        
        #expect(expenseCategories.count == 9)
        #expect(incomeCategories.count == 5)
        
        // 1 default account
        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "Cash")
    }

    @Test("Seeder is idempotent (does not duplicate data on second run)")
    func testSeedingIsIdempotent() throws {
        // Arrange
        DefaultDataSeeder.seed(in: context)
        let countAfterFirstSeed = try context.fetchCount(FetchDescriptor<SDCategory>())
        #expect(countAfterFirstSeed == 14)

        // Act
        DefaultDataSeeder.seed(in: context)

        // Assert
        let countAfterSecondSeed = try context.fetchCount(FetchDescriptor<SDCategory>())
        #expect(countAfterSecondSeed == 14)
    }
}
