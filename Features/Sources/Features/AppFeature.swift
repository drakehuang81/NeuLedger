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
        case route(RouteLinkDestination)
        case task
    }

    @Dependency(\.deeplinkClient) var deeplinkClient
    @Dependency(\.notificationAdapter) var notificationAdapter

    private enum CancelID { case recurringSubscription }

    // MARK: - Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    for await id in notificationAdapter.pendingConfirmations() {
                        let destination = (try? await deeplinkClient.resolveRecurringConfirmation(id)) ?? .none
                        await send(.route(destination))
                    }
                }
                .cancellable(id: CancelID.recurringSubscription)

            case .splashCompleted:
                return .run { send in
                    let canSkipOnboarding = try await deeplinkClient.canSkipOnboarding()
                    await send(.route(canSkipOnboarding ? .main : .onboarding))
                }
            case let .deepLinkReceived(url):
                return .run { send in
                    let destination = try await deeplinkClient.parseLinkTo(url)
                    await send(.route(destination))
                }
            case .onboarding(.delegate(.onboardingCompleted)):
                return .send(.route(.main))
            case .main(.settings(.delegate(.allDataWiped))):
                // Debug "erase everything" finished — drop the entire
                // MainTab state and bounce back to onboarding so the
                // user re-creates their first account against the now-
                // empty store.
                return .send(.route(.onboarding))
            case .route(let action):
                switch action {
                case .carrierManagement:
                    guard case .main(var mainState) = state else { return .none }
                    mainState.selectedTab = .settings
                    mainState.settings.path.append(.carrierManagement(CarrierManagementFeature.State()))
                    state = .main(mainState)
                    return .none
                case .main:
                    state = .main(MainTabFeature.State())
                    return .none
                case .onboarding:
                    state = .onboarding(OnboardingFeature.State())
                    return .none
                case let .recurringConfirmation(template):
                    guard case .main(var mainState) = state else { return .none }
                    mainState.selectedTab = .dashboard
                    mainState.dashboard.addTransaction = AddTransactionFeature.State(
                        mode: .addRecurringConfirmation(template)
                    )
                    state = .main(mainState)
                    return .none
                default:
                    return .none
                }
            default:
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
