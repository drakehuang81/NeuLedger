import Foundation
import SwiftData
import Domain

/// SwiftData-side companion to `Domain.DomainConvertible` — absorbs all
/// mapping, relationship resolution, and lifecycle concerns for an SD model.
///
/// `ModelContext` is only allowed to surface inside conformances of this
/// protocol (mappers) or inside `SwiftDataStore` — see
/// `docs/architecture.md` §4.2.
public protocol PersistentDomainModel: PersistentModel, DomainConvertible
where DomainModel.ID: Sendable & Equatable {

    /// Creates a new SD instance from a Domain value and inserts it into `context`.
    /// Implementations resolve any required relationships here.
    @discardableResult
    static func from(_ domain: DomainModel, context: ModelContext) -> Self

    /// Mutates this SD instance to match `domain`.
    /// Implementations resolve any relationship updates using `context`.
    func applyChanges(from domain: DomainModel, context: ModelContext)

    /// Cleanup before delete (e.g. clearing inverse relationships).
    /// Default implementation does nothing.
    func prepareForDelete()

    /// A predicate that matches this SD by domain ID.
    static func idPredicate(_ id: DomainModel.ID) -> Predicate<Self>
}

public extension PersistentDomainModel {
    func prepareForDelete() {}

    // MARK: - Migration stubs
    //
    // Every SD model gets a real implementation in Tasks 1.3a–1.3g of
    // docs/superpowers/plans/2026-05-20-architecture-migration.md. Until
    // then, these defaults keep the type-checker happy. `SwiftDataStore`
    // (Task 1.4) is the first call site for applyChanges / idPredicate —
    // by the time it ships, every mapper must override these.
    //
    // TODO(Phase 1 收尾): remove these defaults so missing implementations
    // are caught at compile time again.
    func applyChanges(from domain: DomainModel, context: ModelContext) {
        fatalError("\(Self.self) must override applyChanges(from:context:)")
    }
    static func idPredicate(_ id: DomainModel.ID) -> Predicate<Self> {
        fatalError("\(Self.self) must override idPredicate(_:)")
    }
}
