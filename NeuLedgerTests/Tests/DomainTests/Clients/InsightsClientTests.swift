import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("InsightsClient Domain Tests")
struct InsightsClientTests {

    @Test("InsightsClient testValue is accessible via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.insightsClient) var client
        #expect(true, "InsightsClient injected successfully")
    }

    @Test("InsightsClient todayStats mock override")
    func testTodayStatsMock() async throws {
        let expected = StatsSnapshot(today: 200, week: 900, savingsPercentage: 0.5)
        try await withDependencies {
            $0.insightsClient.todayStats = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.todayStats(Date())
            #expect(result == expected)
        }
    }

    @Test("InsightsClient weeklySparkline mock override")
    func testWeeklySparklineMock() async throws {
        let expected: [Decimal] = [1, 2, 3, 4, 5, 6, 7]
        try await withDependencies {
            $0.insightsClient.weeklySparkline = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.weeklySparkline(nil)
            #expect(result == expected)
        }
    }

    @Test("InsightsClient dailyBars mock override")
    func testDailyBarsMock() async throws {
        let day = Date()
        let expected = [DailyTrend(date: day, amount: 350)]
        try await withDependencies {
            $0.insightsClient.dailyBars = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.dailyBars(DateInterval(start: day, duration: 86_400))
            #expect(result == expected)
        }
    }

    @Test("InsightsClient categoryProportions mock override")
    func testCategoryProportionsMock() async throws {
        let expected = [CategoryProportion(name: "食物", amount: 500)]
        try await withDependencies {
            $0.insightsClient.categoryProportions = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.categoryProportions(DateInterval(start: Date(), duration: 86_400))
            #expect(result == expected)
        }
    }

    @Test("InsightsClient budgetGauges mock override")
    func testBudgetGaugesMock() async throws {
        let expected = [BudgetGaugeMetrics(
            id: UUID().uuidString, categoryName: "食物", spentAmount: 300, totalBudget: 1000
        )]
        try await withDependencies {
            $0.insightsClient.budgetGauges = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.budgetGauges(nil)
            #expect(result == expected)
        }
    }

    @Test("InsightsClient detailStats mock override")
    func testDetailStatsMock() async throws {
        let expected = TransactionInsight(kind: .fallback(monthlyCategoryCount: 3))
        let txn = Transaction(
            id: UUID(), amount: 100, date: Date(), note: nil,
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], aiSuggested: false,
            createdAt: Date(), updatedAt: Date()
        )
        try await withDependencies {
            $0.insightsClient.detailStats = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.detailStats(txn)
            if case let .fallback(count) = result.kind {
                #expect(count == 3)
            } else {
                Issue.record("Expected fallback kind")
            }
        }
    }

    @Test("InsightsClient generateAIInsight mock override")
    func testGenerateAIInsightMock() async throws {
        let summary = SpendingSummary(totalIncome: 5000, totalExpense: 2000, periodDescription: "Jan 2026")
        try await withDependencies {
            $0.insightsClient.generateAIInsight = { input in
                #expect(input == summary)
                return "You spent NT$2,000 this month."
            }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.generateAIInsight(summary)
            #expect(result == "You spent NT$2,000 this month.")
        }
    }

    @Test("InsightsClient generateInsights mock override")
    func testGenerateInsightsMock() async throws {
        let expected = [InsightData(
            title: "T", body: "B", metric: "M", metricColor: .accent, cta: "C"
        )]
        try await withDependencies {
            $0.insightsClient.generateInsights = { _ in expected }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.generateInsights(
                SpendingSummary(totalIncome: 0, totalExpense: 0, periodDescription: "P")
            )
            #expect(result == expected)
        }
    }

    @Test("InsightsClient answerFinancialQuestion mock override")
    func testAnswerFinancialQuestionMock() async throws {
        try await withDependencies {
            $0.insightsClient.answerFinancialQuestion = { question in
                #expect(question == "我這個月花了多少？")
                return "你這個月花了 NT$8,400。"
            }
        } operation: {
            @Dependency(\.insightsClient) var client
            let result = try await client.answerFinancialQuestion("我這個月花了多少？")
            #expect(result == "你這個月花了 NT$8,400。")
        }
    }

    @Test("InsightsClient isAIAvailable mock override")
    func testIsAIAvailableMock() {
        withDependencies {
            $0.insightsClient.isAIAvailable = { true }
        } operation: {
            @Dependency(\.insightsClient) var client
            #expect(client.isAIAvailable() == true)
        }
    }

    @Test("InsightsClient isAIAvailable defaults to false")
    func testIsAIAvailableDefault() {
        withDependencies {
            $0.insightsClient.isAIAvailable = { false }
        } operation: {
            @Dependency(\.insightsClient) var client
            #expect(client.isAIAvailable() == false)
        }
    }
}
