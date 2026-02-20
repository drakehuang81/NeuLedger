import SwiftUI
import DesignSystem

/// A bottom action bar with quick access buttons.
///
/// Design Spec:
/// - Corner Radius: 20 (XL)
/// - Background: Glass Surface
/// - Padding: Horizontal 16, Vertical 8
/// - Justify: Space Around
public struct QuickActionBar: View {
    let onAddTransaction: () -> Void
    
    public init(onAdd: @escaping () -> Void) {
        self.onAddTransaction = onAdd
    }
    
    public var body: some View {
        HStack {
            Spacer()
            
            // Action Capsule
            Button(action: onAddTransaction) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    
                    Text("Record") // "記帳"
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.regularMaterial) // Glass Prominent? Or colored?
                // Design says "fill: glass-prominent".
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial) // Glass Container
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        VStack {
            Spacer()
            QuickActionBar {}
                .padding()
        }
    }
}
