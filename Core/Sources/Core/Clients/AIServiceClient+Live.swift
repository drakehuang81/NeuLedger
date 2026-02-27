import Foundation
import Domain
import Dependencies

/// Placeholder live implementation of `AIServiceClient`.
///
/// This phase provides stub implementations that return empty/default values.
/// The real Foundation Models integration will be implemented in a future change.
extension AIServiceClient: @retroactive DependencyKey {
    public static let liveValue = AIServiceClient(
        extractTransaction: { _ in
            ExtractedTransaction()
        },
        suggestCategories: { _, _ in
            CategorySuggestions(suggestions: [], confidence: "none")
        },
        generateInsight: { _ in
            ""
        },
        isAvailable: { false }
    )
}
