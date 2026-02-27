import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("CategoryClient Tests")
struct CategoryClientTests {
    @Test("CategoryClient Dependency Key injection")
    func testDependencyKey() {
        @Dependency(\.categoryClient) var client
        #expect(true, "CategoryClient injected successfully")
    }

    @Test("CategoryClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let expected = [Category(name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)]

        try await withDependencies {
            $0.categoryClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.categoryClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("CategoryClient fetchByType mock override")
    func testFetchByTypeMock() async throws {
        let expected = [Category(name: "Salary", icon: "briefcase", color: "#00FF00", type: .income)]

        try await withDependencies {
            $0.categoryClient.fetchByType = { type in
                #expect(type == .income)
                return expected
            }
        } operation: {
            @Dependency(\.categoryClient) var client
            let result = try await client.fetchByType(.income)
            #expect(result == expected)
        }
    }
}
