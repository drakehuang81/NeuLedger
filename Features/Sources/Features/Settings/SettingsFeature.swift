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

    @Reducer(state: .equatable, action: .equatable)
    public enum Destination {
        case accountManagement(AccountManagementFeature)
        case categoryManagement(CategoryManagementFeature)
        case budgetManagement(BudgetManagementFeature)
        case tagManagement(TagManagementFeature)
        case notificationSettings(NotificationSettingsFeature)
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

        public init(
            accounts: [Account] = [],
            selectedDefaultAccountId: String = "",
            defaultAccountName: String = "",
            currentLanguage: String = "",
            showAccessoryBar: Bool = true
        ) {
            self.accounts = accounts
            self.selectedDefaultAccountId = selectedDefaultAccountId
            self.defaultAccountName = defaultAccountName
            self.currentLanguage = currentLanguage
            self.showAccessoryBar = showAccessoryBar
        }
    }

    // MARK: - Action

    public enum Action: Equatable {
        // Navigation
        case accountManagementTapped
        case categoryManagementTapped
        case budgetManagementTapped
        case tagManagementTapped
        case notificationSettingsTapped
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
    }

    // MARK: - Dependencies

    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
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

            case .notificationSettingsTapped:
                state.path.append(.notificationSettings(NotificationSettingsFeature.State()))
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
