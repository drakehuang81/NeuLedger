import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDTransaction` and `Transaction`.
extension SDTransaction {
    /// Converts this SwiftData model to a Domain `Transaction` value type.
    func toDomain() -> Transaction {
        Transaction(
            id: id,
            amount: amount,
            date: date,
            note: note,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            type: TransactionType(rawValue: type) ?? .expense,
            tags: tags.map { $0.toDomain() },
            aiSuggested: aiSuggested,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Creates an `SDTransaction` from a Domain `Transaction`.
    ///
    /// This method resolves each tag in the transaction's `tags` array,
    /// reusing existing `SDTag` records when possible.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Transaction` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDTransaction` instance inserted into the given context.
    @discardableResult
    static func from(_ domain: Transaction, context: ModelContext) -> SDTransaction {
        let model = SDTransaction(
            id: domain.id,
            amount: domain.amount,
            date: domain.date,
            note: domain.note,
            categoryId: domain.categoryId,
            accountId: domain.accountId,
            toAccountId: domain.toAccountId,
            type: domain.type.rawValue,
            aiSuggested: domain.aiSuggested,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
        model.tags = domain.tags.map { SDTag.resolve($0, context: context) }
        context.insert(model)
        return model
    }
}
