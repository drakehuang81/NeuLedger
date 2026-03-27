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
                VStack(spacing: 24) {
                    // MARK: 金額 header
                    amountHeader

                    // MARK: 詳細資訊
                    detailsCard

                    Spacer(minLength: 0)

                    // MARK: 刪除按鈕
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
//            .navigationTitle(transaction.type.displayName)
//            .navigationBarTitleDisplayMode(.inline)
            .task { await store.send(.task).finish() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_close")) {
                        store.send(.dismiss)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_edit")) {
                        store.send(.editTapped)
                    }
                }
            }
            .confirmationDialog(
                String(localized: "transactions_delete_confirm"),
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
            }
            .sheet(
                item: $store.scope(state: \.editTransaction, action: \.editTransaction)
            ) { editStore in
                AddTransactionView(store: editStore)
            }
        }
    }

    // MARK: - Amount Header

    private var amountHeader: some View {
        VStack(spacing: 8) {
            // Type badge
            Text(transaction.type.displayName)
                .font(Font.Design.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(transaction.type.uiColor.opacity(0.15))
                .foregroundStyle(transaction.type.uiColor)
                .clipShape(Capsule())

            // Amount
            Text(transaction.amount.twdFormatted)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(transaction.type.amountDisplayColor)
                .monospacedDigit()
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            // 日期
            detailRow(icon: "calendar", label: String(localized: "transaction_detail_date"), value: transaction.date.formatted(date: .long, time: .shortened))
            Divider().padding(.leading, 56)

            // 帳戶
            if let accountName = store.accountName {
                detailRow(icon: "wallet.bifold", label: String(localized: "transaction_detail_account"), value: accountName)
                Divider().padding(.leading, 56)
            }

            // 轉帳目標帳戶
            if transaction.type == .transfer, let toName = store.toAccountName {
                detailRow(icon: "arrow.right", label: String(localized: "transaction_detail_to_account"), value: toName)
                Divider().padding(.leading, 56)
            }

            // 分類
            if transaction.type != .transfer, let categoryName = store.categoryName {
                detailRow(icon: "square.grid.2x2", label: String(localized: "transaction_detail_category"), value: categoryName)
                Divider().padding(.leading, 56)
            }

            // 備註
            if let note = transaction.note, !note.isEmpty {
                detailRow(icon: "text.bubble", label: String(localized: "transaction_detail_note"), value: note)
                Divider().padding(.leading, 56)
            }

            // 標籤
            if !transaction.tags.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "tag")
                        .frame(width: 24)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text("transaction_detail_tags")
                        .foregroundStyle(Color.Design.textSecondary)
                    Spacer()
                    FlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
                        ForEach(transaction.tags) { tag in
                            TagPill(text: tag.name)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.Design.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.Design.textSecondary)
                .symbolRenderingMode(.hierarchical)
            Text(label)
                .foregroundStyle(Color.Design.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.Design.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            store.send(.deleteTapped)
        } label: {
            Label(String(localized: "transaction_detail_delete"), systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.Design.expenseRed.opacity(0.1))
                .foregroundStyle(Color.Design.expenseRed)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

