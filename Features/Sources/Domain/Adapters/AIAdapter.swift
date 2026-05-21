import Foundation
import Dependencies
import DependenciesMacros

/// Low-level adapter wrapping Apple Foundation Models.
///
/// `AIAdapter` lives at the Adapter layer (architecture.md §4) — it
/// hides the `LanguageModelSession` / `@Generable` plumbing behind
/// typed closures so the Domain layer keeps zero `FoundationModels`
/// imports. `AIUseCase` (UseCase layer) composes prompts and routes
/// to the adapter; everything that creates a session lives here.
///
/// Tool-calling flows (e.g. `answerFinancialQuestion`) stay in
/// `AIUseCase` because their tool implementations cross multiple
/// Repositories — the adapter is for primitive single-shot calls.
@DependencyClient
public struct AIAdapter: Sendable {
    /// Generate a structured `ExtractedTransaction` for the given
    /// fully-rendered prompt. Caller is responsible for prompt
    /// templating + localization.
    public var extractTransaction: @Sendable (_ prompt: String) async throws -> ExtractedTransaction

    /// Generate structured `CategorySuggestions` for the given
    /// fully-rendered prompt.
    public var suggestCategories: @Sendable (_ prompt: String) async throws -> CategorySuggestions

    /// Generate a freeform text response for the given prompt. Used
    /// for narrative insights.
    public var generateText: @Sendable (_ prompt: String) async throws -> String

    /// Whether the on-device language model is available + downloaded
    /// on this device. Synchronous so caller can fall back without
    /// blocking.
    public var isAvailable: @Sendable () -> Bool = { false }
}

extension AIAdapter: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var aiAdapter: AIAdapter {
        get { self[AIAdapter.self] }
        set { self[AIAdapter.self] = newValue }
    }
}
