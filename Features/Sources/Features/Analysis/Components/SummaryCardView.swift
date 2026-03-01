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
                    Text("收入")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(summary.totalIncome.formattedCurrency)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .font(Font.Design.amount)
                        .foregroundStyle(Color.Design.incomeGreen)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Expense
                VStack(spacing: 4) {
                    Text("支出")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(summary.totalExpense.formattedCurrency)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .font(Font.Design.amount)
                        .foregroundStyle(Color.Design.textPrimary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Net Balance
                VStack(spacing: 4) {
                    Text("結餘")
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(summary.netBalance.formattedCurrency)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .font(Font.Design.amount)
                        .foregroundStyle(summary.netBalance >= 0 ? Color.Design.incomeGreen : Color.Design.expenseRed)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private extension Decimal {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "$0"
    }
}
