import Common
import ComposableArchitecture
import SwiftUI

struct AccessoryView: View {
    let store: StoreOf<AccessoryBarFeature>
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
                .font(.title)
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
                        .font(.title)
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
                        .font(.title)
                        .font(Font.Design.size11Semibold)
                        .foregroundStyle(Color.Design.textSecondary)
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
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                transcriptDisplay(hasTranscript: hasTranscript)
                    .padding(.leading, 4)
                if store.isAIInputLoading {
                    ProgressView()
                        .controlSize(.small)
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
            if let error = store.aiInputError {
                Text(error)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.expenseRed)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Voice input pieces

    @ViewBuilder
    private func transcriptDisplay(hasTranscript: Bool) -> some View {
        if hasTranscript && !store.isRecording {
            MarqueeText(
                text: store.aiInputText,
                font: Font.Design.body,
                color: Color.Design.textPrimary,
                velocity: 30,
                gap: 32
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(hasTranscript ? store.aiInputText : String(localized: "ai_voice_hint"))
                .font(Font.Design.body)
                .foregroundStyle(hasTranscript ? Color.Design.textPrimary : Color.Design.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.15), value: store.aiInputText)
        }
    }

    private var micButton: some View {
        Button {
            store.send(.recordingTapped)
        } label: {
            Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.isRecording ? Color.Design.expenseRed : Color.accentColor)
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
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "a11y_ai_submit"))
    }

    private var closeButton: some View {
        Button {
            store.send(.aiInputDismissed)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.Design.textTertiary)
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

// MARK: - MarqueeText

private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let velocity: Double  // points per second
    let gap: CGFloat      // gap between repeated copies

    @State private var textSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let needsScroll = true// textSize.width > geo.size.width && geo.size.width > 0
            ZStack(alignment: .leading) {
                if needsScroll {
                    TimelineView(.animation) { context in
                        let total = textSize.width + gap
                        let cycle = max(total / velocity, 0.5)
                        let phase = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: cycle) / cycle
                        let offset = -CGFloat(phase) * total

                        HStack(spacing: gap) {
                            label
                            label
                        }
                        .offset(x: offset)
                    }
                } else {
                    label
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
        }
        .frame(height: textSize.height > 0 ? textSize.height : 22)
        .background(
            label
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: MarqueeTextSizeKey.self, value: proxy.size)
                    }
                )
        )
        .onPreferenceChange(MarqueeTextSizeKey.self) { textSize = $0 }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .fixedSize()
    }
}

private struct MarqueeTextSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
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
private func previewStore(_ mutate: (inout AccessoryBarFeature.State) -> Void) -> StoreOf<AccessoryBarFeature> {
    var state = AccessoryBarFeature.State()
    mutate(&state)
    return Store(initialState: state) {
        AccessoryBarFeature()
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
