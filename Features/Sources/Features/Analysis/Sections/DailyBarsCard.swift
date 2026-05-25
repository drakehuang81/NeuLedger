import Common
import Domain
import SwiftUI

/// Glass card showing the last-7-day expense bars.
///
/// Pulls the most recent 7 distinct dates from `dailyTrends` and pads earlier
/// days with zero-amount bars so the bar count is always 7. The most recent
/// day uses the warm accent color; earlier days fade to 33% alpha.
struct DailyBarsCard: View {
    let trends: [DailyTrend]

    private struct DailyPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Decimal
        let isLatest: Bool
    }

    private var points: [DailyPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let trendMap: [Date: Decimal] = Dictionary(
            trends.map { (cal.startOfDay(for: $0.date), $0.amount) },
            uniquingKeysWith: { lhs, rhs in lhs + rhs }
        )
        // Always render today as the last bar — that anchors the "weekday" labels.
        return (0..<7).reversed().compactMap { offset -> DailyPoint? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let isLatest = offset == 0
            return DailyPoint(date: day, amount: trendMap[day] ?? .zero, isLatest: isLatest)
        }
    }

    private var total: Decimal {
        points.map(\.amount).reduce(.zero, +)
    }

    private var average: Decimal {
        guard points.isEmpty == false else { return .zero }
        let avgDouble = NSDecimalNumber(decimal: total).doubleValue / Double(points.count)
        return Decimal(avgDouble.rounded())
    }

    var body: some View {
        GlassContainer(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                header
                bars
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "analysis_daily_eyebrow"))
                    .font(Font.Design.size9Medium.monospacedDigit())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.Design.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("NT$")
                            .font(Font.Design.size9.monospacedDigit())
                            .foregroundStyle(Color.Design.textSecondary)
                        Text(totalBodyText)
                            .font(Font.Design.size14Medium.monospacedDigit())
                            .foregroundStyle(Color.Design.textPrimary)
                    }
                    Text(
                        String(
                            format: String(localized: "analysis_daily_avg_format"),
                            average.twdFormatted.replacingOccurrences(of: "NT$", with: "")
                        )
                    )
                    .font(Font.Design.size10.monospacedDigit())
                    .foregroundStyle(Color.Design.textSecondary)
                }
            }
            Spacer(minLength: 8)
        }
    }

    private var totalBodyText: String {
        // total.twdFormatted is "NT$X,XXX" — strip the prefix so we can render
        // a smaller "NT$" label next to it.
        let formatted = total.twdFormatted
        return formatted.hasPrefix("NT$") ? String(formatted.dropFirst(3)) : formatted
    }

    // MARK: - Bars

    private var bars: some View {
        let maxAmount = max(points.map(\.amount).max() ?? 1, 1)
        let maxDouble = NSDecimalNumber(decimal: maxAmount).doubleValue
        return GeometryReader { proxy in
            let width = proxy.size.width
            let spacing: CGFloat = 6
            let barWidth = max((width - spacing * CGFloat(points.count - 1)) / CGFloat(points.count), 8)
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(points) { point in
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                point.isLatest
                                ? Color.Design.accentOrange
                                : Color.Design.accentOrange.opacity(0.33)
                            )
                            .frame(
                                width: barWidth,
                                height: max(
                                    CGFloat(NSDecimalNumber(decimal: point.amount).doubleValue / maxDouble) * 56,
                                    2
                                )
                            )
                        Text(weekdayLabel(for: point.date))
                            .font(Font.Design.size9.monospacedDigit())
                            .foregroundStyle(
                                point.isLatest ? Color.Design.textPrimary : Color.Design.textSecondary
                            )
                    }
                }
            }
            .frame(width: width, height: 80, alignment: .bottom)
        }
        .frame(height: 80)
    }

    private func weekdayLabel(for date: Date) -> String {
        let cal = Calendar.current
        let weekdayIndex = cal.component(.weekday, from: date) - 1
        let symbols = cal.veryShortWeekdaySymbols
        guard symbols.indices.contains(weekdayIndex) else { return "" }
        return symbols[weekdayIndex]
    }
}
