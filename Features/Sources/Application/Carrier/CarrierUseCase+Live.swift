import Foundation
import Dependencies
import Domain

extension CarrierUseCase: DependencyKey {
    public static var liveValue: CarrierUseCase {
        @Dependency(\.carrierRepository) var carrierRepository
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        return CarrierUseCase(
            listAll: { try await carrierRepository.fetchAll() },
            create: { try await carrierRepository.add($0) },
            update: { try await carrierRepository.update($0) },
            delete: { try await carrierRepository.delete($0) },
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
