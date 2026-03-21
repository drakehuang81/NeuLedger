import SwiftUI
import Charts
import Domain
import Common

struct CategoryPieChartView: View {
    let proportions: [CategoryProportion]
    var onCategoryTapped: ((CategoryProportion) -> Void)? = nil

    var body: some View {
        GlassContainer(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("analysis_category_pie_chart_title")
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)

                Chart(proportions) { item in
                    SectorMark(
                        angle: .value(String(localized: "budget_form_amount"), (item.amount as NSDecimalNumber).doubleValue),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value(String(localized: "add_transaction_category"), item.name))
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartLegend(.hidden)

                // Tappable legend
                VStack(spacing: 0) {
                    ForEach(proportions) { item in
                        Button {
                            onCategoryTapped?(item)
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(.secondary)
                                Text(item.name)
                                    .font(Font.Design.subheadline)
                                    .foregroundStyle(Color.Design.textPrimary)
                                Spacer()
                                Text("NT$\(item.amount as NSDecimalNumber)")
                                    .font(Font.Design.amount)
                                    .foregroundStyle(Color.Design.textSecondary)
                                if onCategoryTapped != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Design.textTertiary)
                                }
                            }
                            .padding(.vertical, 8)
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
