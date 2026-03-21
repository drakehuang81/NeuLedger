import SwiftUI

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
        GlassEffectContainer {
            HStack {
                Spacer()

                // Action Capsule
                Button(action: onAddTransaction) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))

                        Text("action_record")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .glassEffect(Glass.clear.interactive().tint(Color.Design.background), in: Capsule())
                .buttonStyle(.plain)
                .foregroundStyle(Color.primary)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
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
