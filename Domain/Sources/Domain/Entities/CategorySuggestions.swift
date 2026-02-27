import Foundation

/// A structured response containing category recommendations provided by an AI service.
///
/// This structure holds a list of probable categories for a given transaction description and
/// indicates the AI's confidence level in its suggestions.
public struct CategorySuggestions: Equatable, Sendable {
    /// An array of recommended category names.
    public var suggestions: [String]
    
    /// The AI's reported confidence level concerning these suggestions (e.g., "High", "Low", or a specific score).
    public var confidence: String
    
    public init(
        suggestions: [String] = [],
        confidence: String
    ) {
        self.suggestions = suggestions
        self.confidence = confidence
    }
}
