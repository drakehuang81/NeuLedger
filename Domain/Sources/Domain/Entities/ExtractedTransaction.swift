import Foundation

public struct ExtractedTransaction: Equatable, Sendable {
    public var amount: Double?
    public var suggestedCategory: String?
    public var description: String?
    public var type: String?
    
    public init(
        amount: Double? = nil,
        suggestedCategory: String? = nil,
        description: String? = nil,
        type: String? = nil
    ) {
        self.amount = amount
        self.suggestedCategory = suggestedCategory
        self.description = description
        self.type = type
    }
}
