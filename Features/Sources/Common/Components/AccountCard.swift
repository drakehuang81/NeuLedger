import SwiftUI

/// A card displaying account summary.
///
/// Design Spec:
/// - Corner Radius: 16 (LG)
/// - Background: Glass Surface
/// - Padding: 16
/// - Gap: 10
/// - Width: ~160 (Flexible in Grid)
public struct AccountCard: View {
    let name: String
    let balance: Decimal
    let type: String
    let icon: String // System name
    
    public init(
        name: String,
        balance: Decimal,
        type: String,
        icon: String = "building.columns"
    ) {
        self.name = name
        self.balance = balance
        self.type = type
        self.icon = icon
    }
    
    public var body: some View {
        GlassContainer(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.Design.brandPrimary)
                        .frame(width: 20, height: 20)

                    Text(name)
                        .font(Font.Design.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                // Amount
                Text(balance.twdFormatted)
                    .font(Font.Design.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.Design.textPrimary)

                // Type
                Text(type)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }
            .frame(width: 128, alignment: .leading) // 160 - 16*2 padding
        }
    }
}


#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        HStack {
            AccountCard(name: String(localized: "component_bank_account"), balance: 45230, type: String(localized: "component_bank"), icon: "building.columns")
            AccountCard(name: String(localized: "component_wallet"), balance: 1200, type: String(localized: "component_cash"), icon: "wallet.pass")
        }
    }
}
