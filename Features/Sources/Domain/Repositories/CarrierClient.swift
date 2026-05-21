import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing the user's stored e-invoice carriers.
///
/// Use `CarrierClient` to create, retrieve, update, and remove ``Carrier`` records that the user
/// keeps on file for quick selection when logging transactions linked to a government carrier.
@DependencyClient
public struct CarrierClient: Sendable {
    /// Fetches all stored carriers.
    ///
    /// - Returns: An array of all persisted ``Carrier`` entities.
    public var fetchAll: @Sendable () async throws -> [Carrier]

    /// Adds a newly created carrier.
    ///
    /// - Parameter carrier: The ``Carrier`` entity to persist.
    public var add: @Sendable (Carrier) async throws -> Void

    /// Updates an existing carrier.
    ///
    /// - Parameter carrier: The modified ``Carrier`` entity. Its `id` must match an existing record.
    public var update: @Sendable (Carrier) async throws -> Void

    /// Removes a carrier from storage.
    ///
    /// - Parameter id: The unique identifier of the ``Carrier`` to delete.
    public var delete: @Sendable (Carrier.ID) async throws -> Void
}

extension CarrierClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var carrierClient: CarrierClient {
        get { self[CarrierClient.self] }
        set { self[CarrierClient.self] = newValue }
    }
}
