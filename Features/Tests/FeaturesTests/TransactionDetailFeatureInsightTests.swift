import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@MainActor
@Suite("TransactionDetailFeature Insight Tests")
struct TransactionDetailFeatureInsightTests {

    private static let account = Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759")
    private static let sample = Transaction(amount: 100, date: .now, accountId: account.id, type: .expense)

    @Test("insightLoaded sets state.insight")
    func testInsightLoaded() async {
        let store = await TestStore(initialState: TransactionDetailFeature.State(transaction: Self.sample)) {
            TransactionDetailFeature()
        }
        let i = TransactionInsight(kind: .fallback(monthlyCategoryCount: 3))
        await store.send(.insightLoaded(i)) {
            $0.insight = i
        }
    }

    @Test("insightFailed clears insight")
    func testInsightFailed() async {
        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.insight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        }
        await store.send(.insightFailed) {
            $0.insight = nil
        }
    }
}
