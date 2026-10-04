import SwiftUI
import ComposableArchitecture
import Common
import Domain
#if canImport(WatchKit)
import WatchKit
#endif

/// Screen 3: shows the assembled draft and lets the user confirm or
/// cancel.
///
/// Haptics are deliberately *not* optimistic. The tap plays a neutral
/// `.click` to acknowledge the press; a send that never left the Watch
/// plays `.failure` and keeps the draft on screen for a retry. Only a
/// send that actually left plays `.success`, and it rides on
/// `sendSuccessPulse` rather than on the tap — claiming `.success` on tap
/// is the bug this screen used to have, because the tap cannot know
/// whether the send will succeed.
struct ConfirmView: View {

    let store: StoreOf<WatchRecordFeature>

    var body: some View {
        VStack(spacing: 10) {
            summary
            actions
        }
        .padding(.horizontal, 6)
        .onChange(of: store.sendFailure) { _, failure in
            guard failure != nil else { return }
            #if canImport(WatchKit)
            WKInterfaceDevice.current().play(.failure)
            #endif
        }
        .onChange(of: store.sendSuccessPulse) { old, new in
            // Leaving this screen is what reports success, so the haptic
            // has to ride on the state change rather than on the tap —
            // playing it in the button would make it a lie the moment a
            // send fails. Guarding on an increase keeps a state reset
            // (pulse back to 0) from firing a phantom success.
            guard new > old else { return }
            #if canImport(WatchKit)
            WKInterfaceDevice.current().play(.success)
            #endif
        }
    }

    private var summary: some View {
        VStack(spacing: 6) {
            if let category = store.activeCategory {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .foregroundStyle(Color.Design.fromHex(category.color))
                    Text(category.name)
                        .font(Font.Design.body.weight(.semibold))
                }
            }
            Text("NT$ \((store.draft?.amount ?? 0).twdDigits)")
                .font(Font.Design.size22SemiboldRounded)
                .monospacedDigit()
            if let account = store.activeAccount {
                Text(account.name)
                    .font(Font.Design.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var failureBanner: some View {
        if let failure = store.sendFailure {
            Text(failure.localizedMessage)
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.accentRed)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            failureBanner

            Button {
                store.send(.confirmTapped)
                #if canImport(WatchKit)
                // Neutral acknowledgement only — success is reported by
                // leaving this screen, failure by the banner above.
                WKInterfaceDevice.current().play(.click)
                #endif
            } label: {
                Text(String(
                    localized: store.sendFailure == nil
                        ? "watch_confirm_button"
                        : "watch_retry_button"
                ))
                    .font(Font.Design.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Design.accentOrange)
            .disabled(store.isSending)

            Button {
                store.send(.cancelTapped)
            } label: {
                Text(String(localized: "watch_cancel_button"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
    }
}
