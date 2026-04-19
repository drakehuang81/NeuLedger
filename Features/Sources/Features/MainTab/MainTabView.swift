import Common
import ComposableArchitecture
import SwiftUI

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.1, *) {
            tabViewBase
                .tabViewBottomAccessory(isEnabled: store.isAccessoryVisible) {
                    AccessoryView(store: store)
                }
        } else {
            tabViewBase
                .tabViewBottomAccessory {
                    if store.isAccessoryVisible {
                        AccessoryView(store: store)
                    }
                }
        }
    }


    private var tabViewBase: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab("Ledger", systemImage: "chart.pie.fill", value: MainTabFeature.Tab.dashboard) {
                DashboardScreen(store: store.scope(state: \.dashboard, action: \.dashboard))
            }
            Tab("Settings", systemImage: "gearshape.fill", value: MainTabFeature.Tab.settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
            Tab(value: MainTabFeature.Tab.transactions, role: .search) {
                TransactionsView(store: store.scope(state: \.transactions, action: \.transactions))
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: - Nested accessory view (internal only)

    private struct AccessoryView: View {
        let store: StoreOf<MainTabFeature>
        @Environment(\.tabViewBottomAccessoryPlacement) private var placement

        var body: some View {
            switch placement {
            case .inline:
                Button {
                    if store.accessoryMode == .ai {
                        withAnimation(.spring()) {
                            _ = store.send(.aiInputButtonTapped)
                        }
                    } else {
                        store.send(.contextActionTapped)
                    }
                } label: {
                    Image(systemName: store.accessoryMode == .ai ? "wand.and.sparkles" : "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(store.accessoryMode == .ai ? Color.accentColor : Color.primary)
                }
                .contextMenu(if: !store.aiUnavailable) {
                    Button {
                        store.send(.accessoryModeSwitched(.add))
                    } label: {
                        Label(String(localized: "accessory_add"), systemImage: "plus")
                    }
                    Button {
                        store.send(.accessoryModeSwitched(.ai))
                    } label: {
                        Label(String(localized: "accessory_ai_record"), systemImage: "wand.and.sparkles")
                    }
                }
            case .expanded, _:
                if store.isAIInputExpanded {
                    expandedAIInputContent
                } else if store.isAIInputLoading {
                    processingPillContent
                } else {
                    compactPillContent
                }
            }
        }

        // MARK: - ① Compact normal

        private var compactPillContent: some View {
            let isAI = store.accessoryMode == .ai
            return Button {
                if isAI {
                    withAnimation(.spring()) {
                        _ = store.send(.aiInputButtonTapped)
                    }
                } else {
                    store.send(.contextActionTapped)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAI ? "wand.and.sparkles" : "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                    Text(isAI
                         ? String(localized: "accessory_ai_record")
                         : String(localized: "accessory_add"))
                        .font(Font.Design.callout)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .foregroundStyle(isAI ? Color.accentColor : Color.primary)
            }
            .contextMenu(if: !store.aiUnavailable) {
                Button {
                    store.send(.accessoryModeSwitched(.add))
                } label: {
                    Label(String(localized: "accessory_add"), systemImage: "plus")
                }
                Button {
                    store.send(.accessoryModeSwitched(.ai))
                } label: {
                    Label(String(localized: "accessory_ai_record"), systemImage: "wand.and.sparkles")
                }
            }
        }

        // MARK: - ② Processing

        private var processingPillContent: some View {
            AccessoryShimmerPill(text: String(localized: "accessory_ai_processing"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }

        // MARK: - ④ Expanded AI input

        @ViewBuilder
        private var expandedAIInputContent: some View {
            VStack(spacing: 4) {
                // Recording indicator — shown while mic is active
                if store.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.Design.expenseRed)
                            .frame(width: 7, height: 7)
                        Text(String(localized: "speech_recording_label"))
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                    .padding(.horizontal, 16)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    TextField(
                        String(localized: "ai_record_placeholder"),
                        text: Binding(
                            get: { store.aiInputText },
                            set: { store.send(.aiInputTextChanged($0)) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit {
                        store.send(.aiInputSubmitted)
                    }

                    if store.isAIInputLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    } else {
                        // Mic button — idle: mic icon; recording: stop icon in red
                        Button {
                            store.send(.recordingTapped)
                        } label: {
                            Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(
                                    store.isRecording ? Color.Design.expenseRed : Color.primary
                                )
                        }
                        .accessibilityLabel(store.isRecording ? String(localized: "a11y_voice_stop") : String(localized: "a11y_voice_start"))

                        // Send button — disabled when text is empty or recording is active
                        Button {
                            store.send(.aiInputSubmitted)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .disabled(store.aiInputText.isEmpty || store.isRecording)
                        .accessibilityLabel(String(localized: "a11y_ai_submit"))

                        Button {
                            store.send(.aiInputDismissed)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.textTertiary)
                        }
                        .accessibilityLabel(String(localized: "a11y_ai_close"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(
                    Glass.clear.interactive().tint(Color.Design.surface),
                    in: RoundedRectangle(cornerRadius: 18)
                )

                if let error = store.aiInputError {
                    Text(error)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Conditional contextMenu helper

private extension View {
    @ViewBuilder
    func contextMenu(if condition: Bool, @ViewBuilder menuItems: () -> some View) -> some View {
        if condition {
            self.contextMenu(menuItems: menuItems)
        } else {
            self
        }
    }
}

// MARK: - AccessoryShimmerPill

private struct AccessoryShimmerPill: View {
    let text: String
    @State private var shimmerPhase: CGFloat = -1.0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.sparkles")
                .symbolRenderingMode(.hierarchical)
            Text(text)
                .font(Font.Design.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: shimmerPhase * geo.size.width)
            }
            .clipped()
        )
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: Capsule())
        .disabled(true)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.4
            }
        }
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
    )
}
