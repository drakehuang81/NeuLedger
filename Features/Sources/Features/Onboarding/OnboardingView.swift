//  OnboardingView.swift
//  Features

import SwiftUI
import ComposableArchitecture
import Domain
import Common

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            backgroundForCurrentStep
            currentStepView
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.currentStep)
        }
    }

    @ViewBuilder
    private var backgroundForCurrentStep: some View {
        switch store.currentStep {
        case .welcome:          WarmGradientBackground(variant: .top)
        case .accountSelection: WarmGradientBackground(variant: .bottomRight)
        case .ready, .done:     WarmGradientBackground(variant: .center)
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch store.currentStep {
        case .welcome:          welcomeStep
        case .accountSelection: placeholderStep("Account Selection (Task 11)")
        case .ready:            placeholderStep("Ready (Task 12)")
        case .done:             placeholderStep("Done (Task 12)")
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Preview glass card (decorative)
            previewCard
                .padding(.horizontal, 24)
                .modifier(RevealOnAppear(delay: 0.12))

            // Title block
            titleBlock
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .modifier(RevealOnAppear(delay: 0.46))

            Spacer()

            // CTA + dots
            VStack(spacing: 16) {
                PrimaryButton("onboarding_welcome_button", systemImage: "arrow.forward") {
                    store.send(.startButtonTapped)
                }
                HStack {
                    OnboardingPageDots(active: 0)
                    Spacer()
                    Button { store.send(.skipButtonTapped) } label: {
                        Text("common_skip")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .modifier(RevealOnAppear(delay: 0.64))
        }
    }

    private var previewCard: some View {
        GlassContainer(cornerRadius: 28, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("onboarding_welcome_card_eyebrow")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(Decimal(0).twdFormatted)
                    .font(.system(size: 44, weight: .bold).monospacedDigit())
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    chip("onboarding_welcome_chip_starting", color: Color.Design.brandPrimary)
                    chip("onboarding_welcome_chip_on_device", color: .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ key: LocalizedStringKey, color: Color) -> some View {
        Text(key)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            (
                Text("onboarding_welcome_title_lead")
                    .font(.system(size: 44, weight: .bold))
                + Text(" ")
                + Text("onboarding_welcome_title_emphasis")
                    .font(.system(size: 44, weight: .semibold).italic())
                    .foregroundColor(Color.Design.brandPrimary)
            )
            .lineSpacing(-2)

            Text("onboarding_welcome_subtitle")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Placeholder (filled by later tasks)

    private func placeholderStep(_ label: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(label)
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Skip") { store.send(.skipButtonTapped) }
            Spacer()
        }
    }
}

// MARK: - Reveal modifier

private struct RevealOnAppear: ViewModifier {
    let delay: Double
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 24)
            .animation(.easeOut(duration: 0.55).delay(delay), value: visible)
            .task { visible = true }
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentStep: .welcome)) {
            OnboardingFeature()
        }
    )
}
