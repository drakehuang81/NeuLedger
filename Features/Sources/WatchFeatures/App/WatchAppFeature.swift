import Foundation
import ComposableArchitecture

/// Root reducer for the Watch app: composes the quick-record flow
/// (page 1) and the carrier viewer (page 2) behind a vertical-page
/// TabView.
@Reducer
public struct WatchAppFeature: Sendable {

    public enum Tab: Equatable, Sendable {
        case record
        case carrier
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var tab: Tab
        public var record: WatchRecordFeature.State
        public var carrier: WatchCarrierFeature.State

        public init(
            tab: Tab = .record,
            record: WatchRecordFeature.State = .init(),
            carrier: WatchCarrierFeature.State = .init()
        ) {
            self.tab = tab
            self.record = record
            self.carrier = carrier
        }

        /// Vertical paging is allowed only while the record flow sits on
        /// its first (category) step, so keypad taps can't mis-swipe to
        /// the carrier page mid-entry.
        public var isPagingLocked: Bool { record.step != .category }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case record(WatchRecordFeature.Action)
        case carrier(WatchCarrierFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.record, action: \.record) {
            WatchRecordFeature()
        }
        Scope(state: \.carrier, action: \.carrier) {
            WatchCarrierFeature()
        }
    }
}
