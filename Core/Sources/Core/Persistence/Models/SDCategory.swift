import Foundation
import SwiftData

/// A SwiftData persistence model representing a transaction category.
///
/// `SDCategory` mirrors the Domain `Category` entity and is used exclusively
/// within the `Core` module for SwiftData storage.
@Model
final class SDCategory {
    /// The unique identifier of the category.
    @Attribute(.unique) var id: UUID

    /// The display name of the category.
    var name: String

    /// The symbol or image name representing this category.
    var icon: String

    /// A hex color code associated with the category.
    var color: String

    /// The raw string representation of the category's ``TransactionType`` (income or expense).
    var type: String

    /// The preferred sorting position of the category.
    var sortOrder: Int

    /// Whether this category is a system-provided default.
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String,
        type: String,
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }
}
