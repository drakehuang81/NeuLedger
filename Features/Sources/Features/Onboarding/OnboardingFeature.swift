//
//  OnboardingFeature.swift
//  Features

import ComposableArchitecture
import Domain
import Foundation

@Reducer
struct OnboardingFeature {

    enum Step: Equatable {
        case welcome
        case accountSelection
        case ready
        case done
            
        mutating func next() {
            switch self {
            case .welcome: self = .accountSelection
            case .accountSelection: self = .ready
            case .ready: self = .done
            case .done: break
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var currentStep: Step = .welcome
        var selectedTypes: Set<AccountType> = [.cash]
        var customAccounts: [CustomAccountDraft] = []
        @Presents var customAccountSheet: CustomAccountFormFeature.State?
    }

    enum Action: Equatable {
        case nextButtonTapped
        case finishOnboarding

        case typeToggled(AccountType)

        case addCustomAccountTapped
        case customAccountSheet(PresentationAction<CustomAccountFormFeature.Action>)
        case customAccountDeleted(UUID)

        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case onboardingCompleted
        }
    }

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.platformClient) var platformClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case create }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextButtonTapped:
                state.currentStep.next()
                if state.currentStep == .done {
                    return .send(.finishOnboarding)
                }
                return .none

            case let .typeToggled(type):
                if state.selectedTypes.contains(type) {
                    state.selectedTypes.remove(type)
                } else {
                    state.selectedTypes.insert(type)
                }
                return .none

            case .addCustomAccountTapped:
                state.customAccountSheet = CustomAccountFormFeature.State()
                return .none
            case .customAccountSheet(.presented(.delegate(let event))):
                if case let .submitted(draft) = event {
                    state.customAccounts.append(draft)
                }
                state.customAccountSheet = nil
                return .none

            case let .customAccountDeleted(id):
                state.customAccounts.removeAll { $0.id == id }
                return .none

            case .finishOnboarding:
                let types = state.selectedTypes.sorted(by: { $0.rawValue < $1.rawValue })
                let customs = state.customAccounts
                return .run { send in
                    let accounts = types.map(\.new) + customs.map(\.new)
                    try await ledger.setupAccounts(accounts)
                    platformClient.markOnboardingComplete()
                    try await clock.sleep(for: .milliseconds(1600))
                    await send(.delegate(.onboardingCompleted))
                }.cancellable(id: CancelID.create)

            default:
                return .none
            }
        }
        .ifLet(\.$customAccountSheet, action: \.customAccountSheet) {
            CustomAccountFormFeature()
        }
    }
}
