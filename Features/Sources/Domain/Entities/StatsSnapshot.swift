import Foundation

/// A snapshot of summary spending statistics displayed in the Dashboard stats section.
public struct StatsSnapshot: Equatable, Sendable {
    public let today: Decimal
    public let week: Decimal
    public let savingsPercentage: Double

    public init(today: Decimal, week: Decimal, savingsPercentage: Double) {
        self.today = today
        self.week = week
        self.savingsPercentage = savingsPercentage
    }

    public static let zero = StatsSnapshot(today: 0, week: 0, savingsPercentage: 0)
}
