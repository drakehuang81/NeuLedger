import Common
import Domain
import SwiftUI

struct AIInsightCard: View {
    let insight: TransactionInsight?
    let categoryName: String?

    @ViewBuilder
    var body: some View {
        if let insight {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(body(for: insight))
                    .font(Font.Design.size13)
                    .lineSpacing(2)
                    .foregroundStyle(Color.Design.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(Font.Design.size13Medium)
                .foregroundStyle(Color.Design.accentOrange)
            Text("transaction_detail_insight_label")
                .font(Font.Design.size10MediumMonospaced)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)
        }
    }

    private func body(for insight: TransactionInsight) -> String {
        switch insight.kind {
        case let .incomeVsLast(percentDelta, lastAmount, monthlyCount, netMonth):
            let sign = percentDelta >= 0 ? "+" : "−"
            let pct = String(format: "%.1f", abs(percentDelta))
            // format: '%@%@%% vs last (NT$%@). %d income entries this month, net NT$%@.'
            // args:    sign  pct              lastAmount  monthlyCount        netMonth
            return String(
                format: String(localized: "transaction_insight_income_vs_last", bundle: .main),
                sign,
                pct,
                format(lastAmount),
                monthlyCount,
                format(netMonth)
            )
        case let .expenseVsCategoryAvg(percentDelta, avg, monthlyCount, monthTotal):
            let sign = percentDelta >= 0 ? "+" : "−"
            let pct = String(format: "%.0f", abs(percentDelta))
            let label = categoryName ?? String(localized: "transaction_type_expense", bundle: .main)
            // format: '%@%@%% vs %@ avg (NT$%@). %d entries, total NT$%@.'
            // args:    sign  pct      label       avg        monthlyCount  monthTotal
            return String(
                format: String(localized: "transaction_insight_expense_vs_avg", bundle: .main),
                sign,
                pct,
                label,
                format(avg),
                monthlyCount,
                format(monthTotal)
            )
        case let .transfer(monthCount, monthTotal):
            // format: 'Net value unchanged. %d transfers this month, total NT$%@.'
            // args:                          monthCount                    monthTotal
            return String(
                format: String(localized: "transaction_insight_transfer", bundle: .main),
                monthCount,
                format(monthTotal)
            )
        case let .fallback(monthlyCategoryCount):
            // format: 'Entry #%d for this category this month.'
            // args:           monthlyCategoryCount
            return String(
                format: String(localized: "transaction_insight_fallback", bundle: .main),
                monthlyCategoryCount
            )
        }
    }

    private func format(_ decimal: Decimal) -> String {
        let n = NSDecimalNumber(decimal: decimal)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        return fmt.string(from: n) ?? "0"
    }
}
