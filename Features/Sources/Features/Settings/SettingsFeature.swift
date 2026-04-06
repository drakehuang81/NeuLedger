import ComposableArchitecture
import Domain
import Foundation
import WidgetKit

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

    @Reducer(state: .equatable, action: .equatable)
    public enum Destination {
        case accountManagement(AccountManagementFeature)
        case categoryManagement(CategoryManagementFeature)
        case budgetManagement(BudgetManagementFeature)
        case tagManagement(TagManagementFeature)
        case carrierManagement(CarrierManagementFeature)
        case notificationSettings(NotificationSettingsFeature)
        case syncSettings(SyncSettingsFeature)
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
    }

    // MARK: - Dependencies

    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.carrierClient) var carrierClient
    @Dependency(\.openURL) var openURL

    private enum CancelID { case task }

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

            case .path:
                return .none

            case .task:
                return .run { send in
                    async let accounts = accountClient.fetchActive()
                    let defaultId = userSettingsClient.string(.defaultAccountId)
                    let showAccessoryBar = userSettingsClient.bool(.showAccessoryBar)
                    let fetched = try await accounts
                    await send(.accountsLoaded(fetched))
                    await send(.defaultAccountSelected(defaultId))
                    let langCode = Locale.current.language.languageCode?.identifier ?? "zh"
                    let displayName = Locale.current.localizedString(forLanguageCode: langCode)?.localizedCapitalized ?? langCode
                    await send(.languageLoaded(displayName))
                    await send(.accessoryBarToggleChanged(showAccessoryBar))
                    let fetchedCarriers = try await carrierClient.fetchAll()
                    await send(.widgetCarriersLoaded(fetchedCarriers))
                }
                .cancellable(id: CancelID.task)

            case let .accountsLoaded(accounts):
                state.accounts = accounts
                if let selected = accounts.first(where: { $0.id.uuidString == state.selectedDefaultAccountId }) {
                    state.defaultAccountName = selected.name
                } else {
                    state.defaultAccountName = accounts.first?.name ?? String(localized: "settings_none")
                }
                return .none

            case let .defaultAccountSelected(id):
                state.selectedDefaultAccountId = id
                userSettingsClient.setString(id, .defaultAccountId)
                if let account = state.accounts.first(where: { $0.id.uuidString == id }) {
                    state.defaultAccountName = account.name
                }
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

                        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
                        let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })

                        var lines = ["日期,類型,分類,備註,金額,帳戶"]
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy/MM/dd"

                        for t in transactions {
                            let date = formatter.string(from: t.date)
                            let type = t.type.rawValue
                            let category = csvField(t.categoryId.flatMap { categoryMap[$0] }?.name ?? "")
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
                userSettingsClient.setBool(value, .showAccessoryBar)
                return .none

            case .privacyPolicyTapped:
                return .run { _ in
                    await openURL(SettingsFeature.privacyPolicyURL)
                }

            case let .widgetCarriersLoaded(carriers):
                state.carriers = carriers
                let savedId = userSettingsClient.string(.widgetCarrierId)
                state.widgetCarrierId = savedId
                if let carrier = carriers.first(where: { $0.id.uuidString == savedId }) {
                    state.widgetCarrierName = carrier.name
                } else {
                    state.widgetCarrierName = ""
                }
                return .none

            case let .widgetCarrierSelected(id):
                state.widgetCarrierId = id.uuidString
                userSettingsClient.setString(id.uuidString, .widgetCarrierId)
                if let carrier = state.carriers.first(where: { $0.id == id }) {
                    state.widgetCarrierName = carrier.name
                    if let defaults = UserDefaults(suiteName: "group.com.drakehuang.NeuLedger") {
                        defaults.set(carrier.barcode, forKey: "carrierBarcode")
                        defaults.set(carrier.type.rawValue, forKey: "carrierType")
                        defaults.set(carrier.name, forKey: "carrierName")
                        defaults.set(Date(), forKey: "carrierUpdatedAt")
                    }
                }
                return .run { _ in
                    WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")
                }
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
