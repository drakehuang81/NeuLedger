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

        /// ID of the carrier pushed full-screen from the 2+ list.
        /// The presented carrier itself is derived from `carriers` — renames /
        /// barcode edits flow through automatically, and deletion on iPhone
        /// dismisses the screen (derivation returns nil).
        public var presentedCarrierID: Carrier.ID?

        /// Derived: single source of truth stays in `carriers`.
        public var presentedCarrier: Carrier? {
            presentedCarrierID.flatMap { id in carriers?.first { $0.id == id } }
        }

        public init(
            carriers: [Carrier]? = nil,
            presentedCarrierID: Carrier.ID? = nil
        ) {
            self.carriers = carriers
            self.presentedCarrierID = presentedCarrierID
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
                return .none

            case let .carrierTapped(id):
                state.presentedCarrierID = id
                return .none

            case .barcodeDismissed:
                state.presentedCarrierID = nil
                return .none
            }
        }
    }
}
