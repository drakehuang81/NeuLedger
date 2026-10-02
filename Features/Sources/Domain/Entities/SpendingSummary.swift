import Foundation

/// A statistical overview of financial activities within a predefined timeframe.
///
/// The `SpendingSummary` is frequently utilized as the foundation for generating AI-driven insights
/// and dashboard visualizations.
public struct SpendingSummary: Equatable, Sendable {
    /// The aggregated sum of all income during the period.
    public var totalIncome: Decimal

    /// The aggregated sum of all expenditures during the period.
    public var totalExpense: Decimal

    /// A dictionary mapping category names to their respective total accumulated values.
    public var categoryBreakdown: [String: Decimal]

    /// A human-readable description string of the summarized period (e.g., "March 2024", "Last Week").
    public var periodDescription: String

    // MARK: - B1 Warm Redesign additions

    /// The aggregated sum of all expenditures for the current month.
    public var monthTotal: Decimal

    /// The aggregated sum of all expenditures for the current week.
    public var weekTotal: Decimal

    /// The name of the highest-spend category.
    public var topCategoryName: String?

    /// The total amount of the highest-spend category.
    public var topCategoryAmount: Decimal?

    /// 期間內的儲蓄率。`nil` = 沒有收入紀錄、算不出來（不是 0）；負值 = 入不敷出。
    /// 語意與 `StatsSnapshot.savingsPercentage` 相同，見該處說明。
    public var savingsPercentage: Double?

    public init(
        totalIncome: Decimal,
        totalExpense: Decimal,
        categoryBreakdown: [String: Decimal] = [:],
        periodDescription: String,
        monthTotal: Decimal = 0,
        weekTotal: Decimal = 0,
        topCategoryName: String? = nil,
        topCategoryAmount: Decimal? = nil,
        savingsPercentage: Double? = nil
    ) {
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.categoryBreakdown = categoryBreakdown
        self.periodDescription = periodDescription
        self.monthTotal = monthTotal
        self.weekTotal = weekTotal
        self.topCategoryName = topCategoryName
        self.topCategoryAmount = topCategoryAmount
        self.savingsPercentage = savingsPercentage
    }

    /// Convenience init for the B1 carousel use-case where periodDescription is implicit.
    public init(
        monthTotal: Decimal,
        weekTotal: Decimal,
        topCategoryName: String? = nil,
        topCategoryAmount: Decimal? = nil,
        savingsPercentage: Double? = nil
    ) {
        self.totalIncome = 0
        self.totalExpense = 0
        self.categoryBreakdown = [:]
        self.periodDescription = ""
        self.monthTotal = monthTotal
        self.weekTotal = weekTotal
        self.topCategoryName = topCategoryName
        self.topCategoryAmount = topCategoryAmount
        self.savingsPercentage = savingsPercentage
    }
}
