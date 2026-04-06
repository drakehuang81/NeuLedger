import ComposableArchitecture
import Domain
import Foundation
import WidgetKit

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
    }

    // MARK: - Dependencies

    @Dependency(\.carrierClient) var carrierClient
    @Dependency(\.userSettingsClient) var userSettingsClient

    private enum CancelID { case task }

    // MARK: - Body

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

            case let .editTapped(carrier):
                state.addEdit = AddEditCarrierFeature.State(mode: .edit(carrier))
                return .none

            case let .deleteTapped(id):
                state.expandedCarrierId = nil
                return .run { [userSettingsClient] send in
                    try await carrierClient.delete(id)
                    let carriers = try await carrierClient.fetchAll()
                    // If deleted carrier was the widget carrier, clear App Group
                    let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
                    if widgetCarrierId == id.uuidString {
                        let appGroupDefaults = UserDefaults(
                            suiteName: "group.com.drakehuang.NeuLedger"
                        )
                        appGroupDefaults?.removeObject(forKey: "carrierBarcode")
                        appGroupDefaults?.removeObject(forKey: "carrierType")
                        appGroupDefaults?.removeObject(forKey: "carrierName")
                        appGroupDefaults?.removeObject(forKey: "carrierUpdatedAt")
                        userSettingsClient.setString("", .widgetCarrierId)
                        await WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")
                    }
                    await send(.carriersLoaded(carriers))
                } catch: { _, send in
                    let carriers = (try? await carrierClient.fetchAll()) ?? []
                    await send(.carriersLoaded(carriers))
                }

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { [userSettingsClient] send in
                    let carriers = try await carrierClient.fetchAll()
                    // If the widget carrier was edited, update App Group
                    let widgetCarrierId = userSettingsClient.string(.widgetCarrierId)
                    if !widgetCarrierId.isEmpty,
                       let carrier = carriers.first(where: {
                           $0.id.uuidString == widgetCarrierId
                       }) {
                        let appGroupDefaults = UserDefaults(
                            suiteName: "group.com.drakehuang.NeuLedger"
                        )
                        appGroupDefaults?.set(
                            carrier.barcode, forKey: "carrierBarcode"
                        )
                        appGroupDefaults?.set(
                            carrier.type.rawValue, forKey: "carrierType"
                        )
                        appGroupDefaults?.set(
                            carrier.name, forKey: "carrierName"
                        )
                        appGroupDefaults?.set(
                            Date(),
                            forKey: "carrierUpdatedAt"
                        )
                        await WidgetCenter.shared.reloadTimelines(
                            ofKind: "CarrierWidget"
                        )
                    }
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
