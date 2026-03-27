import SwiftUI
import Charts
import Domain
import Common

struct CategoryPieChartView: View {
    let proportions: [CategoryProportion]
    var onCategoryTapped: ((CategoryProportion) -> Void)? = nil

    // Fixed color palette — same order used for both chart sectors and legend dots
    private static let palette: [Color] = [
        Color.Design.brandPrimary,
        Color.Design.incomeGreen,
        Color.Design.expenseRed,
        Color.Design.brandSecondary,
        .orange, .purple, .cyan, .mint, .indigo
    ]

    private func color(at index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }

    var body: some View {
        GlassContainer(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("analysis_category_pie_chart_title")
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)

                Chart(Array(proportions.enumerated()), id: \.element.id) { index, item in
                    SectorMark(
                        angle: .value(String(localized: "budget_form_amount"), (item.amount as NSDecimalNumber).doubleValue),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(color(at: index))
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .chartLegend(.hidden)

                // Tappable legend with matching colors
                VStack(spacing: 0) {
                    ForEach(Array(proportions.enumerated()), id: \.element.id) { index, item in
                        Button {
                            onCategoryTapped?(item)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(color(at: index))
                                Text(item.name)
                                    .font(Font.Design.subheadline)
                                    .foregroundStyle(Color.Design.textPrimary)
                                Spacer()
                                Text(item.amount.twdFormatted)
                                    .font(Font.Design.amount)
                                    .foregroundStyle(Color.Design.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if onCategoryTapped != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Design.textTertiary)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if item.id != proportions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
