import Foundation
import SwiftData

/// A SwiftData persistence model representing a user's financial account.
///
/// `SDAccount` mirrors the Domain `Account` entity and is used exclusively
/// within the `Core` module for SwiftData storage.
@Model
final class SDAccount {
    /// The unique identifier of the account.
    @Attribute(.unique) var id: UUID

    /// The display name of the account.
    var name: String

    /// The raw string representation of the account's ``AccountType``.
    var type: String

    /// The symbol or image name representing this account.
    var icon: String

    /// A hex color code associated with the account.
    var color: String

    /// The preferred sorting position of the account.
    var sortOrder: Int

    /// Whether the account is archived.
    var isArchived: Bool

    /// The date and time when this account was created.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        icon: String,
        color: String,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
