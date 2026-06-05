import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@Suite("DashboardFeature Stats")
struct DashboardFeatureStatsTests {
    @Test(".task triggers statsComputed and sets statsPhase to loaded")
    func test() async {
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.todayStats = { _ in StatsSnapshot(today: 100, week: 400, savingsPercentage: 0.3) }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
            $0.insightsClient.generateInsights = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }
        await store.send(.task)
        await store.receive(\.statsComputed) {
            $0.todaySpending = 100
            $0.weekSpending = 400
            $0.savingsPercentage = 0.3
            $0.statsPhase = .loaded
        }
        await store.skipReceivedActions()
        await store.finish()
    }

    @Test("retrySection(.stats) re-runs the effect")
    func testRetry() async {
        var initial = DashboardFeature.State()
        initial.statsPhase = .failed("x")
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.todayStats = { _ in StatsSnapshot(today: 50, week: 200, savingsPercentage: 0.2) }
        }
        await store.send(.retrySection(.stats)) {
            $0.statsPhase = .loading
        }
        await store.receive(\.statsComputed) {
            $0.todaySpending = 50
            $0.weekSpending = 200
            $0.savingsPercentage = 0.2
            $0.statsPhase = .loaded
        }
    }
}
