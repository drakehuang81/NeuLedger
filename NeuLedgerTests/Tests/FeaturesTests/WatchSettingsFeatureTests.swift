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
        id: "33333333-3333-3333-3333-333333333333",
        name: "Cash", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    private static let cardAccount = Account(
        id: "44444444-4444-4444-4444-444444444444",
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
            $0.ledgerClient.listActiveAccounts = { @Sendable in
                [cash, card]
            }
            $0.platformClient.watchDefaultAccountId = { card.id }
            $0.platformClient.watchPaired = { true }
            $0.platformClient.watchAppInstalled = { true }
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.accounts = [cash, card]
            $0.selectedAccountId = card.id
            $0.isPaired = true
            $0.isWatchAppInstalled = true
        }
    }

    @Test("Loading with no stored default pre-selects the first active account")
    func loadingWithoutStoredDefaultPreselectsFirstActiveAccount() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount

        let store = TestStore(initialState: WatchSettingsFeature.State()) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { @Sendable in
                [cash, card]
            }
            $0.platformClient.watchDefaultAccountId = { nil }
            $0.platformClient.watchPaired = { true }
            $0.platformClient.watchAppInstalled = { true }
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.accounts = [cash, card]
            $0.selectedAccountId = cash.id
            $0.isPaired = true
            $0.isWatchAppInstalled = true
        }
    }

    @Test("A stored default pointing to a missing account falls back to the first active account")
    func loadingWithDeadStoredDefaultFallsBackToFirstActiveAccount() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount

        let store = TestStore(initialState: WatchSettingsFeature.State()) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { @Sendable in
                [cash, card]
            }
            // e.g. the chosen account was archived or deleted in account
            // management after being stored as the Watch default.
            $0.platformClient.watchDefaultAccountId = { "99999999-9999-9999-9999-999999999999" }
            $0.platformClient.watchPaired = { true }
            $0.platformClient.watchAppInstalled = { true }
        }

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.accounts = [cash, card]
            $0.selectedAccountId = cash.id
            $0.isPaired = true
            $0.isWatchAppInstalled = true
        }
    }

    @Test("Selecting an account writes the UUID via platformClient")
    func selectingAccountPersists() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount
        let captured = LockIsolated<Account.ID?>(nil)

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
            $0.platformClient.setWatchDefaultAccountId = { @Sendable id in
                captured.setValue(id)
            }
            $0.platformClient.pushWatchContext = { @Sendable in }
        }

        await store.send(.accountSelected(card.id)) {
            $0.selectedAccountId = card.id
        }

        #expect(captured.value == card.id)
    }

    @Test("Selecting an account immediately pushes a fresh watch context")
    func selectingAccountPushesWatchContext() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount
        let pushed = LockIsolated(false)

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
            $0.platformClient.setWatchDefaultAccountId = { @Sendable _ in }
            $0.platformClient.pushWatchContext = { @Sendable in
                pushed.setValue(true)
            }
        }

        await store.send(.accountSelected(card.id)) {
            $0.selectedAccountId = card.id
        }
        await store.finish()

        #expect(pushed.value)
    }

    // MARK: - B4 補強：listActiveAccounts 拋錯路徑

    @Test("task 中 listActiveAccounts 拋錯時 accounts 退化為空且 selectedAccountId 為 nil")
    func taskListActiveAccountsThrowDegradesGracefully() async {
        struct FetchError: Error {}

        let store = TestStore(initialState: WatchSettingsFeature.State()) {
            WatchSettingsFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { @Sendable in
                throw FetchError()
            }
            $0.platformClient.watchDefaultAccountId = { nil }
            $0.platformClient.watchPaired = { false }
            $0.platformClient.watchAppInstalled = { false }
        }

        await store.send(.task)
        // State 不變（初始值已全是 default）；空 block 斷言 action 確實有被 receive
        await store.receive(\.loaded)
    }

    // MARK: - B4 補強：accountSelected 不驗 membership 的非對稱行為（as-is 行為固化）

    @Test("accountSelected 無條件接受不在 accounts 內的 id 並持久化（as-is 非對稱行為）")
    func accountSelectedAcceptsNonMemberIdAsIs() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount
        let outsiderId = "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
        let captured = LockIsolated<Account.ID?>(nil)

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
            $0.platformClient.setWatchDefaultAccountId = { @Sendable id in
                captured.setValue(id)
            }
            $0.platformClient.pushWatchContext = { @Sendable in }
        }

        // View 保證不可達，但 reducer 不做 membership 驗證（as-is）
        await store.send(.accountSelected(outsiderId)) {
            $0.selectedAccountId = outsiderId
        }

        #expect(captured.value == outsiderId, "accountSelected 應無條件持久化（as-is 行為）")
    }

    @Test("Rapidly re-selecting accounts cancels the in-flight push so only the latest survives")
    func reselectingAccountCancelsInFlightPush() async {
        let cash = Self.cashAccount
        let card = Self.cardAccount
        let pushCalls = LockIsolated(0)
        let firstPushCancelled = LockIsolated(false)

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
            $0.platformClient.setWatchDefaultAccountId = { @Sendable _ in }
            $0.platformClient.pushWatchContext = { @Sendable in
                let call = pushCalls.withValue { count -> Int in
                    count += 1
                    return count
                }
                guard call == 1 else { return }
                // First push hangs until cancelled — simulating a slow
                // WatchConnectivity transfer overtaken by a re-selection.
                await withTaskCancellationHandler {
                    try? await Task.never()
                } onCancel: {
                    firstPushCancelled.setValue(true)
                }
            }
        }

        await store.send(.accountSelected(card.id)) {
            $0.selectedAccountId = card.id
        }
        await store.send(.accountSelected(cash.id)) {
            $0.selectedAccountId = cash.id
        }
        await store.finish()

        #expect(firstPushCancelled.value)
        #expect(pushCalls.value == 2)
    }
}
