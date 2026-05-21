import AVFoundation
import Dependencies
import Domain
import Speech

extension SpeechAdapter: DependencyKey {
    public static var liveValue: SpeechAdapter {
        let actor = SpeechRecordingActor()
        return SpeechAdapter(
            requestPermission: { await actor.requestPermission() },
            startRecording: { actor.startRecording() },
            stopRecording: {
                // Fire-and-forget is acceptable here because:
                // 1. stopRecording() calls streamContinuation?.finish() first,
                //    so the stream consumer sees the stream end immediately once
                //    the actor hop completes.
                // 2. The TCA effect is cancelled via CancelID, so any pending
                //    stream values are dropped regardless.
                // 3. AVAudioEngine.stop() and AVAudioSession.setActive(false) are
                //    idempotent teardown that don't need to complete before the
                //    next action is processed.
                Task { await actor.stopRecording() }
            }
        )
    }
}

// MARK: - SpeechRecordingActor

private actor SpeechRecordingActor {
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    // Fix C1 + C2: store the continuation so stopRecording() can explicitly finish it.
    private var streamContinuation: AsyncThrowingStream<String, Error>.Continuation?

    // Fix I1: request both permissions concurrently, regardless of mic result.
    func requestPermission() async -> Bool {
        async let micGranted = AVAudioApplication.requestRecordPermission()
        let speechStatus = await withCheckedContinuation {
            (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return await micGranted && speechStatus == .authorized
    }

    nonisolated func startRecording() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.beginRecording(continuation: continuation)
            }
        }
    }

    private func beginRecording(
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async {
        // Fix C1 + C2: store continuation before any early-exit path so
        // stopRecording() can always reach it.
        self.streamContinuation = continuation

        do {
            // zh-TW first; fall back to system locale if unavailable on this device
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
                    ?? SFSpeechRecognizer(locale: .current),
                  recognizer.isAvailable else {
                continuation.finish(throwing: SpeechAdapterError.recognizerUnavailable)
                self.streamContinuation = nil
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
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
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
            self.streamContinuation = nil
        }
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        // Fix C1 + C2: explicitly finish the stream so the consumer doesn't hang
        // waiting for a recognition callback that may never arrive after cancel().
        streamContinuation?.finish()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        streamContinuation = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}

