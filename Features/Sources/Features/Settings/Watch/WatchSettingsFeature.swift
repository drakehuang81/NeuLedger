import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct WatchSettingsFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        public var accounts: [Account]
        public var selectedAccountId: UUID?
        public var isPaired: Bool
        public var isWatchAppInstalled: Bool

        public init(
            accounts: [Account] = [],
            selectedAccountId: UUID? = nil,
            isPaired: Bool = false,
            isWatchAppInstalled: Bool = false
        ) {
            self.accounts = accounts
            self.selectedAccountId = selectedAccountId
            self.isPaired = isPaired
            self.isWatchAppInstalled = isWatchAppInstalled
        }
    }

    public enum Action: Sendable {
        case task
        case loaded(accounts: [Account], selectedAccountId: UUID?, isPaired: Bool, isWatchAppInstalled: Bool)
        case accountSelected(UUID)
    }

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.userSettingsAdapter) var userSettingsAdapter
    @Dependency(\.watchBridgeAdapter) var watchBridgeAdapter

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { send in
                    let accounts = (try? await accountClient.fetchActive()) ?? []
                    let raw = userSettingsAdapter.string(.watchDefaultAccountId)
                    let selected = raw.isEmpty ? nil : UUID(uuidString: raw)
                    await send(.loaded(
                        accounts: accounts,
                        selectedAccountId: selected,
                        isPaired: watchBridgeAdapter.isPaired(),
                        isWatchAppInstalled: watchBridgeAdapter.isWatchAppInstalled()
                    ))
                }

            case let .loaded(accounts, selectedAccountId, isPaired, isWatchAppInstalled):
                state.accounts = accounts
                state.selectedAccountId = selectedAccountId
                state.isPaired = isPaired
                state.isWatchAppInstalled = isWatchAppInstalled
                return .none

            case let .accountSelected(id):
                state.selectedAccountId = id
                userSettingsAdapter.setString(id.uuidString, .watchDefaultAccountId)
                return .none
            }
        }
    }
}
