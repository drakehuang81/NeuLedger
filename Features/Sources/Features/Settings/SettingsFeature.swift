import ComposableArchitecture
import Domain
import Foundation

// MARK: - ExportFormat

public enum ExportFormat: Equatable, Sendable {
    case csv
    case json
}

@Reducer
public struct SettingsFeature: Sendable {
    public static let privacyPolicyURL = URL(string: "https://neuledger.app/privacy")!

    public init() {}

    // MARK: - Destination

    @Reducer
    public enum Destination {
        case accountManagement(AccountManagementFeature)
        case categoryManagement(CategoryManagementFeature)
        case budgetManagement(BudgetManagementFeature)
        case tagManagement(TagManagementFeature)
        case carrierManagement(CarrierManagementFeature)
        case notificationSettings(NotificationSettingsFeature)
        case syncSettings(SyncSettingsFeature)
        case watchSettings(WatchSettingsFeature)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var path: StackState<Destination.State> = StackState()
        public var accounts: [Account] = []
        public var selectedDefaultAccountId: String = ""
        public var defaultAccountName: String = ""
        public var currentLanguage: String = ""
        public var exportingFormat: ExportFormat? = nil
        public var exportedFileURL: URL? = nil
        public var exportError: String? = nil
        public var showAccessoryBar: Bool = true
        public var carriers: [Carrier] = []
        public var widgetCarrierId: String = ""
        public var widgetCarrierName: String = ""
        public var isPickingDefaultAccount: Bool = false
        public var isPickingWidgetCarrier: Bool = false
        public var isConfirmingWipeAllData: Bool = false
        public var isWipingAllData: Bool = false
        public var wipeAllDataError: String? = nil
        public var isSeedingRandomData: Bool = false
        public var seedRandomDataResult: String? = nil
        public var seedRandomDataError: String? = nil

        public init(
            accounts: [Account] = [],
            selectedDefaultAccountId: String = "",
            defaultAccountName: String = "",
            currentLanguage: String = "",
            showAccessoryBar: Bool = true,
            carriers: [Carrier] = [],
            widgetCarrierId: String = "",
            widgetCarrierName: String = ""
        ) {
            self.accounts = accounts
            self.selectedDefaultAccountId = selectedDefaultAccountId
            self.defaultAccountName = defaultAccountName
            self.currentLanguage = currentLanguage
            self.showAccessoryBar = showAccessoryBar
            self.carriers = carriers
            self.widgetCarrierId = widgetCarrierId
            self.widgetCarrierName = widgetCarrierName
        }
    }

    // MARK: - Action

