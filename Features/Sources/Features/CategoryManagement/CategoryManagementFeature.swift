import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct CategoryManagementFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var categories: [Domain.Category] = []
        public var selectedType: TransactionType = .expense
        public var isLoading: Bool = false

        @Presents public var addEdit: AddEditCategoryFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}

        public var filteredCategories: [Domain.Category] {
            categories
                .filter { $0.type == selectedType }
                .sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case categoriesLoaded([Domain.Category])
        case selectedTypeChanged(TransactionType)
        case addButtonTapped
        case categoryTapped(Domain.Category)
        case categoriesMoved(IndexSet, Int)
        case deleteRequested(Domain.Category.ID)
        case addEdit(PresentationAction<AddEditCategoryFeature.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case deleteConfirmed(Domain.Category.ID)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.categoryClient) var categoryClient

    private enum CancelID {
        case task
        case reorder
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: Lifecycle
            case .task:
                state.isLoading = true
                return .run { send in
                    let categories = try await categoryClient.fetchAll()
                    let sorted = categories.sorted { $0.sortOrder < $1.sortOrder }
                    await send(.categoriesLoaded(sorted))
                }
                .cancellable(id: CancelID.task)

            case let .categoriesLoaded(categories):
                state.isLoading = false
                state.categories = categories
                return .none

            // MARK: Type Selection
            case let .selectedTypeChanged(type):
                guard type != .transfer else { return .none }
                state.selectedType = type
                return .none

            // MARK: Add
            case .addButtonTapped:
                state.addEdit = AddEditCategoryFeature.State(mode: .add(state.selectedType))
                return .none

            // MARK: Edit
            case let .categoryTapped(category):
                state.addEdit = AddEditCategoryFeature.State(mode: .edit(category))
                return .none

            // MARK: Reorder
            case let .categoriesMoved(source, destination):
                var filtered = state.filteredCategories
                filtered.move(fromOffsets: source, toOffset: destination)

                // Re-assign sortOrder based on new positions
                let reordered = filtered.enumerated().map { index, category in
                    Domain.Category(
                        id: category.id,
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        type: category.type,
                        sortOrder: index,
                        isDefault: category.isDefault
                    )
                }

                // Update state.categories for the reordered items
                for updated in reordered {
                    if let idx = state.categories.firstIndex(where: { $0.id == updated.id }) {
                        state.categories[idx] = updated
                    }
                }

                return .run { _ in
                    for category in reordered {
                        try await categoryClient.update(category)
                    }
                }
                .cancellable(id: CancelID.reorder, cancelInFlight: true)

            // MARK: Delete
            case let .deleteRequested(id):
                guard let category = state.categories.first(where: { $0.id == id }),
                      !category.isDefault
                else { return .none }

                state.alert = AlertState {
                    TextState(String(localized: "alert_delete_category"))
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState(String(localized: "common_delete"))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: "common_cancel"))
                    }
                } message: {
                    TextState(String(format: String(localized: "alert_delete_category_message_name %@"), category.localizedName))
                }
                return .none

            case let .alert(.presented(.deleteConfirmed(id))):
                return .run { send in
                    try await categoryClient.delete(id)
                    let categories = try await categoryClient.fetchAll()
                    let sorted = categories.sorted { $0.sortOrder < $1.sortOrder }
                    await send(.categoriesLoaded(sorted))
                }

            case .alert:
                return .none

            // MARK: AddEdit delegate
            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let categories = try await categoryClient.fetchAll()
                    let sorted = categories.sorted { $0.sortOrder < $1.sortOrder }
                    await send(.categoriesLoaded(sorted))
                }

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            AddEditCategoryFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
