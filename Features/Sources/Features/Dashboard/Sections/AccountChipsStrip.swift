import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// Horizontal strip of account-filter chips for the Dashboard B1 Warm Redesign.
///
/// Tapping a chip filters the Hero balance and recent transactions to the
/// selected account. The `All` chip resets the filter. Skeleton + retry
/// states are driven by `accountsPhase`.
struct AccountChipsStrip: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.accountsPhase {
        case .idle, .loading:
            placeholder.skeleton(when: true)
        case .loaded:
            content
        case let .failed(message):
            SectionFailureView(message: message) {
                store.send(.retrySection(.accounts))
            }
        }
    }

    private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    label: Text("dashboard_chip_all"),
                    isActive: store.selectedAccountID == nil,
                    color: .secondary,
                    balance: nil
                ) {
                    store.send(.accountChipSelected(nil))
                }
                ForEach(store.topAccounts) { account in
                    let isActive = store.selectedAccountID == account.id
                    chip(
                        label: Text(account.name),
                        isActive: isActive,
                        color: Color(hex: account.color),
                        balance: store.accountBalances[account.id]
                    ) {
                        if isActive {
                            store.send(.accountTapped(account.id))
                        } else {
                            store.send(.accountChipSelected(account.id))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(
        label: Text,
        isActive: Bool,
        color: Color,
        balance: Decimal?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                label
                    .font(.system(size: 13, weight: .medium))
                if let balance {
                    Text(balance.twdFormatted)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    Capsule().fill(Color.Design.brandAccent.opacity(0.22))
                } else {
                    Capsule().fill(Color.clear)
                        .glassEffect(Glass.clear.tint(Color.Design.surface), in: Capsule())
                }
            }
            .overlay {
                if isActive {
                    Capsule().strokeBorder(Color.Design.brandAccent.opacity(0.65), lineWidth: 1)
                }
            }
            .foregroundStyle(isActive ? Color.Design.brandAccent : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 32)
            }
        }
    }
}
