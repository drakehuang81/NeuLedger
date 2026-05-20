import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDAccount` and `Account`.
extension SDAccount: PersistentDomainModel {
    /// Converts this SwiftData model to a Domain `Account` value type.
    func toDomain() -> Account {
        let resolvedType: AccountType
        if let mapped = AccountType(rawValue: type) {
            resolvedType = mapped
        } else {
            assertionFailure("SDAccount.type has unknown raw value: \(type)")
            resolvedType = .cash
        }
        return Account(
            id: id,
            name: name,
            type: resolvedType,
            icon: icon,
            color: color,
            sortOrder: sortOrder,
            isArchived: isArchived,
            createdAt: createdAt
        )
    }

    /// Creates an `SDAccount` from a Domain `Account`.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Account` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDAccount` instance inserted into the given context.
    @discardableResult
    static func from(_ domain: Account, context: ModelContext) -> SDAccount {
        let model = SDAccount(
            id: domain.id,
            name: domain.name,
            type: domain.type.rawValue,
            icon: domain.icon,
            color: domain.color,
            sortOrder: domain.sortOrder,
            isArchived: domain.isArchived,
            createdAt: domain.createdAt
        )
        context.insert(model)
        return model
    }
}
