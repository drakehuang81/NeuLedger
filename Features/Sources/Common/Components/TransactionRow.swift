import SwiftUI

/// A row displaying transaction details.
///
/// Design Spec:
/// - Corner Radius: 12 (MD)
/// - Background: Surface (Card Surface)
/// - Padding: Horizontal 16, Vertical 12
/// - Gap: 12
/// - Icon: 22x22 in 40x40 container (tint @ 13% opacity)
/// - Expansion: when `isExpanded && !tags.isEmpty`, reveals a flow-wrapped
///   list of `TagPill`s below a divider.
public struct TransactionRow: View {
    let title: String
    let subtitle: String
    let amountText: String
    let amountColor: Color
    let date: String
    let icon: String // System Name
    let iconColor: Color
    let isExpanded: Bool
    let tags: [String]
    let onTap: () -> Void
    let onOpenDetail: (() -> Void)?

    public init(
        title: String,
        subtitle: String,
        amountText: String,
        amountColor: Color,
        date: String,
        icon: String,
        iconColor: Color = .blue,
        isExpanded: Bool = false,
        tags: [String] = [],
        onTap: @escaping () -> Void = {},
        onOpenDetail: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amountText = amountText
        self.amountColor = amountColor
        self.date = date
        self.icon = icon
        self.iconColor = iconColor
        self.isExpanded = isExpanded
        self.tags = tags
        self.onTap = onTap
        self.onOpenDetail = onOpenDetail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Icon Container — tinted background at 13% opacity
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.13))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.Design.headline)
                        .foregroundStyle(Color.Design.textPrimary)

                    Text(subtitle)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                }

                Spacer()

                // Right Content
                VStack(alignment: .trailing, spacing: 2) {
                    Text(amountText)
                        .font(Font.Design.amount.weight(.semibold))
                        .foregroundStyle(amountColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(date)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isExpanded && (!tags.isEmpty || onOpenDetail != nil) {
                Divider()
                    .padding(.horizontal, 16)

                HStack(alignment: .bottom, spacing: 8) {
                    if !tags.isEmpty {
                        FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                TagPill(text: tag, color: iconColor)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if let onOpenDetail {
                        Button(action: onOpenDetail) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(Font.Design.size11Medium)
                                Text("common_edit")
                                    .font(Font.Design.size11Medium)
                            }
                            .foregroundStyle(Color.Design.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("transaction_row_edit_button")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color.Design.surface)
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
                iconColor: .orange,
                isExpanded: true,
                tags: ["work", "team"]
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
