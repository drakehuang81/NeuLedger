import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct TagManagementFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var tags: [Tag] = []
        public var isLoading: Bool = false
        public var loadError: String? = nil
        public var actionError: String? = nil

        @Presents public var addEdit: AddEditTagFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case tagsLoaded([Tag])
        case loadFailed(String)
        case actionFailed(String)

        case addButtonTapped
        case tagTapped(Tag)
        case deleteRequested(Tag.ID)

        case addEdit(PresentationAction<AddEditTagFeature.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case deleteConfirmed(Tag.ID)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.ledgerClient) var ledger

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let tags = try await ledger.listTags()
                    await send(.tagsLoaded(tags))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.task)

            case let .tagsLoaded(tags):
                state.loadError = nil
                state.actionError = nil
                state.isLoading = false
                state.tags = tags
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none

            case let .actionFailed(message):
                state.actionError = message
                return .none

            case .addButtonTapped:
                state.addEdit = AddEditTagFeature.State(mode: .add)
                return .none

            case let .tagTapped(tag):
                state.addEdit = AddEditTagFeature.State(mode: .edit(tag))
                return .none

            case let .deleteRequested(id):
                state.alert = AlertState {
                    TextState(String(localized: "alert_delete_tag"))
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState(String(localized: "common_delete"))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: "common_cancel"))
                    }
                } message: {
                    TextState(String(localized: "alert_delete_tag_message"))
                }
                return .none

            case let .alert(.presented(.deleteConfirmed(id))):
                return .run { send in
                    try await ledger.deleteTag(id)
                    let tags = try await ledger.listTags()
                    await send(.tagsLoaded(tags))
                } catch: { error, send in
                    await send(.actionFailed(error.localizedDescription))
                }

            case .alert:
                return .none

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let tags = try await ledger.listTags()
                    await send(.tagsLoaded(tags))
                } catch: { error, send in
                    await send(.actionFailed(error.localizedDescription))
                }

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            AddEditTagFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
