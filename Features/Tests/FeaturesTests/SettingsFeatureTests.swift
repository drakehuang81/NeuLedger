import Testing
import Foundation
import ComposableArchitecture
import Domain
import UIKit
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
            $0.userSettingsClient.string = { _ in "" }
            $0.userSettingsClient.setString = { _, _ in }
            $0.accountClient.fetchActive = { Self.sampleAccounts }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.accounts = Self.sampleAccounts
            $0.defaultAccountName = "現金錢包"
        }

        await store.receive(\.aiToggleChanged) {
            $0.isAIEnabled = false
        }

        await store.receive(\.defaultAccountSelected)

        await store.receive(\.languageLoaded) {
            $0.currentLanguage = Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
            )?.localizedCapitalized ?? "zh"
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
            $0.userSettingsClient.string = { _ in "" }
            $0.userSettingsClient.setString = { _, _ in }
            $0.accountClient.fetchActive = { [] }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.defaultAccountName = String(localized: "settings_none")
        }

        // aiEnabled is already true (default), so no state mutation expected
        await store.receive(\.aiToggleChanged)

        await store.receive(\.defaultAccountSelected)

        await store.receive(\.languageLoaded) {
            $0.currentLanguage = Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
            )?.localizedCapitalized ?? "zh"
        }
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
            $0.accounts = Self.sampleAccounts
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
            $0.defaultAccountName = String(localized: "settings_none")
        }
    }

    // MARK: - Default Account Selection

    @Test("defaultAccountSelected persists choice and updates display name")
    func testDefaultAccountSelected() async throws {
        let savedValues: LockIsolated<[String]> = LockIsolated([])

        var initialState = SettingsFeature.State()
        initialState.accounts = Self.sampleAccounts

        let store = await TestStore(initialState: initialState) {
            SettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.setString = { value, _ in
                savedValues.withValue { $0.append(value) }
            }
        }

        let targetId = Self.sampleAccounts[1].id.uuidString
        await store.send(.defaultAccountSelected(targetId)) {
            $0.selectedDefaultAccountId = targetId
            $0.defaultAccountName = "銀行帳戶"
        }

        #expect(savedValues.value == [targetId])
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

    // MARK: - Language

    @Test("languageTapped opens system settings URL")
    func testLanguageTapped() async throws {
        let openedURLs: LockIsolated<[URL]> = LockIsolated([])

        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.openURL = .init { url in
                openedURLs.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.languageTapped)

        #expect(openedURLs.value.count == 1)
        #expect(openedURLs.value.first?.absoluteString == UIApplication.openSettingsURLString)
    }
}
