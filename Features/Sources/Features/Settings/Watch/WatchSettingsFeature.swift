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

    private enum CancelID { case pushWatchContext }

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
                // Single source of truth: Account.resolveDefaultId (shared with
                // WatchDefaultAccountResolver / the Watch sync pipeline).
                state.selectedAccountId = Account.resolveDefaultId(stored: selectedAccountId, in: accounts)
                state.isPaired = isPaired
                state.isWatchAppInstalled = isWatchAppInstalled
                return .none

            case let .accountSelected(id):
                state.selectedAccountId = id
                platformClient.setWatchDefaultAccountId(id)
                // Settings writes don't save SwiftData, so WatchSyncObserver
                // never fires for them — push the fresh default explicitly.
                // cancelInFlight: rapid re-selection must not let an older
                // in-flight push land after (and overwrite) the newest one.
                return .run { _ in await platformClient.pushWatchContext() }
                    .cancellable(id: CancelID.pushWatchContext, cancelInFlight: true)
            }
        }
    }
}
