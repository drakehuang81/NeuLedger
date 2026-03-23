import SwiftUI
import Charts
import Domain
import Common

struct TrendBarChartView: View {
    let trends: [DailyTrend]
    let dateRange: ClosedRange<Date>

    var body: some View {
        GlassContainer(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("analysis_trend_bar_chart_title")
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)

                if trends.isEmpty {
                    Text(String(localized: "analysis_no_data_desc"))
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 180)
                } else {
                    Chart(trends) { item in
                        BarMark(
                            x: .value(String(localized: "add_transaction_date"), item.date, unit: .day),
                            y: .value(String(localized: "budget_form_amount"), (item.amount as NSDecimalNumber).doubleValue),
                            width: .ratio(0.6)
                        )
                        .foregroundStyle(Color.Design.brandPrimary.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                    .chartXScale(domain: dateRange.lowerBound...dateRange.upperBound)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                            AxisGridLine()
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Controls how many days to skip between X-axis labels so they don't overlap.
    private var xAxisStride: Int {
        let days = Calendar.current.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 1
        switch days {
        case ..<10: return 1
        case ..<35: return 5
        default:    return 30
        }
    }
}
