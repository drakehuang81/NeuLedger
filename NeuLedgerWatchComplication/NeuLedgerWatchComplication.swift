import SwiftUI
import WidgetKit
import WatchFeatures

/// Today's expense total displayed as a watchOS Complication.
///
/// Reads the latest `WatchContextSnapshot` from `WatchCacheStore`
/// (shared App Group `group.com.drake.NeuLedger`). Refresh comes from
/// explicit `WidgetCenter.reloadAllTimelines()` calls in
/// `WatchSessionGateway` whenever a new snapshot arrives — Apple's
/// own timeline scheduler is set to `.never`.
struct TodayExpenseProvider: TimelineProvider {

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let timeline = Timeline(entries: [currentEntry()], policy: .never)
        completion(timeline)
    }

    private func currentEntry() -> ComplicationEntry {
        guard let snapshot = WatchCacheStore().load() else {
            return ComplicationEntry.placeholder
        }
        return ComplicationEntry.from(snapshot: snapshot)
    }
}

struct TodayExpenseComplicationView: View {

    @Environment(\.widgetFamily) var family
    let entry: ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    circularBody
        case .accessoryCorner:      cornerBody
        case .accessoryRectangular: rectangularBody
        case .accessoryInline:      inlineBody
        @unknown default:           Text("—")
        }
    }

    private var hasSnapshot: Bool {
        !(entry.todayTotal == 0 && entry.todayCount == 0)
    }

    private var displayAmount: String {
        hasSnapshot ? entry.displayAmount : "—"
    }

    // MARK: families

    private var circularBody: some View {
        VStack(spacing: 0) {
            Text("今日")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(displayAmount)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
    }

    private var cornerBody: some View {
        Text(displayAmount)
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .widgetCurvesContent()
            .widgetLabel {
                if let progress = entry.monthBudgetProgress {
                    Gauge(value: progress.clamped(to: 0...1), in: 0...1) {
                        Text("月")
                    }
                } else {
                    Text("今日支出")
                }
            }
    }

    private var rectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("今日支出")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("NT$ \(displayAmount)")
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
            if entry.todayCount > 0 {
                Text("\(entry.todayCount) 筆交易")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineBody: some View {
        Text("今日 NT$ \(displayAmount)")
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct TodayExpenseComplication: Widget {

    let kind: String = "TodayExpenseComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayExpenseProvider()) { entry in
            TodayExpenseComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日支出")
        .description("顯示今日累計支出與本月預算進度。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
