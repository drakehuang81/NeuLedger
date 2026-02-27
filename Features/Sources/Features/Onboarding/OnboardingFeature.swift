//
//  OnboardingFeature.swift
//  Features
//
//  Created by NeuLedger on 2026/2/28.
//

import ComposableArchitecture
import Domain
import Foundation

@Reducer
struct OnboardingFeature {

    // MARK: - Step

    enum Step: Equatable {
        case welcome
        case accountSetup
        case ready
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var currentStep: Step = .welcome
        var accountName: String = String(localized: "onboarding_setup_name_placeholder")
        var accountType: AccountType = .cash
    }

    // MARK: - Action

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case startButtonTapped
        case nextButtonTapped
        case finishButtonTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case onboardingCompleted
        }
    }

    // MARK: - Dependencies

    @Dependency(\.userSettingsClient) var userSettingsClient

    // MARK: - Body

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .startButtonTapped:
                state.currentStep = .accountSetup
                return .none

            case .nextButtonTapped:
                state.currentStep = .ready
                return .none

            case .finishButtonTapped:
                userSettingsClient.setBool(true, .hasCompletedOnboarding)
                return .send(.delegate(.onboardingCompleted))

            case .delegate:
                return .none
            }
        }
    }
}
