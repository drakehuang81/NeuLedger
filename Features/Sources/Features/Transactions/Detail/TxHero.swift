import Common
import Domain
import SwiftUI

struct TxHero: View {
    let transaction: Domain.Transaction
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            categoryPill
            amountRow
            titleRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryPill: some View {
        HStack(spacing: 8) {
            if let icon = transaction.type.heroSymbol {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(transaction.type.amountDisplayColor)
            }
            if let name = categoryName {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.Design.textPrimary)
            } else {
                Text(Self.fallbackCategoryKey(for: transaction.type))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.Design.textPrimary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: Capsule())
    }

    private var amountRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(verbatim: "NT$")
                .font(.system(size: 20, design: .monospaced))
                .foregroundStyle(Color.Design.textSecondary)
            Text(amountFormatted)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(transaction.type.amountDisplayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(Font.Design.headline.weight(.semibold))
                .foregroundStyle(Color.Design.textPrimary)
            if transaction.aiSuggested {
                aiFilledBadge
            }
        }
    }

    private var aiFilledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))
            Text("transaction_detail_ai_filled")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .foregroundStyle(Color.Design.incomeGreen)
        .background(Color.Design.incomeGreen.opacity(0.15))
        .clipShape(Capsule())
    }

    private var amountFormatted: String {
        let sign: String
        switch transaction.type {
        case .income: sign = "+"
        case .expense: sign = "−"
        case .transfer: sign = ""
        }
        let n = NSDecimalNumber(decimal: transaction.amount)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        let body = fmt.string(from: n) ?? "0"
        return "\(sign)\(body)"
    }

    private var displayTitle: String {
        if let note = transaction.note, !note.isEmpty { return note }
        if let name = categoryName, !name.isEmpty { return name }
        return Self.fallbackCategoryString(for: transaction.type)
    }

    private static func fallbackCategoryKey(for type: TransactionType) -> LocalizedStringKey {
        switch type {
        case .income: return "transaction_type_income"
        case .expense: return "transaction_type_expense"
        case .transfer: return "transaction_type_transfer"
        }
    }

    private static func fallbackCategoryString(for type: TransactionType) -> String {
        switch type {
        case .income: return String(localized: "transaction_type_income", bundle: .main)
        case .expense: return String(localized: "transaction_type_expense", bundle: .main)
        case .transfer: return String(localized: "transaction_type_transfer", bundle: .main)
        }
    }
}

private extension TransactionType {
    var heroSymbol: String? {
        switch self {
        case .income: return "arrow.down.left.circle.fill"
        case .expense: return "arrow.up.right.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}
