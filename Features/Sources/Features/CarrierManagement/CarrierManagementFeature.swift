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

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case deleteConfirmed(Carrier.ID)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.carrierClient) var carrierClient
    @Dependency(\.userSettingsAdapter) var userSettingsAdapter
    @Dependency(\.widgetSyncClient) var widgetSyncClient

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { [widgetSyncClient] send in
                    let carriers = try await carrierClient.fetchAll()
                    await widgetSyncClient.syncAllCarriers(carriers)
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
                return .run { [userSettingsAdapter, widgetSyncClient] send in
                    try await carrierClient.delete(id)
                    let carriers = try await carrierClient.fetchAll()
                    // If the deleted carrier was the active widget carrier, clear App Group
                    let widgetCarrierId = userSettingsAdapter.string(.widgetCarrierId)
                    if widgetCarrierId == id.uuidString {
                        userSettingsAdapter.setString("", .widgetCarrierId)
                        await widgetSyncClient.clearCarrier()
                    }
                    await widgetSyncClient.syncAllCarriers(carriers)
                    await send(.carriersLoaded(carriers))
                } catch: { _, send in
                    let carriers = (try? await carrierClient.fetchAll()) ?? []
                    await send(.carriersLoaded(carriers))
                }

            case .alert:
                return .none

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { [userSettingsAdapter, widgetSyncClient] send in
                    let carriers = try await carrierClient.fetchAll()
                    let widgetCarrierId = userSettingsAdapter.string(.widgetCarrierId)

                    if widgetCarrierId.isEmpty, let first = carriers.first {
                        // P0: Auto-assign the first ever carrier as the widget carrier
                        userSettingsAdapter.setString(first.id.uuidString, .widgetCarrierId)
                        await widgetSyncClient.syncCarrier(
                            first.barcode,
                            first.type.rawValue,
                            first.name
                        )
                    } else if !widgetCarrierId.isEmpty,
                              let carrier = carriers.first(where: {
                                  $0.id.uuidString == widgetCarrierId
                              }) {
                        // If the widget carrier was edited, update App Group
                        await widgetSyncClient.syncCarrier(
                            carrier.barcode,
                            carrier.type.rawValue,
                            carrier.name
                        )
                    }

                    await widgetSyncClient.syncAllCarriers(carriers)
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
        .ifLet(\.$alert, action: \.alert)
    }
}
