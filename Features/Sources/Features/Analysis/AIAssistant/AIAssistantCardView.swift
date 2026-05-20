import Common
import ComposableArchitecture
import SwiftUI

struct AIAssistantCardView: View {
    let store: StoreOf<AIAssistantFeature>

    var body: some View {
        Group {
            if store.isExpanded {
                expandedCard
            } else {
                collapsedCard
            }
        }
        .task {
            await store.send(.task).finish()
        }
    }

    // MARK: - Collapsed

    private var collapsedCard: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                _ = store.send(.expandTapped)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                Text(String(localized: "ai_assistant_prompt"))
                    .font(Font.Design.body)
                    .foregroundStyle(Color.Design.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Expanded

    private var expandedCard: some View {
        GlassContainer(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                    Text(String(localized: "ai_assistant_title"))
                        .font(Font.Design.headline)
                        .foregroundStyle(Color.Design.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            _ = store.send(.expandTapped)
                        }
                    } label: {
                        Label(String(localized: "ai_assistant_collapse"), systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                conversationArea

                Divider()

                inputRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Conversation

    @ViewBuilder
    private var conversationArea: some View {
        if store.messages.isEmpty {
            Text(String(localized: "ai_assistant_prompt"))
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if store.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.leading, 12)
                                Spacer()
                            }
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 220)
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation {
                        if let last = store.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: store.isLoading) { _, loading in
                    if loading {
                        withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                    }
                }
            }
        }

        if let error = store.errorMessage {
            HStack(alignment: .top, spacing: 4) {
                Text(error)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.expenseRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    store.send(.dismissError)
                } label: {
                    Image(systemName: "xmark")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                String(localized: "ai_assistant_placeholder"),
                text: Binding(
                    get: { store.inputText },
                    set: { store.send(.inputChanged($0)) }
                ),
                axis: .vertical
            )
            .lineLimit(1...3)
            .textFieldStyle(.plain)
            .font(Font.Design.body)
            .submitLabel(.send)
            .onSubmit { store.send(.submitTapped) }

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            } else {
                Button {
                    store.send(.submitTapped)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(store.inputText.isEmpty)
            }
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: AIAssistantFeature.Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(Font.Design.body)
                .foregroundStyle(message.role == .user ? Color.white : Color.Design.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.role == .user
                        ? Color.accentColor
                        : Color.Design.surface,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

#Preview("Collapsed") {
    AIAssistantCardView(
        store: Store(initialState: AIAssistantFeature.State()) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { true }
        }
    )
    .padding()
}

#Preview("Expanded with messages") {
    var state = AIAssistantFeature.State()
    state.isExpanded = true
    state.messages = [
        .init(role: .user, text: "上個月哪個分類花最多？"),
        .init(role: .assistant, text: "餐飲類，共花了 NT$4,200，佔總支出 34%。"),
    ]
    return AIAssistantCardView(
        store: Store(initialState: state) {
            AIAssistantFeature()
        } withDependencies: {
            $0.aiUseCase.isAvailable = { true }
        }
    )
    .padding()
}
