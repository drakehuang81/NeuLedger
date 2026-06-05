import Testing
import SwiftData
import Foundation
import Dependencies
import Domain
@testable import Core

/// Live tests for `PlanningClient` — budget CRUD + `listActive`
/// (migrated from `BudgetClientTests`) plus the budget-warning preference
/// round-trips (new, lifted from the former `AppEnvironmentUseCase`).
@Suite("PlanningClient Live Tests")
struct PlanningClientLiveTests {

    /// Fresh in-memory container holding the budget + transaction schema.
    private func freshContainer() throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// An in-memory `UserSettingsAdapter` backed by an actor-isolated box,
    /// so warning-preference setters/getters round-trip.
    private final class SettingsBox: @unchecked Sendable {
        private let lock = NSLock()
        private var bools: [String: Bool] = [:]
        private var ints: [String: Int] = [:]
        func getBool(_ key: String, _ fallback: Bool) -> Bool {
            lock.lock(); defer { lock.unlock() }
            return bools[key] ?? fallback
        }
        func setBool(_ value: Bool, _ key: String) {
            lock.lock(); defer { lock.unlock() }
            bools[key] = value
        }
        func getInt(_ key: String, _ fallback: Int) -> Int {
            lock.lock(); defer { lock.unlock() }
            return ints[key] ?? fallback
        }
        func setInt(_ value: Int, _ key: String) {
            lock.lock(); defer { lock.unlock() }
            ints[key] = value
        }
    }

    private func inMemorySettings(_ box: SettingsBox) -> UserSettingsAdapter {
        var adapter = UserSettingsAdapter.testValue
        adapter.bool = { key in box.getBool(key.rawValue, key.defaultValue) }
        adapter.setBool = { value, key in box.setBool(value, key.rawValue) }
        adapter.int = { key in box.getInt(key.rawValue, key.defaultValue) }
        adapter.setInt = { value, key in box.setInt(value, key.rawValue) }
        return adapter
    }

    private func sut(_ container: ModelContainer, settings: UserSettingsAdapter? = nil) -> PlanningClient {
        withDependencies {
            $0.modelContainer = container
            if let settings { $0.userSettingsAdapter = settings }
        } operation: {
            PlanningClient.liveValue
        }
    }

    private func budget(
        name: String = "食費",
        amount: Decimal = 10000,
        isActive: Bool = true
    ) -> Budget {
        Budget(
            id: UUID(),
            name: name,
            amount: amount,
            categoryId: nil,
            period: .monthly,
            startDate: Date(),
            isActive: isActive
        )
    }

    // MARK: - CRUD (migrated from BudgetClientTests)

    @Test("create stores budget and listAll returns it")
    func testCreateAndListAll() async throws {
        let container = try freshContainer()
        let client = sut(container)
        let b = budget(name: "食費", amount: 10000)
        try await client.create(b)
        let all = try await client.listAll()
        #expect(all.count == 1)
        #expect(all[0].name == "食費")
        #expect(all[0].amount == 10000)
    }

    @Test("update modifies existing budget")
    func testUpdate() async throws {
        let container = try freshContainer()
        let client = sut(container)
        let b = budget(name: "原始", amount: 5000)
        try await client.create(b)

        let updated = Budget(
            id: b.id, name: "更新後", amount: 8000, categoryId: nil,
            period: .monthly, startDate: b.startDate, isActive: true
        )
        try await client.update(updated)

        let all = try await client.listAll()
        #expect(all.count == 1)
        #expect(all[0].name == "更新後")
        #expect(all[0].amount == 8000)
    }

    @Test("delete removes budget from store")
    func testDelete() async throws {
        let container = try freshContainer()
        let client = sut(container)
        let b = budget()
        try await client.create(b)
        try await client.delete(b.id)
        let all = try await client.listAll()
        #expect(all.isEmpty)
    }

    @Test("listActive returns only active budgets")
    func testListActive() async throws {
        let container = try freshContainer()
        let client = sut(container)
        try await client.create(budget(name: "Active", amount: 1000, isActive: true))
        try await client.create(budget(name: "Inactive", amount: 2000, isActive: false))

        let result = try await client.listActive()
        #expect(result.count == 1)
        #expect(result[0].name == "Active")
    }

    // MARK: - currentStatus

    @Test("currentStatus sums in-period expense transactions")
    func testCurrentStatus() async throws {
        let container = try freshContainer()
        let client = sut(container)
        let b = budget(amount: 1000)
        try await client.create(b)

        // Seed two expense transactions dated today via a transaction store.
        let txStore = withDependencies {
            $0.modelContainer = container
        } operation: {
            TransactionStore()
        }
        let now = Date()
        for amount in [Decimal(300), Decimal(200)] {
            try await txStore.add(Transaction(
                id: UUID(), amount: amount, date: now, note: nil,
                categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
                type: .expense, tags: [], aiSuggested: false,
                createdAt: now, updatedAt: now
            ))
        }

        let status = try await client.currentStatus(b)
        #expect(status.spent == 500)
    }

    // MARK: - New: budget-warning preference round-trips

    @Test("setWarningEnabled then warningEnabled reads back the same value")
    func testWarningEnabledRoundTrip() async throws {
        let container = try freshContainer()
        let box = SettingsBox()
        let client = sut(container, settings: inMemorySettings(box))

        #expect(client.warningEnabled() == false) // default
        client.setWarningEnabled(true)
        #expect(client.warningEnabled() == true)
        client.setWarningEnabled(false)
        #expect(client.warningEnabled() == false)
    }

    @Test("setWarningThreshold then warningThreshold reads back the same value")
    func testWarningThresholdRoundTrip() async throws {
        let container = try freshContainer()
        let box = SettingsBox()
        let client = sut(container, settings: inMemorySettings(box))

        #expect(client.warningThreshold() == 80) // default
        client.setWarningThreshold(65)
        #expect(client.warningThreshold() == 65)
    }
}
