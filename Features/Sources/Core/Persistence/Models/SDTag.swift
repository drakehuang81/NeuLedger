import Foundation
import SwiftData

/// A SwiftData persistence model representing a user-defined tag.
///
/// `SDTag` mirrors the Domain `Tag` entity. It participates in a many-to-many
/// relationship with ``SDTransaction`` via SwiftData's native `@Relationship`.
@Model
final class SDTag {
    /// The unique identifier of the tag.
    @Attribute(.unique) var id: UUID

    /// The display name of the tag.
    var name: String

    /// An optional hex color code associated with the tag.
    var color: String?

    /// The transactions associated with this tag (inverse of ``SDTransaction/tags``).
    @Relationship(inverse: \SDTransaction.tags)
    var transactions: [SDTransaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
    }
}
