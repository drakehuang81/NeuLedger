import Foundation

/// Errors produced by the Core persistence layer.
public enum CoreError: Error, LocalizedError, Sendable {
    /// The requested entity was not found.
    case notFound(String)

    /// An operation was rejected due to a business rule violation.
    case operationDenied(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let entity):
            return "Entity not found: \(entity)"
        case .operationDenied(let reason):
            return "Operation denied: \(reason)"
        }
    }
}
