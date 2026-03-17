import Foundation
import FoundationModels

/// A structured response containing category recommendations provided by an AI service.
///
/// `@Generable` lets Foundation Models produce this struct from a prompt.
@Generable
public struct CategorySuggestions: Equatable, Sendable {
    /// Up to 3 category names from the provided list, ranked by relevance. Must be exact matches.
    @Guide(description: "Up to 3 category names from the provided list, ranked by relevance. Must be exact matches from the list.")
    public var suggestions: [String]

    /// The AI's reported confidence level (e.g., "high", "medium", "low").
    @Guide(description: "Confidence level: 'high', 'medium', or 'low'.")
    public var confidence: String

    public init(
        suggestions: [String] = [],
        confidence: String = "low"
    ) {
        self.suggestions = suggestions
        self.confidence = confidence
    }
}
