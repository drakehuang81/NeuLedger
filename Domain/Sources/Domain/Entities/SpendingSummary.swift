import Foundation

public struct SpendingSummary: Equatable, Sendable {
    public var totalIncome: Decimal
    public var totalExpense: Decimal
    public var categoryBreakdown: [String: Decimal]
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
