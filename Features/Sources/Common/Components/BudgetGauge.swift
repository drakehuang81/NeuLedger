import SwiftUI

/// A gauge showing budget progress.
///
/// Design Spec:
/// - Corner Radius: LG (Container), Pill (Bar)
/// - Background: Surface (Not Glass?) Design says "fill: surface", implies solid.
/// - Progress: Gradient [brand-primary -> brand-secondary]
public struct BudgetGauge: View {
    let total: Decimal
    let used: Decimal
    let label: String?
    
    public init(total: Decimal, used: Decimal, label: String? = nil) {
        self.total = total
        self.used = used
        self.label = label
    }
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        let value = (used as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue
        return min(max(value, 0), 1)
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(LocalizedStringKey(label ?? "gauge_monthly_budget"))
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(Font.Design.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Design.textPrimary)
            }
            
            // Bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.Design.surfaceSecondary)
                        .frame(height: 8)
                    
                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple], // Brand Gradient
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)
            
            // Footer
            HStack {
                Text("gauge_used") + Text(" \(used.formattedCurrency)")
                    .font(Font.Design.amount)
                    .foregroundStyle(Color.Design.textSecondary)
                Spacer()
                Text("gauge_remaining") + Text(" \((total - used).formattedCurrency)")
                    .font(Font.Design.amount)
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
        .padding(16)
        .background(Color.Design.surface) // Surface
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        BudgetGauge(total: 5000, used: 3250, label: "Dining")
            .padding()
    }
}
