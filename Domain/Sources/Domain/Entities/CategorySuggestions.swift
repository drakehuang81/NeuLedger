import Foundation

public struct CategorySuggestions: Equatable, Sendable {
    public var suggestions: [String]
    public var confidence: String
    
    public init(
        suggestions: [String] = [],
        confidence: String
    ) {
        self.suggestions = suggestions
        self.confidence = confidence
    }
}
