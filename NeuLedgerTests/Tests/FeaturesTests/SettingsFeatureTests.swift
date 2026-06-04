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

    private static let sampleCategories: [Domain.Category] = [
        Domain.Category(name: "餐飲", icon: "fork.knife", color: "orange", type: .expense, sortOrder: 0),
        Domain.Category(name: "薪資", icon: "dollarsign", color: "green", type: .income, sortOrder: 0),
    ]

    private static func sampleTransactions(accountId: Account.ID, categoryId: Domain.Category.ID) -> [Transaction] {
        [
            Transaction(
                amount: 150,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                note: "午餐",
                categoryId: categoryId,
                accountId: accountId,
                type: .expense
            ),
            Transaction(
                amount: 50000,
                date: Date(timeIntervalSince1970: 1_700_086_400),
                note: nil,
                categoryId: nil,
                accountId: accountId,
                type: .income
            ),
        ]
    }

    // MARK: - task Effect

    @Test(".task loads account name concurrently")
    func testTaskLoadsAccountName() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.platformClient.showAccessoryBar = { false }
            $0.platformClient.setShowAccessoryBar = { _ in }
            $0.ledger.defaultAccountId = { nil }
            $0.ledger.setDefaultAccountId = { _ in }
            $0.ledger.listActiveAccounts = { Self.sampleAccounts }
            $0.carrierClient.listAll = { [] }
            $0.carrierClient.activeForWidget = { nil }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.accounts = Self.sampleAccounts
            $0.defaultAccountName = "現金錢包"
        }

        await store.receive(\.defaultAccountSelected)

        await store.receive(\.languageLoaded) {
            $0.currentLanguage = Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
            )?.localizedCapitalized ?? "zh"
        }

        await store.receive(\.accessoryBarToggleChanged) {
            $0.showAccessoryBar = false
        }
        await store.receive(\.delegate.accessoryBarVisibilityChanged)

        await store.receive(\.widgetCarriersLoaded)
    }

    @Test(".task shows '無' when no active accounts")
    func testTaskShowsNoneWhenNoAccounts() async throws {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.platformClient.showAccessoryBar = { true }
            $0.platformClient.setShowAccessoryBar = { _ in }
            $0.ledger.defaultAccountId = { nil }
            $0.ledger.setDefaultAccountId = { _ in }
            $0.ledger.listActiveAccounts = { [] }
            $0.carrierClient.listAll = { [] }
            $0.carrierClient.activeForWidget = { nil }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.defaultAccountName = String(localized: "settings_none")
        }

        await store.receive(\.defaultAccountSelected)

        await store.receive(\.languageLoaded) {
            $0.currentLanguage = Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
            )?.localizedCapitalized ?? "zh"
        }

        // showAccessoryBar is already true (default), so no state mutation expected
        await store.receive(\.accessoryBarToggleChanged)
        await store.receive(\.delegate.accessoryBarVisibilityChanged)

        await store.receive(\.widgetCarriersLoaded)
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
            $0.ledger.setDefaultAccountId = { value in
                savedValues.withValue { $0.append(value ?? "") }
            }
        }

        let targetId = Self.sampleAccounts[1].id
        await store.send(.defaultAccountSelected(targetId)) {
            $0.selectedDefaultAccountId = targetId
            $0.defaultAccountName = "銀行帳戶"
        }

        #expect(savedValues.value == [targetId])
    }

    // MARK: - Export CSV

    @Test("exportCSVTapped sets exportingFormat to .csv then completes with a URL")
    func testExportCSVSuccess() async throws {
        let account = Self.sampleAccounts[0]
        let category = Self.sampleCategories[0]
        let transactions = Self.sampleTransactions(accountId: account.id, categoryId: category.id)

        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.ledger.listAll = { _ in transactions.map { EnrichedTransaction(transaction: $0) } }
            $0.ledger.listCategories = { _ in Self.sampleCategories }
            $0.ledger.listAccounts = { Self.sampleAccounts }
        }

        await store.send(.exportCSVTapped) {
            $0.exportingFormat = .csv
        }

        await store.receive(\.exportCompleted) {
            $0.exportingFormat = nil
            $0.exportedFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("NeuLedger_export.csv")
        }

        let savedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeuLedger_export.csv")
        let content = try String(contentsOf: savedURL, encoding: .utf8)
        #expect(content.contains("午餐"))
        #expect(content.contains("餐飲"))
        #expect(content.contains("-150"))
        #expect(content.contains("50000"))
    }

    @Test("exportSheetDismissed clears exportedFileURL")
    func testExportSheetDismissed() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.csv")
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        }
        // Seed state with a URL manually
        await store.send(.exportCompleted(url)) {
            $0.exportingFormat = nil
            $0.exportedFileURL = url
        }
        await store.send(.exportSheetDismissed) {
            $0.exportedFileURL = nil
        }
    }

    // MARK: - Export JSON

    @Test("exportJSONTapped sets exportingFormat to .json then completes with a URL")
    func testExportJSONSuccess() async throws {
        let account = Self.sampleAccounts[0]
        let category = Self.sampleCategories[0]
        let transactions = Self.sampleTransactions(accountId: account.id, categoryId: category.id)

        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.ledger.listAll = { _ in transactions.map { EnrichedTransaction(transaction: $0) } }
        }

        await store.send(.exportJSONTapped) {
            $0.exportingFormat = .json
        }

        await store.receive(\.exportCompleted) {
            $0.exportingFormat = nil
            $0.exportedFileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("NeuLedger_export.json")
        }

        let savedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeuLedger_export.json")
        let data = try Data(contentsOf: savedURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([Transaction].self, from: data)
        #expect(decoded.count == 2)
    }

    // MARK: - Export Failure

    @Test("exportCSVTapped propagates error to exportError state")
    func testExportFailed() async throws {
        struct TestError: Error { let message: String }

        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.ledger.listAll = { _ in throw TestError(message: "fetch failed") }
            $0.ledger.listCategories = { _ in [] }
            $0.ledger.listAccounts = { [] }
        }

        await store.send(.exportCSVTapped) {
            $0.exportingFormat = .csv
        }

        await store.receive(\.exportFailed) {
            $0.exportingFormat = nil
            $0.exportError = TestError(message: "fetch failed").localizedDescription
        }
    }

    // MARK: - Privacy Policy

    @Test("privacyPolicyTapped opens the privacy policy URL")
    func testPrivacyPolicyTapped() async throws {
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

        await store.send(.privacyPolicyTapped)

        #expect(openedURLs.value.count == 1)
        #expect(openedURLs.value.first == SettingsFeature.privacyPolicyURL)
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
        #expect(openedURLs.value.first?.absoluteString == "app-settings:")
    }
}

