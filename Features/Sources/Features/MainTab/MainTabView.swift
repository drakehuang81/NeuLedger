import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab("Ledger", systemImage: "chart.pie.fill", value: MainTabFeature.Tab.dashboard) {
                DashboardScreen(store: store.scope(state: \.dashboard, action: \.dashboard))
            }

            Tab("Search", systemImage: "list.bullet.rectangle.fill", value: MainTabFeature.Tab.transactions) {
                TransactionsView(store: store.scope(state: \.transactions, action: \.transactions))
            }

            Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis) {
                AnalysisView(store: store.scope(state: \.analysis, action: \.analysis))
            }

            Tab("Settings", systemImage: "gearshape.fill", value: MainTabFeature.Tab.settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
        }
        .tabViewStyle(.sidebarAdaptable)
#if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            await store.send(.task).finish()
        }
        .animation(.spring(), value: store.isAIInputExpanded)
        .tabViewBottomAccessory {
            if store.isAIInputExpanded {
                // Expanded: natural language input bar
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        TextField("描述這筆交易…", text: Binding(
                            get: { store.aiInputText },
                            set: { store.send(.aiInputTextChanged($0)) }
                        ))
                        .textFieldStyle(.plain)
                        .submitLabel(.send)
                        .onSubmit { store.send(.aiInputSubmitted) }

                        if store.isAIInputLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        } else {
                            Button {
                                store.send(.aiInputSubmitted)
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
                    .background(.regularMaterial, in: Capsule())

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
            } else {
                // Compact: AI wand + original + button
                HStack {
                    Spacer()
                    // AI wand button — disabled when Foundation Models is unavailable
                    if store.aiUnavailable {
                        Button {} label: {
                            Image(systemName: "wand.and.sparkles")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.textTertiary)
                        }
                        .disabled(true)
                    } else {
                        Button {
                            withAnimation(.spring()) {
                                _ = store.send(.aiInputButtonTapped)
                            }
                        } label: {
                            Image(systemName: "wand.and.sparkles")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }

                    // Original + button — behaviour unchanged
                    Button {
                        store.send(.contextActionTapped)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
#endif
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
    )
}
