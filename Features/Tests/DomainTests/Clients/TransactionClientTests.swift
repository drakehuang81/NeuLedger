import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("TransactionClient Tests")
struct TransactionClientTests {
    @Test("TransactionClient Dependency Key injection")
    func testDependencyKey() {
        @Dependency(\.transactionClient) var client
        #expect(true, "TransactionClient injected successfully")
    }

    @Test("TransactionClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let now = Date()
        let expected = [Transaction(amount: 100, date: now, accountId: UUID(), type: .expense, createdAt: now, updatedAt: now)]

        try await withDependencies {
            $0.transactionClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.transactionClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("TransactionClient fetch with filter mock override")
    func testFetchWithFilterMock() async throws {
        let now = Date()
        let expected = [Transaction(amount: 200, date: now, accountId: UUID(), type: .income, createdAt: now, updatedAt: now)]

        try await withDependencies {
            $0.transactionClient.fetch = { _ in expected }
        } operation: {
            @Dependency(\.transactionClient) var client
            let filter = TransactionFilter(types: [.income])
            let result = try await client.fetch(filter)
            #expect(result == expected)
        }
    }

    @Test("TransactionClient search mock override")
    func testSearchMock() async throws {
        let now = Date()
        let expected = [Transaction(amount: 150, date: now, note: "lunch", accountId: UUID(), type: .expense, createdAt: now, updatedAt: now)]

        try await withDependencies {
            $0.transactionClient.search = { query in
                #expect(query == "lunch")
                return expected
            }
        } operation: {
            @Dependency(\.transactionClient) var client
            let result = try await client.search("lunch")
            #expect(result == expected)
        }
    }
}
