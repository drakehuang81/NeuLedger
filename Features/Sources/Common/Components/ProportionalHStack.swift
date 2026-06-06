import SwiftUI

/// A horizontal layout that fills the available width, giving each child
/// a share proportional to its ideal (content) width.
///
/// Unlike `HStack` with `maxWidth: .infinity` children — which splits the
/// width evenly — longer content receives a wider slot, so text avoids
/// wrapping or shrinking until the whole row runs out of space. Every
/// child is proposed the same height (the tallest ideal height), keeping
/// the row visually uniform.
public struct ProportionalHStack: Layout {
    var spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let totalSpacing = spacing * CGFloat(subviews.count - 1)
        let idealWidth = ideals.reduce(0) { $0 + $1.width } + totalSpacing
        let height = ideals.map(\.height).max() ?? 0
        return CGSize(width: proposal.width ?? idealWidth, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard !subviews.isEmpty else { return }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let totalSpacing = spacing * CGFloat(subviews.count - 1)
        let available = max(bounds.width - totalSpacing, 0)
        let totalIdealWidth = ideals.reduce(0) { $0 + $1.width }
        let rowHeight = ideals.map(\.height).max() ?? 0

        var currentX = bounds.minX
        for (index, subview) in subviews.enumerated() {
            // Fall back to an even split when every child reports zero width.
            let share = totalIdealWidth > 0
                ? ideals[index].width / totalIdealWidth
                : 1 / CGFloat(subviews.count)
            let width = available * share
            subview.place(
                at: CGPoint(x: currentX, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: rowHeight)
            )
            currentX += width + spacing
        }
    }
}
