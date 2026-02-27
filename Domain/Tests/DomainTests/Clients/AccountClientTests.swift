import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("AccountClient Tests")
struct AccountClientTests {
    @Test("AccountClient Dependency Key injection")
    func testDependencyKey() {
        @Dependency(\.accountClient) var client
        #expect(true, "AccountClient injected successfully")
    }

    @Test("AccountClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let now = Date()
        let expected = [Account(name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF", createdAt: now)]

        try await withDependencies {
            $0.accountClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.accountClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("AccountClient computeBalance mock override")
    func testComputeBalanceMock() async throws {
        let accountId = UUID()

        try await withDependencies {
            $0.accountClient.computeBalance = { id in
                #expect(id == accountId)
                return 1500
            }
        } operation: {
            @Dependency(\.accountClient) var client
            let balance = try await client.computeBalance(accountId)
            #expect(balance == 1500)
        }
    }
}
