import ComposableArchitecture
import Domain
import Foundation
import UIKit

@Reducer
public struct SettingsFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var isAIEnabled: Bool = true
        public var accounts: [Account] = []
        public var selectedDefaultAccountId: String = ""
        public var defaultAccountName: String = ""
        public var currentLanguage: String = ""
        public var isExporting: Bool = false
        public var exportedFileURL: URL? = nil
        public var exportError: String? = nil

        public init(
            isAIEnabled: Bool = true,
            accounts: [Account] = [],
            selectedDefaultAccountId: String = "",
            defaultAccountName: String = "",
            currentLanguage: String = ""
        ) {
            self.isAIEnabled = isAIEnabled
            self.accounts = accounts
            self.selectedDefaultAccountId = selectedDefaultAccountId
            self.defaultAccountName = defaultAccountName
            self.currentLanguage = currentLanguage
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case aiToggleChanged(Bool)
        case accountsLoaded([Account])
        case defaultAccountSelected(String)
        case languageTapped
        case languageLoaded(String)
        case exportCSVTapped
        case exportJSONTapped
        case exportCompleted(URL)
        case exportFailed(String)
        case exportSheetDismissed
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
            case .task:
                return .run { send in
                    async let accounts = accountClient.fetchActive()
                    let isAIEnabled = userSettingsClient.bool(.aiEnabled)
                    let defaultId = userSettingsClient.string(.defaultAccountId)
                    let fetched = try await accounts
                    await send(.accountsLoaded(fetched))
                    await send(.aiToggleChanged(isAIEnabled))
                    await send(.defaultAccountSelected(defaultId))
                    let langCode = Locale.current.language.languageCode?.identifier ?? "zh"
                    let displayName = Locale.current.localizedString(forLanguageCode: langCode)?.localizedCapitalized ?? langCode
                    await send(.languageLoaded(displayName))
                }
                .cancellable(id: CancelID.task)

            case let .aiToggleChanged(value):
                state.isAIEnabled = value
                userSettingsClient.setBool(value, .aiEnabled)
                return .none

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
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        await openURL(url)
                    }
                }

            case .exportCSVTapped:
                state.isExporting = true
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
                            let category = t.categoryId.flatMap { categoryMap[$0] }?.name ?? ""
                            let note = t.note?.replacingOccurrences(of: ",", with: "\u{FF0C}") ?? ""
                            let amount: String
                            switch t.type {
                            case .expense: amount = "-\(t.amount)"
                            case .income, .transfer: amount = "\(t.amount)"
                            }
                            let account = accountMap[t.accountId]?.name ?? ""
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
                state.isExporting = true
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
                state.isExporting = false
                state.exportedFileURL = url
                return .none

            case let .exportFailed(error):
                state.isExporting = false
                state.exportError = error
                return .none

            case .exportSheetDismissed:
                state.exportedFileURL = nil
                return .none

            case .privacyPolicyTapped:
                print("[Settings] Privacy policy tapped — not yet implemented")
                return .none
            }
        }
    }
}
