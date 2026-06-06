import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct CarrierManagementFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var carriers: [Carrier] = []
        public var isLoading: Bool = false
        public var expandedCarrierId: Carrier.ID? = nil
        @Presents public var addEdit: AddEditCarrierFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case carriersLoaded([Carrier])
        case carrierRowTapped(Carrier.ID)
        case addTapped
        case editTapped(Carrier)
        case deleteTapped(Carrier.ID)
        case addEdit(PresentationAction<AddEditCarrierFeature.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case deleteConfirmed(Carrier.ID)
        }

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            /// Any carrier write (add/edit/delete) completed; the parent
            /// (Settings) should reload its own carrier-derived state.
            case carriersChanged
        }
    }

    // MARK: - Dependencies

    @Dependency(\.carrierClient) var carrierClient

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let carriers = try await carrierClient.listAll()
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

            case let .editTapped(carrier):
                state.addEdit = AddEditCarrierFeature.State(mode: .edit(carrier))
                return .none

            case let .deleteTapped(id):
                let name = state.carriers.first(where: { $0.id == id })?.name ?? ""
                state.alert = AlertState {
                    TextState(String(localized: "alert_delete_carrier"))
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState(String(localized: "common_delete"))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: "common_cancel"))
                    }
                } message: {
                    TextState(String(format: String(localized: "alert_delete_carrier_message"), name))
                }
                return .none

            case let .alert(.presented(.deleteConfirmed(id))):
                state.expandedCarrierId = nil
                return .merge(
                    .run { send in
                        // CarrierClient.delete reloads the widget (syncAllCarriers) internally.
                        let wasActiveWidgetCarrier = carrierClient.activeForWidget() == id
                        try await carrierClient.delete(id)
                        let carriers = try await carrierClient.listAll()
                        // If the deleted carrier was the active widget carrier, re-point the
                        // widget at the first remaining carrier (or leave it if none remain).
                        if wasActiveWidgetCarrier, let first = carriers.first {
                            await carrierClient.setActiveForWidget(first.id)
                        }
                        await send(.carriersLoaded(carriers))
                    } catch: { _, send in
                        let carriers = (try? await carrierClient.listAll()) ?? []
                        await send(.carriersLoaded(carriers))
                    },
                    .send(.delegate(.carriersChanged))
                )

            case .alert:
                return .none

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .merge(
                    .run { send in
                        // CarrierClient.create/update reloads the widget (syncAllCarriers)
                        // internally; AddEditCarrierFeature already performed the mutation.
                        let carriers = try await carrierClient.listAll()
                        if carrierClient.activeForWidget() == nil, let first = carriers.first {
                            // P0: Auto-assign the first ever carrier as the widget carrier.
                            await carrierClient.setActiveForWidget(first.id)
                        }
                        await send(.carriersLoaded(carriers))
                    },
                    .send(.delegate(.carriersChanged))
                )

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            AddEditCarrierFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
