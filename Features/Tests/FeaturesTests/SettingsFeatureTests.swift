import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("SettingsFeature Tests")
struct SettingsFeatureTests {

    // MARK: - Helpers

    private static let sampleAccounts: [Account] = [
        Account(name: "現金錢包", type: .cash, icon: "wallet.bifold", color: "green", sortOrder: 0),
        Account(name: "銀行帳戶", type: .bank, icon: "building.columns", color: "blue", sortOrder: 1),
    ]

    // MARK: - task Effect

    @Test(".task loads AI state and account name concurrently")
    func testTaskLoadsAIStateAndAccountName() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { _ in false }
            $0.accountClient.fetchActive = { Self.sampleAccounts }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.defaultAccountName = "現金錢包"
        }

        await store.receive(\.aiToggleChanged) {
            $0.isAIEnabled = false
        }
    }

    @Test(".task shows '無' when no active accounts")
    func testTaskShowsNoneWhenNoAccounts() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { _ in true }
            $0.accountClient.fetchActive = { [] }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.defaultAccountName = "無"
        }

        // aiEnabled is already true (default), so no state mutation expected
        await store.receive(\.aiToggleChanged)
    }

    // MARK: - AI Toggle

    @Test("aiToggleChanged(true) updates isAIEnabled state to true")
    func testAIToggleChangedTrue() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State(isAIEnabled: false)
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.setBool = { _, _ in }
        }

        await store.send(.aiToggleChanged(true)) {
            $0.isAIEnabled = true
        }
    }

    @Test("aiToggleChanged(false) updates isAIEnabled state to false")
    func testAIToggleChangedFalse() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State(isAIEnabled: true)
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.setBool = { _, _ in }
        }

        await store.send(.aiToggleChanged(false)) {
            $0.isAIEnabled = false
        }
    }

    // MARK: - accountsLoaded

    @Test("accountsLoaded sets defaultAccountName to first account")
    func testAccountsLoadedSetsFirstAccount() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        }

        await store.send(.accountsLoaded(Self.sampleAccounts)) {
            $0.defaultAccountName = "現金錢包"
        }
    }

    @Test("accountsLoaded with empty array sets defaultAccountName to '無'")
    func testAccountsLoadedEmptySetsNone() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State(defaultAccountName: "現金錢包")
        ) {
            SettingsFeature()
        }

        await store.send(.accountsLoaded([])) {
            $0.defaultAccountName = "無"
        }
    }

    // MARK: - Placeholder Actions

    @Test("exportCSVTapped does not mutate state")
    func testExportCSVTapped() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        }

        await store.send(.exportCSVTapped)
    }

    @Test("exportJSONTapped does not mutate state")
    func testExportJSONTapped() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        }

        await store.send(.exportJSONTapped)
    }

    @Test("privacyPolicyTapped does not mutate state")
    func testPrivacyPolicyTapped() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        }

        await store.send(.privacyPolicyTapped)
    }
}
