import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("BudgetClient Integration Tests")
struct BudgetClientTests {
    var container: ModelContainer
    var sut: BudgetClient

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container

        let testDatabaseClient = DatabaseClient(modelContainer: { _container })

        self.sut = withDependencies {
            $0.databaseClient = testDatabaseClient
        } operation: {
            BudgetClient.liveValue
        }
    }

    @Test("add stores budget and fetchAll returns it")
    func testAddAndFetchAll() async throws {
        let budget = Budget(
            id: UUID(),
            name: "食費",
            amount: 10000,
            categoryId: nil,
            period: .monthly,
            startDate: Date(),
            isActive: true
        )
        try await sut.add(budget)
        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].name == "食費")
        #expect(all[0].amount == 10000)
    }

    @Test("update modifies existing budget")
    func testUpdate() async throws {
        let budget = Budget(
            id: UUID(),
            name: "原始",
            amount: 5000,
            categoryId: nil,
            period: .monthly,
            startDate: Date(),
            isActive: true
        )
        try await sut.add(budget)

        let updatedBudget = Budget(
            id: budget.id,
            name: "更新後",
            amount: 8000,
            categoryId: nil,
            period: .monthly,
            startDate: budget.startDate,
            isActive: true
        )
        try await sut.update(updatedBudget)

        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].name == "更新後")
        #expect(all[0].amount == 8000)
    }

    @Test("delete removes budget from store")
    func testDelete() async throws {
        let budget = Budget(
            id: UUID(),
            name: "食費",
            amount: 10000,
            categoryId: nil,
            period: .monthly,
            startDate: Date(),
            isActive: true
        )
        try await sut.add(budget)
        try await sut.delete(budget.id)
        let all = try await sut.fetchAll()
        #expect(all.isEmpty)
    }

    @Test("fetchActive returns only active budgets")
    func testFetchActive() async throws {
        let activeBudget = Budget(
            id: UUID(),
            name: "Active",
            amount: 1000,
            categoryId: nil,
            period: .monthly,
            startDate: Date(),
            isActive: true
        )
        let inactiveBudget = Budget(
            id: UUID(),
            name: "Inactive",
            amount: 2000,
            categoryId: nil,
            period: .monthly,
            startDate: Date(),
            isActive: false
        )
        try await sut.add(activeBudget)
        try await sut.add(inactiveBudget)

        let result = try await sut.fetchActive()
        #expect(result.count == 1)
        #expect(result[0].name == "Active")
    }
}
