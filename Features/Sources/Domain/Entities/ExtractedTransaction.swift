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

/// A data structure holding transaction fragments parsed from natural language.
///
/// `@Generable` lets Foundation Models produce this struct directly from a prompt.
/// All fields are Optional so the model can express uncertainty — callers check nil before using.
@Generable
public struct ExtractedTransaction: Equatable, Sendable {
    /// The parsed monetary value of the transaction, if successfully determined.
    @Guide(description: "Transaction amount in TWD as a whole number (no decimals), always positive. Nil if unclear.")
    public var amount: Int?

    /// A potential category name interpreted from the context of the user's description.
    @Guide(description: "Best-guess category name from user's input. Nil if not determinable.")
    public var suggestedCategory: String?

    /// A cleaned and formatted version of the transaction's description or note.
    @Guide(description: "Short note summarising the transaction. Use the same language as the prompt. Nil if not provided.")
    public var description: String?

    /// The interpreted textual nature of the transaction.
    @Guide(description: "Type: 'expense', 'income', or 'transfer'. Nil if unclear.")
    public var type: String?

    // Keep the custom init for callers (testValue, test fixtures, etc.).
    // If @Generable synthesizes a conflicting init, remove this block.
    public init(
        amount: Int? = nil,
        suggestedCategory: String? = nil,
        description: String? = nil,
        type: String? = nil
    ) {
        self.amount = amount
        self.suggestedCategory = suggestedCategory
        self.description = description
        self.type = type
    }
}

#endif
