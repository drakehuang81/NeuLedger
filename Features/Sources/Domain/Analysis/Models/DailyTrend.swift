import Foundation

public struct DailyTrend: Equatable, Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let amount: Decimal
    
    public init(date: Date, amount: Decimal) {
        self.date = date
        self.amount = amount
    }
}
