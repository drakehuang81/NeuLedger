import Foundation

public struct FinancialSummary: Equatable, Sendable {
    public let totalIncome: Decimal
    public let totalExpense: Decimal
    
    public var netBalance: Decimal {
        totalIncome - totalExpense
    }
    
    public init(totalIncome: Decimal, totalExpense: Decimal) {
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
    }
}
