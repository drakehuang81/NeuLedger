import Foundation
import ComposableArchitecture
import Domain

/// Watch carrier viewer reducer. Read-only: state is a projection of the
/// snapshot cache plus which carrier (if any) is shown full-screen.
///
/// The view derives the four-state UI from `carriers`:
/// `nil` → sync hint, `[]` → empty guidance, one → barcode fast path,
/// 2+ → list (tap pushes the barcode via `presentedCarrier`).
@Reducer
public struct WatchCarrierFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Sendable {
        /// `nil` = not yet synced (or pre-carrier iPhone build);
        /// `[]` = synced and genuinely none.
        public var carriers: [Carrier]?

        /// Carrier currently pushed full-screen from the 2+ list.
        /// (The single-carrier fast path renders directly off
        /// `carriers`, without touching this.)
        public var presentedCarrier: Carrier?

        public init(
            carriers: [Carrier]? = nil,
            presentedCarrier: Carrier? = nil
        ) {
            self.carriers = carriers
            self.presentedCarrier = presentedCarrier
        }
    }

    public enum Action: Sendable {
        case task
        case carriersUpdated([Carrier]?)
        case carrierTapped(Carrier.ID)
        case barcodeDismissed
    }

    @Dependency(\.watchCarrierClient) var carrierClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { [carrierClient] send in
                    await send(.carriersUpdated(carrierClient.carriers()))
                    // Re-load whenever a fresh iPhone snapshot lands, same
                    // pattern as WatchRecordFeature.task.
                    for await _ in NotificationCenter.default.notifications(
                        named: WatchCacheStore.didUpdateNotification
                    ) {
                        await send(.carriersUpdated(carrierClient.carriers()))
                    }
                }

            case let .carriersUpdated(carriers):
                state.carriers = carriers
                if let presented = state.presentedCarrier {
                    // Re-resolve by id: pick up renames/barcode edits, and
                    // dismiss if the carrier was deleted on iPhone.
                    state.presentedCarrier = carriers?.first { $0.id == presented.id }
                }
                return .none

            case let .carrierTapped(id):
                state.presentedCarrier = state.carriers?.first { $0.id == id }
                return .none

            case .barcodeDismissed:
                state.presentedCarrier = nil
                return .none
            }
        }
    }
}
