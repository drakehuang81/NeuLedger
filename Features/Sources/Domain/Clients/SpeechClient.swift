import Dependencies
import DependenciesMacros
import Foundation

/// A client interface for speech recognition and audio recording.
///
/// Use `SpeechClient` to request microphone and speech permissions, stream real-time
/// transcription results, and stop the active recording session.
@DependencyClient
public struct SpeechClient: Sendable {
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

extension SpeechClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}
