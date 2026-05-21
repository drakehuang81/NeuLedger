import Dependencies
import Domain
import Foundation

extension CloudSyncUseCase: DependencyKey {
    public static var liveValue: CloudSyncUseCase {
        @Dependency(\.cloudKitSyncAdapter) var cloudKitSyncAdapter
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        let isAvailable: @Sendable () -> Bool = {
            cloudKitSyncAdapter.isAvailable()
        }

        let isEnabled: @Sendable () -> Bool = {
            userSettingsAdapter.bool(.isSyncEnabled)
        }

        let lastSyncedAt: @Sendable () -> Date? = {
            userSettingsAdapter.date(.lastSyncedAt)
        }

        let capturedCloudKitSyncAdapter = cloudKitSyncAdapter
        let capturedUserSettingsAdapter = userSettingsAdapter

        let enable: @Sendable () -> AsyncThrowingStream<Double, Error> = {
            AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        continuation.yield(0.2)
                        try await capturedCloudKitSyncAdapter.switchToCloudContainer()
                        continuation.yield(0.8)

                        capturedUserSettingsAdapter.setBool(true, .isSyncEnabled)
                        capturedUserSettingsAdapter.setDate(Date(), .lastSyncedAt)

                        continuation.yield(1.0)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        let requestNow: @Sendable () async throws -> Void = {
            await cloudKitSyncAdapter.flushPendingChanges()
            userSettingsAdapter.setDate(Date(), .lastSyncedAt)
        }

        return CloudSyncUseCase(
            isAvailable: isAvailable,
            isEnabled: isEnabled,
            lastSyncedAt: lastSyncedAt,
            enable: enable,
            requestNow: requestNow
        )
    }
}
