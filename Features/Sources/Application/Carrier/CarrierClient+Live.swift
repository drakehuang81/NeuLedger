import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `CarrierClient`.
///
/// Persistence goes directly through `CarrierStore` (no repository
/// indirection). The active-widget-carrier selection is stored via `\.userSettingsAdapter`
/// under the existing `.widgetCarrierId` key. Every mutation (`create` / `update` / `delete`
/// / `setActiveForWidget`) finishes by reloading the carrier widget through
/// `\.widgetSyncAdapter` — a post-condition lifted from `CarrierManagementFeature`'s former
/// manual reload calls.
extension CarrierClient: DependencyKey {
    public static var liveValue: CarrierClient {
        let store = CarrierStore()
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter
        @Dependency(\.widgetSyncAdapter) var widgetSyncAdapter

        return CarrierClient(
            listAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.createdAt)])
            },
            create: { carrier in
                try await store.add(carrier)
                let carriers = (try? await store.fetchAll(sortBy: [SortDescriptor(\.createdAt)])) ?? []
                await widgetSyncAdapter.syncAllCarriers(carriers)
            },
            update: { carrier in
                try await store.update(carrier)
                let carriers = (try? await store.fetchAll(sortBy: [SortDescriptor(\.createdAt)])) ?? []
                await widgetSyncAdapter.syncAllCarriers(carriers)
            },
            delete: { id in
                try await store.delete(id: id)
                let carriers = (try? await store.fetchAll(sortBy: [SortDescriptor(\.createdAt)])) ?? []
                await widgetSyncAdapter.syncAllCarriers(carriers)
            },
            setActiveForWidget: { id in
                userSettingsAdapter.setString(id.uuidString, .widgetCarrierId)
                let carriers = (try? await store.fetchAll(sortBy: [SortDescriptor(\.createdAt)])) ?? []
                await widgetSyncAdapter.syncAllCarriers(carriers)
            },
            activeForWidget: {
                let raw = userSettingsAdapter.string(.widgetCarrierId)
                guard !raw.isEmpty else { return nil }
                return UUID(uuidString: raw)
            }
        )
    }
}
