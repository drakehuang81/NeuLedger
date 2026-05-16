import Common
import ComposableArchitecture
import SwiftUI

struct AccessoryView: View {
    let store: StoreOf<MainTabFeature>
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        switch placement {
        case .inline:
            inlineView
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
    // MARK: - Inline placement (tab bar minimized)

    private var inlineView: some View {
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
    }

    // MARK: - ① Compact normal

    private var compactPillContent: some View {
        let isAI = store.accessoryMode == .ai
        let canSwitchMode = !store.aiUnavailable
        return HStack(spacing: 0) {
            Button {
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
                .padding(.leading, 20)
                .padding(.trailing, canSwitchMode ? 10 : 20)
                .padding(.vertical, 12)
                .foregroundStyle(isAI ? Color.accentColor : Color.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if canSwitchMode {
                Menu {
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
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.Design.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "a11y_accessory_switch_mode"))
            }
        }
    }

    // MARK: - ② Processing

    private var processingPillContent: some View {
        AccessoryShimmerPill(text: String(localized: "accessory_ai_processing"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    // MARK: - ④ Expanded AI input (voice-only)

    @ViewBuilder
    private var expandedAIInputContent: some View {
        let hasTranscript = !store.aiInputText.isEmpty
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

            HStack(alignment: .center, spacing: 4) {
                transcriptDisplay(hasTranscript: hasTranscript)

                if store.isAIInputLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 44, height: 44)
                } else {
                    micButton
                    if hasTranscript && !store.isRecording {
                        sendButton
                    }
                    closeButton
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

    // MARK: - Voice input pieces

    @ViewBuilder
    private func transcriptDisplay(hasTranscript: Bool) -> some View {
        Text(hasTranscript ? store.aiInputText : String(localized: "ai_voice_hint"))
            .font(Font.Design.body)
            .foregroundStyle(hasTranscript ? Color.Design.textPrimary : Color.Design.textTertiary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.15), value: store.aiInputText)
    }

    private var micButton: some View {
        Button {
            store.send(.recordingTapped)
        } label: {
            Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.isRecording ? Color.Design.expenseRed : Color.accentColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(store.isRecording
                            ? String(localized: "a11y_voice_stop")
                            : String(localized: "a11y_voice_start"))
    }

    private var sendButton: some View {
        Button {
            store.send(.aiInputSubmitted)
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "a11y_ai_submit"))
    }

    private var closeButton: some View {
        Button {
            store.send(.aiInputDismissed)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.Design.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "a11y_ai_close"))
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
            .clipShape(Capsule())
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

// MARK: - Previews

@MainActor
private func previewStore(_ mutate: (inout MainTabFeature.State) -> Void) -> StoreOf<MainTabFeature> {
    var state = MainTabFeature.State()
    mutate(&state)
    return Store(initialState: state) {
        MainTabFeature()
    }
}

#Preview("Compact — Add") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .add
        state.aiUnavailable = false
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Compact — AI") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .ai
        state.aiUnavailable = false
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Processing") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .ai
        state.aiUnavailable = false
        state.isAIInputLoading = true
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Expanded — Empty") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .ai
        state.aiUnavailable = false
        state.isAIInputExpanded = true
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Expanded — With Text") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .ai
        state.aiUnavailable = false
        state.isAIInputExpanded = true
        state.aiInputText = "今天午餐 120 元，全家便利商店"
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Expanded — Recording") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .ai
        state.aiUnavailable = false
        state.isAIInputExpanded = true
        state.isRecording = true
        state.aiInputText = "今天午餐"
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Expanded — Error") {
    AccessoryView(store: previewStore { state in
        state.accessoryMode = .ai
        state.aiUnavailable = false
        state.isAIInputExpanded = true
        state.aiInputText = "亂七八糟"
        state.aiInputError = String(localized: "ai_extraction_error")
    })
    .padding()
    .background(Color(.systemGroupedBackground))
}
