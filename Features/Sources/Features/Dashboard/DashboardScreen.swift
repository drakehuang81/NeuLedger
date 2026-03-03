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
                // Task 3.2: Header and balance
                balanceSection

                // Task 3.3: Quick actions
                actionsSection

                // Task 3.4: AI Insight card
                insightSection

                // Task 3.5: My Wallets (Accounts) horizontal scroll
                accountsSection

                // Task 3.6: Recent Transactions vertical list
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
            NavigationStack {
                // Placeholder view for AddTransaction
                Text("Add Transaction")
                    .navigationTitle("記帳")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                addTransactionStore.send(.dismiss)
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Balance Section (Task 3.2)

    private var balanceSection: some View {
        VStack(spacing: 8) {
            Text("總資產")
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Actions Section (Task 3.3)

    private var actionsSection: some View {
        HStack(spacing: 16) {
            // Quick action: Add transaction
            Button {
                store.send(.addTransactionButtonTapped)
            } label: {
                Label("記帳", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Insight Section (Task 3.4)

    private var insightSection: some View {
        Group {
            if store.isLoadingInsight {
                // Skeleton loader using redacted
                insightCard(text: "正在為您分析最近的消費模式，請稍候...")
                    .redacted(reason: .placeholder)
            } else if let insight = store.aiInsight {
                insightCard(text: insight)
            } else if store.hasTransactions {
                // Fallback: no insight available but has data
                insightCard(text: "暫時無法取得 AI 洞察，請稍後重試。")
                    .opacity(0.6)
            }
            // If no transactions at all, don't show the insight card
        }
    }

    private func insightCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI 洞察")
                    .font(.headline)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Accounts Section (Task 3.5)

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的錢包")
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
                    title: "尚無錢包",
                    description: "新增您的第一個錢包或帳戶來開始管理財務。",
                    actionTitle: "新增錢包",
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
                Text("最近交易")
                    .font(.headline)

                Spacer()

                if store.hasTransactions {
                    Button("查看全部") {
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
                                title: transaction.note ?? "交易",
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
                    title: "尚無交易",
                    description: "記錄您的第一筆花費吧！",
                    actionTitle: "記一筆",
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
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
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
