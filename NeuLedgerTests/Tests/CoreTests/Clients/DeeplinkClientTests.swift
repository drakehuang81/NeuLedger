import Testing
import Dependencies
import Foundation
@testable import Domain
@testable import Core

@Suite("DeeplinkClient Tests")
struct DeeplinkClientTests {

    // MARK: - parseLinkTo

    @Test("parseLinkTo returns .carrierManagement for neuledger://carrier-management")
    func parseCarrierManagementHost() async throws {
        let client = DeeplinkClient.liveValue
        let url = URL(string: "neuledger://carrier-management")!

        let result = try await client.parseLinkTo(url)

        #expect(result == .carrierManagement)
    }

    @Test("parseLinkTo returns .none for unknown neuledger host")
    func parseUnknownHost() async throws {
        let client = DeeplinkClient.liveValue
        let url = URL(string: "neuledger://something-else")!

        let result = try await client.parseLinkTo(url)

        #expect(result == .none)
    }

    @Test("parseLinkTo returns .none for non-neuledger scheme")
    func parseForeignScheme() async throws {
        let client = DeeplinkClient.liveValue
        let url = URL(string: "https://example.com/carrier-management")!

        let result = try await client.parseLinkTo(url)

        #expect(result == .none)
    }

    // MARK: - canSkipOnboarding

    @Test("canSkipOnboarding returns true when hasCompletedOnboarding flag is true")
    func canSkipWhenOnboardingCompleted() async throws {
        try await withDependencies {
            $0.userSettingsRepository.bool = { key in
                key.rawValue == SettingsKey<Bool>.hasCompletedOnboarding.rawValue
            }
        } operation: {
            let client = DeeplinkClient.liveValue
            let result = try await client.canSkipOnboarding()
            #expect(result == true)
        }
    }

    @Test("canSkipOnboarding returns false when hasCompletedOnboarding flag is false")
    func cannotSkipWhenOnboardingIncomplete() async throws {
        try await withDependencies {
            $0.userSettingsRepository.bool = { _ in false }
        } operation: {
            let client = DeeplinkClient.liveValue
            let result = try await client.canSkipOnboarding()
            #expect(result == false)
        }
    }

    // MARK: - testValue

    @Test("testValue is accessible via DependencyValues")
    func testValueRegistered() {
        withDependencies {
            $0.deeplinkClient = .testValue
        } operation: {
            @Dependency(\.deeplinkClient) var client
            _ = client
        }
    }
}
