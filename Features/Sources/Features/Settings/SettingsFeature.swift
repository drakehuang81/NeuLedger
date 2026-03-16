import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct SettingsFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var isAIEnabled: Bool = true
        public var defaultAccountName: String = ""

        public init(
            isAIEnabled: Bool = true,
            defaultAccountName: String = ""
        ) {
            self.isAIEnabled = isAIEnabled
            self.defaultAccountName = defaultAccountName
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case aiToggleChanged(Bool)
        case accountsLoaded([Account])
        case exportCSVTapped
        case exportJSONTapped
        case privacyPolicyTapped
    }

    // MARK: - Dependencies

    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.accountClient) var accountClient

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    async let accounts = accountClient.fetchActive()
                    let isAIEnabled = userSettingsClient.bool(.aiEnabled)
                    let fetched = try await accounts
                    await send(.accountsLoaded(fetched))
                    await send(.aiToggleChanged(isAIEnabled))
                }
                .cancellable(id: CancelID.task)

            case let .aiToggleChanged(value):
                state.isAIEnabled = value
                userSettingsClient.setBool(value, .aiEnabled)
                return .none

            case let .accountsLoaded(accounts):
                state.defaultAccountName = accounts.first?.name ?? String(localized: "settings_none")
                return .none

            case .exportCSVTapped:
                print("[Settings] Export CSV tapped — not yet implemented")
                return .none

            case .exportJSONTapped:
                print("[Settings] Export JSON tapped — not yet implemented")
                return .none

            case .privacyPolicyTapped:
                print("[Settings] Privacy policy tapped — not yet implemented")
                return .none
            }
        }
    }
}
