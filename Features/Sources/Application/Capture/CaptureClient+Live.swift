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
import Domain
import Dependencies

/// Live implementation of `CaptureClient`.
///
/// The extraction + suggestion + availability closures are migrated from the
/// former `AIUseCase+Live`: they compose localized prompts and route to
/// `\.aiAdapter`, which hides the `LanguageModelSession` / `@Generable`
/// plumbing. `extractFromText` and `extractFromVoice` share an identical
/// implementation today; they are kept as separate closures so future
/// voice-specific prompt tuning can land in `extractFromVoice` alone.
///
/// The three voice-session closures are a 1:1 forward to `\.speechAdapter`
/// (`requestPermission` / `startRecording` / `stopRecording`) — this is the
/// cost of the "Features must not touch the Adapter layer" rule, and is
/// accepted per the design contract (§A.4).
extension CaptureClient: DependencyKey {
    private static func listSeparator() -> String {
        Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true ? "、" : ", "
    }

    public static var liveValue: CaptureClient {
        @Dependency(\.aiAdapter) var aiAdapter
        @Dependency(\.speechAdapter) var speechAdapter

        // extractFromText and extractFromVoice share identical implementation
        // today. Keeping them as separate closures lets future voice-specific
        // prompt tuning land in extractFromVoice alone.
        let extract: @Sendable (String) async throws -> ExtractedTransaction = { input in
            let template = String(localized: "ai_prompt_extract_transaction", bundle: .main)
            let prompt = String(format: template, input)
            return try await aiAdapter.extractTransaction(prompt)
        }

        return CaptureClient(
            extractFromText: extract,
            extractFromVoice: extract,

            suggestCategories: { description, existingCategories in
                let categoryList = existingCategories.joined(separator: listSeparator())
                let template = String(localized: "ai_prompt_suggest_categories", bundle: .main)
                let prompt = String(format: template, description, categoryList)
                return try await aiAdapter.suggestCategories(prompt)
            },

            isAvailable: {
                aiAdapter.isAvailable()
            },

            // MARK: - Voice session (1:1 forward to speechAdapter)

            requestVoicePermission: {
                await speechAdapter.requestPermission()
            },

            startVoiceSession: {
                speechAdapter.startRecording()
            },

            stopVoiceSession: {
                speechAdapter.stopRecording()
            }
        )
    }
}

#endif
