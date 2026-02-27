import Foundation

public struct Account: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: AccountType
    public var icon: String
    public var color: String
    public var sortOrder: Int
    public var isArchived: Bool
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
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
