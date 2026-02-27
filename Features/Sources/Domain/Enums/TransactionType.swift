import Foundation

/// A type representing the directional flow of funds for a transaction.
///
/// Use `TransactionType` to distinguish between outgoing, incoming, and internal monetary movements.
public enum TransactionType: String, Codable, CaseIterable, Equatable, Sendable {
    /// An outgoing payment that reduces the total asset balance.
    case expense
    
    /// An incoming payment that increases the total asset balance.
    case income
    
    /// A transfer of funds between two accounts, leaving the total asset balance unchanged.
    case transfer
}
