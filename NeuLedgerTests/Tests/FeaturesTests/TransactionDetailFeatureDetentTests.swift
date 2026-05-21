import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@Suite("TransactionDetailFeature Detent Tests")
struct TransactionDetailFeatureDetentTests {

    private static let sample = Transaction(amount: 100, date: .now, accountId: UUID(), type: .expense)

    @Test("detentChanged updates state.detent")
    func testDetentChange() async {
        let store = await TestStore(initialState: TransactionDetailFeature.State(transaction: Self.sample)) {
            TransactionDetailFeature()
        }
        await store.send(.detentChanged(.large)) {
            $0.detent = .large
        }
        await store.send(.detentChanged(.medium)) {
            $0.detent = .medium
        }
    }
}
