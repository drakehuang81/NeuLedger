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

#endif
