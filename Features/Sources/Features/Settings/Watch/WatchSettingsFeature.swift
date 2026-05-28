import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct WatchSettingsFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        public var accounts: [Account]
        public var selectedAccountId: Account.ID?
        public var isPaired: Bool
        public var isWatchAppInstalled: Bool

        public init(
            accounts: [Account] = [],
            selectedAccountId: Account.ID? = nil,
            isPaired: Bool = false,
            isWatchAppInstalled: Bool = false
        ) {
            self.accounts = accounts
            self.selectedAccountId = selectedAccountId
            self.isPaired = isPaired
            self.isWatchAppInstalled = isWatchAppInstalled
        }
    }

    public enum Action: Equatable, Sendable {
        case task
        case loaded(accounts: [Account], selectedAccountId: Account.ID?, isPaired: Bool, isWatchAppInstalled: Bool)
        case accountSelected(Account.ID)
    }

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.userSettingsRepository) var userSettingsRepository
    @Dependency(\.watchBridgeAdapter) var watchBridgeAdapter

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { send in
                    let accounts = (try? await accountClient.fetchActive()) ?? []
                    let raw = userSettingsRepository.string(.watchDefaultAccountId)
                    let selected: Account.ID? = raw.isEmpty ? nil : raw
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
                userSettingsRepository.setString(id, .watchDefaultAccountId)
                return .none
            }
        }
    }
}
