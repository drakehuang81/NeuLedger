import Common
import Domain
import SwiftUI

/// Glass card with a 108pt donut chart + top-3 category list + expandable
/// row breakdown.
///
/// TODO: `CategoryProportion` only carries `id` / `name` / `amount`. Per-slice
/// colors and icons come from a fallback palette + SF Symbol heuristic because
/// the reducer/state is locked. When `Domain.CategoryProportion` is extended
/// with color/icon, swap the helpers below.
struct CategoryDonutCard: View {
    let proportions: [CategoryProportion]
    let onRowTapped: (CategoryProportion) -> Void

    // Same palette used by the legacy `CategoryPieChartView` so the colors
    // remain stable while we migrate.
    private static let palette: [Color] = [
        Color.Design.brandPrimary,
        Color.Design.incomeGreen,
        Color.Design.expenseRed,
        Color.Design.brandSecondary,
        Color.Design.accentOrange,
        Color.Design.aiPurple,
        Color.Design.transferPurple,
        Color.Design.accentBlue,
        Color.Design.accentYellow
    ]

    private func color(for index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }

    private var sortedProportions: [(index: Int, item: CategoryProportion)] {
        Array(proportions.enumerated())
            .map { (index: $0.offset, item: $0.element) }
    }

    private var totalAmount: Decimal {
        proportions.map(\.amount).reduce(.zero, +)
    }

    var body: some View {
        GlassContainer(cornerRadius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                header
                donutAndTopCategories
                Divider()
                    .padding(.vertical, 2)
                rowList
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "analysis_donut_eyebrow"))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.Design.textSecondary)
            Spacer()
            Text(String(localized: "analysis_donut_tap_hint"))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(Color.Design.accentOrange)
        }
    }

    // MARK: - Donut + top categories

    private var donutAndTopCategories: some View {
        HStack(alignment: .center, spacing: 14) {
            donut
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sortedProportions.prefix(3), id: \.item.id) { entry in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: entry.index))
                            .frame(width: 8, height: 8)
                        Text(entry.item.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.Design.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(percentText(for: entry.item))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Color.Design.textSecondary)
                    }
                }
                if proportions.count > 3 {
                    Text(
                        String(
                            format: String(localized: "analysis_donut_more_format"),
                            proportions.count - 3
                        )
                    )
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(Color.Design.textSecondary)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var donut: some View {
        let total = NSDecimalNumber(decimal: totalAmount).doubleValue
        let segments: [(start: Double, end: Double, color: Color)] = {
            guard total > 0 else { return [] }
            var cursor: Double = 0
            return sortedProportions.map { entry in
                let value = NSDecimalNumber(decimal: entry.item.amount).doubleValue
                let start = cursor
                cursor += value / total
                return (start: start, end: cursor, color: color(for: entry.index))
            }
        }()

        return ZStack {
            // Track
            Circle()
                .stroke(Color.Design.textSecondary.opacity(0.12), lineWidth: 14)
                .frame(width: 108, height: 108)

            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .frame(width: 108, height: 108)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text(String(localized: "analysis_donut_total"))
                    .font(.system(size: 7, weight: .medium).monospacedDigit())
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.Design.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("NT$")
                        .font(.system(size: 8).monospacedDigit())
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(totalAmount.twdFormatted.replacingOccurrences(of: "NT$", with: ""))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.Design.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: 80)
        }
        .frame(width: 108, height: 108)
    }

    // MARK: - Row list

    private var rowList: some View {
        VStack(spacing: 0) {
            ForEach(sortedProportions, id: \.item.id) { entry in
                Button {
                    onRowTapped(entry.item)
                } label: {
                    rowContent(for: entry.item, color: color(for: entry.index))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if entry.item.id != sortedProportions.last?.item.id {
                    Divider()
                }
            }
        }
    }

    private func rowContent(for proportion: CategoryProportion, color: Color) -> some View {
        let widthRatio = proportionRatio(for: proportion)
        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(color)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(proportion.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.Design.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("NT$")
                            .font(.system(size: 8).monospacedDigit())
                            .foregroundStyle(Color.Design.textSecondary)
                        Text(proportion.amount.twdFormatted.replacingOccurrences(of: "NT$", with: ""))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color.Design.textPrimary)
                    }
                }
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.Design.textSecondary.opacity(0.10))
                            .frame(height: 4)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: proxy.size.width * widthRatio, height: 4)
                        }
                        .frame(height: 4)
                    }
                    Text(percentText(for: proportion))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(Color.Design.textSecondary)
                        .frame(minWidth: 28, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func proportionRatio(for proportion: CategoryProportion) -> CGFloat {
        let total = NSDecimalNumber(decimal: totalAmount).doubleValue
        guard total > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: proportion.amount).doubleValue
        return CGFloat(min(max(value / total, 0), 1))
    }

    private func percentText(for proportion: CategoryProportion) -> String {
        let ratio = proportionRatio(for: proportion)
        return String(format: "%.0f%%", ratio * 100)
    }
}
