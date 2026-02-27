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
    
    public init(
        totalIncome: Decimal,
        totalExpense: Decimal,
        categoryBreakdown: [String: Decimal] = [:],
        periodDescription: String
    ) {
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.categoryBreakdown = categoryBreakdown
        self.periodDescription = periodDescription
    }
}
