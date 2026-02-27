import Foundation

public enum TransactionType: String, Codable, CaseIterable, Equatable, Sendable {
    case expense
    case income
    case transfer
}
