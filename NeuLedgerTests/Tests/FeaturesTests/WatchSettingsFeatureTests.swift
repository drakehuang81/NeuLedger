import Foundation
import Testing
import Dependencies
import Domain
import ConcurrencyExtras
import ComposableArchitecture
@testable import Features

@MainActor
@Suite("WatchSettingsFeature Tests")
struct WatchSettingsFeatureTests {

    private static let cashAccount = Account(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "Cash", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    private static let cardAccount = Account(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        name: "Card", type: .creditCard, icon: "creditcard",
        color: "#5E5CE6", sortOrder: 1, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test("Loading populates accounts and reads the currently-selected default")
    func loadingPopulatesAccountsAndCurrentSelection() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount

        let store = TestStore(initialState: WatchSettingsFeature.State()) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { @Sendable in
                [cash, card]
            }
            $0.userSettingsRepository.string = { @Sendable _ in
                card.id.uuidString
            }
            $0.watchBridgeAdapter.isPaired = { true }
            $0.watchBridgeAdapter.isWatchAppInstalled = { true }
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.accounts = [cash, card]
            $0.selectedAccountId = card.id
            $0.isPaired = true
            $0.isWatchAppInstalled = true
        }
    }

    @Test("Selecting an account writes the UUID to userSettingsRepository")
    func selectingAccountPersists() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount
        let captured = LockIsolated<String?>(nil)

        let store = TestStore(
            initialState: WatchSettingsFeature.State(
                accounts: [cash, card],
                selectedAccountId: cash.id,
                isPaired: true,
                isWatchAppInstalled: true
            )
        ) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.userSettingsRepository.setString = { @Sendable value, _ in
                captured.setValue(value)
            }
        }

        await store.send(.accountSelected(card.id)) {
            $0.selectedAccountId = card.id
        }

        #expect(captured.value == card.id.uuidString)
    }
}
