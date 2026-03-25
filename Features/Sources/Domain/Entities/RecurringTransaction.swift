import Foundation

public struct RecurringTransaction: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var amount: Decimal
    public var note: String?
    public var categoryId: Category.ID?
    public var accountId: Account.ID
    public var toAccountId: Account.ID?   // transfers only
    public var type: TransactionType
    public var tags: [Tag]
    public var frequency: BudgetPeriod    // .weekly / .monthly / .yearly
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: UUID, amount: Decimal, note: String?,
        categoryId: Category.ID?, accountId: Account.ID,
        toAccountId: Account.ID?, type: TransactionType,
        tags: [Tag], frequency: BudgetPeriod,
        nextDueDate: Date, isActive: Bool, createdAt: Date
    ) {
        self.id = id; self.amount = amount; self.note = note
        self.categoryId = categoryId; self.accountId = accountId
        self.toAccountId = toAccountId; self.type = type
        self.tags = tags; self.frequency = frequency
        self.nextDueDate = nextDueDate; self.isActive = isActive
        self.createdAt = createdAt
    }

    /// Returns the next due date after `base` according to `frequency`.
    public func nextDate(after base: Date, calendar: Calendar = .current) -> Date {
        switch frequency {
        case .weekly:  return calendar.date(byAdding: .weekOfYear, value: 1, to: base) ?? base
        case .monthly: return calendar.date(byAdding: .month,      value: 1, to: base) ?? base
        case .yearly:  return calendar.date(byAdding: .year,       value: 1, to: base) ?? base
        }
    }
}
