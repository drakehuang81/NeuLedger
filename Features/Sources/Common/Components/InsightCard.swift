import SwiftUI

/// A card displaying AI insights or tips.
///
/// Design Spec:
/// - Corner Radius: 16 (LG)
/// - Background: Glass Surface
/// - Padding: 16
/// - Content: Sparkle Icon + Title + Body text
public struct InsightCard: View {
    let title: String
    let bodyText: String
    let onClose: (() -> Void)?
    
    public init(
        title: String,
        body: String,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.bodyText = body
        self.onClose = onClose
    }
    
    public var body: some View {
        GlassContainer(cornerRadius: 16, padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.yellow)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Font.Design.headline)
                        .foregroundStyle(Color.Design.textPrimary)

                    Text(bodyText)
                        .font(Font.Design.subheadline)
                        .foregroundStyle(Color.Design.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.textSecondary)
                            .padding(8)
                            .background(Color.Design.separator)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        VStack {
            InsightCard(
                title: "AI Analysis",
                body: "Spending on dining increased by 15% this week compared to last month average.",
                onClose: {}
            )
            
            InsightCard(
                title: "Tip",
                body: "Consider settings a budget for Coffee."
            )
        }
        .padding()
    }
}
