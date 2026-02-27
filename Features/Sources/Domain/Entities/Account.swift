import Foundation

/// A representation of a physical or virtual financial account.
///
/// Use `Account` to represent where funds are held, such as physical cash, bank accounts, or digital wallets.
public struct Account: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// The unique identifier of the account.
    public let id: UUID
    
    /// The display name of the account, such as "Daily Wallet" or "Credit Card".
    public var name: String
    
    /// The financial nature or type of this account.
    public var type: AccountType
    
    /// The symbol or image name representing this account (e.g., an SF Symbol name).
    public var icon: String
    
    /// A custom color associated with the account, represented as a hex string or system color name.
    public var color: String
    
    /// The preferred sorting position of the account when displayed in lists.
    public var sortOrder: Int
    
    /// A Boolean value that determines whether the account is currently archived.
    ///
    /// Archived accounts keep their historical transaction data but are omitted from active selection interfaces.
    public var isArchived: Bool
    
    /// The date and time when this account entity was created.
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
