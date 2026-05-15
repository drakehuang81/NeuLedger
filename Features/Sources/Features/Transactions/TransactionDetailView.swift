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
            .scrollIndicators(.hidden)
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
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}
