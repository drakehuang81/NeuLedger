import Common
import Domain
import SwiftUI

/// 1×4 grid of compact KPI cards (支出 / 收入 / 結餘 / 存錢率).
///
/// Each card renders an eyebrow + mono value + (optional) delta caption.
/// Deltas are intentionally omitted whenever prior-period data is not yet wired
/// through `AnalysisFeature.State` — we render the row without any fake values.
struct KPIStrip: View {
    let summary: FinancialSummary?

    var body: some View {
        let expense = summary?.totalExpense ?? .zero
        let income = summary?.totalIncome ?? .zero
        let net = (summary?.netBalance) ?? .zero
        let savingsRate: String = {
            guard let summary, summary.totalIncome > 0 else {
                return String(localized: "analysis_kpi_savings_unavailable")
            }
            let income = NSDecimalNumber(decimal: summary.totalIncome).doubleValue
            let net = NSDecimalNumber(decimal: summary.netBalance).doubleValue
            return String(format: "%.0f%%", (net / income) * 100)
        }()

        HStack(spacing: 6) {
            kpiCard(
                key: "analysis_kpi_expense",
                value: expense.twdFormatted,
                valueColor: Color.Design.textPrimary,
                showCurrencyPrefix: true
            )
            kpiCard(
                key: "analysis_kpi_income",
                value: income.twdFormatted,
                valueColor: Color.Design.incomeGreen,
                showCurrencyPrefix: true
            )
            kpiCard(
                key: "analysis_kpi_net",
                value: net.twdFormatted,
                valueColor: net >= 0 ? Color.Design.accentOrange : Color.Design.expenseRed,
                showCurrencyPrefix: true
            )
            kpiCard(
                key: "analysis_kpi_savings_rate",
                value: savingsRate,
                valueColor: Color.Design.textPrimary,
                showCurrencyPrefix: false
            )
        }
    }

    // MARK: - Card

    private func kpiCard(
        key: String.LocalizationValue,
        value: String,
        valueColor: Color,
        showCurrencyPrefix: Bool
    ) -> some View {
        // The Decimal+Currency formatter already produces "NT$1,234". Split the
        // prefix so the design's small "NT$" label can render at 8pt.
        let trimmed: (prefix: String?, body: String) = {
            guard showCurrencyPrefix, value.hasPrefix("NT$") else { return (nil, value) }
            return ("NT$", String(value.dropFirst(3)))
        }()

        return VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: key))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.Design.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if let prefix = trimmed.prefix {
                    Text(prefix)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(Color.Design.textSecondary)
                }
                Text(trimmed.body)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.Design.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }
}
