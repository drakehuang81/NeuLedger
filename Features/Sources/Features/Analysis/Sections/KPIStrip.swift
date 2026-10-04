import Common
import Domain
import SwiftUI

/// 1×4 grid of compact KPI cards (支出 / 收入 / 結餘 / 存錢率).
///
/// Each card renders an eyebrow + mono value + (optional) delta caption.
/// TODO: prior-period delta caption (MoM, savings rank). Requires
/// `AnalysisFeature.State` to expose a prior-period summary; currently
/// omitted so we don't render fake values.
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

        let negativeSavings = (summary?.totalIncome ?? 0) > 0 && net < 0

        HStack(spacing: 6) {
            kpiCard(
                key: "analysis_kpi_expense",
                prefix: expense.twdParts.symbol,
                body: expense.twdParts.digits,
                valueColor: Color.Design.textPrimary
            )
            kpiCard(
                key: "analysis_kpi_income",
                prefix: income.twdParts.symbol,
                body: income.twdParts.digits,
                valueColor: Color.Design.incomeGreen
            )
            kpiCard(
                key: "analysis_kpi_net",
                prefix: net.twdParts.symbol,
                body: net.twdParts.digits,
                valueColor: net >= 0 ? Color.Design.accentOrange : Color.Design.expenseRed
            )
            kpiCard(
                key: "analysis_kpi_savings_rate",
                prefix: nil,
                body: savingsRate,
                // 與 Dashboard 的 StatsRow 同一條規則：負儲蓄率走紅色。
                // 這個 KPI 本來就沒有被 kernel 的夾制蓋到（它自己從
                // `FinancialSummary` 算），所以一直看得到負值，只是顏色
                // 跟隔壁的淨額卡不一致。
                valueColor: negativeSavings ? Color.Design.expenseRed : Color.Design.textPrimary
            )
        }
    }

    // MARK: - Card

    private func kpiCard(
        key: String.LocalizationValue,
        prefix: String?,
        body: String,
        valueColor: Color
    ) -> some View {
        // `twdParts` already splits the symbol from the digits, so the design's
        // small "NT$" label renders at 8pt without string surgery here. The old
        // `hasPrefix("NT$")` check silently failed on negative amounts, whose
        // formatted form starts with "-" — the net card then lost its label.
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: key))
                .font(Font.Design.size9Medium.monospacedDigit())
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.Design.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if let prefix {
                    Text(prefix)
                        .font(Font.Design.size9.monospacedDigit())
                        .foregroundStyle(Color.Design.textSecondary)
                }
                Text(body)
                    .font(Font.Design.size14Medium.monospacedDigit())
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
