import Foundation
import Domain
import Dependencies

extension DeeplinkClient: DependencyKey {
    public static var liveValue: DeeplinkClient {
        @Dependency(\.userSettingsRepository) var userSettingsRepository
        return .init(
            parseLinkTo: { url in
                guard url.scheme == "neuledger" else { return .none }
                switch url.host {
                case "carrier-management":
                    return .carrierManagement
                default:
                    return .none
                }
            },
            canSkipOnboarding: {
                return userSettingsRepository.bool(.hasCompletedOnboarding)
            }
        )
    }
}
