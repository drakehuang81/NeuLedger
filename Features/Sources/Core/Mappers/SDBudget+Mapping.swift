import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDBudget` and `Budget`.
extension SDBudget: DomainConvertible {
    /// Converts this SwiftData model to a Domain `Budget` value type.
    func toDomain() -> Budget {
        let resolvedPeriod: BudgetPeriod
        if let mapped = BudgetPeriod(rawValue: period) {
            resolvedPeriod = mapped
        } else {
            assertionFailure("SDBudget.period has unknown raw value: \(period)")
            resolvedPeriod = .monthly
        }
        return Budget(
            id: id,
            name: name,
            amount: amount,
            categoryId: categoryId,
            period: resolvedPeriod,
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
