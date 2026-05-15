import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@MainActor
@Suite("DashboardFeature Row Expansion")
struct DashboardFeatureExpansionTests {
    @Test("Toggling same id twice collapses; tapping a different id replaces")
    func testRowExpansionToggle() async {
        let id1 = UUID()
        let id2 = UUID()
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
        await store.send(.transactionRowToggled(id1)) {
            $0.expandedTransactionID = id1
        }
        await store.send(.transactionRowToggled(id1)) {
            $0.expandedTransactionID = nil
        }
        await store.send(.transactionRowToggled(id2)) {
            $0.expandedTransactionID = id2
        }
        await store.send(.transactionRowToggled(id1)) {
            $0.expandedTransactionID = id1
        }
    }
}
