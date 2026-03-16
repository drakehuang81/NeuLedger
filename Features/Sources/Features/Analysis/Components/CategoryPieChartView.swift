import SwiftUI
import Charts
import Domain
import Common

struct CategoryPieChartView: View {
    let proportions: [CategoryProportion]
    
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
                .chartLegend(position: .bottom, alignment: .center)
            }
        }
    }
}
