import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// Horizontal strip of account-filter chips for the Dashboard B1 Warm Redesign.
///
/// Tap a chip to filter the Hero balance and recent transactions. The strip
/// is **purely a filter control** — navigation into the per-account analysis
/// screen lives in the "餘額總覽" section header above HeroBalanceCard.
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
            HStack(spacing: 10) {
                allChip
                ForEach(store.topAccounts) { account in
                    accountChip(account)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - All chip

    private var allChip: some View {
        let isActive = store.selectedAccountID == nil
        return Button {
            store.send(.accountChipSelected(nil))
        } label: {
            HStack(spacing: 8) {
                iconBadge(systemName: "square.grid.2x2.fill", tint: .secondary)
                Text("dashboard_chip_all")
                    .font(Font.Design.size14Semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modifier(ChipBackground(isActive: isActive))
            .foregroundStyle(isActive ? Color.Design.brandAccent : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account chip

    private func accountChip(_ account: Account) -> some View {
        let isActive = store.selectedAccountID == account.id
        let tint = Color.Design.fromHex(account.color)

        return Button {
            store.send(.accountChipSelected(account.id))
        } label: {
            HStack(spacing: 8) {
                iconBadge(systemName: account.icon, tint: tint)
                Text(account.name)
                    .font(Font.Design.size14Semibold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.Design.brandAccent : Color.primary)
        .modifier(ChipBackground(isActive: isActive))
        .animation(.snappy(duration: 0.2), value: isActive)
    }

    // MARK: - Building blocks

    private func iconBadge(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(Font.Design.size12Semibold)
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
            .background(tint.opacity(0.18), in: Circle())
    }

    private var placeholder: some View {
        HStack(spacing: 10) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: 96, height: 40)
            }
        }
    }
}

// MARK: - Chip background

private struct ChipBackground: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    Capsule().fill(Color.Design.brandAccent.opacity(0.18))
                } else {
                    Capsule().fill(Color.clear)
                        .glassEffect(Glass.clear.tint(Color.Design.surface), in: Capsule())
                }
            }
            .overlay {
                if isActive {
                    Capsule().strokeBorder(Color.Design.brandAccent.opacity(0.55), lineWidth: 1)
                }
            }
    }
}
