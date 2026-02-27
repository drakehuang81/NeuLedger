import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("TagClient Tests")
struct TagClientTests {
    @Test("TagClient Dependency Key injection")
    func testDependencyKey() {
        @Dependency(\.tagClient) var client
        #expect(true, "TagClient injected successfully")
    }

    @Test("TagClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let expected = [Domain.Tag(name: "Travel", color: "#0000FF")]

        try await withDependencies {
            $0.tagClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.tagClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("TagClient add mock override")
    func testAddMock() async throws {
        try await withDependencies {
            $0.tagClient.add = { _ in }
        } operation: {
            @Dependency(\.tagClient) var client
            let tag = Domain.Tag(name: "Business")
            try await client.add(tag)
        }
    }
}
