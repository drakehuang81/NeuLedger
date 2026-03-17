import Foundation
import FoundationModels

/// A data structure holding transaction fragments parsed from natural language.
///
/// `@Generable` lets Foundation Models produce this struct directly from a prompt.
/// All fields are Optional so the model can express uncertainty — callers check nil before using.
@Generable
public struct ExtractedTransaction: Equatable, Sendable {
    /// The parsed monetary value of the transaction, if successfully determined.
    @Guide(description: "Transaction amount in TWD as a whole number (no decimals), always positive. Nil if unclear.")
    public var amount: Int?

    /// A potential category name interpreted from the context of the user's description.
    @Guide(description: "Best-guess category name from user's input. Nil if not determinable.")
    public var suggestedCategory: String?

    /// A cleaned and formatted version of the transaction's description or note.
    @Guide(description: "Short note in Traditional Chinese if possible. Nil if not provided.")
    public var description: String?

    /// The interpreted textual nature of the transaction.
    @Guide(description: "Type: 'expense', 'income', or 'transfer'. Nil if unclear.")
    public var type: String?

    // Keep the custom init for callers (testValue, test fixtures, etc.).
    // If @Generable synthesizes a conflicting init, remove this block.
    public init(
        amount: Int? = nil,
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
