import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@Suite("DashboardFeature Insight Carousel")
struct DashboardFeatureInsightTests {
    @Test("Loads 3 insights and sets insightIndex to 0")
    func testLoad() async {
        let mock = [
            InsightData(title: "A", body: "a", metric: "1%", metricColor: .income),
            InsightData(title: "B", body: "b", metric: "2%", metricColor: .expense),
            InsightData(title: "C", body: "c", metric: "3%", metricColor: .accent)
        ]
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateInsights = { _ in mock }
            $0.insightsClient.generateAIInsight = { _ in "" }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }
        await store.send(.task)
        await store.receive(\.insightsLoaded) {
            $0.insights = mock
            $0.insightIndex = 0
            $0.insightPhase = .loaded
        }
        await store.skipReceivedActions()
        await store.finish()
    }

    @Test("insightIndexChanged updates the index, clamped to valid range")
    func testIndex() async {
        var initial = DashboardFeature.State()
        initial.insights = [
            InsightData(title: "A", body: "a", metric: "1%", metricColor: .income),
            InsightData(title: "B", body: "b", metric: "2%", metricColor: .income),
            InsightData(title: "C", body: "c", metric: "3%", metricColor: .income)
        ]
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }
        await store.send(.insightIndexChanged(2)) {
            $0.insightIndex = 2
        }
        await store.send(.insightIndexChanged(-5)) {
            $0.insightIndex = 0
        }
        await store.send(.insightIndexChanged(99)) {
            $0.insightIndex = 2
        }
    }

    @Test("retrySection(.insight) re-runs the effect")
    func testRetry() async {
        let mock = [InsightData(title: "X", body: "x", metric: "0%", metricColor: .neutral)]
        var initial = DashboardFeature.State()
        initial.insightPhase = .failed("x")
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.insightsClient.generateInsights = { _ in mock }
        }
        await store.send(.retrySection(.insight)) {
            $0.insightPhase = .loading
        }
        await store.receive(\.insightsLoaded) {
            $0.insights = mock
            $0.insightIndex = 0
            $0.insightPhase = .loaded
        }
    }
}
