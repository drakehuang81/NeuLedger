import Foundation
import SwiftData

/// A SwiftData persistence model representing a user-defined budget.
///
/// `SDBudget` mirrors the Domain `Budget` entity and is used exclusively
/// within the `Core` module for SwiftData storage.
@Model
final class SDBudget {
    /// The unique identifier of the budget.
    @Attribute(.unique) var id: UUID

    /// The custom display name of the budget.
    var name: String

    /// The target spending limit for this budget.
    var amount: Decimal

    /// The identifier of the specific category this budget applies to, if any.
    var categoryId: UUID?

    /// The raw string representation of the ``BudgetPeriod``.
    var period: String

    /// The original commencement date of this budget.
    var startDate: Date

    /// Whether the budget is currently active and being tracked.
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        categoryId: UUID? = nil,
        period: String,
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
