import SwiftUI

/// A prominent display for total balance and monthly summary.
///
/// Design Spec:
/// - Corner Radius: 24 (XL)
/// - Background: iOS 26 Liquid Glass (.glassEffect)
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
            Text("balance_total")
                .font(Font.Design.subheadline)
                .foregroundStyle(Color.Design.textSecondary)
            
            Text(totalBalance.twdFormatted)
                .font(Font.Design.largeTitle.weight(.bold).monospacedDigit()) // Bricolage equivalent
                .foregroundStyle(Color.Design.textPrimary)
            
            HStack(spacing: 12) {
                // Income
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down") // Incoming
                        .foregroundStyle(Color.Design.incomeGreen)
                        .font(.caption)
                    Text(income.twdFormatted)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
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
                    Text(expense.twdFormatted)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
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
        .glassEffect(
            Glass.clear
                .interactive()
                .tint(Color.Design.background),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
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
