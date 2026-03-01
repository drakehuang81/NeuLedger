import SwiftUI

/// A row displaying transaction details.
///
/// Design Spec:
/// - Corner Radius: 12 (MD)
/// - Background: Surface (Card Surface)
/// - Padding: Horizontal 16, Vertical 12
/// - Gap: 12
/// - Icon: 22x22 in 40x40 container
public struct TransactionRow: View {
    let title: String
    let subtitle: String
    let amount: Decimal
    let date: String
    let icon: String // System Name
    let iconColor: Color
    
    public init(
        title: String,
        subtitle: String,
        amount: Decimal,
        date: String,
        icon: String,
        iconColor: Color = .blue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.date = date
        self.icon = icon
        self.iconColor = iconColor
    }
    
    private var isExpense: Bool {
        amount < 0
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(Color.Design.surfaceSecondary) // Surface Secondary
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20)) // 22x22 approx
                    .foregroundStyle(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.Design.headline) // 16pt Medium
                    .foregroundStyle(Color.Design.textPrimary)
                
                Text(subtitle)
                    .font(Font.Design.caption) // 13pt
                    .foregroundStyle(Color.Design.textSecondary)
            }
            
            Spacer()
            
            // Right Content
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount.formattedCurrency)
                    .font(Font.Design.amount.weight(.semibold)) // 16pt Mono Semibold
                    .foregroundStyle(isExpense ? Color.Design.expenseRed : Color.Design.incomeGreen)
                
                Text(date)
                    .font(Font.Design.caption) // 12pt
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.Design.surface) // Surface (Card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension Decimal {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack {
            TransactionRow(
                title: "Lunch",
                subtitle: "Food · Cash",
                amount: -120,
                date: "Today 12:30",
                icon: "fork.knife",
                iconColor: .orange
            )
            
            TransactionRow(
                title: "Salary",
                subtitle: "Work · Bank",
                amount: 50000,
                date: "Yesterday",
                icon: "briefcase.fill",
                iconColor: .blue
            )
        }
        .padding()
    }
}
