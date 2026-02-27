import Foundation

/// A data structure holding transaction fragments parsed from natural language.
///
/// Use `ExtractedTransaction` as the intermediate output of AI processing before
/// converting the structured data into an actual ``Transaction`` entity.
public struct ExtractedTransaction: Equatable, Sendable {
    /// The parsed monetary value of the transaction, if successfully determined.
    public var amount: Double?
    
    /// A potential category name interpreted from the context of the user's description.
    public var suggestedCategory: String?
    
    /// A cleaned and formatted version of the transaction's description or note.
    public var description: String?
    
    /// The interpreted textual nature of the transaction (e.g., "income" or "expense").
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
