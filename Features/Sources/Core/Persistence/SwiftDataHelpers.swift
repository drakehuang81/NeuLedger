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

// MARK: - DatabaseClient Helpers

extension DatabaseClient {

    // MARK: Context

    /// Creates a new `ModelContext` from the shared `ModelContainer`.
    func makeContext() -> ModelContext {
        ModelContext(modelContainer())
    }

    // MARK: Fetch

    /// Fetches persistence models matching the given descriptor and maps them to domain values.
    func fetch<T: DomainConvertible>(
        _ descriptor: FetchDescriptor<T>
    ) throws -> [T.DomainModel] {
        let context = makeContext()
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    // MARK: Add

    /// Inserts a new persistence model created from the given domain value and saves.
    func add<T: DomainConvertible>(
        _ domain: T.DomainModel,
        as type: T.Type
    ) throws {
        let context = makeContext()
        T.from(domain, context: context)
        try context.save()
    }

    // MARK: Update

    /// Fetches a single model matching the descriptor, applies a mutation closure, and saves.
    ///
    /// The `mutation` closure receives both the fetched model and its `ModelContext`.
    /// The context is provided for operations that need to resolve related objects
    /// (e.g. `SDTag.resolve(_:context:)`) — most callers can ignore it with `_`.
    ///
    /// - Throws: `CoreError.notFound` if no matching entity exists.
    func update<T: PersistentModel>(
        matching descriptor: FetchDescriptor<T>,
        mutation: (T, ModelContext) throws -> Void
    ) throws {
        let context = makeContext()
        var bounded = descriptor
        bounded.fetchLimit = 1
        guard let existing = try context.fetch(bounded).first else {
            throw CoreError.notFound("\(T.self)")
        }
        try mutation(existing, context)
        try context.save()
    }

    // MARK: Delete

    /// Fetches a single model matching the descriptor, optionally validates it, deletes it, and saves.
    ///
    /// - Parameters:
    ///   - descriptor: A `FetchDescriptor` that should match exactly one entity.
    ///   - validation: An optional closure to validate the entity before deletion.
    ///                 Throwing from this closure cancels the delete.
    /// - Throws: `CoreError.notFound` if no matching entity exists; re-throws any error from `validation`.
    func deleteFirst<T: PersistentModel>(
        matching descriptor: FetchDescriptor<T>,
        validation: ((T) throws -> Void)? = nil
    ) throws {
        let context = makeContext()
        var bounded = descriptor
        bounded.fetchLimit = 1
        guard let existing = try context.fetch(bounded).first else {
            throw CoreError.notFound("\(T.self)")
        }
        try validation?(existing)
        context.delete(existing)
        try context.save()
    }
}
