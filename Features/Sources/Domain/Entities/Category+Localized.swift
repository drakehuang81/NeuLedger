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

    /// English seed name → i18n key. Mirrors the SeedCategory entries
    /// in `Features/Sources/Core/Persistence/DatabaseClient.swift`.
    /// Keep in sync if seeds change.
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
