import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// The main Dashboard screen composing the feature store with the SwiftUI view layer.
///
/// This view connects to the `DashboardFeature` store using TCA View paradigms and
/// composes the design-system components: `refBalance`, `refActions`, `refInsight`,
/// `AccountCard`, `TransactionRow`, and `EmptyStateView`.
public struct DashboardScreen: View {
    @Bindable var store: StoreOf<DashboardFeature>

    public init(store: StoreOf<DashboardFeature>) {
        self.store = store
    }

    public var body: some View {
        // Task 3.7: Wrap in ScrollView with .refreshable
        ScrollView {
            VStack(spacing: 24) {
                balanceSection

                insightSection

                accountsSection

                transactionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
        // Task 3.7: Pull-to-refresh
        .refreshable {
            await store.send(.pulledToRefresh).finish()
        }
        .task {
            await store.send(.task).finish()
        }
        // Task 3.8: Sheet for AddTransaction
        .sheet(
            item: $store.scope(state: \.addTransaction, action: \.addTransaction)
        ) { addTransactionStore in
            AddTransactionView(store: addTransactionStore)
        }
    }

    // MARK: - Balance Section (Task 3.2)

    private var balanceSection: some View {
        VStack(spacing: 8) {
            Text("dashboard_total_balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(store.totalBalance.formatted(.currency(code: "TWD")))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassEffect(
            Glass.clear
                .interactive()
                .tint(Color.Design.background),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }


    // MARK: - Insight Section (Task 3.4)

    private var insightSection: some View {
        Group {
            if store.isLoadingInsight {
                // Skeleton loader using redacted
                insightCard(text: String(localized: "dashboard_ai_loading"))
                    .redacted(reason: .placeholder)
            } else if let insight = store.aiInsight {
                insightCard(text: insight)
            } else if store.hasTransactions {
                // Fallback: no insight available but has data
                insightCard(text: String(localized: "dashboard_ai_unavailable"))
                    .opacity(0.6)
            }
            // If no transactions at all, don't show the insight card
        }
    }

    private func insightCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.Design.brandSecondary)
                Text("dashboard_ai_insight")
                    .font(.headline)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(
            Glass.clear
                .interactive()
                .tint(Color.Design.background),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: - Accounts Section (Task 3.5)

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard_my_wallets")
                .font(.headline)

            if store.hasAccounts {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.topAccounts) { account in
                            Button {
                                store.send(.accountTapped(account.id))
                            } label: {
                                AccountCard(
                                    name: account.name,
                                    balance: 0, // Balance is aggregated at dashboard level
                                    type: account.type.displayLabel,
                                    icon: account.icon
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                // Global EmptyStateView if no accounts
                EmptyStateView(
                    icon: "wallet.pass.fill",
                    title: String(localized: "dashboard_no_wallets_title"),
                    description: String(localized: "dashboard_no_wallets_desc"),
                    actionTitle: String(localized: "dashboard_add_wallet"),
                    action: { store.send(.addTransactionButtonTapped) }
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Transactions Section (Task 3.6)

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard_recent_transactions")
                    .font(.headline)

                Spacer()

                if store.hasTransactions {
                    Button(String(localized: "dashboard_see_all")) {
                        store.send(.seeAllTransactionsTapped)
                    }
                    .font(.subheadline)
                }
            }

            if store.hasTransactions {
                VStack(spacing: 8) {
                    ForEach(store.recentTransactions) { transaction in
                        Button {
                            store.send(.transactionTapped(transaction.id))
                        } label: {
                            TransactionRow(
                                title: transaction.note ?? String(localized: "dashboard_transaction_default"),
                                subtitle: transaction.type.rawValue,
                                amount: transaction.type == .expense ? -transaction.amount : transaction.amount,
                                date: transaction.date.formatted(date: .abbreviated, time: .shortened),
                                icon: iconForTransactionType(transaction.type),
                                iconColor: colorForTransactionType(transaction.type)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if store.hasAccounts {
                // Has accounts but no transactions
                EmptyStateView(
                    icon: "tray.fill",
                    title: String(localized: "dashboard_no_transactions_title"),
                    description: String(localized: "dashboard_no_transactions_desc"),
                    actionTitle: String(localized: "dashboard_add_first"),
                    action: { store.send(.addTransactionButtonTapped) }
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func iconForTransactionType(_ type: TransactionType) -> String {
        switch type {
        case .expense: return "arrow.up.right"
        case .income: return "arrow.down.left"
        case .transfer: return "arrow.left.arrow.right"
        }
    }

    private func colorForTransactionType(_ type: TransactionType) -> Color {
        switch type {
        case .expense: return Color.Design.expenseRed
        case .income: return Color.Design.incomeGreen
        case .transfer: return Color.Design.accentBlue
        }
    }
}

#Preview("Dashboard with data") {
    DashboardScreen(
        store: Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
    )
}
