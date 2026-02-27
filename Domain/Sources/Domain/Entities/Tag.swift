import Foundation

/// A custom marker appended to a transaction.
///
/// Use `Tag` as a secondary, multi-dimensional method for categorizing expenditures or incomes
/// independently of their primary ``Category``.
public struct Tag: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// The unique identifier of the tag.
    public let id: UUID
    
    /// The display name of the tag, such as "Business Trip", "Project A", or "Tax Deductible".
    public var name: String
    
    /// An optional custom color code representing the tag in the UI.
    public var color: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
    }
}
