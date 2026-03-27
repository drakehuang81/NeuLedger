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
    let amountText: String
    let amountColor: Color
    let date: String
    let icon: String // System Name
    let iconColor: Color

    public init(
        title: String,
        subtitle: String,
        amountText: String,
        amountColor: Color,
        date: String,
        icon: String,
        iconColor: Color = .blue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amountText = amountText
        self.amountColor = amountColor
        self.date = date
        self.icon = icon
        self.iconColor = iconColor
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
                Text(amountText)
                    .font(Font.Design.amount.weight(.semibold)) // 16pt Mono Semibold
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

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


#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack {
            TransactionRow(
                title: "Lunch",
                subtitle: "Food · Cash",
                amountText: "-NT$120",
                amountColor: .red,
                date: "Today 12:30",
                icon: "fork.knife",
                iconColor: .orange
            )

            TransactionRow(
                title: "Salary",
                subtitle: "Work · Bank",
                amountText: "NT$50,000",
                amountColor: .green,
                date: "Yesterday",
                icon: "briefcase.fill",
                iconColor: .blue
            )
        }
        .padding()
    }
}
