import SwiftUI

/// A card displaying AI insights or tips.
///
/// Design Spec:
/// - Corner Radius: 22 (B1 Warm Redesign)
/// - Background: Glass Surface
/// - Padding: 16
/// - Content: Title + optional MetricBadge on right + Body text + optional CTA button
public struct InsightCard: View {
    let title: String
    let bodyText: String
    let metric: String?
    let metricColor: Color?
    let cta: String?
    let onClose: (() -> Void)?
    let onCTATap: (() -> Void)?

    public init(
        title: String,
        body: String,
        metric: String? = nil,
        metricColor: Color? = nil,
        cta: String? = nil,
        onClose: (() -> Void)? = nil,
        onCTATap: (() -> Void)? = nil
    ) {
        self.title = title
        self.bodyText = body
        self.metric = metric
        self.metricColor = metricColor
        self.cta = cta
        self.onClose = onClose
        self.onCTATap = onCTATap
    }

    public var body: some View {
        GlassContainer(cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(Font.Design.size16)
                        .foregroundStyle(Color.Design.accentYellow)

                    Text(title)
                        .font(Font.Design.size16Semibold)
                        .foregroundStyle(Color.Design.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let metric, let metricColor {
                        MetricBadge(text: metric, color: metricColor)
                    }

                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.textSecondary)
                                .padding(6)
                                .background(Color.Design.separator)
                                .clipShape(Circle())
                        }
                    }
                }

                Text(bodyText)
                    .font(Font.Design.size13)
                    .foregroundStyle(Color.Design.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let cta {
                    Button {
                        onCTATap?()
                    } label: {
                        HStack(spacing: 4) {
                            Text(cta)
                                .font(Font.Design.size13Semibold)
                            Image(systemName: "chevron.right")
                                .font(Font.Design.size11Semibold)
                        }
                        .foregroundStyle(Color.Design.brandPrimary)
                    }
                    .buttonStyle(.plain)
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
                title: "本週支出減少 12%",
                body: "你比上週省下 NT$ 3,200，可以考慮加碼儲蓄",
                metric: "-12%",
                metricColor: Color.Design.incomeGreen,
                cta: "查看分析"
            )

            InsightCard(
                title: "Tip",
                body: "Consider setting a budget for Coffee."
            )
        }
        .padding()
    }
}
