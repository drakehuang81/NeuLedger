import SwiftUI
import Domain
import Common

struct SummaryCardView: View {
    let summary: FinancialSummary
    
    var body: some View {
        GlassContainer(padding: 24) {
            HStack(spacing: 0) {
                // Income
                VStack(spacing: 4) {
                    Text("analysis_summary_income")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(summary.totalIncome.twdFormatted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .font(Font.Design.amount)
                        .foregroundStyle(Color.Design.incomeGreen)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Expense
                VStack(spacing: 4) {
                    Text("analysis_summary_expense")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(summary.totalExpense.twdFormatted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .font(Font.Design.amount)
                        .foregroundStyle(Color.Design.textPrimary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Net Balance
                VStack(spacing: 4) {
                    Text("analysis_summary_net_balance")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(summary.netBalance.twdFormatted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .font(Font.Design.amount)
                        .foregroundStyle(summary.netBalance >= 0 ? Color.Design.incomeGreen : Color.Design.expenseRed)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
