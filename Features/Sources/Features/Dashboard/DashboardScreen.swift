import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// The main Dashboard screen — composition root for the B1 Warm Redesign.
///
/// Composes the per-section view stack (Hero balance, stats, transactions,
/// insight, accounts) on top of a warm gradient background. Other sections
/// are skeleton placeholders to be filled in by later slices.
public struct DashboardScreen: View {
    @Bindable var store: StoreOf<DashboardFeature>

    public init(store: StoreOf<DashboardFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Slice 3 placeholder (header)
                        Color.clear.frame(height: 56)

                        // Slice 4 placeholder (account chip filter)
                        Color.clear.frame(height: 44)

                        HeroBalanceCard(store: store)

                        // Slice 5 placeholder (stats pills)
                        GlassContainer(cornerRadius: 16, padding: 12) {
                            Text("…")
                                .frame(maxWidth: .infinity)
                        }
                        .skeleton(when: true)

                        // Slice 7 placeholder (insight card)
                        GlassContainer(cornerRadius: 22, padding: 16) {
                            Text("…")
                                .frame(maxWidth: .infinity)
                        }
                        .skeleton(when: true)

                        transactionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                .refreshable {
                    await store.send(.pulledToRefresh).finish()
                }
            }
            .navigationBarHidden(true)
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
        } destination: { store in
            switch store.case {
            case .analysis(let store):
                AnalysisView(store: store)
            }
        }
    }

    // MARK: - Transactions Section (preserved; replaced in Slice 6)

    @ViewBuilder
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard_recent_transactions")
                    .font(Font.Design.headline)

                Spacer()

                if store.hasTransactions {
                    Button(String(localized: "dashboard_see_all")) {
                        store.send(.seeAllTransactionsTapped)
                    }
                    .font(Font.Design.subheadline)
                }
            }

            if store.hasTransactions {
                VStack(spacing: 8) {
                    ForEach(store.recentTransactions) { transaction in
                        transactionButton(for: transaction)
                    }
                }
            } else if store.hasAccounts {
                EmptyStateView(
                    icon: "tray.fill",
                    title: String(localized: "dashboard_no_transactions_title"),
                    description: String(localized: "dashboard_no_transactions_desc"),
                    actionTitle: String(localized: "dashboard_add_first"),
                    action: { store.send(.addTransactionButtonTapped) }
                )
                .frame(maxWidth: .infinity)
            } else {
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

    // MARK: - Helpers

    private func transactionButton(for transaction: Domain.Transaction) -> some View {
        let category = transaction.categoryId.flatMap { store.categoryMap[$0] }
        let (icon, iconColor) = resolvedIconAndColor(for: transaction, category: category)
        return Button {
            store.send(.transactionTapped(transaction.id))
        } label: {
            TransactionRow(
                title: transaction.note ?? String(localized: "dashboard_transaction_default"),
                subtitle: transaction.type.displayName,
                amountText: transaction.signedAmountText,
                amountColor: iconColor,
                date: transaction.date.formatted(date: .abbreviated, time: .shortened),
                icon: icon,
                iconColor: iconColor
            )
        }
        .buttonStyle(.plain)
    }

    /// Resolves the SF Symbol name and tint color for a transaction row.
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


#Preview("Dashboard") {
    DashboardScreen(
        store: Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
    )
}
