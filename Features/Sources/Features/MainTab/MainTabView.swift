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
                    CustomAccessoryView(store: store)
                }
        } else {
            if store.isAccessoryVisible {
                tabViewBase
                    .tabViewBottomAccessory {
                        CustomAccessoryView(store: store)
                    }
            } else {
                tabViewBase
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
}

private struct CustomAccessoryView: View {
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
            } else if let answer = store.aiAnswer {
                resultPillContent(answer)
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
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(
            isAI ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1),
            lineWidth: 1
        ))
        .padding(.vertical, 8)
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

    // MARK: - ③ Result

    private func resultPillContent(_ answer: String) -> some View {
        Button {
            store.send(.resultPillTapped)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                Text(answer)
                    .font(Font.Design.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 3) {
                    Text(String(localized: "accessory_expand"))
                        .font(Font.Design.caption)
                    Image(systemName: "chevron.up")
                        .font(Font.Design.caption)
                }
                .foregroundStyle(Color.Design.textTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - ④ Expanded AI input

    @ViewBuilder
    private var expandedAIInputContent: some View {
        VStack(spacing: 4) {
            // AI answer card — shown when aiAnswer is available
            if let answer = store.aiAnswer {
                GlassContainer(cornerRadius: 16, padding: 0) {
                    ScrollView {
                        Text(answer)
                            .font(Font.Design.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 160)
                }
                .padding(.horizontal, 12)
            }

            HStack(spacing: 8) {
                // Mode badge — tap to toggle between record / ask
                Button {
                    store.send(.inputPurposeSwitched(
                        store.inputPurpose == .record ? .ask : .record
                    ))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: store.inputPurpose == .record ? "pencil" : "bubble.left")
                            .font(.caption)
                        Text(store.inputPurpose == .record
                            ? String(localized: "accessory_mode_record_short")
                            : String(localized: "accessory_mode_ask_short"))
                            .font(Font.Design.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2), in: Capsule())
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .fixedSize()

                TextField(
                    store.inputPurpose == .record
                        ? String(localized: "ai_record_placeholder")
                        : String(localized: "ai_ask_placeholder"),
                    text: Binding(
                        get: { store.aiInputText },
                        set: { store.send(.aiInputTextChanged($0)) }
                    )
                )
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit {
                    if store.inputPurpose == .record {
                        store.send(.aiInputSubmitted)
                    } else {
                        store.send(.askSubmitted)
                    }
                }

                if store.isAIInputLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                } else {
                    Button {
                        if store.inputPurpose == .record {
                            store.send(.aiInputSubmitted)
                        } else {
                            store.send(.askSubmitted)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(store.aiInputText.isEmpty)

                    Button {
                        store.send(.aiInputDismissed)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(Glass.clear.interactive().tint(Color.Design.surface), in: Capsule())

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
