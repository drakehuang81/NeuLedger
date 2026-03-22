import SwiftUI

/// A layout that arranges children in a left-aligned, wrapping flow.
///
/// Children are placed horizontally until they no longer fit, then wrap
/// to the next line — similar to CSS flexbox with `flex-wrap: wrap`.
public struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if index > 0 && currentX + horizontalSpacing + size.width > maxWidth {
                // Wrap to next line
                totalHeight += rowHeight + verticalSpacing
                currentX = 0
                rowHeight = 0
            }

            currentX += size.width + (currentX > 0 ? horizontalSpacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        // Two-pass: first figure out line breaks, then place with vertical centering
        var lines: [(range: Range<Int>, height: CGFloat)] = []
        let sizes: [CGSize] = subviews.map { $0.sizeThatFits(.unspecified) }

        var i = 0
        while i < subviews.count {
            var lineWidth: CGFloat = 0
            var lh: CGFloat = 0
            var j = i
            while j < subviews.count {
                let size = sizes[j]
                let needed = lineWidth == 0 ? size.width : lineWidth + horizontalSpacing + size.width
                if needed > maxWidth && j > i { break }
                lineWidth = needed
                lh = max(lh, size.height)
                j += 1
            }
            lines.append((i..<j, lh))
            i = j
        }

        var currentY: CGFloat = bounds.minY
        for line in lines {
            var currentX: CGFloat = bounds.minX
            for idx in line.range {
                let size = sizes[idx]
                let yOffset = (line.height - size.height) / 2
                subviews[idx].place(
                    at: CGPoint(x: currentX, y: currentY + yOffset),
                    proposal: ProposedViewSize(size)
                )
                currentX += size.width + horizontalSpacing
            }
            currentY += line.height + verticalSpacing
        }
    }
}
