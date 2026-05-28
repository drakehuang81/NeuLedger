//
//  AppFeature.swift
//  Features
//
//  Created by NeuLedger on 2026/2/28.
//

import ComposableArchitecture
import Foundation
import Core
import Domain

// MARK: - AppFeature

@Reducer
struct AppFeature {

    // MARK: - State

    @ObservableState
    @CasePathable
    @dynamicMemberLookup
    enum State: Equatable {
        case splash
        case onboarding(OnboardingFeature.State)
        case main(MainTabFeature.State)

        init() { self = .splash }
    }

    // MARK: - Action

    enum Action: Equatable {
        case splashCompleted
        case deepLinkReceived(URL)
        case onboarding(OnboardingFeature.Action)
        case main(MainTabFeature.Action)
    }

    @Dependency(\.userSettingsAdapter) var userSettingsAdapter

    // MARK: - Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .splashCompleted:
                state = userSettingsAdapter.bool(.hasCompletedOnboarding)
                    ? .main(MainTabFeature.State())
                    : .onboarding(OnboardingFeature.State())
                return .none

            case let .deepLinkReceived(url):
                guard url.scheme == "neuledger",
                      url.host == "carrier-management" else { return .none }
                guard case .main(var mainState) = state else { return .none }
                mainState.selectedTab = .settings
                mainState.settings.path.append(.carrierManagement(CarrierManagementFeature.State()))
                state = .main(mainState)
                return .none

            case .onboarding(.delegate(.onboardingCompleted)):
                state = .main(MainTabFeature.State())
                return .none

            case .onboarding:
                return .none

            case .main(.settings(.delegate(.allDataWiped))):
                // Debug "erase everything" finished — drop the entire
                // MainTab state and bounce back to onboarding so the
                // user re-creates their first account against the now-
                // empty store.
                state = .onboarding(OnboardingFeature.State())
                return .none

            case .main:
                return .none
            }
        }
        .ifCaseLet(\.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        .ifCaseLet(\.main, action: \.main) {
            MainTabFeature()
        }
    }
}
