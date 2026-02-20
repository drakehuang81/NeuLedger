import SwiftUI
import DesignSystem

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
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20, height: 20)
                
                Text(name)
                    .font(.caption) // 14pt approx
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            // Amount
            Text(balance.currencyFormat)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary)
            
            // Type
            Text(type)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .frame(width: 160, alignment: .leading) // Fixed width per design spec? Or flexible?
        // Design says width: 160. But usually flexible is better.
        // I'll keep frame(width: 160) for now as default, or remove it for flexibility.
        // To be safe, I'll remove fixed width and let container decide, or use idealWidth.
        // Actually, cards in horizontal scroll usually fixed width. I'll stick to flexible relative to parent or fixed frame modifier outside.
        // But for this component, let's keep it flexible but min width.
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// Helper for formatting
private extension Decimal {
    var currencyFormat: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$" // Default
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        HStack {
            AccountCard(name: "Bank Account", balance: 45230, type: "Bank", icon: "building.columns")
            AccountCard(name: "Wallet", balance: 1200, type: "Cash", icon: "wallet.pass")
        }
    }
}
