import Foundation
import SwiftData

/// A SwiftData persistence model representing a recurring transaction template.
///
/// `SDRecurringTransaction` mirrors the Domain `RecurringTransaction` entity and is used
/// exclusively within the `Core` module for SwiftData storage.
@Model
final class SDRecurringTransaction {
    /// The unique identifier of the recurring transaction.
    @Attribute(.unique) var id: UUID

    /// The fixed amount charged or received each cycle.
    var amount: Decimal

    /// An optional description for the recurring transaction.
    var note: String?

    /// The identifier of the category this recurring transaction belongs to, if any.
    var categoryId: UUID?

    /// The identifier of the source account.
    var accountId: UUID

    /// The identifier of the destination account for transfers, if any.
    var toAccountId: UUID?

    /// The raw string representation of the ``TransactionType``.
    var typeRaw: String

    /// The identifiers of tags associated with this recurring transaction.
    var tagIds: [UUID]

    /// The raw string representation of the ``BudgetPeriod`` frequency.
    var frequencyRaw: String

    /// The next date on which this recurring transaction is due.
    var nextDueDate: Date

    /// Whether this recurring transaction is currently active.
    var isActive: Bool

    /// The date this recurring transaction was first created.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        note: String? = nil,
        categoryId: UUID? = nil,
        accountId: UUID,
        toAccountId: UUID? = nil,
        typeRaw: String,
        tagIds: [UUID] = [],
        frequencyRaw: String,
        nextDueDate: Date,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.categoryId = categoryId
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.typeRaw = typeRaw
        self.tagIds = tagIds
        self.frequencyRaw = frequencyRaw
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
