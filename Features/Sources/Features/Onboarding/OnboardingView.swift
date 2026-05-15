import SwiftUI
import ComposableArchitecture
import Domain
import Common

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            backgroundForCurrentStep
                .id(backgroundIdentity)
                .transition(.opacity)
            VStack(spacing: 0) {
                currentStepView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(store.currentStep)
                    .transition(stepTransition)
                bottomBar
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.currentStep)
        .sheet(item: $store.scope(state: \.customAccountSheet, action: \.customAccountSheet)) { sheetStore in
            CustomAccountFormView(store: sheetStore)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Persistent Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 16) {
            if store.currentStep != .done {
                primaryActionButton
                    .id(store.currentStep)
                    .transition(.opacity)
                HStack {
                    PageDots(active: dotIndex)
                        .animation(.easeInOut(duration: 0.35), value: dotIndex)
                    Spacer()
                    Button { store.send(.skipButtonTapped) } label: {
                        Text("common_skip")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(showsSkip ? 1 : 0)
                    .disabled(!showsSkip)
                }
                .frame(height: 28)
            }
        }
        .frame(height: bottomBarHeight, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private var bottomBarHeight: CGFloat { 96 }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch store.currentStep {
        case .welcome:
            PrimaryButton("onboarding_welcome_button", systemImage: "arrow.forward") {
                store.send(.startButtonTapped)
            }
        case .accountSelection:
            PrimaryButton(continueButtonKey) { store.send(.nextButtonTapped) }
                .opacity(continueDisabled ? 0.5 : 1)
                .disabled(continueDisabled)
        case .ready:
            PrimaryButton("onboarding_ready_button") { store.send(.finishButtonTapped) }
                .disabled(store.isCreatingAccounts)
        case .done:
            EmptyView()
        }
    }

    private var dotIndex: Int {
        switch store.currentStep {
        case .welcome:          0
        case .accountSelection: 1
        case .ready, .done:     2
        }
    }

    private var showsSkip: Bool {
        switch store.currentStep {
        case .welcome, .accountSelection: true
        case .ready, .done:               false
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

    private var backgroundIdentity: Int {
        switch store.currentStep {
        case .welcome:          0
        case .accountSelection: 1
        case .ready, .done:     2
        }
    }

    private var stepTransition: AnyTransition {
        switch store.currentStep {
        case .done:
            return .opacity.combined(with: .scale(scale: 0.96))
        default:
            return .opacity
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch store.currentStep {
        case .welcome:          welcomeStep
        case .accountSelection: accountSelectionStep
        case .ready:            readyStep
        case .done:             doneStep
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            previewCard
                .padding(.horizontal, 24)
                .modifier(RevealOnAppear(delay: 0.12))

            titleBlock
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .modifier(RevealOnAppear(delay: 0.46))

            Spacer()
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

    // MARK: - Account Selection

    private var accountSelectionStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboarding_step_indicator_2")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Text("onboarding_selection_title")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 12)
            Text("onboarding_selection_subtitle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            typeCard(for: type)
                        }
                    }

                    if !store.customAccounts.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(store.customAccounts) { draft in
                                customAccountRow(draft)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Button { store.send(.addCustomAccountTapped) } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("onboarding_selection_add_custom")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(
                                    Color.secondary.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 1, dash: [6])
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private var totalSelectedCount: Int {
        store.selectedTypes.count + store.customAccounts.count
    }

    private var continueDisabled: Bool { totalSelectedCount == 0 }

    private var continueButtonKey: LocalizedStringKey {
        let format = String(localized: "onboarding_selection_continue_format")
        return LocalizedStringKey(String(format: format, totalSelectedCount))
    }

    @ViewBuilder
    private func typeCard(for type: AccountType) -> some View {
        let isSelected = store.selectedTypes.contains(type)
        Button { store.send(.typeToggled(type)) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(hex: type.defaultColor).opacity(0.12))
                        Image(systemName: type.defaultIcon)
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: type.defaultColor))
                    }
                    .frame(width: 36, height: 36)
                    Spacer()
                    selectionIndicator(isSelected: isSelected)
                }
                Spacer()
                Text(eyebrow(for: type))
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                Text(type.displayLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .frame(minHeight: 140, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.Design.brandPrimary : Color.clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.Design.brandPrimary : Color.clear)
            Circle()
                .strokeBorder(
                    isSelected ? Color.clear : Color.secondary.opacity(0.5),
                    lineWidth: 1.5
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
    }

    private func eyebrow(for type: AccountType) -> String {
        switch type {
        case .cash:       "CASH"
        case .bank:       "BANK"
        case .creditCard: "CREDIT"
        case .eWallet:    "WALLET"
        }
    }

    @ViewBuilder
    private func customAccountRow(_ draft: CustomAccountDraft) -> some View {
        HStack {
            Image(systemName: draft.type.defaultIcon)
                .foregroundStyle(Color(hex: draft.color))
            Text(draft.name)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Button { store.send(.customAccountDeleted(draft.id)) } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.Design.brandPrimary)
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.Design.brandPrimary.opacity(0.35), radius: 28, x: 0, y: 10)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 12) {
                    Text("onboarding_ready_title")
                        .font(.system(size: 36, weight: .bold))
                    Text("onboarding_ready_subtitle")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                GlassContainer(cornerRadius: 22, padding: 20) {
                    VStack(spacing: 8) {
                        Text("onboarding_ready_total_label")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(Decimal(0).twdFormatted)
                            .font(.system(size: 24, weight: .bold).monospacedDigit())
                        Text(accountCountText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .frame(width: 220)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var accountCountText: LocalizedStringKey {
        let count = max(totalSelectedCount, 1)
        let format = String(localized: "onboarding_ready_account_count_format")
        return LocalizedStringKey(String(format: format, count))
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.Design.brandPrimary)
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.Design.brandPrimary.opacity(0.55), radius: 30, x: 0, y: 12)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .modifier(RevealOnAppear(delay: 0.05))
            VStack(spacing: 8) {
                Text("onboarding_done_title")
                    .font(.system(size: 36, weight: .bold))
                Text("onboarding_done_subtitle")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .modifier(RevealOnAppear(delay: 0.20))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
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

#Preview("Account Selection") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentStep: .accountSelection)) {
            OnboardingFeature()
        }
    )
}

#Preview("Ready") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentStep: .ready, selectedTypes: [.cash, .bank])) {
            OnboardingFeature()
        }
    )
}

#Preview("Done") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentStep: .done)) {
            OnboardingFeature()
        }
    )
}
