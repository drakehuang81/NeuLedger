import Foundation

public struct Category: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var color: String
    public var type: TransactionType
    public var sortOrder: Int
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
