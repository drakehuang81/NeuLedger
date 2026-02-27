import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDCategory` and `Category`.
extension SDCategory {
    /// Converts this SwiftData model to a Domain `Category` value type.
    func toDomain() -> Domain.Category {
        Category(
            id: id,
            name: name,
            icon: icon,
            color: color,
            type: TransactionType(rawValue: type) ?? .expense,
            sortOrder: sortOrder,
            isDefault: isDefault
        )
    }

    /// Creates an `SDCategory` from a Domain `Category`.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Category` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDCategory` instance inserted into the given context.
    @discardableResult
    static func from(_ domain: Domain.Category, context: ModelContext) -> SDCategory {
        let model = SDCategory(
            id: domain.id,
            name: domain.name,
            icon: domain.icon,
            color: domain.color,
            type: domain.type.rawValue,
            sortOrder: domain.sortOrder,
            isDefault: domain.isDefault
        )
        context.insert(model)
        return model
    }
}
