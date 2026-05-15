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
            ZStack {
                WarmGradientBackground(variant: .top)

                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.transactions.isEmpty {
                    emptyState
                } else {
                    transactionsList
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle(String(localized: "transactions_title"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                ),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String(localized: "transactions_search_prompt")
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
                String(localized: "transactions_delete_confirm"),
                isPresented: Binding(
                    get: { store.deleteConfirmationId != nil },
                    set: { if !$0 { store.send(.deleteCancelled) } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "common_delete"), role: .destructive) {
                    store.send(.deleteConfirmed)
                }
                Button(String(localized: "common_cancel"), role: .cancel) {
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
        .accessibilityLabel(String(localized: "a11y_transactions_filter"))
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if store.hasActiveFilters || !store.searchText.isEmpty {
            noMatchState
        } else {
            EmptyStateView(
                icon: "list.bullet.rectangle",
                title: String(localized: "transactions_no_records_title"),
                description: String(localized: "transactions_no_records_desc")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// "查無結果" 狀態 + 設計的 AI prompt cards（點擊塞回 searchText）
    private var noMatchState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "transactions_no_match_title"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Design.textPrimary)
                    Text(String(localized: "transactions_no_match_desc"))
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.Design.aiPurple)
                    Text(String(localized: "transactions_try_examples"))
                        .font(.system(size: 11, weight: .medium))
                        .monospaced()
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 8) {
                    ForEach(Self.searchExamples, id: \.query) { example in
                        Button {
                            store.send(.searchTextChanged(example.query))
                        } label: {
                            promptCard(icon: example.icon, query: example.query, hint: example.hint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func promptCard(icon: String, query: String, hint: String) -> some View {
        GlassContainer(cornerRadius: 14, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14)) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.Design.aiPurple.opacity(0.14))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.Design.aiPurple)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(query)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.Design.textPrimary)
                    Text(hint)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(Color.Design.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
    }

    private struct SearchExample {
        let icon: String
        let query: String
        let hint: String
    }

    /// 字面關鍵字示例，點擊後直接代入 searchText 由 reducer 的 debounce search 接手。
    /// 不需要 AI 端點，所以全部都是真實會 match 的 substring。
    private static let searchExamples: [SearchExample] = [
        .init(icon: "cup.and.saucer", query: "星巴克", hint: "Starbucks · coffee"),
        .init(icon: "car",            query: "Uber",   hint: "Rides"),
        .init(icon: "tv",             query: "Netflix", hint: "Subscription"),
        .init(icon: "bag",            query: "7-11",   hint: "Convenience store"),
        .init(icon: "arrow.triangle.2.circlepath", query: "訂閱", hint: "Recurring charges"),
        .init(icon: "person.2",       query: "公帳",   hint: "Shared / splittable"),
    ]

    // MARK: - Transactions List

    private var transactionsList: some View {
        ScrollView {
            if store.searchText.isEmpty {
                LazyVStack  {
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
        let amountColor = transaction.type.uiColor
        return Button {
            store.send(.transactionTapped(transaction))
        } label: {
            TransactionRow(
                title: transaction.note ?? transaction.type.displayName,
                subtitle: transaction.type.displayName,
                amountText: transaction.signedAmountText,
                amountColor: amountColor,
                date: transaction.date.formatted(date: .omitted, time: .shortened),
                icon: transaction.type.systemImageName,
                iconColor: amountColor
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.send(.deleteTransaction(transaction.id))
            } label: {
                Label(String(localized: "common_delete"), systemImage: "trash")
            }
        }
    }

    private func dateSectionHeader(_ date: Date) -> some View {
        HStack(spacing: 6) {
            Text(sectionTitle(for: date))
                .font(.system(size: 11, weight: .medium))
                .monospaced()
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Helpers

    private var groupedTransactions: [(date: Date, transactions: [Domain.Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "transactions_today") }
        if calendar.isDateInYesterday(date) { return String(localized: "transactions_yesterday") }
        return date.formatted(.dateTime.year().month().day())
    }

}
