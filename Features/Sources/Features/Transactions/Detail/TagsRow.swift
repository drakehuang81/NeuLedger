import Common
import Domain
import SwiftUI

struct TagsRow: View {
    let tags: [Tag]

    @ViewBuilder
    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("transaction_detail_tags")
                    .font(Font.Design.size10MediumMonospaced)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(tags) { tag in
                        TagPill(text: tag.name)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
