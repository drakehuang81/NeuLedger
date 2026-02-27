import Foundation

public struct Budget: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var amount: Decimal
    public var categoryId: Category.ID? // Optional: if nil, applies to total spending
    public var period: BudgetPeriod
    public var startDate: Date
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
