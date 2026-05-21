import Dependencies
import DependenciesMacros
import Foundation

/// A client interface for speech recognition and audio recording.
///
/// Use `SpeechAdapter` to request microphone and speech permissions, stream real-time
/// transcription results, and stop the active recording session.
@DependencyClient
public struct SpeechAdapter: Sendable {
    /// Requests both microphone and speech recognition permissions.
    /// Returns true only if both are granted.
    public var requestPermission: @Sendable () async -> Bool = { false }

    /// Starts recording and returns a stream of partial transcription strings.
    /// Each yielded String is the latest best-transcription result.
    /// Default returns an immediately-finished stream so that tests do not hang.
    public var startRecording: @Sendable () -> AsyncThrowingStream<String, Error> = { .finished() }

    /// Stops recording and releases the audio session so other apps can resume audio.
    public var stopRecording: @Sendable () -> Void = { }
}

extension SpeechAdapter: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var speechAdapter: SpeechAdapter {
        get { self[SpeechAdapter.self] }
        set { self[SpeechAdapter.self] = newValue }
    }
}

// MARK: - SpeechAdapterError

/// Errors thrown by `SpeechAdapter.startRecording()`.
/// Defined in Domain so the Features layer can pattern-match without a Core dependency.
public enum SpeechAdapterError: Error {
    /// The speech recognizer is not available on this device or locale.
    case recognizerUnavailable
}
