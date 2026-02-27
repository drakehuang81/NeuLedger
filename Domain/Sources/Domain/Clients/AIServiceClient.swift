import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct AIServiceClient: Sendable {
    public var extractTransaction: @Sendable (String) async throws -> ExtractedTransaction
    public var suggestCategories: @Sendable (String, [String]) async throws -> CategorySuggestions
    public var generateInsight: @Sendable (SpendingSummary) async throws -> String
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
