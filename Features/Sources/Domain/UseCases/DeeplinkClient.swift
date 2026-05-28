import Foundation
import CasePaths
import Dependencies
import DependenciesMacros

// MARK: - RouteLinkDestination

@CasePathable
public enum RouteLinkDestination: Sendable, Equatable {
    case carrierManagement
    case main
    case onboarding
    case none
}

// MARK: - DeeplinkClient

@DependencyClient
public struct DeeplinkClient: Sendable {

    public var parseLinkTo: @Sendable (URL) async throws -> RouteLinkDestination

    public var canSkipOnboarding: @Sendable () async throws -> Bool
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
