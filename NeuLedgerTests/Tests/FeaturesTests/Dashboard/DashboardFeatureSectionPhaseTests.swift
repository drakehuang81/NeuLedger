import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@Suite("DashboardFeature SectionPhase")
struct DashboardFeatureSectionPhaseTests {

    @Test("weeklySpending success transitions heroPhase to loaded")
    func testHeroSuccess() async {
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.weeklySparkline = { _ in [10, 20, 30, 40, 50, 60, 70] }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.insightsClient.isAIAvailable = { false }
            $0.insightsClient.generateInsights = { _ in [] }
        }

        await MainActor.run {
            store.exhaustivity = .off
        }
        await store.send(.task)
        await store.skipReceivedActions()
        await store.finish()
        await MainActor.run {
            #expect(store.state.weeklySpending == [10, 20, 30, 40, 50, 60, 70])
            #expect(store.state.heroPhase == .loaded)
        }
    }

    @Test("weeklySpending failure transitions heroPhase to failed")
    func testHeroFailure() async {
        struct Boom: Error {}
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.weeklySparkline = { _ in throw Boom() }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.insightsClient.isAIAvailable = { false }
            $0.insightsClient.generateInsights = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }
        await store.send(.task)
        await store.skipReceivedActions()
        await store.finish()
        await MainActor.run {
            #expect(store.state.heroPhase == .failed(String(localized: "dashboard_section_load_failed", bundle: .main)))
        }
    }

    @Test("retrySection(.hero) resets phase to loading and reloads")
    func testRetryHero() async {
        var initial = DashboardFeature.State()
        initial.heroPhase = .failed("err")
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.insightsClient.weeklySparkline = { _ in [1, 2, 3, 4, 5, 6, 7] }
        }
        await store.send(.retrySection(.hero)) {
            $0.heroPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [1, 2, 3, 4, 5, 6, 7]
            $0.heroPhase = .loaded
        }
    }

    @Test("retrySection(.stats) resets phase to loading and reloads")
    func testRetryStats() async {
        var initial = DashboardFeature.State()
        initial.statsPhase = .failed("err")
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.todayStats = { _ in StatsSnapshot(today: 0, week: 0, savingsPercentage: 0) }
        }
        await store.send(.retrySection(.stats)) {
            $0.statsPhase = .loading
        }
        await store.receive(\.statsComputed) {
            $0.statsPhase = .loaded
        }
    }

    @Test("sectionFailed sets the per-section failed phase")
    func testSectionFailedRouting() async {
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
        await store.send(.sectionFailed(.insight, "x")) {
            $0.insightPhase = .failed("x")
        }
        await store.send(.sectionFailed(.accounts, "y")) {
            $0.accountsPhase = .failed("y")
        }
    }
}
