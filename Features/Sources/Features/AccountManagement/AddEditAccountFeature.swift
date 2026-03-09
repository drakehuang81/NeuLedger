import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AddEditAccountFeature: Sendable {
    public init() {}

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
        case add
        case edit(Account)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var name: String
        public var type: AccountType
        public var icon: String
        public var colorHex: String
        public var nameError: String?
        public var existingNames: [String]

        public init(
            mode: Mode = .add,
            existingNames: [String] = []
        ) {
            self.mode = mode
            self.existingNames = existingNames

            switch mode {
            case .add:
                self.name = ""
                self.type = .cash
                self.icon = "creditcard"
                self.colorHex = "#3478F6"
            case let .edit(account):
                self.name = account.name
                self.type = account.type
                self.icon = account.icon
                self.colorHex = account.color
            }

            self.nameError = nil
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case nameChanged(String)
        case typeChanged(AccountType)
        case iconChanged(String)
        case colorHexChanged(String)
        case saveTapped
        case cancelTapped
        case savedSuccessfully
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                state.nameError = nil
                return .none

            case let .typeChanged(type):
                state.type = type
                return .none

            case let .iconChanged(icon):
                state.icon = icon
                return .none

            case let .colorHexChanged(hex):
                state.colorHex = hex
                return .none

            case .saveTapped:
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    state.nameError = "請輸入帳戶名稱"
                    return .none
                }
                if state.existingNames.contains(trimmedName) {
                    state.nameError = "此名稱已被使用"
                    return .none
                }

                let mode = state.mode
                let name = trimmedName
                let type = state.type
                let icon = state.icon
                let colorHex = state.colorHex

                return .run { send in
                    switch mode {
                    case .add:
                        let account = Account(
                            name: name,
                            type: type,
                            icon: icon,
                            color: colorHex
                        )
                        try await accountClient.add(account)
                    case let .edit(existing):
                        let updated = Account(
                            id: existing.id,
                            name: name,
                            type: type,
                            icon: icon,
                            color: colorHex,
                            sortOrder: existing.sortOrder,
                            isArchived: existing.isArchived,
                            createdAt: existing.createdAt
                        )
                        try await accountClient.update(updated)
                    }
                    await send(.savedSuccessfully)
                }

            case .savedSuccessfully:
                return .run { send in
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }
}
