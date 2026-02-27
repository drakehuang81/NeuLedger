import Foundation

public enum AccountType: String, Codable, CaseIterable, Equatable, Sendable {
    case cash
    case bank
    case creditCard
    case eWallet
}
