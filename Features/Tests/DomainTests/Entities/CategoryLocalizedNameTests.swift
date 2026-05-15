import Foundation
import Testing
@testable import Domain

@Suite("Category.localizedName Tests")
struct CategoryLocalizedNameTests {

    private static func make(name: String, isDefault: Bool) -> Domain.Category {
        Category(
            name: name,
            icon: "tag",
            color: "#000000",
            type: .expense,
            isDefault: isDefault
        )
    }

    @Test("Default seed with English seed name resolves to localized string")
    func testDefaultSeedResolves() {
        let cat = Self.make(name: "Food", isDefault: true)
        let result = cat.localizedName
        // zh-Hant simulator → "餐飲"; en simulator → "Food".
        #expect(result == "餐飲" || result == "Food")
        // The localized lookup must not echo the i18n key back.
        #expect(result != "category_seed_food")
    }

    @Test("Default category renamed by user falls back to raw name")
    func testDefaultRenamedFallback() {
        let cat = Self.make(name: "My Food", isDefault: true)
        #expect(cat.localizedName == "My Food")
    }

    @Test("Non-default user-created category falls back to raw name")
    func testUserCreatedFallback() {
        let cat = Self.make(name: "Coffee", isDefault: false)
        #expect(cat.localizedName == "Coffee")
    }

    @Test("All 14 seed names resolve to a non-empty, non-key value")
    func testAllSeedsResolve() {
        let seedNames = [
            "Food", "Transport", "Entertainment", "Shopping",
            "Housing", "Utilities", "Health", "Education", "Other Expense",
            "Salary", "Freelance", "Investment", "Gift", "Other Income",
        ]
        for name in seedNames {
            let cat = Self.make(name: name, isDefault: true)
            let result = cat.localizedName
            #expect(!result.isEmpty, "\(name) localizedName was empty")
            #expect(!result.hasPrefix("category_seed_"), "\(name) returned i18n key instead of translation")
        }
    }
}
