import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct CarrierClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Carrier]
    public var add: @Sendable (Carrier) async throws -> Void
    public var update: @Sendable (Carrier) async throws -> Void
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
