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

/// A client interface for the Capture context — turning the user's raw input
/// (typed text or a voice transcript) into structured transaction data, plus
/// the voice-recording session lifecycle.
///
/// `CaptureClient` consolidates the creation-side AI features formerly on
/// `AIUseCase` (`extractFromText` / `extractFromVoice` / `suggestCategories`
/// / `isAvailable`) together with the voice session that previously required
/// callers to inject `SpeechAdapter` directly. The three voice methods are a
/// 1:1 forward to `\.speechAdapter` so the Features layer never touches the
/// Adapter layer.
@DependencyClient
public struct CaptureClient: Sendable {
    /// Extracts a structured `ExtractedTransaction` from a natural-language
    /// description authored by the user.
    public var extractFromText: @Sendable (_ text: String) async throws -> ExtractedTransaction

    /// Extracts a structured `ExtractedTransaction` from a voice transcript.
    /// Voice is transcribed via the voice session methods below; this entry
    /// point only receives the resulting text, but exists as a separate
    /// method so future voice-specific prompt tuning can plug in without
    /// touching `extractFromText`.
    public var extractFromVoice: @Sendable (_ transcript: String) async throws -> ExtractedTransaction

    /// Suggests the most appropriate categories for a given transaction
    /// description, ranked against the supplied existing category names.
    public var suggestCategories: @Sendable (_ text: String, _ existing: [String]) async throws -> CategorySuggestions

    /// Whether the on-device language model is available for capture features.
    public var isAvailable: @Sendable () -> Bool = { false }

    /// Requests microphone + speech-recognition permission. Returns true only
    /// if both are granted. 1:1 forward to `\.speechAdapter.requestPermission`.
    public var requestVoicePermission: @Sendable () async -> Bool = { false }

    /// Starts a voice recording session and returns a stream of partial
    /// transcription strings (each is the latest best transcription). 1:1
    /// forward to `\.speechAdapter.startRecording`.
    public var startVoiceSession: @Sendable () -> AsyncThrowingStream<String, Error> = { .finished() }

    /// Stops the active voice recording session and releases the audio
    /// session. 1:1 forward to `\.speechAdapter.stopRecording`.
    public var stopVoiceSession: @Sendable () -> Void = { }
}

extension CaptureClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var captureClient: CaptureClient {
        get { self[CaptureClient.self] }
        set { self[CaptureClient.self] = newValue }
    }
}

#endif
