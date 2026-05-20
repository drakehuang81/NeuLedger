import Foundation
import SwiftData
import Dependencies
import Domain

/// Generic CRUD store over a `(Domain, SD)` pair.
///
/// `SwiftDataStore` is the **only** type allowed to consume
/// `\.modelContainer` (see `docs/architecture.md` §4.2). Repositories
/// instantiate it with zero arguments — `SwiftDataStore<Domain, SD>()` —
/// and call its five methods. All `ModelContext` usage stays inside.
public struct SwiftDataStore<Domain: Identifiable & Sendable,
                              SD: PersistentDomainModel>: Sendable
    where SD.DomainModel == Domain
{
    @Dependency(\.modelContainer) private var container

    public init() {}

    /// Returns all stored Domain values, optionally sorted by SD-side descriptors.
    public func fetchAll(sortBy descriptors: [SortDescriptor<SD>] = []) async throws -> [Domain] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SD>(sortBy: descriptors)
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    /// Returns the Domain value with the given id, or nil if no such entity exists.
    public func fetch(id: Domain.ID) async throws -> Domain? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SD>(predicate: SD.idPredicate(id))
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.toDomain()
    }

    /// Inserts a new Domain value as an SD model and saves.
    public func add(_ domain: Domain) async throws {
        let context = ModelContext(container)
        SD.from(domain, context: context)
        try context.save()
    }

    /// Finds the SD model with `domain.id`, applies changes, and saves.
    /// Throws `CoreError.notFound` if no matching SD exists.
    public func update(_ domain: Domain) async throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SD>(predicate: SD.idPredicate(domain.id))
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else {
            throw CoreError.notFound("\(SD.self)")
        }
        existing.applyChanges(from: domain, context: context)
        try context.save()
    }

    /// Finds the SD model with the given id, calls `prepareForDelete()`,
    /// deletes the SD instance, and saves.
    /// Throws `CoreError.notFound` if no matching SD exists.
    public func delete(id: Domain.ID) async throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SD>(predicate: SD.idPredicate(id))
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else {
            throw CoreError.notFound("\(SD.self)")
        }
        existing.prepareForDelete()
        context.delete(existing)
        try context.save()
    }
}
