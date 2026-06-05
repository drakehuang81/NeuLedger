import Foundation

/// A user-defined financial goal allocated for a specific time period or category.
///
/// Use `Budget` to track expected spending against actual expenditures over a defined timeframe.
public struct Budget: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// The unique identifier of the budget.
    public let id: UUID
    
    /// The custom display name of the budget, such as "Dining Budget" or "Total Monthly Budget".
    public var name: String
    
    /// The target spending limit for this budget.
    public var amount: Decimal
    
    /// The identifier of the specific category this budget applies to.
    ///
    /// If this property is `nil`, the budget acts as a global spending limit across all categories.
    public var categoryId: Category.ID? // Optional: if nil, applies to total spending
    
    /// The recurring time interval (e.g., weekly, monthly) over which this budget calculates spending.
    public var period: BudgetPeriod
    
    /// The original commencement date of this budget.
    public var startDate: Date
    
    /// A Boolean value that indicates whether the budget is currently active and being enforced.
    public var isActive: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        categoryId: Category.ID? = nil,
        period: BudgetPeriod,
        startDate: Date,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.categoryId = categoryId
        self.period = period
        self.startDate = startDate
        self.isActive = isActive
    }
}

public extension Budget {
    /// Evaluate whether to fire a budget warning.
    ///
    /// `amount <= 0` short-circuits to
    /// `BudgetWarningOutcome(shouldWarn: false, usedPercent: 0)`.
    ///
    /// - Parameters:
    ///   - transactionsInPeriod: All transactions that fall within the
    ///     budget's current period (caller is responsible for the date filter).
    ///     This function filters out non-expense rows and rows that don't
    ///     match the budget's `categoryId` (if the budget is category-scoped).
    ///   - threshold: The warning threshold percentage, e.g. `80` for 80%.
    ///   - lastWarnedPercent: The percent at which this budget was last
    ///     warned in the current period, or `nil` if never warned this period.
    ///     `shouldWarn` returns false when a prior warning already covered
    ///     this threshold (`lastWarnedPercent >= threshold`).
    /// - Returns: The evaluation outcome.
    func evaluate(
        transactionsInPeriod: [Transaction],
        threshold: Int,
        lastWarnedPercent: Int?
    ) -> BudgetWarningOutcome {
        guard amount > 0 else {
            return BudgetWarningOutcome(shouldWarn: false, usedPercent: 0)
        }
        let totalSpent = transactionsInPeriod
            .filter { txn in
                guard txn.type == .expense else { return false }
                guard let scopedCategoryId = categoryId else { return true }
                return txn.categoryId == scopedCategoryId
            }
            .reduce(into: Decimal(0)) { $0 += $1.amount }
        let ratio = (totalSpent / amount * 100) as NSDecimalNumber
        let usedPercent = ratio.intValue   // truncation is intentional (conservative)
        let shouldWarn = usedPercent >= threshold
            && (lastWarnedPercent == nil || lastWarnedPercent! < threshold)
        return BudgetWarningOutcome(shouldWarn: shouldWarn, usedPercent: usedPercent)
    }
}


/// The result of evaluating a budget against its in-period transactions.
public struct BudgetWarningOutcome: Equatable, Sendable {
    /// Whether the caller should fire a new warning notification now.
    /// True when `usedPercent >= threshold` AND the budget has not yet
    /// been warned at this threshold level for the current period.
    public let shouldWarn: Bool

    /// The percentage of the budget that has been spent (rounded down).
    /// Always in `0...Int.max`. Independent of `shouldWarn` so the
    /// caller can persist it for next-period comparison.
    public let usedPercent: Int

    public init(shouldWarn: Bool, usedPercent: Int) {
        self.shouldWarn = shouldWarn
        self.usedPercent = usedPercent
    }
}
