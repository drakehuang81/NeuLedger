import Foundation
import SwiftData

// MARK: - DomainConvertible

/// A protocol that unifies bidirectional mapping between a SwiftData `@Model`
/// and its corresponding Domain value type.
///
/// Conforming types must provide:
/// - `toDomain()` to convert from the persistence model to the domain model.
/// - `from(_:context:)` to create and insert a persistence model from a domain value.
///
/// All five SD models (`SDAccount`, `SDBudget`, `SDCategory`, `SDTag`, `SDTransaction`)
/// already implement these methods; conformance is declared in their `+Mapping` files.
protocol DomainConvertible: PersistentModel {
    associatedtype DomainModel

    /// Converts this persistence model to its Domain value type.
    func toDomain() -> DomainModel

    /// Creates a persistence model from the given Domain value and inserts it into the context.
    @discardableResult
    static func from(_ domain: DomainModel, context: ModelContext) -> Self
}
