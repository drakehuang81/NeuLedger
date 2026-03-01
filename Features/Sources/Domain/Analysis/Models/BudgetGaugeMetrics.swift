import Foundation

public struct BudgetGaugeMetrics: Equatable, Sendable, Identifiable {
    public let id: String
    public let categoryName: String
    public let spentAmount: Decimal
    public let totalBudget: Decimal
    
    public var remainingAmount: Decimal {
        max(0, totalBudget - spentAmount)
    }
    
    public var progressPercentage: Double {
        guard totalBudget > 0 else { return 0 }
        return Double(truncating: (spentAmount / totalBudget) as NSNumber)
    }
    
    public init(id: String = UUID().uuidString, categoryName: String, spentAmount: Decimal, totalBudget: Decimal) {
        self.id = id
        self.categoryName = categoryName
        self.spentAmount = spentAmount
        self.totalBudget = totalBudget
    }
}
