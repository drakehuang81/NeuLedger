import Testing
import SwiftData
import Foundation
import Dependencies
import Domain
@testable import Core

/// Live tests for `InsightsClient`.
///
/// The six statistical projections are migrated equivalents of the
/// former `TransactionClient` stats tests (`statsSnapshot` /
/// `weeklySpending` / `detailStats`) and the `AnalyticsUseCase`
/// `budgetGauges` path — all now exercised through
/// `InsightsClient.liveValue`. The AI cases cover model availability
/// (via a stubbed `AIAdapter`) and the `generateAIInsight` cache
/// behaviour (same `SpendingSummary` must hit the cache and avoid a
/// second adapter call).
@Suite("InsightsClient Live Tests")
struct InsightsClientLiveTests {

    /// Fresh in-memory container holding the full schema.
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

    /// Builds the live client wired to a given container and an optional
    /// `AIAdapter` override.
    private func sut(_ container: ModelContainer, aiAdapter: AIAdapter? = nil) -> InsightsClient {
        withDependencies {
            $0.databaseClient = DatabaseClient(modelContainer: { container })
            $0.modelContainer = container
            if let aiAdapter { $0.aiAdapter = aiAdapter }
        } operation: {
            InsightsClient.liveValue
        }
    }

    private func insert(_ tx: SDTransaction, into container: ModelContainer) throws {
        let ctx = ModelContext(container)
        ctx.insert(tx)
        try ctx.save()
    }

    private func expenseTx(amount: Decimal, date: Date, accountId: String, categoryId: UUID? = nil) -> SDTransaction {
        SDTransaction(
            id: UUID(), amount: amount, date: date, note: "",
            categoryId: categoryId, accountId: accountId, toAccountId: nil,
            type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: date, updatedAt: date
        )
    }

    // MARK: - todayStats (migrated from TransactionClientStatsTests)

    @Test("todayStats computes today + week + savings %")
    func testTodayStats() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 200, date: today, accountId: acct), into: container)
        let d3 = cal.date(byAdding: .day, value: -3, to: today)!
        try insert(expenseTx(amount: 100, date: d3, accountId: acct), into: container)
        let ctx = ModelContext(container)
        ctx.insert(SDTransaction(
            id: UUID(), amount: 1000, date: d3, note: "",
            categoryId: nil, accountId: acct, toAccountId: nil,
            type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: d3, updatedAt: d3
        ))
        try ctx.save()

        let client = sut(container)
        let snap = try await client.todayStats(Date())
        #expect(snap.today == 200)
        #expect(snap.week == 300)
        #expect(abs(snap.savingsPercentage - 0.7) < 0.001)
    }

    // MARK: - weeklySparkline (migrated from TransactionClientWeeklyTests)

    @Test("weeklySparkline returns 7 entries summed per day, oldest to newest")
    func testWeeklySparkline() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acct = UUID().uuidString
        for i in 0 ..< 7 {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            try insert(expenseTx(amount: Decimal(100 * (i + 1)), date: date, accountId: acct), into: container)
        }

        let client = sut(container)
        let result = try await client.weeklySparkline(nil)
        #expect(result.count == 7)
        #expect(result[6] == 100)   // today
        #expect(result[0] == 700)   // 6 days ago
    }

    // MARK: - detailStats (migrated from TransactionClientDetailStatsTests)

    @Test("detailStats returns expenseVsCategoryAvg")
    func testDetailStats() async throws {
        let container = try freshContainer()
        let now = Date()
        let acct = "11000000-0000-0000-0000-000000000001"
        let catFood = UUID(uuidString: "33000000-0000-0000-0000-000000000001")!
        let subject = Transaction(amount: 250, date: now, categoryId: catFood, accountId: acct, type: .expense)
        let other = Transaction(amount: 150, date: now, categoryId: catFood, accountId: acct, type: .expense)
        let ctx = ModelContext(container)
        SDTransaction.from(subject, context: ctx)
        SDTransaction.from(other, context: ctx)
        try ctx.save()

        let client = sut(container)
        let insight = try await client.detailStats(subject)
        guard case let .expenseVsCategoryAvg(_, avg, count, total) = insight.kind else {
            Issue.record("Expected expenseVsCategoryAvg, got \(insight.kind)")
            return
        }
        #expect(count == 2)
        #expect(total == 400)
        #expect(avg == 200)
    }

    // MARK: - budgetGauges (active budgets read directly via SwiftDataStore)

    @Test("budgetGauges reads active budgets directly and computes spent")
    func testBudgetGauges() async throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)

        let budgetId = UUID()
        let activeBudget = Budget(
            id: budgetId, name: "食費", amount: 1000, categoryId: nil,
            period: .monthly, startDate: Date(), isActive: true
        )
        let inactiveBudget = Budget(
            id: UUID(), name: "停用", amount: 5000, categoryId: nil,
            period: .monthly, startDate: Date(), isActive: false
        )
        SDBudget.from(activeBudget, context: ctx)
        SDBudget.from(inactiveBudget, context: ctx)
        try ctx.save()

        // Two in-period expenses summing to 300.
        let now = Date()
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 200, date: now, accountId: acct), into: container)
        try insert(expenseTx(amount: 100, date: now, accountId: acct), into: container)

        let client = sut(container)
        let gauges = try await client.budgetGauges(nil)
        #expect(gauges.count == 1) // only the active budget
        #expect(gauges.first?.id == budgetId.uuidString)
        #expect(gauges.first?.spentAmount == 300)
        #expect(gauges.first?.totalBudget == 1000)
    }

    // MARK: - isAIAvailable (reflects AIAdapter)

    @Test("isAIAvailable reflects AIAdapter availability — true")
    func testIsAIAvailableTrue() async throws {
        let container = try freshContainer()
        var adapter = AIAdapter.testValue
        adapter.isAvailable = { true }
        let client = sut(container, aiAdapter: adapter)
        #expect(client.isAIAvailable() == true)
    }

    @Test("isAIAvailable reflects AIAdapter availability — false")
    func testIsAIAvailableFalse() async throws {
        let container = try freshContainer()
        var adapter = AIAdapter.testValue
        adapter.isAvailable = { false }
        let client = sut(container, aiAdapter: adapter)
        #expect(client.isAIAvailable() == false)
    }

    // MARK: - generateAIInsight cache behaviour

    @Test("generateAIInsight caches by summary — second call hits cache, no second adapter call")
    func testGenerateAIInsightCaches() async throws {
        let container = try freshContainer()

        // Unique periodDescription so the process-shared InsightCache
        // (static let) cannot be polluted by other tests.
        let summary = SpendingSummary(
            totalIncome: 5000,
            totalExpense: 2000,
            categoryBreakdown: [:],
            periodDescription: "cache-test-\(UUID().uuidString)"
        )

        let callCount = CallCounter()
        var adapter = AIAdapter.testValue
        adapter.generateText = { _ in
            await callCount.increment()
            return "洞察：本期支出 NT$2,000"
        }

        let client = sut(container, aiAdapter: adapter)
        let first = try await client.generateAIInsight(summary)
        let second = try await client.generateAIInsight(summary)

        #expect(first == "洞察：本期支出 NT$2,000")
        #expect(second == first)
        let count = await callCount.value
        #expect(count == 1, "adapter.generateText should only be called once thanks to the cache")
    }

    private actor CallCounter {
        private(set) var value = 0
        func increment() { value += 1 }
    }
}
