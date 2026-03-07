import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct TransactionsView: View {
    @Bindable var store: StoreOf<TransactionsFeature>

    public init(store: StoreOf<TransactionsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.transactions.isEmpty {
                    emptyState
                } else {
                    transactionsList
                }
            }
            .navigationTitle("記帳記錄")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                ),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜尋備註"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            .task {
                await store.send(.task).finish()
            }
            .confirmationDialog(
                "確定要刪除這筆交易嗎？",
                isPresented: Binding(
                    get: { store.deleteConfirmationId != nil },
                    set: { if !$0 { store.send(.deleteCancelled) } }
                ),
                titleVisibility: .visible
            ) {
                Button("刪除", role: .destructive) {
                    store.send(.deleteConfirmed)
                }
                Button("取消", role: .cancel) {
                    store.send(.deleteCancelled)
                }
            }
            .sheet(
                item: $store.scope(state: \.detail, action: \.detail)
            ) { detailStore in
                TransactionDetailView(store: detailStore)
            }
            .sheet(
                item: $store.scope(state: \.filter, action: \.filter)
            ) { filterStore in
                FilterView(store: filterStore)
            }
            .sheet(
                item: $store.scope(state: \.addTransaction, action: \.addTransaction)
            ) { addStore in
                AddTransactionView(store: addStore)
            }
        }
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button {
            store.send(.filterButtonTapped)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .symbolRenderingMode(.hierarchical)
                if store.hasActiveFilters {
                    Circle()
                        .fill(Color.Design.brandPrimary)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "list.bullet.rectangle",
            title: store.hasActiveFilters || !store.searchText.isEmpty
                ? "沒有符合的交易"
                : "尚無交易記錄",
            description: store.hasActiveFilters || !store.searchText.isEmpty
                ? "試試調整搜尋或篩選條件"
                : "從 Dashboard 或右上角按鈕新增第一筆記錄"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        ScrollView {
            if store.searchText.isEmpty {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groupedTransactions, id: \.date) { group in
                        Section {
                            ForEach(group.transactions) { transaction in
                                transactionRow(transaction)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                            }
                        } header: {
                            dateSectionHeader(group.date)
                        }
                    }
                }
                .padding(.bottom, 100)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.transactions) { transaction in
                        transactionRow(transaction)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }

    private func transactionRow(_ transaction: Domain.Transaction) -> some View {
        Button {
            store.send(.transactionTapped(transaction))
        } label: {
            TransactionRow(
                title: transaction.note ?? transaction.type.displayName,
                subtitle: transaction.type.displayName,
                amount: amountValue(for: transaction),
                date: transaction.date.formatted(date: .omitted, time: .shortened),
                icon: transaction.type.icon,
                iconColor: transaction.type.color
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.send(.deleteTransaction(transaction.id))
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    private func dateSectionHeader(_ date: Date) -> some View {
        HStack {
            Text(sectionTitle(for: date))
                .font(Font.Design.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Design.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.Design.background)
    }

    // MARK: - Helpers

    private var groupedTransactions: [(date: Date, transactions: [Domain.Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value) }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.year().month().day())
    }

    private func amountValue(for transaction: Domain.Transaction) -> Decimal {
        switch transaction.type {
        case .expense: return -transaction.amount
        case .income: return transaction.amount
        case .transfer: return transaction.amount
        }
    }
}

private extension TransactionType {
    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .transfer: return "轉帳"
        }
    }

    var icon: String {
        switch self {
        case .expense: return "arrow.up.circle.fill"
        case .income: return "arrow.down.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .expense: return Color.Design.expenseRed
        case .income: return Color.Design.incomeGreen
        case .transfer: return Color.Design.textSecondary
        }
    }
}
