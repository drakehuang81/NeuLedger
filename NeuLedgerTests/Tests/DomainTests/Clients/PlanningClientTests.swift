import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("PlanningClient Domain Tests")
struct PlanningClientTests {

    @Test("PlanningClient testValue is accessible via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.planningClient) var client
        #expect(true, "PlanningClient injected successfully")
    }

    @Test("PlanningClient listAll mock override")
    func testListAllMock() async throws {
        let expected = [Budget(name: "Groceries", amount: 500, period: .monthly, startDate: Date())]
        try await withDependencies {
            $0.planningClient.listAll = { expected }
        } operation: {
            @Dependency(\.planningClient) var client
            let result = try await client.listAll()
            #expect(result == expected)
        }
    }

    @Test("PlanningClient listActive mock override")
    func testListActiveMock() async throws {
        let active = [Budget(name: "Active", amount: 1000, period: .monthly, startDate: Date(), isActive: true)]
        try await withDependencies {
            $0.planningClient.listActive = { active }
        } operation: {
            @Dependency(\.planningClient) var client
            let result = try await client.listActive()
            #expect(result == active)
            #expect(result.first?.isActive == true)
        }
    }

    @Test("PlanningClient create mock override")
    func testCreateMock() async throws {
        try await withDependencies {
            $0.planningClient.create = { _ in }
        } operation: {
            @Dependency(\.planningClient) var client
            try await client.create(Budget(name: "X", amount: 100, period: .monthly, startDate: Date()))
        }
    }

    @Test("PlanningClient update mock override")
    func testUpdateMock() async throws {
        try await withDependencies {
            $0.planningClient.update = { _ in }
        } operation: {
            @Dependency(\.planningClient) var client
            try await client.update(Budget(name: "X", amount: 100, period: .monthly, startDate: Date()))
        }
    }

    @Test("PlanningClient delete mock override")
    func testDeleteMock() async throws {
        let id = UUID()
        try await withDependencies {
            $0.planningClient.delete = { _ in }
        } operation: {
            @Dependency(\.planningClient) var client
            try await client.delete(id)
        }
    }

    @Test("PlanningClient currentStatus mock override")
    func testCurrentStatusMock() async throws {
        let budget = Budget(name: "X", amount: 1000, period: .monthly, startDate: Date())
        let expected = BudgetStatus(
            budget: budget, periodStart: Date(), periodEnd: Date(), spent: 250
        )
        try await withDependencies {
            $0.planningClient.currentStatus = { _ in expected }
        } operation: {
            @Dependency(\.planningClient) var client
            let result = try await client.currentStatus(budget)
            #expect(result.spent == 250)
        }
    }

    @Test("PlanningClient evaluateAfterTransaction mock override")
    func testEvaluateMock() async {
        let txn = Transaction(
            id: UUID(), amount: 100, date: Date(), note: nil,
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], aiSuggested: false,
            createdAt: Date(), updatedAt: Date()
        )
        await withDependencies {
            $0.planningClient.evaluateAfterTransaction = { _ in }
        } operation: {
            @Dependency(\.planningClient) var client
            await client.evaluateAfterTransaction(txn)
        }
    }

    @Test("PlanningClient warningEnabled / setWarningEnabled mock override")
    func testWarningEnabledMock() {
        withDependencies {
            $0.planningClient.warningEnabled = { true }
            $0.planningClient.setWarningEnabled = { _ in }
        } operation: {
            @Dependency(\.planningClient) var client
            #expect(client.warningEnabled() == true)
            client.setWarningEnabled(false)
        }
    }

    @Test("PlanningClient warningThreshold / setWarningThreshold mock override")
    func testWarningThresholdMock() {
        withDependencies {
            $0.planningClient.warningThreshold = { 90 }
            $0.planningClient.setWarningThreshold = { _ in }
        } operation: {
            @Dependency(\.planningClient) var client
            #expect(client.warningThreshold() == 90)
            client.setWarningThreshold(70)
        }
    }
}
