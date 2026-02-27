//
//  OnboardingView.swift
//  Features
//
//  Created by NeuLedger on 2026/2/28.
//

import SwiftUI
import ComposableArchitecture
import Domain
import Common

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            Color.Design.background
                .ignoresSafeArea()

            switch store.currentStep {
            case .welcome:
                welcomeStep
            case .accountSetup:
                accountSetupStep
            case .ready:
                readyStep
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // App Icon Placeholder
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.Design.brandPrimary, Color.Design.brandSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                // Title Group
                VStack(spacing: 12) {
                    Text("onboarding_welcome_title")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.Design.textPrimary)

                    Text("onboarding_welcome_subtitle")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.Design.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Start Button
            PrimaryButton("onboarding_welcome_button", systemImage: "arrow.forward") {
                store.send(.startButtonTapped)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 60)
    }

    // MARK: - Step 2: Account Setup

    private var accountSetupStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("onboarding_setup_title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.Design.textPrimary)

                    Text("onboarding_setup_subtitle")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.Design.textSecondary)
                }

                // Form
                VStack(alignment: .leading, spacing: 24) {
                    // Account Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("onboarding_setup_name_label")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.Design.textSecondary)

                        TextField(
                            "onboarding_setup_name_placeholder",
                            text: $store.accountName
                        )
                        .font(.system(size: 17))
                        .padding(16)
                        .background(Color.Design.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Account Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("onboarding_setup_type_label")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.Design.textSecondary)

                        Picker("", selection: $store.accountType) {
                            ForEach(AccountType.allCases, id: \.self) { type in
                                Text(type.displayLabel)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            Spacer()

            // Next Button
            PrimaryButton("onboarding_setup_button") {
                store.send(.nextButtonTapped)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 60)
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Success Icon
                Circle()
                    .fill(Color.Design.incomeGreen)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                    }

                // Title Group
                VStack(spacing: 12) {
                    Text("onboarding_ready_title")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.Design.textPrimary)

                    Text("onboarding_ready_subtitle")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.Design.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Preview Card
                VStack(spacing: 12) {
                    Text("onboarding_ready_balance_label")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.Design.textSecondary)

                    Text("$0")
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.Design.textPrimary)
                }
                .padding(20)
                .frame(width: 200)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            Spacer()

            // Finish Button
            PrimaryButton("onboarding_ready_button") {
                store.send(.finishButtonTapped)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 60)
    }

}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView(
        store: Store(
            initialState: OnboardingFeature.State(currentStep: .welcome)
        ) {
            OnboardingFeature()
        }
    )
}
