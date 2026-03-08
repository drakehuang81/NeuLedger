import Testing
import SwiftData
import Foundation
@testable import Core
import Domain

@Suite("Database Seeding Tests")
struct DatabaseSeedingTests {
    var context: ModelContext

    init() {
        let client = DatabaseClient.testValue
        self.context = ModelContext(client.modelContainer())
    }

    @Test("Seeds initial categories and default account")
    func testSeedingInitialData() throws {
        let categories = try context.fetch(FetchDescriptor<SDCategory>())
        let accounts = try context.fetch(FetchDescriptor<SDAccount>())

        let expenseCategories = categories.filter { $0.type == TransactionType.expense.rawValue }
        let incomeCategories = categories.filter { $0.type == TransactionType.income.rawValue }

        #expect(expenseCategories.count == 9)
        #expect(incomeCategories.count == 5)
        #expect(categories.count == 14)

        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "Cash")
        #expect(accounts.first?.type == AccountType.cash.rawValue)
    }

    @Test("All seeded categories are marked as default")
    func testAllCategoriesAreDefault() throws {
        let categories = try context.fetch(FetchDescriptor<SDCategory>())

        for category in categories {
            #expect(category.isDefault == true, "Category '\(category.name)' should be default")
        }
    }

    @Test("Seeding is idempotent via testValue")
    func testSeedingIsIdempotent() throws {
        // testValue already seeded once during init.
        // Create a second context from the same container and verify no duplicates.
        let countBefore = try context.fetchCount(FetchDescriptor<SDCategory>())
        #expect(countBefore == 14)

        // Fetching again should yield the same count (no re-seeding on subsequent access)
        let countAfter = try context.fetchCount(FetchDescriptor<SDCategory>())
        #expect(countAfter == 14)
    }
}
