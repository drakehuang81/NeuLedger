import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// Top bar for the Analysis screen (B1 Warm Glass redesign).
///
/// Layout (left → right):
///  - 30×30 decorative icon chip (chart glyph)
///  - eyebrow period label + "Analytics" title
///  - period segmented pills (月 / 週 / 年)
///  - account filter Menu chip (only when accounts exist)
struct AnalysisTopBar: View {
    @Bindable var store: StoreOf<AnalysisFeature>

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            titleStack
            Spacer(minLength: 8)
            periodSegmented
            accountMenu
        }
    }

    // MARK: - Subviews

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrowLabel(for: store.selectedPeriod))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.Design.textSecondary)
            Text(String(localized: "analysis_title"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.Design.textPrimary)
                .lineLimit(1)
        }
    }

    private var periodSegmented: some View {
        HStack(spacing: 4) {
            ForEach(AnalysisFeature.State.Period.allCases) { period in
                periodPill(period)
            }
        }
    }

    private func periodPill(_ period: AnalysisFeature.State.Period) -> some View {
        let isSelected = store.selectedPeriod == period
        return Button {
            store.send(.periodChanged(period))
        } label: {
            Text(period.displayName)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(
                    isSelected ? Color.Design.textInverse : Color.Design.textSecondary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.Design.textPrimary)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.Design.separator, lineWidth: 0.5)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var accountMenu: some View {
        if !store.accounts.isEmpty {
            Menu {
                Button(String(localized: "analysis_all_accounts")) {
                    store.send(.accountSelected(nil))
                }
                ForEach(store.accounts) { account in
                    Button(account.name) {
                        store.send(.accountSelected(account.id))
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.Design.textPrimary.opacity(0.06))
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Design.textPrimary)
                }
                .frame(width: 30, height: 30)
            }
        }
    }

    // MARK: - Helpers

    /// Returns an uppercase eyebrow label for the current period — e.g. "MAY 2026",
    /// "WEEK 19", or "2026".
    private func eyebrowLabel(for period: AnalysisFeature.State.Period) -> String {
        let now = Date()
        let cal = Calendar.current
        switch period {
        case .week:
            let week = cal.component(.weekOfYear, from: now)
            // Localized "WEEK 19" — kept simple/uppercase to match the design eyebrow.
            return String(format: "%@ %d", String(localized: "analysis_eyebrow_week").uppercased(), week)
        case .month:
            let f = DateFormatter()
            f.locale = .current
            f.setLocalizedDateFormatFromTemplate("MMM yyyy")
            return f.string(from: now).uppercased()
        case .year:
            let f = DateFormatter()
            f.locale = .current
            f.setLocalizedDateFormatFromTemplate("yyyy")
            return f.string(from: now)
        }
    }
}
