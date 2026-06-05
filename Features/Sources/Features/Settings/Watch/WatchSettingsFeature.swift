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

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.platformClient) var platformClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { send in
                    let accounts = (try? await ledger.listActiveAccounts()) ?? []
                    await send(.loaded(
                        accounts: accounts,
                        selectedAccountId: platformClient.watchDefaultAccountId(),
                        isPaired: platformClient.watchPaired(),
                        isWatchAppInstalled: platformClient.watchAppInstalled()
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
                platformClient.setWatchDefaultAccountId(id)
                return .none
            }
        }
    }
}