@Suite("SettingsFeature — accessory bar toggle")
struct SettingsAccessoryBarTests {

    @Test("task loads showAccessoryBar=false from UserSettings")
    func taskLoadsAccessoryBarFalse() async {
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.platformClient.showAccessoryBar = { false }
            $0.platformClient.setShowAccessoryBar = { _ in }
            $0.ledger.defaultAccountId = { nil }
            $0.ledger.setDefaultAccountId = { _ in }
            $0.ledger.listActiveAccounts = { [] }
            $0.carrierClient.listAll = { [] }
            $0.carrierClient.activeForWidget = { nil }
        }
        await store.send(.task)
        await store.receive(\.accountsLoaded) {
            $0.defaultAccountName = String(localized: "settings_none")
        }
        await store.receive(\.defaultAccountSelected)
        await store.receive(\.languageLoaded) {
            $0.currentLanguage = Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
            )?.localizedCapitalized ?? "zh"
        }
        await store.receive(.accessoryBarToggleChanged(false)) {
            $0.showAccessoryBar = false
        }
        await store.receive(.delegate(.accessoryBarVisibilityChanged(false)))
        await store.receive(\.widgetCarriersLoaded)
    }

    @Test("accessoryBarToggleChanged persists and updates state")
    func toggleChangedPersists() async {
        let persisted: LockIsolated<Bool> = LockIsolated(true)
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.platformClient.setShowAccessoryBar = { value in
                persisted.setValue(value)
            }
        }
        await store.send(.accessoryBarToggleChanged(false)) {
            $0.showAccessoryBar = false
        }
        await store.receive(.delegate(.accessoryBarVisibilityChanged(false)))
        #expect(persisted.value == false)
    }
}

