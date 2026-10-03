// watchOS 一併排除，不是只看 `canImport`：Xcode 27 起 watchOS SDK 也**有**
// FoundationModels，所以 `canImport` 在 watch target 變成 true——但裡面的
// `@Generable` / `@Guide` / `GenerationSchema` 全部標著 watchOS 27+，而本專案的
// watchOS deployment target 是 26.2，於是整包在 watch 上編不過（Xcode Cloud
// build #21 就是這樣失敗的，當時的處置是把 workflow 釘回 Xcode 26.6）。
//
// 直接排除而不是加 `@available`：手錶端沒有任何程式碼用到這些型別
// （grep 全 `WatchFeatures` 與 Watch app target 為零），所以把它們留在 watch
// 的編譯單元裡本來就沒有意義。
#if canImport(FoundationModels) && !os(watchOS)
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

#endif
