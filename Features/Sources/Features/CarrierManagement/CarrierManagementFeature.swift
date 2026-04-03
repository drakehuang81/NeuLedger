import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct CarrierManagementFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var carriers: [Carrier] = []
        public var isLoading: Bool = false
        public var expandedCarrierId: Carrier.ID? = nil
        @Presents public var addEdit: AddEditCarrierFeature.State?

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case task
        case carriersLoaded([Carrier])
        case carrierRowTapped(Carrier.ID)
        case addTapped
        case deleteTapped(Carrier.ID)
        case addEdit(PresentationAction<AddEditCarrierFeature.Action>)
    }

    @Dependency(\.carrierClient) var carrierClient

    private enum CancelID { case task }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let carriers = try await carrierClient.fetchAll()
                    await send(.carriersLoaded(carriers))
                }
                .cancellable(id: CancelID.task)

            case let .carriersLoaded(carriers):
                state.isLoading = false
                state.carriers = carriers
                return .none

            case let .carrierRowTapped(id):
                if state.expandedCarrierId == id {
                    state.expandedCarrierId = nil
                } else {
                    state.expandedCarrierId = id
                }
                return .none

            case .addTapped:
                state.addEdit = AddEditCarrierFeature.State(mode: .add)
                return .none

            case let .deleteTapped(id):
                state.expandedCarrierId = nil
                return .run { send in
                    try await carrierClient.delete(id)
                    let carriers = try await carrierClient.fetchAll()
                    await send(.carriersLoaded(carriers))
                }

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let carriers = try await carrierClient.fetchAll()
                    await send(.carriersLoaded(carriers))
                }

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            AddEditCarrierFeature()
        }
    }
}
