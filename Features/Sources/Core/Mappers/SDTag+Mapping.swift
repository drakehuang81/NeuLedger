import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDTag` and `Tag`.
extension SDTag {
    /// Converts this SwiftData model to a Domain `Tag` value type.
    func toDomain() -> Tag {
        Tag(
            id: id,
            name: name,
            color: color
        )
    }

    /// Creates an `SDTag` from a Domain `Tag`.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Tag` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDTag` instance inserted into the given context.
    @discardableResult
    static func from(_ domain: Tag, context: ModelContext) -> SDTag {
        let model = SDTag(
            id: domain.id,
            name: domain.name,
            color: domain.color
        )
        context.insert(model)
        return model
    }

    /// Resolves an existing `SDTag` by its identifier or creates a new one.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Tag` to resolve.
    ///   - context: The `ModelContext` to search and potentially insert into.
    /// - Returns: An existing or newly created `SDTag`.
    static func resolve(_ domain: Tag, context: ModelContext) -> SDTag {
        let tagId = domain.id
        let descriptor = FetchDescriptor<SDTag>(
            predicate: #Predicate { $0.id == tagId }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        return SDTag.from(domain, context: context)
    }
}
