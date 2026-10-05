import Foundation

public extension Category {

    /// Returns a localized display name for default seed categories.
    /// User-created or user-renamed default categories fall back to the
    /// raw stored `name`.
    var localizedName: String {
        guard isDefault, let key = Self.seedLocalizationMap[name] else {
            return name
        }
        return String(localized: String.LocalizationValue(key), bundle: .main)
    }

    /// 把內部對照表開放給 seed 守門測試。
    ///
    /// 存在的理由是跨模組：`SeedCategory` 住在 Core、這份對照表住在 Domain，
    /// 所以唯一能同時看見兩者的地方是 Core 的測試 target，而它需要一個
    /// public 入口才問得到「這個 seed 名有沒有 key」。
    static func seedLocalizationKey(forSeedName name: String) -> String? {
        seedLocalizationMap[name]
    }

    /// Seed 英文名 → i18n key。`DatabaseSeedingTests` 的
    /// `testSeedNamesHaveLocalizationKeys` 會在 seed 缺 key 時失敗，所以這份
    /// 對照表不再靠「記得同步」維持——它對照的是
    /// `Features/Sources/Core/Persistence/PersistenceBootstrap.swift` 裡的
    /// `SeedCategory` 清單。
    private static let seedLocalizationMap: [String: String] = [
        "Food":            "category_seed_food",
        "Transport":       "category_seed_transport",
        "Entertainment":   "category_seed_entertainment",
        "Shopping":        "category_seed_shopping",
        "Housing":         "category_seed_housing",
        "Utilities":       "category_seed_utilities",
        "Health":          "category_seed_health",
        "Education":       "category_seed_education",
        "Other Expense":   "category_seed_other_expense",
        "Salary":          "category_seed_salary",
        "Freelance":       "category_seed_freelance",
        "Investment":      "category_seed_investment",
        "Gift":            "category_seed_gift",
        "Other Income":    "category_seed_other_income",
    ]
}
