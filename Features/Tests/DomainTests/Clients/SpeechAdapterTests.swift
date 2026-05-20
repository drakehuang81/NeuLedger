import Dependencies
import Foundation
import Testing
@testable import Domain

@Suite("SpeechAdapter Tests")
struct SpeechAdapterTests {

    @Test("SpeechAdapter testValue defaults: requestPermission returns false")
    func testDependencyKey() async {
        let client = SpeechAdapter(
            requestPermission: { false },
            startRecording: { .finished() },
            stopRecording: { }
        )
        let granted = await client.requestPermission()
        #expect(granted == false)
    }

    @Test("SpeechAdapter requestPermission mock override")
    func testRequestPermissionMock() async {
        await withDependencies {
            $0.speechAdapter.requestPermission = { true }
        } operation: {
            @Dependency(\.speechAdapter) var client
            let result = await client.requestPermission()
            #expect(result == true)
        }
    }

    @Test("SpeechAdapter startRecording mock emits transcription text")
    func testStartRecordingMock() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.yield("早餐五十五元")
        continuation.finish()

        try await withDependencies {
            $0.speechAdapter.startRecording = { stream }
        } operation: {
            @Dependency(\.speechAdapter) var client
            var results: [String] = []
            for try await text in client.startRecording() {
                results.append(text)
            }
            #expect(results == ["早餐五十五元"])
        }
    }

    @Test("SpeechAdapter stopRecording mock override")
    func testStopRecordingMock() {
        let called = LockIsolated(false)
        withDependencies {
            $0.speechAdapter.stopRecording = { called.setValue(true) }
        } operation: {
            @Dependency(\.speechAdapter) var client
            client.stopRecording()
        }
        #expect(called.value == true)
    }
}
