import SwiftUI
import Charts
import Domain
import Common

struct TrendBarChartView: View {
    let trends: [DailyTrend]
    
    var body: some View {
        GlassContainer(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("analysis_trend_bar_chart_title")
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)
                
                Chart(trends) { item in
                    BarMark(
                        x: .value(String(localized: "add_transaction_date"), item.date, unit: .day),
                        y: .value(String(localized: "budget_form_amount"), (item.amount as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(Color.Design.brandPrimary.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day())
                            }
                        }
                    }
                }
            }
        }
    }
}
