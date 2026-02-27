import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for interacting with AI-powered financial services.
///
/// Use `AIServiceClient` to parse natural language into transactions, generate category suggestions,
/// and provide intelligent spending insights.
@DependencyClient
public struct AIServiceClient: Sendable {
    /// Extracts structured transaction data from a natural language description.
    ///
    /// - Parameter text: The natural language string describing a transaction.
    /// - Returns: An `ExtractedTransaction` containing the parsed data.
    public var extractTransaction: @Sendable (String) async throws -> ExtractedTransaction
    
    /// Suggests the most appropriate categories for a given transaction description.
    ///
    /// - Parameters:
    ///   - description: The text describing the transaction.
    ///   - availableCategories: An array of existing category names to choose from.
    /// - Returns: A `CategorySuggestions` value detailing the recommended categories and confidence.
    public var suggestCategories: @Sendable (String, [String]) async throws -> CategorySuggestions
    
    /// Generates personalized insights and advice based on recent spending data.
    ///
    /// - Parameter summary: The `SpendingSummary` containing aggregated financial data.
    /// - Returns: A localized string containing the generated insights.
    public var generateInsight: @Sendable (SpendingSummary) async throws -> String
    
    /// Checks the availability of the underlying AI service.
    ///
    /// - Returns: `true` if the AI service is properly configured and reachable; otherwise, `false`.
    public var isAvailable: @Sendable () -> Bool = { false }
}

extension AIServiceClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var aiServiceClient: AIServiceClient {
        get { self[AIServiceClient.self] }
        set { self[AIServiceClient.self] = newValue }
    }
}