@Suite("SettingsFeature — navigation")
struct SettingsNavigationTests {

    @Test("accountManagementTapped appends accountManagement to path")
    func accountManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.accountManagementTapped) {
            $0.path.append(.accountManagement(AccountManagementFeature.State()))
        }
    }

    @Test("categoryManagementTapped appends categoryManagement to path")
    func categoryManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.categoryManagementTapped) {
            $0.path.append(.categoryManagement(CategoryManagementFeature.State()))
        }
    }

    @Test("budgetManagementTapped appends budgetManagement to path")
    func budgetManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.budgetManagementTapped) {
            $0.path.append(.budgetManagement(BudgetManagementFeature.State()))
        }
    }

    @Test("tagManagementTapped appends tagManagement to path")
    func tagManagementTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.tagManagementTapped) {
            $0.path.append(.tagManagement(TagManagementFeature.State()))
        }
    }

    @Test("notificationSettingsTapped appends notificationSettings to path")
    func notificationSettingsTapped() async {
        let store = await TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        await store.send(.notificationSettingsTapped) {
            $0.path.append(.notificationSettings(NotificationSettingsFeature.State()))
        }
    }

}

@Suite("SettingsFeature — widget carrier")
struct SettingsWidgetCarrierTests {

    // MARK: - Helpers

    private static let sampleAccounts: [Account] = [
        Account(name: "現金錢包", type: .cash, icon: "wallet.bifold", color: "green", sortOrder: 0),
        Account(name: "銀行帳戶", type: .bank, icon: "building.columns", color: "blue", sortOrder: 1),
    ]

    private static let sampleCarriers: [Carrier] = [
        Carrier(name: "我的手機條碼", type: .phoneBarcodeCarrier, barcode: "/ABC1234"),
        Carrier(name: "自然人憑證", type: .citizenDigitalCertificate, barcode: "/PCERT1234567890AB"),
    ]

    @Test(".task loads widget carriers and selected carrier name")
    func testTaskLoadsWidgetCarriers() async throws {
        let carrier = Self.sampleCarriers[0]
        let store = await TestStore(
            initialState: SettingsFeature.State()
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.platformClient.showAccessoryBar = { false }
            $0.platformClient.setShowAccessoryBar = { _ in }
            $0.ledger.defaultAccountId = { nil }
            $0.ledger.setDefaultAccountId = { _ in }
            $0.ledger.listActiveAccounts = { Self.sampleAccounts }
            $0.carrierClient.listAll = { Self.sampleCarriers }
            $0.carrierClient.activeForWidget = { carrier.id }
        }

        await store.send(.task)

        await store.receive(\.accountsLoaded) {
            $0.accounts = Self.sampleAccounts
            $0.defaultAccountName = "現金錢包"
        }
        await store.receive(\.defaultAccountSelected)
        await store.receive(\.languageLoaded) {
            $0.currentLanguage = Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "zh"
            )?.localizedCapitalized ?? "zh"
        }
        await store.receive(\.accessoryBarToggleChanged) {
            $0.showAccessoryBar = false
        }
        await store.receive(\.delegate.accessoryBarVisibilityChanged)
        await store.receive(\.widgetCarriersLoaded) {
            $0.carriers = Self.sampleCarriers
            $0.widgetCarrierId = carrier.id.uuidString
            $0.widgetCarrierName = "我的手機條碼"
        }
    }

    @Test("widgetCarrierSelected updates state and calls carrierClient.setActiveForWidget")
    func testWidgetCarrierSelected() async throws {
        let carriers = Self.sampleCarriers
        let target = carriers[1]
        let activatedId: LockIsolated<Carrier.ID?> = LockIsolated(nil)

        let store = await TestStore(
            initialState: SettingsFeature.State(carriers: carriers)
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.carrierClient.setActiveForWidget = { id in
                activatedId.setValue(id)
            }
        }

        await store.send(.widgetCarrierSelected(target.id)) {
            $0.widgetCarrierId = target.id.uuidString
            $0.widgetCarrierName = "自然人憑證"
        }

        #expect(activatedId.value == target.id)
    }
}
