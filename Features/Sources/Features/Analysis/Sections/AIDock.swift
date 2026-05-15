import Common
import Domain
import SwiftUI

/// Collapsible AI insight dock. Closed = single line + chevron; tapping
/// reveals the full description text.
///
/// Renders nothing when `insight` is nil — keeping this view-only logic out of
/// `AnalysisFeature`.
struct AIDock: View {
    let insight: InsightDetail?

    @State private var isOpen: Bool = false

    var body: some View {
        if let insight {
            content(for: insight)
        }
    }

    private func content(for insight: InsightDetail) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                isOpen.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Design.accentOrange)
                    Text(headlineText(for: insight))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.Design.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.Design.textSecondary)
                }

                if isOpen, !insight.description.isEmpty {
                    Text(insight.description)
                        .font(.system(size: 12.5))
                        .lineSpacing(3)
                        .foregroundStyle(Color.Design.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.Design.accentOrange.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.Design.accentOrange.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func headlineText(for insight: InsightDetail) -> String {
        if isOpen {
            return insight.title.isEmpty
                ? String(localized: "analysis_ai_dock_prompt")
                : insight.title
        }
        // Closed state: prefer the AI's title if available, otherwise show the
        // friendly prompt copy.
        return insight.title.isEmpty
            ? String(localized: "analysis_ai_dock_prompt")
            : insight.title
    }
}
