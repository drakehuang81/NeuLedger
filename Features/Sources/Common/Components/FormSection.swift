import SwiftUI

/// A budget/settings-style form section with a mono UPPERCASE header,
/// a Glass-tinted rounded card around the content, and an optional
/// footer hint paragraph.
public struct FormSection<Content: View>: View {
    private let headerKey: LocalizedStringKey
    private let footerKey: LocalizedStringKey?
    private let content: () -> Content

    public init(
        _ headerKey: LocalizedStringKey,
        footerKey: LocalizedStringKey? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headerKey = headerKey
        self.footerKey = footerKey
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerKey)
                .font(Font.Design.size11MediumMonospaced)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)
                .padding(.leading, 6)
                .padding(.bottom, 8)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(
                    Glass.clear.tint(Color.Design.surface),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            if let footerKey {
                Text(footerKey)
                    .font(Font.Design.size12)
                    .foregroundStyle(Color.Design.textSecondary)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 22)
    }
}
