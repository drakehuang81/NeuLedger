import Foundation
import SwiftData

/// A SwiftData persistence model representing a financial transaction.
///
/// `SDTransaction` mirrors the Domain `Transaction` entity. It holds a
/// many-to-many relationship with ``SDTag`` through the `tags` property.
@Model
final class SDTransaction {
    /// The unique identifier of the transaction.
    @Attribute(.unique) var id: UUID

    /// The monetary value of the transaction (always positive).
    var amount: Decimal

    /// The date when the transaction occurred.
    var date: Date

    /// Optional notes or memo for the transaction.
    var note: String?

    /// The identifier of the associated category, if any.
    var categoryId: UUID?

    /// The identifier of the primary account involved.
    var accountId: UUID

    /// The identifier of the destination account (only for transfers).
    var toAccountId: UUID?

    /// The raw string representation of the ``TransactionType``.
    var type: String

    /// Whether this transaction's details were populated by an AI service.
    var aiSuggested: Bool

    /// The date when this record was originally created.
    var createdAt: Date

    /// The date when this record was last modified.
    var updatedAt: Date

    /// The tags associated with this transaction (many-to-many).
    @Relationship var tags: [SDTag] = []

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date,
        note: String? = nil,
        categoryId: UUID? = nil,
        accountId: UUID,
        toAccountId: UUID? = nil,
        type: String,
        aiSuggested: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.categoryId = categoryId
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.type = type
        self.aiSuggested = aiSuggested
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
