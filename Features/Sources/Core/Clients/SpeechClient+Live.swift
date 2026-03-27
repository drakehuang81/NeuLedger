import AVFoundation
import Dependencies
import Domain
import Speech

extension SpeechClient: DependencyKey {
    public static var liveValue: SpeechClient {
        let actor = SpeechRecordingActor()
        return SpeechClient(
            requestPermission: { await actor.requestPermission() },
            startRecording: { actor.startRecording() },
            stopRecording: { Task { await actor.stopRecording() } }
        )
    }
}

// MARK: - SpeechRecordingActor

private actor SpeechRecordingActor {
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    func requestPermission() async -> Bool {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { return false }

        let status = await withCheckedContinuation {
            (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }

    nonisolated func startRecording() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                await self.beginRecording(continuation: continuation)
            }
        }
    }

    private func beginRecording(
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        do {
            // zh-TW first; fall back to system locale if unavailable on this device
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
                    ?? SFSpeechRecognizer(locale: .current),
                  recognizer.isAvailable else {
                continuation.finish(throwing: SpeechClientError.recognizerUnavailable)
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let engine = AVAudioEngine()
            audioEngine = engine

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    continuation.yield(result.bestTranscription.formattedString)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else if result?.isFinal == true {
                    continuation.finish()
                }
            }
        } catch {
            continuation.finish(throwing: error)
        }
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}

// MARK: - SpeechClientError

enum SpeechClientError: Error {
    case recognizerUnavailable
}
