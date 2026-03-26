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
        NavigationStack {
            ZStack {
                Color.Design.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        balanceSection

                        quickActionsSection

                        accountsSection

                        transactionsSection

                        insightSection

                        Color.clear.frame(height: 1000)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .refreshable {
                await store.send(.pulledToRefresh).finish()
            }
            .navigationTitle(String(localized: "dashboard_title"))
            .navigationBarTitleDisplayMode(.large)
            .task {
                await store.send(.task).finish()
            }
            .sheet(
                item: $store.scope(state: \.addTransaction, action: \.addTransaction)
            ) { addTransactionStore in
                AddTransactionView(store: addTransactionStore)
            }
            .sheet(
                item: $store.scope(state: \.detail, action: \.detail)
            ) { detailStore in
                TransactionDetailView(store: detailStore)
            }
            .navigationDestination(
                item: $store.scope(state: \.analysis, action: \.analysis)
            ) { analysisStore in
                AnalysisView(store: analysisStore)
            }
        }
    }

    // MARK: - Balance Section (Task 3.2)
    @ViewBuilder
    private var balanceSection: some View {
        GlassContainer(
            cornerRadius: 20,
            padding: EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0)
        ) {
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
        }
    }


    // MARK: - Quick Actions Section (Step 4A)

    @ViewBuilder
    private var quickActionsSection: some View {
        GlassContainer(
            cornerRadius: 20,
            padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        ) {
            HStack(spacing: 0) {
                quickActionButton(
                    title: String(localized: "common_expense"),
                    icon: "minus.circle.fill",
                    color: Color.Design.expenseRed
                ) { store.send(.quickActionExpenseTapped) }

                Divider().frame(height: 40)

                quickActionButton(
                    title: String(localized: "common_income"),
                    icon: "plus.circle.fill",
                    color: Color.Design.incomeGreen
                ) { store.send(.quickActionIncomeTapped) }

                Divider().frame(height: 40)

                quickActionButton(
                    title: String(localized: "common_transfer"),
                    icon: "arrow.left.arrow.right",
                    color: Color.Design.brandSecondary
                ) { store.send(.quickActionTransferTapped) }
            }
            .frame(maxWidth: .infinity)
        }
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
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Text(title)
                    .font(Font.Design.caption.weight(.medium))
                    .foregroundStyle(Color.Design.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insight Section (Task 3.4)

    @ViewBuilder
    private var insightSection: some View {
        if store.isLoadingInsight {
            InsightCard(
                title: String(localized: "dashboard_ai_insight"),
                body: String(localized: "dashboard_ai_loading")
            )
            .redacted(reason: .placeholder)
        } else if let insight = store.aiInsight {
            InsightCard(
                title: String(localized: "dashboard_ai_insight"),
                body: insight
            )
        } else if store.hasTransactions {
            InsightCard(
                title: String(localized: "dashboard_ai_insight"),
                body: String(localized: "dashboard_ai_unavailable")
            )
            .opacity(0.6)
        }
    }

    // MARK: - Accounts Section (Task 3.5)

    @ViewBuilder
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

    @ViewBuilder
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
        let isExpense = transaction.type == .expense
        let signedAmount = isExpense ? -transaction.amount : transaction.amount
        return Button {
            store.send(.transactionTapped(transaction.id))
        } label: {
            TransactionRow(
                title: transaction.note ?? String(localized: "dashboard_transaction_default"),
                subtitle: transaction.type.displayName,
                amountText: signedAmount.twdFormatted,
                amountColor: iconColor,
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
