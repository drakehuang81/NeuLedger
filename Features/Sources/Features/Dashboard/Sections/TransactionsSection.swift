import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// Dashboard "recent transactions" section.
///
/// Renders up to 6 rows from `store.filteredRecent`. Each row can expand to
/// reveal its tags via `FlowLayout` of `TagPill`s; the active expanded row is
/// driven by `state.expandedTransactionID`.
struct TransactionsSection: View {
    let store: StoreOf<DashboardFeature>

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("HH:mm")
        return f
    }()

    var body: some View {
        GlassContainer(cornerRadius: 22, padding: 4) {
            switch store.transactionsPhase {
            case .idle, .loading:
                content.skeleton(when: true)
            case .loaded:
                content
            case let .failed(message):
                SectionFailureView(message: message) {
                    store.send(.retrySection(.transactions))
                }
                .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let rows = Array(store.filteredRecent.prefix(6))
        if rows.isEmpty {
            EmptyStateView(
                icon: "tray",
                title: String(localized: "transactions_empty_title"),
                description: String(localized: "transactions_empty_body")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(rows) { tx in
                    let category = tx.categoryId.flatMap { store.categoryMap[$0] }
                    let iconColor = Color.Design.fromHex(category?.color ?? "#999999")
                    TransactionRow(
                        title: tx.note?.isEmpty == false
                            ? (tx.note ?? "")
                            : (category?.localizedName ?? "—"),
                        subtitle: category?.localizedName ?? tx.type.displayName,
                        amountText: tx.signedAmountText,
                        amountColor: tx.type == .income
                            ? Color.Design.incomeGreen
                            : Color.Design.expenseRed,
                        date: Self.timeFormatter.string(from: tx.date),
                        icon: category?.icon ?? "questionmark.circle",
                        iconColor: iconColor,
                        isExpanded: store.expandedTransactionID == tx.id,
                        tags: tx.tags.map(\.name),
                        onTap: {
                            store.send(
                                .transactionRowToggled(tx.id),
                                animation: .spring(response: 0.4, dampingFraction: 0.85)
                            )
                        },
                        onOpenDetail: {
                            store.send(.transactionTapped(tx.id))
                        }
                    )
                    if tx.id != rows.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}
