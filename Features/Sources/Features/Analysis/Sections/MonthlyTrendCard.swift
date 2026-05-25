import Common
import Domain
import SwiftUI

/// Glass card showing the 6-month trend bars.
///
/// TODO: AnalysisFeature.State currently only loads transactions for the
/// selected period (`.week` / `.month` / `.year`). Deriving a true 6-month
/// trend requires fetching a separate window, which is out of scope for this
/// view-only redesign. For now this view is rendered only when the caller
/// passes data; `AnalysisView` keeps `hasMonthlyTrendData = false` until the
/// reducer can supply prior-period totals.
struct MonthlyTrendCard: View {
    let monthlyTotals: [Decimal]

    private var maxValue: Double {
        max(NSDecimalNumber(decimal: monthlyTotals.max() ?? 1).doubleValue, 1)
    }

    private var average: Decimal {
        guard monthlyTotals.isEmpty == false else { return .zero }
        let total = monthlyTotals.reduce(Decimal.zero, +)
        let avg = NSDecimalNumber(decimal: total).doubleValue / Double(monthlyTotals.count)
        return Decimal(avg.rounded())
    }

    var body: some View {
        GlassContainer(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                header
                bars
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "analysis_monthly_eyebrow"))
                    .font(Font.Design.size9Medium.monospacedDigit())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.Design.textSecondary)
                Text(
                    String(
                        format: String(localized: "analysis_monthly_avg_format"),
                        average.twdFormatted
                    )
                )
                .font(Font.Design.size13.monospacedDigit())
                .foregroundStyle(Color.Design.textPrimary)
            }
            Spacer(minLength: 8)
        }
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(monthlyTotals.enumerated()), id: \.offset) { index, amount in
                let isLatest = index == monthlyTotals.count - 1
                let h = max(CGFloat(NSDecimalNumber(decimal: amount).doubleValue / maxValue) * 48, 2)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        isLatest
                        ? Color.Design.accentOrange
                        : Color.Design.textSecondary.opacity(0.30)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: h)
            }
        }
        .frame(height: 56)
    }
}
