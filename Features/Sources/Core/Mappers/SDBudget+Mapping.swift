import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDBudget` and `Budget`.
extension SDBudget {
    /// Converts this SwiftData model to a Domain `Budget` value type.
    func toDomain() -> Budget {
        Budget(
            id: id,
            name: name,
            amount: amount,
            categoryId: categoryId,
            period: BudgetPeriod(rawValue: period) ?? .monthly,
            startDate: startDate,
            isActive: isActive
        )
    }

    /// Creates an `SDBudget` from a Domain `Budget`.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Budget` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDBudget` instance inserted into the given context.
    @discardableResult
    static func from(_ domain: Budget, context: ModelContext) -> SDBudget {
        let model = SDBudget(
            id: domain.id,
            name: domain.name,
            amount: domain.amount,
            categoryId: domain.categoryId,
            period: domain.period.rawValue,
            startDate: domain.startDate,
            isActive: domain.isActive
        )
        context.insert(model)
        return model
    }
}
