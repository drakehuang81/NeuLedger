#if canImport(FoundationModels)
import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("CaptureClient Domain Tests")
struct CaptureClientTests {

    @Test("CaptureClient testValue is accessible via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.captureClient) var client
        #expect(true, "CaptureClient injected successfully")
    }

    @Test("CaptureClient extractFromText mock override")
    func testExtractFromTextMock() async throws {
        let expected = ExtractedTransaction(amount: 150, suggestedCategory: "Food", description: "lunch", type: "expense")

        try await withDependencies {
            $0.captureClient.extractFromText = { input in
                #expect(input == "lunch 150")
                return expected
            }
        } operation: {
            @Dependency(\.captureClient) var client
            let result = try await client.extractFromText("lunch 150")
            #expect(result == expected)
        }
    }

    @Test("CaptureClient extractFromVoice mock override")
    func testExtractFromVoiceMock() async throws {
        let expected = ExtractedTransaction(amount: 55, suggestedCategory: "Food", description: "早餐", type: "expense")

        try await withDependencies {
            $0.captureClient.extractFromVoice = { transcript in
                #expect(transcript == "早餐五十五元")
                return expected
            }
        } operation: {
            @Dependency(\.captureClient) var client
            let result = try await client.extractFromVoice("早餐五十五元")
            #expect(result == expected)
        }
    }

    @Test("CaptureClient suggestCategories mock override")
    func testSuggestCategoriesMock() async throws {
        let expected = CategorySuggestions(suggestions: ["Food", "Groceries"], confidence: "high")

        try await withDependencies {
            $0.captureClient.suggestCategories = { input, categories in
                #expect(input == "lunch")
                #expect(categories.contains("Food"))
                return expected
            }
        } operation: {
            @Dependency(\.captureClient) var client
            let result = try await client.suggestCategories("lunch", ["Food", "Transport"])
            #expect(result == expected)
        }
    }

    @Test("CaptureClient isAvailable mock override")
    func testIsAvailableMock() {
        withDependencies {
            $0.captureClient.isAvailable = { true }
        } operation: {
            @Dependency(\.captureClient) var client
            #expect(client.isAvailable() == true)
        }
    }

    @Test("CaptureClient requestVoicePermission mock override")
    func testRequestVoicePermissionMock() async {
        await withDependencies {
            $0.captureClient.requestVoicePermission = { true }
        } operation: {
            @Dependency(\.captureClient) var client
            let granted = await client.requestVoicePermission()
            #expect(granted == true)
        }
    }

    @Test("CaptureClient startVoiceSession mock emits transcription text")
    func testStartVoiceSessionMock() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        continuation.yield("早餐五十五元")
        continuation.finish()

        try await withDependencies {
            $0.captureClient.startVoiceSession = { stream }
        } operation: {
            @Dependency(\.captureClient) var client
            var results: [String] = []
            for try await text in client.startVoiceSession() {
                results.append(text)
            }
            #expect(results == ["早餐五十五元"])
        }
    }

    @Test("CaptureClient stopVoiceSession mock override")
    func testStopVoiceSessionMock() {
        let called = LockIsolated(false)
        withDependencies {
            $0.captureClient.stopVoiceSession = { called.setValue(true) }
        } operation: {
            @Dependency(\.captureClient) var client
            client.stopVoiceSession()
        }
        #expect(called.value == true)
    }
}

#endif
