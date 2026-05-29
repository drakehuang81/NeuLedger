import Foundation
import Domain
import Dependencies

extension DeeplinkClient: DependencyKey {
    public static var liveValue: DeeplinkClient {
        @Dependency(\.userSettingsRepository) var userSettingsRepository
        @Dependency(\.recurringTransactionClient) var recurringTransactionClient
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
            },
            resolveRecurringConfirmation: { id in
                let all = try await recurringTransactionClient.fetchAll()
                guard let template = all.first(where: { $0.id == id }) else { return .none }
                return .recurringConfirmation(template)
            }
        )
    }
}
