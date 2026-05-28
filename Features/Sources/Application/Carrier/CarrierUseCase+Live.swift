import Foundation
import Dependencies
import Domain

extension CarrierUseCase: DependencyKey {
    public static var liveValue: CarrierUseCase {
        @Dependency(\.carrierClient) var carrierClient
        @Dependency(\.userSettingsRepository) var userSettingsRepository

        return CarrierUseCase(
            listAll: { try await carrierClient.fetchAll() },
            create: { try await carrierClient.add($0) },
            update: { try await carrierClient.update($0) },
            delete: { try await carrierClient.delete($0) },
            setActiveForWidget: { id in
                userSettingsRepository.setString(id.uuidString, .widgetCarrierId)
            },
            activeForWidget: {
                let raw = userSettingsRepository.string(.widgetCarrierId)
                guard !raw.isEmpty else { return nil }
                return UUID(uuidString: raw)
            }
        )
    }
}
