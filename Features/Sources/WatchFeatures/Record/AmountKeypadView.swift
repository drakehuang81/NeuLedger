import SwiftUI
import ComposableArchitecture
import Common
import Domain

/// Screen 2: a fixed 3×4 numeric keypad with a live amount preview.
/// Layout, top to bottom:
///   row 0: 7 8 9
///   row 1: 4 5 6
///   row 2: 1 2 3
///   row 3: ⌫ 0 ✓
struct AmountKeypadView: View {

    let store: StoreOf<WatchRecordFeature>

    private let rows: [[Key]] = [
        [.digit(7), .digit(8), .digit(9)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(1), .digit(2), .digit(3)],
        [.backspace, .digit(0), .confirm]
    ]

    var body: some View {
        VStack(spacing: 6) {
            amountDisplay
            VStack(spacing: 4) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var amountDisplay: some View {
        Text("NT$ \(formatted(store.draft?.amount ?? 0))")
            .font(Font.Design.size22SemiboldRounded)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 6)
    }

    private func keyButton(_ key: Key) -> some View {
        Button {
            switch key {
            case let .digit(d):
                store.send(.amountDigit(d))
            case .backspace:
                store.send(.amountBackspace)
            case .confirm:
                store.send(.amountConfirmed)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                key.label
                    .font(Font.Design.body.weight(.semibold))
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .disabled(key.isDisabled(amount: store.draft?.amount ?? 0))
    }

    private func formatted(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    private enum Key: Hashable {
        case digit(Int)
        case backspace
        case confirm

        @ViewBuilder var label: some View {
            switch self {
            case let .digit(d):  Text(String(d))
            case .backspace:     Image(systemName: "delete.left")
            case .confirm:       Image(systemName: "checkmark")
            }
        }

        func isDisabled(amount: Decimal) -> Bool {
            switch self {
            case .confirm:   return amount <= 0
            case .backspace: return amount <= 0
            case .digit:     return false
            }
        }
    }
}
