import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct TransactionDetailView: View {
    @Bindable var store: StoreOf<TransactionDetailFeature>

    public init(store: StoreOf<TransactionDetailFeature>) {
        self.store = store
    }

    private var transaction: Domain.Transaction { store.transaction }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    TxHero(transaction: transaction, categoryName: store.categoryName)
                    AIInsightCard(insight: store.insight, categoryName: store.categoryName)
                    DetailFieldsCard(
                        transaction: transaction,
                        account: store.account,
                        toAccount: store.toAccount
                    )
                    if store.detent == .large {
                        TagsRow(tags: transaction.tags)
                        ActivityCard(transaction: transaction)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 120) // leave room for action bar + undo
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .overlay(alignment: .bottom) {
                if store.pendingDelete {
                    UndoBanner(onUndo: { store.send(.undoTapped) })
                        .padding(.horizontal, 14)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: store.pendingDelete)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_close")) { store.send(.dismiss) }
                }
                ToolbarItem(placement: .principal) {
                    Text("transaction_detail_title")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }
            .task { await store.send(.task).finish() }
            .confirmationDialog(
                String(localized: "transaction_detail_delete_confirm_title"),
                isPresented: Binding(
                    get: { store.showDeleteConfirmation },
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
            } message: {
                Text("transaction_detail_delete_confirm_body")
            }
            .sheet(item: $store.scope(state: \.editTransaction, action: \.editTransaction)) { editStore in
                AddTransactionView(store: editStore)
            }
            .alert($store.scope(state: \.deleteFailureAlert, action: \.deleteFailureAlert))
        }
        .presentationDetents(
            [.medium, .large],
            selection: Binding(
                get: { store.detent == .large ? .large : .medium },
                set: { newValue in
                    store.send(.detentChanged(newValue == .large ? .large : .medium))
                }
            )
        )
        .presentationDragIndicator(.visible)
        .presentationBackground {
            WarmGradientBackground(variant: .top)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                store.send(.editTapped)
            } label: {
                Label(String(localized: "common_edit"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.Design.accentOrange)
            .accessibilityIdentifier("transaction_detail_edit_button")

            Button(role: .destructive) {
                store.send(.deleteTapped)
            } label: {
                Text("common_delete")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            .tint(Color.Design.expenseRed)
            .disabled(store.pendingDelete)
            .accessibilityIdentifier("transaction_detail_delete_button")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Previews

#if DEBUG
private enum PreviewFixtures {
    static let cashAccount = Account(
        id: UUID(uuidString: "AA000000-0000-0000-0000-000000000001")!,
        name: "Cash 現金", type: .cash, icon: "banknote", color: "#8E8E93"
    )
    static let bankAccount = Account(
        id: UUID(uuidString: "AA000000-0000-0000-0000-000000000002")!,
        name: "玉山銀行", type: .bank, icon: "building.columns.fill", color: "#0A84FF"
    )
    static let ewalletAccount = Account(
        id: UUID(uuidString: "AA000000-0000-0000-0000-000000000003")!,
        name: "悠遊卡", type: .eWallet, icon: "iphone.gen3", color: "#5E5CE6"
    )

    static let foodCategory = Domain.Category(
        id: UUID(uuidString: "BB000000-0000-0000-0000-000000000001")!,
        name: "餐飲", icon: "fork.knife", color: "#FF6B6B", type: .expense
    )
    static let salaryCategory = Domain.Category(
        id: UUID(uuidString: "BB000000-0000-0000-0000-000000000002")!,
        name: "薪資", icon: "banknote.fill", color: "#34C759", type: .income
    )

    static let expenseTx = Transaction(
        id: UUID(uuidString: "CC000000-0000-0000-0000-000000000001")!,
        amount: 165,
        date: Date(),
        note: "鬍鬚張午餐 · 滷肉飯 + 排骨酥湯",
        categoryId: foodCategory.id,
        accountId: ewalletAccount.id,
        type: .expense,
        tags: [
            Tag(id: UUID(), name: "lunch", color: "#FF9500"),
            Tag(id: UUID(), name: "weekday", color: "#FF9500")
        ],
        aiSuggested: false
    )

    static let incomeTx = Transaction(
        id: UUID(uuidString: "CC000000-0000-0000-0000-000000000002")!,
        amount: 50_000,
        date: Date(),
        note: "4月薪資 — Acme Studio 月薪 + 績效",
        categoryId: salaryCategory.id,
        accountId: bankAccount.id,
        type: .income,
        tags: [Tag(id: UUID(), name: "salary", color: "#34C759")],
        aiSuggested: true
    )

    static let transferTx = Transaction(
        id: UUID(uuidString: "CC000000-0000-0000-0000-000000000003")!,
        amount: 3000,
        date: Date(),
        note: "提領現金 · 週末用",
        categoryId: nil,
        accountId: bankAccount.id,
        toAccountId: cashAccount.id,
        type: .transfer,
        tags: [],
        aiSuggested: false
    )

    @MainActor
    static func store(for tx: Domain.Transaction) -> StoreOf<TransactionDetailFeature> {
        var state = TransactionDetailFeature.State(transaction: tx)
        state.detent = .large
        switch tx.type {
        case .expense:
            state.account = ewalletAccount
            state.accountName = ewalletAccount.name
            state.categoryName = foodCategory.name
            state.insight = TransactionInsight(kind: .expenseVsCategoryAvg(
                percentDelta: -9.3, avg: 182, monthlyCount: 12, monthTotal: 2_184
            ))
        case .income:
            state.account = bankAccount
            state.accountName = bankAccount.name
            state.categoryName = salaryCategory.name
            state.insight = TransactionInsight(kind: .incomeVsLast(
                percentDelta: 4.2, lastAmount: 48_000, monthlyCount: 1, netMonth: 47_830
            ))
        case .transfer:
            state.account = bankAccount
            state.accountName = bankAccount.name
            state.toAccount = cashAccount
            state.toAccountName = cashAccount.name
            state.insight = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5_500))
        }
        return Store(initialState: state) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.accountClient.fetchAll = { [bankAccount, cashAccount, ewalletAccount] }
            $0.categoryClient.fetchAll = { [foodCategory, salaryCategory] }
            $0.transactionClient.detailStats = { _ in
                TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
            }
        }
    }
}

#Preview("Expense · Large detent") {
    Color.Design.background
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TransactionDetailView(store: PreviewFixtures.store(for: PreviewFixtures.expenseTx))
        }
}

#Preview("Income · AI Filled") {
    Color.Design.background
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TransactionDetailView(store: PreviewFixtures.store(for: PreviewFixtures.incomeTx))
        }
}

#Preview("Transfer · From → To") {
    Color.Design.background
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TransactionDetailView(store: PreviewFixtures.store(for: PreviewFixtures.transferTx))
        }
}
#endif

