import Foundation

/// An interval defining the recurring life cycle of a budget.
///
/// Use `BudgetPeriod` to determine how often a budget resets its tracked spending against its target amount.
public enum BudgetPeriod: String, Codable, CaseIterable, Equatable, Sendable {
    /// A budget calculated on a weekly basis.
    case weekly

    /// A budget calculated on a monthly basis.
    case monthly

    /// A budget calculated on a yearly basis.
    case yearly

    /// A localized display name for the period.
    public var localizedName: String {
        switch self {
        case .weekly:  return String(localized: "budget_period_weekly", bundle: .main)
        case .monthly: return String(localized: "budget_period_monthly", bundle: .main)
        case .yearly:  return String(localized: "budget_period_yearly", bundle: .main)
        }
    }

    /// Short localized suffix used in UI labels such as "NT$ 8,000 / 月".
    public var localizedSuffix: String {
        switch self {
        case .weekly:  return String(localized: "budget_period_suffix_weekly", bundle: .main)
        case .monthly: return String(localized: "budget_period_suffix_monthly", bundle: .main)
        case .yearly:  return String(localized: "budget_period_suffix_yearly", bundle: .main)
        }
    }
}
