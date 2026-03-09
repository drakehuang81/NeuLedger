import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AddEditTagFeature: Sendable {
    public init() {}

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
        case add
        case edit(Tag)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var name: String
        public var colorHex: String
        public var nameError: String?

        public init(mode: Mode = .add) {
            self.mode = mode
            switch mode {
            case .add:
                self.name = ""
                self.colorHex = "#3478F6"
            case let .edit(tag):
                self.name = tag.name
                self.colorHex = tag.color ?? "#3478F6"
            }
        }

        var navigationTitle: String {
            switch mode {
            case .add: return "新增標籤"
            case .edit: return "編輯標籤"
            }
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case nameChanged(String)
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

    @Dependency(\.tagClient) var tagClient
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                state.nameError = nil
                return .none

            case let .colorHexChanged(hex):
                state.colorHex = hex
                return .none

            case .saveTapped:
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    state.nameError = "標籤名稱不能為空"
                    return .none
                }

                let mode = state.mode
                let colorHex = state.colorHex

                return .run { send in
                    switch mode {
                    case .add:
                        let tag = Tag(name: trimmedName, color: colorHex)
                        try await tagClient.add(tag)
                    case let .edit(existing):
                        let updated = Tag(id: existing.id, name: trimmedName, color: colorHex)
                        try await tagClient.update(updated)
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
