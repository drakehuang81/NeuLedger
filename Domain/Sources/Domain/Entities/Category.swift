import Foundation

/// A classification used to group related transactions together.
///
/// `Category` objects help users organize their financial flow (e.g., "Food", "Transportation", "Salary").
public struct Category: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// The unique identifier of the category.
    public let id: UUID
    
    /// The display name of the category.
    public var name: String
    
    /// The symbol or image name representing this category.
    public var icon: String
    
    /// A custom color associated with the category, represented as a hex string or system color name.
    public var color: String
    
    /// The fundamental nature of transactions belonging to this category (income or expense).
    public var type: TransactionType
    
    /// The preferred sorting position of the category when displayed in lists.
    public var sortOrder: Int
    
    /// A Boolean value that determines whether the category is a system-provided default.
    ///
    /// Default categories typically cannot be deleted by the user.
    public var isDefault: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String,
        type: TransactionType,
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
