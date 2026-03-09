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

        @Presents public var addEdit: AddEditTagFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case tagsLoaded([Tag])

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

    @Dependency(\.tagClient) var tagClient

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let tags = try await tagClient.fetchAll()
                    await send(.tagsLoaded(tags))
                }
                .cancellable(id: CancelID.task)

            case let .tagsLoaded(tags):
                state.isLoading = false
                state.tags = tags
                return .none

            case .addButtonTapped:
                state.addEdit = AddEditTagFeature.State(mode: .add)
                return .none

            case let .tagTapped(tag):
                state.addEdit = AddEditTagFeature.State(mode: .edit(tag))
                return .none

            case let .deleteRequested(id):
                state.alert = AlertState {
                    TextState("刪除標籤")
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState("刪除")
                    }
                    ButtonState(role: .cancel) {
                        TextState("取消")
                    }
                } message: {
                    TextState("此標籤將從所有關聯交易中移除。確定要刪除嗎？")
                }
                return .none

            case let .alert(.presented(.deleteConfirmed(id))):
                return .run { send in
                    try await tagClient.delete(id)
                    let tags = try await tagClient.fetchAll()
                    await send(.tagsLoaded(tags))
                }

            case .alert:
                return .none

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let tags = try await tagClient.fetchAll()
                    await send(.tagsLoaded(tags))
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
