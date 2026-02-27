import Foundation

public enum BudgetPeriod: String, Codable, CaseIterable, Equatable, Sendable {
    case weekly
    case monthly
    case yearly
}
