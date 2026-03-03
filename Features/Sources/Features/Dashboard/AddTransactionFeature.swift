import ComposableArchitecture
import Domain
import Foundation

/// A placeholder reducer for the Add Transaction flow.
///
/// This feature will be fully implemented in a separate change.
/// For now it provides the minimal State/Action/Reducer surface
/// required by `DashboardFeature` to wire up `@Presents` navigation.
@Reducer
public struct AddTransactionFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case dismiss
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .dismiss:
                return .none
            }
        }
    }
}
