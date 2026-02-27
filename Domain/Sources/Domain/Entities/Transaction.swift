import Foundation

public struct Transaction: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var amount: Decimal
    public var date: Date
    public var note: String?
    public var categoryId: Category.ID?
    public var accountId: Account.ID
    public var toAccountId: Account.ID? // Only set if type == .transfer
    public var type: TransactionType
    public var tags: [Tag]
    public var aiSuggested: Bool
    public var createdAt: Date
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
