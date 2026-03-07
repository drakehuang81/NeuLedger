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
            .navigationTitle(transaction.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.send(.task).finish() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        store.send(.dismiss)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("編輯") {
                        store.send(.editTapped)
                    }
                }
            }
            .confirmationDialog(
                "確定要刪除這筆交易嗎？",
                isPresented: Binding(
                    get: { store.showDeleteConfirmation },
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
                .background(transaction.type.badgeColor.opacity(0.15))
                .foregroundStyle(transaction.type.badgeColor)
                .clipShape(Capsule())

            // Amount
            Text(transaction.amount.formattedTWD)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(transaction.type.amountColor)
                .monospacedDigit()
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            // 日期
            detailRow(icon: "calendar", label: "日期", value: transaction.date.formatted(date: .long, time: .shortened))
            Divider().padding(.leading, 56)

            // 帳戶
            if let accountName = store.accountName {
                detailRow(icon: "wallet.bifold", label: "帳戶", value: accountName)
                Divider().padding(.leading, 56)
            }

            // 轉帳目標帳戶
            if transaction.type == .transfer, let toName = store.toAccountName {
                detailRow(icon: "arrow.right", label: "轉至", value: toName)
                Divider().padding(.leading, 56)
            }

            // 分類
            if transaction.type != .transfer, let categoryName = store.categoryName {
                detailRow(icon: "square.grid.2x2", label: "分類", value: categoryName)
                Divider().padding(.leading, 56)
            }

            // 備註
            if let note = transaction.note, !note.isEmpty {
                detailRow(icon: "text.bubble", label: "備註", value: note)
                Divider().padding(.leading, 56)
            }

            // 標籤
            if !transaction.tags.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "tag")
                        .frame(width: 24)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text("標籤")
                        .foregroundStyle(Color.Design.textSecondary)
                    Spacer()
                    FlowLayout(spacing: 4) {
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
            Label("刪除交易", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.Design.expenseRed.opacity(0.1))
                .foregroundStyle(Color.Design.expenseRed)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Helpers

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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

    var badgeColor: Color {
        switch self {
        case .expense: return Color.Design.expenseRed
        case .income: return Color.Design.incomeGreen
        case .transfer: return Color.Design.brandPrimary
        }
    }

    var amountColor: Color {
        switch self {
        case .expense: return Color.Design.expenseRed
        case .income: return Color.Design.incomeGreen
        case .transfer: return Color.Design.textPrimary
        }
    }
}

private extension Decimal {
    var formattedTWD: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: self as NSDecimalNumber) ?? "0"
        return "NT$ \(number)"
    }
}
