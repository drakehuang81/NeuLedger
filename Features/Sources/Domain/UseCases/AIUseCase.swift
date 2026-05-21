import Foundation
import Dependencies
import DependenciesMacros

/// A use case for active AI features — extracting structured data
/// from natural language and suggesting categorisations.
///
/// Surface follows `docs/architecture.md` §5 Intelligence Context.
/// Live implementation delegates the raw `LanguageModelSession` /
/// `@Generable` plumbing to `AIAdapter` (Adapter layer); prompt
/// templating and orchestration stay in this UseCase.
///
/// Read-side narrative AI (`generateInsight`) belongs to
/// `AnalyticsUseCase` per §5 — it's a summary of existing data
/// rather than a creation action — but is exposed here in transitional
/// form for callsites that haven't migrated yet.
@DependencyClient
public struct AIUseCase: Sendable {
    /// Extracts a structured `ExtractedTransaction` from a
    /// natural-language description authored by the user.
    public var extractFromText: @Sendable (_ text: String) async throws -> ExtractedTransaction

    /// Extracts a structured `ExtractedTransaction` from a voice
    /// transcript. Voice is transcribed elsewhere (`SpeechAdapter`);
    /// this entry point only receives the resulting text, but exists
    /// as a separate method so future voice-specific prompt tuning
    /// can plug in without touching `extractFromText`.
    public var extractFromVoice: @Sendable (_ transcript: String) async throws -> ExtractedTransaction

    /// Suggests the most appropriate categories for a given
    /// transaction description.
    public var suggestCategories: @Sendable (_ text: String, _ existing: [String]) async throws -> CategorySuggestions

    /// Narrative insight from a `SpendingSummary`. Lives on
    /// `AnalyticsUseCase` per §5 (`generateAIInsight`); kept here for
    /// backwards compatibility during the migration.
    public var generateInsight: @Sendable (SpendingSummary) async throws -> String

    /// Carousel-style list of insights for the Dashboard B1 redesign.
    /// Currently returns hand-authored copy; will be promoted to a
    /// real adapter call when the design ships.
    public var generateInsights: @Sendable (_ summary: SpendingSummary) async throws -> [InsightData] = { _ in [] }

    /// Tool-calling QA over the user's transaction history. Stays on
    /// `AIUseCase` because the tool implementation crosses multiple
    /// Repositories (transactions + categories) and that orchestration
    /// is part of the UseCase, not the Adapter.
    public var answerFinancialQuestion: @Sendable (String) async throws -> String

    /// Whether the on-device language model is available.
    public var isAvailable: @Sendable () -> Bool = { false }
}

extension AIUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var aiUseCase: AIUseCase {
        get { self[AIUseCase.self] }
        set { self[AIUseCase.self] = newValue }
    }
}
