import Foundation

/// A record representing a single financial movement, such as an expense, income, or transfer.
///
/// `Transaction` is the core entity of the application, capturing the details of money flows.
/// It associates an amount with specific dates, accounts, categories, and optional descriptive tags or notes.
public struct Transaction: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// The unique identifier of the transaction.
    public let id: UUID
    
    /// The monetary value of the transaction.
    public var amount: Decimal
    
    /// The date and time when the transaction occurred or was recorded.
    public var date: Date
    
    /// Optional supplementary details or memos provided by the user.
    public var note: String?
    
    /// The identifier of the category analyzing this transaction.
    ///
    /// This may be `nil` for certain types like transfers, or if the transaction is uncategorized.
    public var categoryId: Category.ID?
    
    /// The identifier of the primary account involved in the transaction.
    ///
    /// For expenses, this is where funds are withdrawn. For income, this is where funds are deposited.
    public var accountId: Account.ID
    
    /// The identifier of the destination account.
    ///
    /// This value is only used when the `type` is ``TransactionType/transfer``, indicating the receiving end of the transfer.
    public var toAccountId: Account.ID? // Only set if type == .transfer
    
    /// The fundamental nature of the transaction (e.g., expense, income, transfer).
    public var type: TransactionType
    
    /// An array of custom descriptive tags associated with this transaction.
    public var tags: [Tag]
    
    /// A Boolean value that indicates whether the transaction details were populated automatically by an AI service.
    public var aiSuggested: Bool
    
    /// The date and time when this record was originally created.
    public var createdAt: Date
    
    /// The date and time when this record was last modified.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date,
        note: String? = nil,
        categoryId: Category.ID? = nil,
        accountId: Account.ID,
        toAccountId: Account.ID? = nil,
        type: TransactionType,
        tags: [Tag] = [],
        aiSuggested: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.categoryId = categoryId
        self.accountId = accountId
        self.toAccountId = toAccountId
        self.type = type
        self.tags = tags
        self.aiSuggested = aiSuggested
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
