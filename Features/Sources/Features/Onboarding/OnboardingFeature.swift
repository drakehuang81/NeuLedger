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
        var isCreatingAccount: Bool = false
    }

    // MARK: - Action

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case startButtonTapped
        case nextButtonTapped
        case finishButtonTapped
        case skipButtonTapped
        case accountCreated
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case onboardingCompleted
        }
    }

    // MARK: - Dependencies

    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.accountClient) var accountClient

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
                let name = state.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
                let accountName = name.isEmpty ? Account.defaultCashName : name
                let accountType = state.accountType
                return .run { [userSettingsClient, accountClient] send in
                    let account = Account(
                        name: accountName,
                        type: accountType,
                        icon: accountType.defaultIcon,
                        color: accountType.defaultColor
                    )
                    try await accountClient.add(account)
                    userSettingsClient.setBool(true, .hasCompletedOnboarding)
                    await send(.accountCreated)
                }

            case .skipButtonTapped:
                return .run { [userSettingsClient, accountClient] send in
                    let defaultAccount = Account(
                        name: Account.defaultCashName,
                        type: .cash,
                        icon: "banknote",
                        color: Account.defaultCashColorHex
                    )
                    try await accountClient.add(defaultAccount)
                    userSettingsClient.setBool(true, .hasCompletedOnboarding)
                    await send(.accountCreated)
                }

            case .accountCreated:
                state.isCreatingAccount = true
                return .send(.delegate(.onboardingCompleted))

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Default Account Constants

private extension Account {
    /// Locale-independent name for the default cash account created during onboarding skip.
    /// This value is persisted to the database and must not vary by locale.
    static let defaultCashName = "Cash"

    /// Default hex color for the cash account type.
    static let defaultCashColorHex = "#2ECC71"
}

// MARK: - AccountType Defaults

private extension AccountType {
    var defaultIcon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .eWallet: "wallet.bifold"
        }
    }

    var defaultColor: String {
        switch self {
        case .cash: "#2ECC71"
        case .bank: "#3498DB"
        case .creditCard: "#E74C3C"
        case .eWallet: "#9B59B6"
        }
    }
}
