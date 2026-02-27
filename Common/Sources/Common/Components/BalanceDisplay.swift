import SwiftUI

/// A prominent display for total balance and monthly summary.
///
/// Design Spec:
/// - Corner Radius: 24 (XL)
/// - Background: Glass Prominent (Regular Material)
/// - Padding: 20
/// - Gap: 8 (Main Stack), 12 (Income/Expense Row)
public struct BalanceDisplay: View {
    let totalBalance: Decimal
    let income: Decimal
    let expense: Decimal
    
    public init(totalBalance: Decimal, income: Decimal, expense: Decimal) {
        self.totalBalance = totalBalance
        self.income = income
        self.expense = expense
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            
            Text(totalBalance.currencyFormat)
                .font(.system(size: 36, weight: .bold, design: .rounded)) // Bricolage equivalent
                .foregroundStyle(Color.primary)
            
            HStack(spacing: 12) {
                // Income
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down") // Incoming
                        .foregroundStyle(Color.Design.incomeGreen)
                        .font(.caption)
                    Text(income.currencyFormat)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.Design.incomeGreen.opacity(0.1))
                .clipShape(Capsule())
                
                // Expense
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up") // Outgoing
                        .foregroundStyle(Color.Design.expenseRed)
                        .font(.caption)
                    Text(expense.currencyFormat)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.Design.expenseRed.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial) // Glass Prominent
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private extension Decimal {
    var currencyFormat: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2).ignoresSafeArea()
        BalanceDisplay(
            totalBalance: 128450,
            income: 32000,
            expense: 1280
        )
        .padding()
    }
}
