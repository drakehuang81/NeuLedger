import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("BudgetClient Tests")
struct BudgetClientTests {
    @Test("BudgetClient Dependency Key injection")
    func testDependencyKey() {
        @Dependency(\.budgetClient) var client
        #expect(true, "BudgetClient injected successfully")
    }

    @Test("BudgetClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let now = Date()
        let expected = [Budget(name: "Groceries", amount: 500, period: .monthly, startDate: now)]

        try await withDependencies {
            $0.budgetClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.budgetClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("BudgetClient fetchActive mock override")
    func testFetchActiveMock() async throws {
        let now = Date()
        let active = [Budget(name: "Active", amount: 1000, period: .monthly, startDate: now, isActive: true)]

        try await withDependencies {
            $0.budgetClient.fetchActive = { active }
        } operation: {
            @Dependency(\.budgetClient) var client
            let result = try await client.fetchActive()
            #expect(result == active)
            #expect(result.first?.isActive == true)
        }
    }
}
