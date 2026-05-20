import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@MainActor
@Suite("DashboardFeature Stats")
struct DashboardFeatureStatsTests {
    @Test(".task triggers statsComputed and sets statsPhase to loaded")
    func test() async {
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.statsSnapshot = { StatsSnapshot(today: 100, week: 400, savingsPercentage: 0.3) }
            $0.transactionClient.weeklySpending = { _, _ in [] }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
            $0.aiUseCase.generateInsights = { _ in [] }
        }
        store.exhaustivity = .off
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
        let store = TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.statsSnapshot = { StatsSnapshot(today: 50, week: 200, savingsPercentage: 0.2) }
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
