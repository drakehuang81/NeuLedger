import Foundation
import Dependencies
import DependenciesMacros

// `RouteLinkDestination` relocated to
// `Domain/ValueObjects/RouteLinkDestination.swift` (same module).

// MARK: - DeeplinkClient

@DependencyClient
public struct DeeplinkClient: Sendable {

    public var parseLinkTo: @Sendable (URL) async throws -> RouteLinkDestination

    public var canSkipOnboarding: @Sendable () async throws -> Bool

    public var resolveRecurringConfirmation: @Sendable (_ id: RecurringTransaction.ID) async throws -> RouteLinkDestination
}

// MARK: - TestDependencyKey

extension DeeplinkClient: TestDependencyKey {
    public static let testValue = Self()
}

// MARK: - DependencyValues

public extension DependencyValues {
    var deeplinkClient: DeeplinkClient {
        get { self[DeeplinkClient.self] }
        set { self[DeeplinkClient.self] = newValue }
    }
}