    public enum Action: Equatable {
        // Navigation
        case accountManagementTapped
        case categoryManagementTapped
        case budgetManagementTapped
        case tagManagementTapped
        case carrierManagementTapped
        case notificationSettingsTapped
        case syncSettingsTapped
        case watchSettingsTapped
        case path(StackActionOf<Destination>)
        case task
        case accountsLoaded([Account])
        case defaultAccountSelected(String)
        case languageTapped
        case languageLoaded(String)
        case exportCSVTapped
        case exportJSONTapped
        case exportCompleted(URL)
        case exportFailed(String)
        case exportSheetDismissed
        case accessoryBarToggleChanged(Bool)
        case privacyPolicyTapped
        case widgetCarrierSelected(Carrier.ID)
        case widgetCarriersLoaded([Carrier])
        case defaultAccountTapped
        case defaultAccountPickerDismissed
        case widgetCarrierTapped
        case widgetCarrierPickerDismissed
        // Destructive: wipe local + cloud data (debug entry point)
        case wipeAllDataTapped
        case wipeAllDataDismissed
        case wipeAllDataConfirmed
        case wipeAllDataCompleted
        case wipeAllDataFailed(String)
        // Debug-only: seed randomized accounts + transactions for manual testing
        case seedRandomDataTapped
        case seedRandomDataCompleted(accountCount: Int, transactionCount: Int)
        case seedRandomDataFailed(String)
        case seedRandomDataDismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// All local + cloud data was destroyed; parent should route
            /// the UI back to onboarding.
            case allDataWiped
            /// User toggled the floating accessory bar visibility; parent
            /// should sync its own state so the change applies immediately.
            case accessoryBarVisibilityChanged(Bool)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.userSettingsAdapter) var userSettingsAdapter
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.carrierClient) var carrierClient
    @Dependency(\.cloudSyncUseCase) var cloudSyncUseCase
    @Dependency(\.openURL) var openURL

    private enum CancelID { case task; case wipeAll; case seedRandom }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: Navigation
            case .accountManagementTapped:
                state.path.append(.accountManagement(AccountManagementFeature.State()))
                return .none

            case .categoryManagementTapped:
                state.path.append(.categoryManagement(CategoryManagementFeature.State()))
                return .none

            case .budgetManagementTapped:
                state.path.append(.budgetManagement(BudgetManagementFeature.State()))
                return .none

            case .tagManagementTapped:
                state.path.append(.tagManagement(TagManagementFeature.State()))
                return .none

            case .carrierManagementTapped:
                state.path.append(.carrierManagement(CarrierManagementFeature.State()))
                return .none

            case .notificationSettingsTapped:
                state.path.append(.notificationSettings(NotificationSettingsFeature.State()))
                return .none

            case .syncSettingsTapped:
                state.path.append(.syncSettings(SyncSettingsFeature.State()))
                return .none

            case .watchSettingsTapped:
                state.path.append(.watchSettings(WatchSettingsFeature.State()))
                return .none

            case .path:
                return .none

            case .task:
                return .run { send in
                    async let accounts = accountClient.fetchActive()
                    let defaultId = userSettingsAdapter.string(.defaultAccountId)
                    let showAccessoryBar = userSettingsAdapter.bool(.showAccessoryBar)
                    let fetched = try await accounts
                    await send(.accountsLoaded(fetched))
                    await send(.defaultAccountSelected(defaultId))
                    let langCode = Locale.current.language.languageCode?.identifier ?? "zh"
                    let displayName = Locale.current.localizedString(forLanguageCode: langCode)?.localizedCapitalized ?? langCode
                    await send(.languageLoaded(displayName))
                    await send(.accessoryBarToggleChanged(showAccessoryBar))
                    let fetchedCarriers = try await carrierClient.listAll()
                    await send(.widgetCarriersLoaded(fetchedCarriers))
                }
                .cancellable(id: CancelID.task)

            case let .accountsLoaded(accounts):
                state.accounts = accounts
                if let selected = accounts.first(where: { $0.id == state.selectedDefaultAccountId }) {
                    state.defaultAccountName = selected.name
                } else {
                    state.defaultAccountName = accounts.first?.name ?? String(localized: "settings_none")
                }
                return .none

            case let .defaultAccountSelected(id):
                state.selectedDefaultAccountId = id
                state.isPickingDefaultAccount = false
                userSettingsAdapter.setString(id, .defaultAccountId)
                if let account = state.accounts.first(where: { $0.id == id }) {
                    state.defaultAccountName = account.name
                }
                return .none

            case .defaultAccountTapped:
                state.isPickingDefaultAccount = true
                return .none

            case .defaultAccountPickerDismissed:
                state.isPickingDefaultAccount = false
                return .none

            case .widgetCarrierTapped:
                state.isPickingWidgetCarrier = true
                return .none

            case .widgetCarrierPickerDismissed:
                state.isPickingWidgetCarrier = false
                return .none

            case let .languageLoaded(name):
                state.currentLanguage = name
                return .none

            case .languageTapped:
                return .run { _ in
                    if let url = URL(string: "app-settings:") {
                        await openURL(url)
                    }
                }

            case .exportCSVTapped:
                state.exportingFormat = .csv
                state.exportError = nil
                return .run { [transactionClient, categoryClient, accountClient] send in
                    do {
                        let transactions = try await transactionClient.fetchAll()
                        let categories = try await categoryClient.fetchAll()
                        let accounts = try await accountClient.fetchAll()

                        let categoryMap = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                        let accountMap = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

                        let csvHeader = [
                            String(localized: "settings_export_csv_header_date"),
                            String(localized: "settings_export_csv_header_type"),
                            String(localized: "settings_export_csv_header_category"),
                            String(localized: "settings_export_csv_header_note"),
                            String(localized: "settings_export_csv_header_amount"),
                            String(localized: "settings_export_csv_header_account")
                        ].joined(separator: ",")
                        var lines = [csvHeader]
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy/MM/dd"

                        for t in transactions {
                            let date = formatter.string(from: t.date)
                            let type = t.type.rawValue
                            let category = csvField(t.categoryId.flatMap { categoryMap[$0] }?.localizedName ?? "")
                            let note = csvField(t.note ?? "")
                            let amount: String
                            switch t.type {
                            case .expense: amount = "-\(t.amount)"
                            case .income, .transfer: amount = "\(t.amount)"
                            }
                            let account = csvField(accountMap[t.accountId]?.name ?? "")
                            lines.append("\(date),\(type),\(category),\(note),\(amount),\(account)")
                        }

                        let csv = lines.joined(separator: "\n")
                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("NeuLedger_export.csv")
                        try csv.write(to: url, atomically: true, encoding: .utf8)
                        await send(.exportCompleted(url))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }

            case .exportJSONTapped:
                state.exportingFormat = .json
                state.exportError = nil
                return .run { [transactionClient] send in
                    do {
                        let transactions = try await transactionClient.fetchAll()
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = .prettyPrinted
                        encoder.dateEncodingStrategy = .iso8601
                        let data = try encoder.encode(transactions)
                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("NeuLedger_export.json")
                        try data.write(to: url, options: .atomic)
                        await send(.exportCompleted(url))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }

            case let .exportCompleted(url):
                state.exportingFormat = nil
                state.exportedFileURL = url
                return .none

            case let .exportFailed(error):
                state.exportingFormat = nil
                state.exportError = error
                return .none

            case .exportSheetDismissed:
                state.exportedFileURL = nil
                return .none

            case let .accessoryBarToggleChanged(value):
                state.showAccessoryBar = value
                userSettingsAdapter.setBool(value, .showAccessoryBar)
                return .send(.delegate(.accessoryBarVisibilityChanged(value)))

            case .privacyPolicyTapped:
                return .run { _ in
                    await openURL(SettingsFeature.privacyPolicyURL)
                }

            case let .widgetCarriersLoaded(carriers):
                state.carriers = carriers
                let activeId = carrierClient.activeForWidget()
                state.widgetCarrierId = activeId?.uuidString ?? ""
                if let activeId, let carrier = carriers.first(where: { $0.id == activeId }) {
                    state.widgetCarrierName = carrier.name
                } else {
                    state.widgetCarrierName = ""
                }
                return .none

            case let .widgetCarrierSelected(id):
                state.widgetCarrierId = id.uuidString
                state.isPickingWidgetCarrier = false
                if let carrier = state.carriers.first(where: { $0.id == id }) {
                    state.widgetCarrierName = carrier.name
                }
                return .run { [carrierClient] _ in
                    await carrierClient.setActiveForWidget(id)
                }

            case .wipeAllDataTapped:
                state.wipeAllDataError = nil
                state.isConfirmingWipeAllData = true
                return .none

            case .wipeAllDataDismissed:
                state.isConfirmingWipeAllData = false
                return .none

            case .wipeAllDataConfirmed:
                state.isConfirmingWipeAllData = false
                state.isWipingAllData = true
                state.wipeAllDataError = nil
                return .run { [cloudSyncUseCase] send in
                    do {
                        try await cloudSyncUseCase.wipeAll()
                        await send(.wipeAllDataCompleted)
                    } catch {
                        await send(.wipeAllDataFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.wipeAll)

            case .wipeAllDataCompleted:
                state.isWipingAllData = false
                // Tell the parent to swap the root destination back to
                // onboarding; SettingsFeature itself can't navigate that
                // far because its state lives below MainTab.
                return .send(.delegate(.allDataWiped))

            case let .wipeAllDataFailed(message):
                state.isWipingAllData = false
                state.wipeAllDataError = message
                return .none

            case .seedRandomDataTapped:
                guard !state.isSeedingRandomData else { return .none }
                state.isSeedingRandomData = true
                state.seedRandomDataResult = nil
                state.seedRandomDataError = nil
                return .run { [accountClient, transactionClient, categoryClient] send in
                    do {
                        let categories = try await categoryClient.fetchAll()
                        let expenseCats = categories.filter { $0.type == .expense }
                        let incomeCats = categories.filter { $0.type == .income }
                        let nameSeeds = ["主錢包", "活儲", "信用卡", "悠遊", "街口", "現金", "副帳", "外幣", "投資", "緊急"]
                        let palette = ["#FF9500", "#34C759", "#0A84FF", "#FF3B30", "#5E5CE6",
                                       "#FF2D55", "#30D158", "#64D2FF", "#FF9F0A", "#BF5AF2"]
                        let now = Date()
                        let day: TimeInterval = 24 * 60 * 60

                        let accountCount = Int.random(in: 2...5)
                        var totalTransactions = 0

                        for i in 0..<accountCount {
                            let type = AccountType.allCases.randomElement() ?? .cash
                            let nameBase = nameSeeds.randomElement() ?? "帳戶"
                            let account = Account(
                                name: "\(nameBase) #\(Int.random(in: 100...999))",
                                type: type,
                                icon: type.defaultIcon,
                                color: palette.randomElement() ?? type.defaultColor,
                                sortOrder: 1000 + i
                            )
                            try await accountClient.add(account)

                            let txnCount = Int.random(in: 30...60)
                            for _ in 0..<txnCount {
                                let isExpense = Double.random(in: 0..<1) < 0.75
                                let txnType: TransactionType = isExpense ? .expense : .income
                                let pool = isExpense ? expenseCats : incomeCats
                                let categoryId = pool.randomElement()?.id
                                let amount: Decimal = isExpense
                                    ? Decimal(Int.random(in: 30...3_000))
                                    : Decimal(Int.random(in: 500...30_000))
                                let daysAgo = Double(Int.random(in: 0...90))
                                let date = now.addingTimeInterval(-daysAgo * day - Double.random(in: 0..<day))
                                let txn = Transaction(
                                    amount: amount,
                                    date: date,
                                    note: nil,
                                    categoryId: categoryId,
                                    accountId: account.id,
                                    type: txnType
                                )
                                try await transactionClient.add(txn)
                            }
                            totalTransactions += txnCount
                        }
                        await send(.seedRandomDataCompleted(
                            accountCount: accountCount,
                            transactionCount: totalTransactions
                        ))
                    } catch {
                        await send(.seedRandomDataFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.seedRandom)

            case let .seedRandomDataCompleted(accountCount, transactionCount):
                state.isSeedingRandomData = false
                state.seedRandomDataResult = "已產生 \(accountCount) 個帳戶、\(transactionCount) 筆交易"
                return .run { [accountClient] send in
                    let accounts = try await accountClient.fetchActive()
                    await send(.accountsLoaded(accounts))
                }

            case let .seedRandomDataFailed(message):
                state.isSeedingRandomData = false
                state.seedRandomDataError = message
                return .none

            case .seedRandomDataDismissed:
                state.seedRandomDataResult = nil
                state.seedRandomDataError = nil
                return .none

            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    // MARK: - CSV Helpers

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

extension SettingsFeature.Destination.State: Equatable {}
extension SettingsFeature.Destination.Action: Equatable {}
