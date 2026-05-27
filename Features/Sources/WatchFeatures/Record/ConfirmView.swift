import SwiftUI
import ComposableArchitecture
import Common
import Domain
#if canImport(WatchKit)
import WatchKit
#endif

/// Screen 3: shows the assembled draft and lets the user confirm or
/// cancel. Confirm fires a `.success` haptic (optimistic — we don't
/// wait for the iPhone to ack).
struct ConfirmView: View {

    let store: StoreOf<WatchRecordFeature>

    var body: some View {
        VStack(spacing: 10) {
            summary
            actions
        }
        .padding(.horizontal, 6)
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
            Text("NT$ \(formatted(store.draft?.amount ?? 0))")
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

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                store.send(.confirmTapped)
                #if canImport(WatchKit)
                WKInterfaceDevice.current().play(.success)
                #endif
            } label: {
                Text("確認")
                    .font(Font.Design.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Design.accentOrange)

            Button {
                store.send(.cancelTapped)
            } label: {
                Text("取消")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
    }

    private func formatted(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }
}
