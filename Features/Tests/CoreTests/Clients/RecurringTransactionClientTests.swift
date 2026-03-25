import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("RecurringTransactionClient Integration Tests")
struct RecurringTransactionClientIntegrationTests {
    var container: ModelContainer
    var sut: RecurringTransactionClient

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
            SDRecurringTransaction.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container

        let testDatabaseClient = DatabaseClient(modelContainer: { _container })

        self.sut = withDependencies {
            $0.databaseClient = testDatabaseClient
        } operation: {
            RecurringTransactionClient.liveValue
        }
    }

    func makeSample(id: UUID = UUID()) -> RecurringTransaction {
        RecurringTransaction(
            id: id,
            amount: 15000,
            note: "房租",
            categoryId: nil,
            accountId: UUID(),
            toAccountId: nil,
            type: .expense,
            tags: [],
            frequency: .monthly,
            nextDueDate: Date(),
            isActive: true,
            createdAt: Date()
        )
    }

    @Test("add and fetchAll returns the recurring transaction")
    func testAddAndFetchAll() async throws {
        let rt = makeSample()
        try await sut.add(rt)
        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].note == "房租")
        #expect(all[0].frequency == .monthly)
    }

    @Test("fetchDue returns only items due on or before given date")
    func testFetchDue() async throws {
        let past = Date(timeIntervalSinceNow: -86400)
        let future = Date(timeIntervalSinceNow: 86400)
        var rtPast = makeSample()
        rtPast.nextDueDate = past
        var rtFuture = makeSample()
        rtFuture.nextDueDate = future
        try await sut.add(rtPast)
        try await sut.add(rtFuture)
        let due = try await sut.fetchDue(on: Date())
        #expect(due.count == 1)
        #expect(due[0].nextDueDate == past)
    }

    @Test("fetchDue excludes inactive recurring transactions")
    func testFetchDueExcludesInactive() async throws {
        let past = Date(timeIntervalSinceNow: -86400)
        var rtActive = makeSample(); rtActive.nextDueDate = past; rtActive.isActive = true
        var rtInactive = makeSample(); rtInactive.nextDueDate = past; rtInactive.isActive = false
        try await sut.add(rtActive)
        try await sut.add(rtInactive)
        let due = try await sut.fetchDue(on: Date())
        #expect(due.count == 1)
        #expect(due[0].isActive == true)
    }

    @Test("update modifies the recurring transaction")
    func testUpdate() async throws {
        var rt = makeSample()
        try await sut.add(rt)
        rt.note = "修改後"
        rt.isActive = false
        try await sut.update(rt)
        let all = try await sut.fetchAll()
        #expect(all[0].note == "修改後")
        #expect(all[0].isActive == false)
    }

    @Test("delete removes the recurring transaction")
    func testDelete() async throws {
        let rt = makeSample()
        try await sut.add(rt)
        try await sut.delete(rt.id)
        let all = try await sut.fetchAll()
        #expect(all.isEmpty)
    }
}
