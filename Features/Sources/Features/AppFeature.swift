//
//  AppFeature.swift
//  Features
//
//  Created by NeuLedger on 2026/2/28.
//

import ComposableArchitecture

@Reducer
struct AppFeature {
    
    // MARK: - Destination
    
    @CasePathable
    @dynamicMemberLookup
    enum Destination: Equatable {
        case onboarding(OnboardingFeature.State)
        case main
    }
    
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        var destination: Destination
    }
    
    // MARK: - Action
    
    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
    }
    
    // MARK: - Body
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onboarding(.delegate(.onboardingCompleted)):
                state.destination = .main
                return .none
                
            case .onboarding:
                return .none
            }
        }
        .ifLet(\.destination.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
    }
}
