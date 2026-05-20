import Foundation

/// Bridge between an infrastructure model and its Domain representation.
///
/// Lives in the Domain layer so the rest of the codebase can reason about
/// "the domain side of a bridge" without depending on SwiftData. The
/// Core companion `PersistentDomainModel` adds SwiftData-specific
/// lifecycle and lookup methods.
public protocol DomainConvertible {
    associatedtype DomainModel: Identifiable & Sendable

    /// Converts this infrastructure model to its Domain representation.
    func toDomain() -> DomainModel
}
