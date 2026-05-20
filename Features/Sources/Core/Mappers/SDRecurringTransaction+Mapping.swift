import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDRecurringTransaction` and `RecurringTransaction`.
extension SDRecurringTransaction: PersistentDomainModel {
    /// Converts this SwiftData model to a Domain `RecurringTransaction` value type.
    ///
    /// Tags are not resolved in v1; `tagIds` are preserved in storage for future use.
    func toDomain() -> RecurringTransaction {
        RecurringTransaction(
            id: id,
            amount: amount,
            note: note,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            type: TransactionType(rawValue: typeRaw) ?? .expense,
            tags: [],
            frequency: BudgetPeriod(rawValue: frequencyRaw) ?? .monthly,
            nextDueDate: nextDueDate,
            isActive: isActive,
            createdAt: createdAt
        )
    }

    /// Creates an `SDRecurringTransaction` from a Domain `RecurringTransaction`.
    ///
    /// - Parameters:
    ///   - domain: The Domain `RecurringTransaction` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDRecurringTransaction` instance inserted into the given context.
    @discardableResult
    static func from(_ domain: RecurringTransaction, context: ModelContext) -> SDRecurringTransaction {
        let model = SDRecurringTransaction(
            id: domain.id,
            amount: domain.amount,
            note: domain.note,
            categoryId: domain.categoryId,
            accountId: domain.accountId,
            toAccountId: domain.toAccountId,
            typeRaw: domain.type.rawValue,
            tagIds: domain.tags.map(\.id),
            frequencyRaw: domain.frequency.rawValue,
            nextDueDate: domain.nextDueDate,
            isActive: domain.isActive,
            createdAt: domain.createdAt
        )
        context.insert(model)
        return model
    }

    func applyChanges(from domain: RecurringTransaction, context: ModelContext) {
        amount = domain.amount
        note = domain.note
        categoryId = domain.categoryId
        accountId = domain.accountId
        toAccountId = domain.toAccountId
        typeRaw = domain.type.rawValue
        tagIds = domain.tags.map(\.id)
        frequencyRaw = domain.frequency.rawValue
        nextDueDate = domain.nextDueDate
        isActive = domain.isActive
    }

    static func idPredicate(_ id: RecurringTransaction.ID) -> Predicate<SDRecurringTransaction> {
        #Predicate<SDRecurringTransaction> { $0.id == id }
    }
}
