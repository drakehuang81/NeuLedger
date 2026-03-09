import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AccountManagementFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var accounts: [Account] = []
        public var balances: [Account.ID: Decimal] = [:]
        public var isLoading: Bool = false
        @Presents public var addEdit: AddEditAccountFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}

        public var activeAccounts: [Account] {
            accounts.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
        }

        public var archivedAccounts: [Account] {
            accounts.filter { $0.isArchived }
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case accountsLoaded([Account])
        case balancesLoaded([Account.ID: Decimal])
        case addButtonTapped
        case accountTapped(Account)
        case deleteRequested(Account.ID)
        case unarchiveTapped(Account.ID)
        case showArchiveConfirmation(Account.ID)
        case showDeleteConfirmation(Account.ID)
        case addEdit(PresentationAction<AddEditAccountFeature.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case archiveConfirmed(Account.ID)
            case deleteConfirmed(Account.ID)
            case unarchiveConfirmed(Account.ID)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.transactionClient) var transactionClient

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let accounts = try await accountClient.fetchAll()
                    await send(.accountsLoaded(accounts))
                }
                .cancellable(id: CancelID.task)

            case let .accountsLoaded(accounts):
                state.isLoading = false
                state.accounts = accounts
                let ids = accounts.map(\.id)
                return .run { send in
                    var balances: [Account.ID: Decimal] = [:]
                    await withTaskGroup(of: (Account.ID, Decimal).self) { group in
                        for id in ids {
                            group.addTask {
                                let balance = (try? await accountClient.computeBalance(id)) ?? 0
                                return (id, balance)
                            }
                        }
                        for await (id, balance) in group {
                            balances[id] = balance
                        }
                    }
                    await send(.balancesLoaded(balances))
                }

            case let .balancesLoaded(balances):
                state.balances = balances
                return .none

            case .addButtonTapped:
                state.addEdit = AddEditAccountFeature.State(
                    mode: .add,
                    existingNames: state.accounts.map(\.name)
                )
                return .none

            case let .accountTapped(account):
                if account.isArchived {
                    state.alert = AlertState {
                        TextState("已封存帳戶")
                    } actions: {
                        ButtonState(action: .unarchiveConfirmed(account.id)) {
                            TextState("解除封存")
                        }
                        ButtonState(role: .cancel) {
                            TextState("取消")
                        }
                    } message: {
                        TextState("是否要解除封存此帳戶？")
                    }
                } else {
                    let existingNames = state.accounts
                        .filter { $0.id != account.id }
                        .map(\.name)
                    state.addEdit = AddEditAccountFeature.State(
                        mode: .edit(account),
                        existingNames: existingNames
                    )
                }
                return .none

            case let .deleteRequested(id):
                return .run { send in
                    let transactions = try await transactionClient.fetch(
                        TransactionFilter(accountIds: [id])
                    )
                    if transactions.isEmpty {
                        await send(.showDeleteConfirmation(id))
                    } else {
                        await send(.showArchiveConfirmation(id))
                    }
                }

            case let .showArchiveConfirmation(id):
                state.alert = AlertState {
                    TextState("無法刪除")
                } actions: {
                    ButtonState(action: .archiveConfirmed(id)) {
                        TextState("改為封存")
                    }
                    ButtonState(role: .cancel) {
                        TextState("取消")
                    }
                } message: {
                    TextState("此帳戶有關聯交易，無法刪除。是否改為封存？")
                }
                return .none

            case let .showDeleteConfirmation(id):
                state.alert = AlertState {
                    TextState("確定要刪除？")
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState("刪除")
                    }
                    ButtonState(role: .cancel) {
                        TextState("取消")
                    }
                } message: {
                    TextState("此操作無法還原。")
                }
                return .none

            case let .alert(.presented(.archiveConfirmed(id))):
                return .run { send in
                    try await accountClient.archive(id)
                    let accounts = try await accountClient.fetchAll()
                    await send(.accountsLoaded(accounts))
                }

            case let .alert(.presented(.deleteConfirmed(id))):
                return .run { send in
                    try await accountClient.delete(id)
                    let accounts = try await accountClient.fetchAll()
                    await send(.accountsLoaded(accounts))
                }

            case let .alert(.presented(.unarchiveConfirmed(id))):
                return .send(.unarchiveTapped(id))

            case .alert:
                return .none

            case let .unarchiveTapped(id):
                guard let account = state.accounts.first(where: { $0.id == id }) else {
                    return .none
                }
                var updated = account
                updated.isArchived = false
                let toUpdate = updated
                return .run { send in
                    try await accountClient.update(toUpdate)
                    let accounts = try await accountClient.fetchAll()
                    await send(.accountsLoaded(accounts))
                }

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let accounts = try await accountClient.fetchAll()
                    await send(.accountsLoaded(accounts))
                }

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            AddEditAccountFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
