import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing the user's stored e-invoice carriers, including the
/// carrier currently bound to the CarrierWidget.
///
/// `CarrierClient` consolidates carrier persistence (CRUD) together with widget-facing
/// concerns: which carrier is active for the widget, and triggering widget timeline
/// reloads after every mutation. The Features layer drives carrier management entirely
/// through this client.
@DependencyClient
public struct CarrierClient: Sendable {
    /// Fetches all stored carriers.
    public var listAll: @Sendable () async throws -> [Carrier]

    /// Persists a newly created carrier, then reloads the carrier widget.
    public var create: @Sendable (_ carrier: Carrier) async throws -> Void

    /// Updates an existing carrier, then reloads the carrier widget.
    public var update: @Sendable (_ carrier: Carrier) async throws -> Void

    /// Removes a carrier from storage, then reloads the carrier widget.
    public var delete: @Sendable (_ id: Carrier.ID) async throws -> Void

    /// Marks the carrier with the given id as the active carrier for the widget, then
    /// reloads the carrier widget.
    public var setActiveForWidget: @Sendable (_ id: Carrier.ID) async -> Void

    /// Returns the id of the carrier currently bound to the widget, or `nil` if none.
    public var activeForWidget: @Sendable () -> Carrier.ID? = { nil }
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
