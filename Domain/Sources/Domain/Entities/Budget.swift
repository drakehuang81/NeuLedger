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
