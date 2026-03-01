import SwiftUI
import Charts
import Domain
import Common

struct TrendBarChartView: View {
    let trends: [DailyTrend]
    
    var body: some View {
        GlassContainer(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("每日趨勢")
                    .font(Font.Design.headline)
                    .foregroundStyle(Color.Design.textPrimary)
                
                Chart(trends) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("金額", (item.amount as NSDecimalNumber).doubleValue)
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
