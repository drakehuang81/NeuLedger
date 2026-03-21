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

                quickActionsSection

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

            Text(store.totalBalance.twdFormatted)
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


    // MARK: - Quick Actions Section (Step 4A)

    private var quickActionsSection: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                quickActionButton(
                    title: String(localized: "common_expense"),
                    icon: "minus.circle.fill",
                    color: Color.Design.expenseRed
                ) { store.send(.quickActionExpenseTapped) }

                quickActionButton(
                    title: String(localized: "common_income"),
                    icon: "plus.circle.fill",
                    color: Color.Design.incomeGreen
                ) { store.send(.quickActionIncomeTapped) }

                quickActionButton(
                    title: String(localized: "common_transfer"),
                    icon: "arrow.left.arrow.right",
                    color: Color.Design.textSecondary
                ) { store.send(.quickActionTransferTapped) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.horizontal)
    }

    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                Text(title)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .glassEffect(Glass.clear.interactive().tint(Color.Design.background), in: Capsule())
        .buttonStyle(.plain)
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
                                    balance: store.accountBalances[account.id] ?? 0,
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
                        transactionButton(for: transaction)
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

    private func transactionButton(for transaction: Domain.Transaction) -> some View {
        let category = transaction.categoryId.flatMap { store.categoryMap[$0] }
        let (icon, iconColor) = resolvedIconAndColor(for: transaction, category: category)
        let subtitle: String = {
            switch transaction.type {
            case .expense: return String(localized: "common_expense")
            case .income: return String(localized: "common_income")
            case .transfer: return String(localized: "common_transfer")
            }
        }()
        return Button {
            store.send(.transactionTapped(transaction.id))
        } label: {
            TransactionRow(
                title: transaction.note ?? String(localized: "dashboard_transaction_default"),
                subtitle: subtitle,
                amount: transaction.type == .expense ? -transaction.amount : transaction.amount,
                date: transaction.date.formatted(date: .abbreviated, time: .shortened),
                icon: icon,
                iconColor: iconColor
            )
        }
        .buttonStyle(.plain)
    }

    /// Resolves the SF Symbol name and tint color for a transaction row.
    ///
    /// Priority: transfer type → category icon/color → type-based fallback.
    private func resolvedIconAndColor(
        for transaction: Domain.Transaction,
        category: Domain.Category?
    ) -> (icon: String, color: Color) {
        switch transaction.type {
        case .transfer:
            return ("arrow.left.arrow.right", Color.Design.textSecondary)
        case .expense, .income:
            if let cat = category {
                return (cat.icon, Color(hex: cat.color))
            }
            return transaction.type == .expense
                ? ("minus.circle.fill", Color.Design.expenseRed)
                : ("plus.circle.fill", Color.Design.incomeGreen)
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
