import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AddEditCategoryFeature: Sendable {
    public init() {}

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
        case add(TransactionType)
        case edit(Domain.Category)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var name: String
        public var icon: String
        public var colorHex: String
        public var type: TransactionType
        public var nameError: String?
        public var isDefault: Bool

        public init(mode: Mode) {
            self.mode = mode
            switch mode {
            case let .add(type):
                self.type = type
                self.name = ""
                self.icon = "tag.fill"
                self.colorHex = "#007AFF"
                self.isDefault = false
            case let .edit(category):
                self.type = category.type
                self.name = category.name
                self.icon = category.icon
                self.colorHex = category.color
                self.isDefault = category.isDefault
            }
            self.nameError = nil
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case nameChanged(String)
        case iconChanged(String)
        case colorHexChanged(String)
        case typeChanged(TransactionType)
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

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case save }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                state.nameError = nil
                return .none

            case let .iconChanged(icon):
                state.icon = icon
                return .none

            case let .colorHexChanged(hex):
                state.colorHex = hex
                return .none

            case let .typeChanged(type):
                // Don't change type for default categories
                guard !state.isDefault else { return .none }
                state.type = type
                return .none

            case .saveTapped:
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    state.nameError = String(localized: "error_category_name_empty")
                    return .none
                }

                let mode = state.mode
                let name = trimmedName
                let icon = state.icon
                let colorHex = state.colorHex
                let type = state.type

                return .run { send in
                    switch mode {
                    case let .add(initialType):
                        let category = Domain.Category(
                            name: name,
                            icon: icon,
                            color: colorHex,
                            type: type != .transfer ? type : initialType,
                            sortOrder: 0,
                            isDefault: false
                        )
                        try await ledger.createCategory(category)

                    case let .edit(existing):
                        let updated = Domain.Category(
                            id: existing.id,
                            name: name,
                            icon: icon,
                            color: colorHex,
                            type: existing.isDefault ? existing.type : type,
                            sortOrder: existing.sortOrder,
                            isDefault: existing.isDefault
                        )
                        try await ledger.updateCategory(updated)
                    }
                    await send(.savedSuccessfully)
                }
                .cancellable(id: CancelID.save)

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
