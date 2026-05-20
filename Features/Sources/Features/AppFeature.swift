//
//  AppFeature.swift
//  Features
//
//  Created by NeuLedger on 2026/2/28.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    
    // MARK: - Destination
    
    @CasePathable
    @dynamicMemberLookup
    enum Destination: Equatable {
        case splash
        case onboarding(OnboardingFeature.State)
        case main(MainTabFeature.State)
    }
    
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        var destination: Destination
        
        init(destination: Destination = .splash) {
            self.destination = destination
        }
    }
    
    // MARK: - Action
    
    enum Action: Equatable {
        case onAppear
        case deepLinkReceived(URL)
        case onboarding(OnboardingFeature.Action)
        case main(MainTabFeature.Action)
    }
    
    @Dependency(\.userSettingsAdapter) var userSettingsAdapter
    
    // MARK: - Body
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.destination = userSettingsAdapter.bool(.hasCompletedOnboarding)
                    ? .main(MainTabFeature.State())
                    : .onboarding(OnboardingFeature.State())
                return .none
                
            case let .deepLinkReceived(url):
                guard url.scheme == "neuledger",
                      url.host == "carrier-management" else { return .none }
                guard case .main(var mainState) = state.destination else { return .none }
                mainState.selectedTab = .settings
                mainState.settings.path.append(.carrierManagement(CarrierManagementFeature.State()))
                state.destination = .main(mainState)
                return .none

            case .onboarding(.delegate(.onboardingCompleted)):
                state.destination = .main(MainTabFeature.State())
                return .none

            case .onboarding:
                return .none

            case .main:
                return .none
            }
        }
        .ifLet(\.destination.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        .ifLet(\.destination.main, action: \.main) {
            MainTabFeature()
        }
    }
}
