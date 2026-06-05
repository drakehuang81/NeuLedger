#if canImport(FoundationModels)
import Testing
import Foundation
import Dependencies
import Domain
@testable import Core

/// Live tests for `CaptureClient` — verifies that `liveValue` forwards to the
/// underlying adapters:
/// - extract* / suggestCategories / isAvailable → `\.aiAdapter` (migrated
///   from the former `AIUseCase+Live`)
/// - requestVoicePermission / startVoiceSession / stopVoiceSession → 1:1
///   forward to `\.speechAdapter`.
@Suite("CaptureClient Live Tests")
struct CaptureClientLiveTests {

    /// Records what the spy `aiAdapter` was asked to do.
    private final class AISpy: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var lastExtractPrompt: String?
        private(set) var lastSuggestPrompt: String?
        private(set) var isAvailableCalls = 0
        func recordExtract(_ prompt: String) {
            lock.lock(); defer { lock.unlock() }
            lastExtractPrompt = prompt
        }
        func recordSuggest(_ prompt: String) {
            lock.lock(); defer { lock.unlock() }
            lastSuggestPrompt = prompt
        }
        func recordIsAvailable() {
            lock.lock(); defer { lock.unlock() }
            isAvailableCalls += 1
        }
        var extractPrompt: String? { lock.lock(); defer { lock.unlock() }; return lastExtractPrompt }
        var suggestPrompt: String? { lock.lock(); defer { lock.unlock() }; return lastSuggestPrompt }
        var availableCount: Int { lock.lock(); defer { lock.unlock() }; return isAvailableCalls }
    }

    private func spyAIAdapter(
        _ spy: AISpy,
        extracted: ExtractedTransaction = ExtractedTransaction(amount: 150, suggestedCategory: "Food", description: "lunch", type: "expense"),
        suggestions: CategorySuggestions = CategorySuggestions(suggestions: ["Food"], confidence: "high"),
        available: Bool = true
    ) -> AIAdapter {
        var adapter = AIAdapter.testValue
        adapter.extractTransaction = { prompt in spy.recordExtract(prompt); return extracted }
        adapter.suggestCategories = { prompt in spy.recordSuggest(prompt); return suggestions }
        adapter.generateText = { _ in "" }
        adapter.isAvailable = { spy.recordIsAvailable(); return available }
        return adapter
    }

    /// Records how the spy `speechAdapter` was driven.
    private final class SpeechSpy: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var permissionCalls = 0
        private(set) var startCalls = 0
        private(set) var stopCalls = 0
        func recordPermission() { lock.lock(); defer { lock.unlock() }; permissionCalls += 1 }
        func recordStart() { lock.lock(); defer { lock.unlock() }; startCalls += 1 }
        func recordStop() { lock.lock(); defer { lock.unlock() }; stopCalls += 1 }
        var permissionCount: Int { lock.lock(); defer { lock.unlock() }; return permissionCalls }
        var startCount: Int { lock.lock(); defer { lock.unlock() }; return startCalls }
        var stopCount: Int { lock.lock(); defer { lock.unlock() }; return stopCalls }
    }

    private func spySpeechAdapter(
        _ spy: SpeechSpy,
        granted: Bool = true,
        stream: @escaping @Sendable () -> AsyncThrowingStream<String, Error> = { .finished() }
    ) -> SpeechAdapter {
        var adapter = SpeechAdapter.testValue
        adapter.requestPermission = { spy.recordPermission(); return granted }
        adapter.startRecording = { spy.recordStart(); return stream() }
        adapter.stopRecording = { spy.recordStop() }
        return adapter
    }

    // MARK: - AI forwarding (migrated from AIUseCaseTests)

    @Test("extractFromText forwards the rendered prompt to aiAdapter and returns its result")
    func testExtractFromText() async throws {
        let aiSpy = AISpy()
        let expected = ExtractedTransaction(amount: 200, suggestedCategory: "Coffee", description: "café", type: "expense")
        let result = try await withDependencies {
            $0.aiAdapter = spyAIAdapter(aiSpy, extracted: expected)
            $0.speechAdapter = spySpeechAdapter(SpeechSpy())
        } operation: {
            try await CaptureClient.liveValue.extractFromText("café 200")
        }
        #expect(result == expected)
        #expect(aiSpy.extractPrompt?.contains("café 200") == true)
    }

    @Test("extractFromVoice forwards the rendered prompt to aiAdapter and returns its result")
    func testExtractFromVoice() async throws {
        let aiSpy = AISpy()
        let expected = ExtractedTransaction(amount: 55, suggestedCategory: "Food", description: "早餐", type: "expense")
        let result = try await withDependencies {
            $0.aiAdapter = spyAIAdapter(aiSpy, extracted: expected)
            $0.speechAdapter = spySpeechAdapter(SpeechSpy())
        } operation: {
            try await CaptureClient.liveValue.extractFromVoice("早餐五十五元")
        }
        #expect(result == expected)
        #expect(aiSpy.extractPrompt?.contains("早餐五十五元") == true)
    }

    @Test("suggestCategories forwards a prompt embedding the input + existing categories")
    func testSuggestCategories() async throws {
        let aiSpy = AISpy()
        let expected = CategorySuggestions(suggestions: ["Food", "Groceries"], confidence: "high")
        let result = try await withDependencies {
            $0.aiAdapter = spyAIAdapter(aiSpy, suggestions: expected)
            $0.speechAdapter = spySpeechAdapter(SpeechSpy())
        } operation: {
            try await CaptureClient.liveValue.suggestCategories("lunch", ["Food", "Transport"])
        }
        #expect(result == expected)
        #expect(aiSpy.suggestPrompt?.contains("lunch") == true)
        #expect(aiSpy.suggestPrompt?.contains("Food") == true)
    }

    @Test("isAvailable forwards to aiAdapter")
    func testIsAvailable() async throws {
        let aiSpy = AISpy()
        let result = withDependencies {
            $0.aiAdapter = spyAIAdapter(aiSpy, available: true)
            $0.speechAdapter = spySpeechAdapter(SpeechSpy())
        } operation: {
            CaptureClient.liveValue.isAvailable()
        }
        #expect(result == true)
        #expect(aiSpy.availableCount == 1)
    }

    // MARK: - Voice session forwarding (1:1 to speechAdapter)

    @Test("requestVoicePermission forwards to speechAdapter.requestPermission")
    func testRequestVoicePermission() async throws {
        let speechSpy = SpeechSpy()
        let granted = await withDependencies {
            $0.aiAdapter = spyAIAdapter(AISpy())
            $0.speechAdapter = spySpeechAdapter(speechSpy, granted: true)
        } operation: {
            await CaptureClient.liveValue.requestVoicePermission()
        }
        #expect(granted == true)
        #expect(speechSpy.permissionCount == 1)
    }

    @Test("startVoiceSession forwards to speechAdapter.startRecording and relays the stream")
    func testStartVoiceSession() async throws {
        let speechSpy = SpeechSpy()
        let makeStream: @Sendable () -> AsyncThrowingStream<String, Error> = {
            let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
            continuation.yield("早餐五十五元")
            continuation.finish()
            return stream
        }
        let collected = try await withDependencies {
            $0.aiAdapter = spyAIAdapter(AISpy())
            $0.speechAdapter = spySpeechAdapter(speechSpy, stream: makeStream)
        } operation: { () async throws -> [String] in
            var results: [String] = []
            for try await text in CaptureClient.liveValue.startVoiceSession() {
                results.append(text)
            }
            return results
        }
        #expect(collected == ["早餐五十五元"])
        #expect(speechSpy.startCount == 1)
    }

    @Test("stopVoiceSession forwards to speechAdapter.stopRecording")
    func testStopVoiceSession() async throws {
        let speechSpy = SpeechSpy()
        withDependencies {
            $0.aiAdapter = spyAIAdapter(AISpy())
            $0.speechAdapter = spySpeechAdapter(speechSpy)
        } operation: {
            CaptureClient.liveValue.stopVoiceSession()
        }
        #expect(speechSpy.stopCount == 1)
    }
}

#endif
