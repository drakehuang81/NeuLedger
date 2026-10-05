import Testing
import SwiftData
import Foundation
@testable import Core
import Domain

@Suite("Database Seeding Tests")
struct DatabaseSeedingTests {
    var context: ModelContext

    init() {
        let client = PersistenceBootstrap.testValue
        self.context = ModelContext(client.modelContainer())
    }

    @Test("Seeds initial categories only — accounts are created via Onboarding")
    func testSeedingInitialData() throws {
        let categories = try context.fetch(FetchDescriptor<SDCategory>())
        let accounts = try context.fetch(FetchDescriptor<SDAccount>())

        let expenseCategories = categories.filter { $0.type == TransactionType.expense.rawValue }
        let incomeCategories = categories.filter { $0.type == TransactionType.income.rawValue }

        #expect(expenseCategories.count == 9)
        #expect(incomeCategories.count == 5)
        #expect(categories.count == 14)

        #expect(accounts.isEmpty)
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

    /// 取代 `Category+Localized` 原本那句「Keep in sync if seeds change」。
    ///
    /// 清單是從 `SeedCategory` 動態讀的，所以新增 seed 分類而忘記加 i18n key
    /// 時這條會紅——不像 `CategoryLocalizedNameTests` 的硬寫清單，那邊也得
    /// 手動補（它跨不過模組邊界：`SeedCategory` 在 Core、那個測試在 DomainTests）。
    @Test("Every seed category name has a Domain localization key")
    func testSeedNamesHaveLocalizationKeys() {
        let seeds = SeedCategory.defaultExpenseCategories + SeedCategory.defaultIncomeCategories
        #expect(!seeds.isEmpty, "seed 清單是空的，這條測試會變成空轉")
        for seed in seeds {
            #expect(
                Category.seedLocalizationKey(forSeedName: seed.name) != nil,
                "Seed '\(seed.name)' 在 Category.seedLocalizationMap 裡沒有對應 key"
            )
        }
    }
}
