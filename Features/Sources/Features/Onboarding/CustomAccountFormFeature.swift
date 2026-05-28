//  CustomAccountFormFeature.swift
//  Features
//
//  Sub-reducer for the "add custom account" sheet shown from the
//  account selection step of OnboardingFeature.

import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct CustomAccountFormFeature {

    @ObservableState
    public struct State: Equatable {
        public var name: String
        public var type: AccountType
        public var color: String

        public init(name: String = "", type: AccountType = .bank, color: String = {
            assert(CustomAccountFormFeature.colorPalette.isEmpty == false)
            return CustomAccountFormFeature.colorPalette[0]
        }()) {
            self.name = name
            self.type = type
            self.color = color
        }

        public var canSubmit: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelTapped
        case submitTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismissed
            case submitted(CustomAccountDraft)
        }
    }

    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .cancelTapped:
                return .send(.delegate(.dismissed))
            case .submitTapped:
                guard state.canSubmit else { return .none }
                let draft = CustomAccountDraft(
                    id: uuid(),
                    name: state.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: state.type,
                    color: state.color
                )
                return .send(.delegate(.submitted(draft)))
            default:
                return .none
            }
        }
    }
}

public extension CustomAccountFormFeature {
    /// Color palette offered in the sheet (matches B-Warm design tokens).
    static let colorPalette: [String] = [
        "#FF9500", // accent
        "#0A84FF", // bank blue
        "#5E5CE6", // e-wallet purple
        "#FF2D55", // credit red
        "#34C759", // income green
        "#8E8E93", // cash gray
    ]
}
