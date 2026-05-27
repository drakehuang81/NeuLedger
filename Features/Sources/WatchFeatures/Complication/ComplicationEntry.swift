import Foundation
import Domain
#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(WidgetKit)
/// `TimelineEntry` carrying just the data the today-total Complication
/// needs. Built from `WatchContextSnapshot` (or `.placeholder` when the
/// snapshot is missing).
public struct ComplicationEntry: TimelineEntry, Equatable, Sendable {
    public let date: Date
    public let todayTotal: Decimal
    public let todayCount: Int
    public let monthBudgetProgress: Double?

    public init(
        date: Date,
        todayTotal: Decimal,
        todayCount: Int,
        monthBudgetProgress: Double?
    ) {
        self.date = date
        self.todayTotal = todayTotal
        self.todayCount = todayCount
        self.monthBudgetProgress = monthBudgetProgress
    }

    public static let placeholder = ComplicationEntry(
        date: Date(),
        todayTotal: 0,
        todayCount: 0,
        monthBudgetProgress: nil
    )

    public static func from(snapshot: WatchContextSnapshot, now: Date = Date()) -> ComplicationEntry {
        ComplicationEntry(
            date: now,
            todayTotal: snapshot.todayTotal,
            todayCount: snapshot.todayCount,
            monthBudgetProgress: snapshot.monthBudgetProgress
        )
    }

    /// Pre-formatted thousand-separated integer string for display.
    /// Watches show "NT$ \(displayAmount)" or just "\(displayAmount)".
    public var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: todayTotal as NSDecimalNumber) ?? "0"
    }
}
#endif
