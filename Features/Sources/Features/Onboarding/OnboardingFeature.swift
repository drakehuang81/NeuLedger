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
    }

    @ObservableState
    struct State: Equatable {
        var currentStep: Step = .welcome
        var selectedTypes: Set<AccountType> = [.cash]
        var customAccounts: [CustomAccountDraft] = []
        @Presents var customAccountSheet: CustomAccountFormFeature.State?
        var isCreatingAccounts: Bool = false
    }

    enum Action: Equatable {
        case startButtonTapped
        case typeToggled(AccountType)
        case addCustomAccountTapped
        case customAccountSheet(PresentationAction<CustomAccountFormFeature.Action>)
        case customAccountDeleted(UUID)
        case nextButtonTapped
        case finishButtonTapped
        case skipButtonTapped
        case accountsCreated
        case doneAnimationFinished
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case onboardingCompleted
        }
    }

    @Dependency(\.userSettingsAdapter) var userSettingsAdapter
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case create }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startButtonTapped:
                state.currentStep = .accountSelection
                return .none

            case .nextButtonTapped:
                state.currentStep = .ready
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

            case let .customAccountSheet(.presented(.delegate(.submitted(draft)))):
                state.customAccounts.append(draft)
                state.customAccountSheet = nil
                return .none

            case .customAccountSheet(.presented(.delegate(.dismissed))):
                state.customAccountSheet = nil
                return .none

            case .customAccountSheet:
                return .none

            case let .customAccountDeleted(id):
                state.customAccounts.removeAll { $0.id == id }
                return .none

            case .finishButtonTapped, .skipButtonTapped:
                state.isCreatingAccounts = true
                let types = state.selectedTypes
                let customs = state.customAccounts
                return .run { [accountClient, userSettingsAdapter] send in
                    if types.isEmpty && customs.isEmpty {
                        // Use a stable UUID for the auto-seeded Cash account.
                        // After delete-and-reinstall, CloudKit may still hold a
                        // previously seeded copy; skip the insert if a row with
                        // that id already exists to avoid duplicates.
                        let existing = try await accountClient.fetchAll()
                        if !existing.contains(where: { $0.id == Account.defaultCashID }) {
                            let acc = Account(
                                id: Account.defaultCashID,
                                name: AccountType.cash.displayLabel,
                                type: .cash,
                                icon: AccountType.cash.defaultIcon,
                                color: AccountType.cash.defaultColor
                            )
                            try await accountClient.add(acc)
                        }
                    } else {
                        for type in types.sorted(by: { $0.rawValue < $1.rawValue }) {
                            let acc = Account(
                                name: type.displayLabel,
                                type: type,
                                icon: type.defaultIcon,
                                color: type.defaultColor
                            )
                            try await accountClient.add(acc)
                        }
                        for d in customs {
                            let acc = Account(
                                name: d.name,
                                type: d.type,
                                icon: d.type.defaultIcon,
                                color: d.color
                            )
                            try await accountClient.add(acc)
                        }
                    }
                    userSettingsAdapter.setBool(true, .hasCompletedOnboarding)
                    await send(.accountsCreated)
                }
                .cancellable(id: CancelID.create)

            case .accountsCreated:
                state.currentStep = .done
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(1600))
                    await send(.doneAnimationFinished)
                }

            case .doneAnimationFinished:
                return .send(.delegate(.onboardingCompleted))

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$customAccountSheet, action: \.customAccountSheet) {
            CustomAccountFormFeature()
        }
    }
}
