import Foundation
import Dependencies
import Domain

extension CarrierUseCase: DependencyKey {
    public static var liveValue: CarrierUseCase {
        @Dependency(\.carrierClient) var carrierClient
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        return CarrierUseCase(
            listAll: { try await carrierClient.fetchAll() },
            create: { try await carrierClient.add($0) },
            update: { try await carrierClient.update($0) },
            delete: { try await carrierClient.delete($0) },
            setActiveForWidget: { id in
                userSettingsAdapter.setString(id.uuidString, .widgetCarrierId)
            },
            activeForWidget: {
                let raw = userSettingsAdapter.string(.widgetCarrierId)
                guard !raw.isEmpty else { return nil }
                return UUID(uuidString: raw)
            }
        )
    }
}
