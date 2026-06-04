#if canImport(FoundationModels)
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
