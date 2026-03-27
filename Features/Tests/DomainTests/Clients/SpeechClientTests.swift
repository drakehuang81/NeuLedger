import Dependencies
import Foundation
import Testing
@testable import Domain

@Suite("SpeechClient Tests")
struct SpeechClientTests {

    @Test("SpeechClient is injectable via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.speechClient) var client
        #expect(true, "SpeechClient injected successfully")
    }

    @Test("SpeechClient requestPermission mock override")
    func testRequestPermissionMock() async {
        await withDependencies {
            $0.speechClient.requestPermission = { true }
        } operation: {
            @Dependency(\.speechClient) var client
            let result = await client.requestPermission()
            #expect(result == true)
        }
    }

    @Test("SpeechClient startRecording mock emits transcription text")
    func testStartRecordingMock() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.yield("早餐五十五元")
        continuation.finish()

        try await withDependencies {
            $0.speechClient.startRecording = { stream }
        } operation: {
            @Dependency(\.speechClient) var client
            var results: [String] = []
            for try await text in client.startRecording() {
                results.append(text)
            }
            #expect(results == ["早餐五十五元"])
        }
    }

    @Test("SpeechClient stopRecording mock override")
    func testStopRecordingMock() {
        let called = LockIsolated(false)
        withDependencies {
            $0.speechClient.stopRecording = { called.setValue(true) }
        } operation: {
            @Dependency(\.speechClient) var client
            client.stopRecording()
        }
        #expect(called.value == true)
    }
}
