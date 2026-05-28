import Dependencies
import Domain
import Foundation
import SwiftData

extension CloudSyncUseCase: DependencyKey {
    public static var liveValue: CloudSyncUseCase {
        @Dependency(\.cloudKitSyncAdapter) var cloudKitSyncAdapter
        @Dependency(\.userSettingsRepository) var userSettingsRepository

        let isAvailable: @Sendable () -> Bool = {
            cloudKitSyncAdapter.isAvailable()
        }

        let isEnabled: @Sendable () -> Bool = {
            userSettingsRepository.bool(.isSyncEnabled)
        }

        let lastSyncedAt: @Sendable () -> Date? = {
            userSettingsRepository.date(.lastSyncedAt)
        }

        let capturedCloudKitSyncAdapter = cloudKitSyncAdapter
        let capturedUserSettingsRepository = userSettingsRepository

        let enable: @Sendable () -> AsyncThrowingStream<Double, Error> = {
            AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        continuation.yield(0.2)
                        try await capturedCloudKitSyncAdapter.switchToCloudContainer()
                        continuation.yield(0.8)

                        capturedUserSettingsRepository.setBool(true, .isSyncEnabled)
                        capturedUserSettingsRepository.setDate(Date(), .lastSyncedAt)

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
            userSettingsRepository.setDate(Date(), .lastSyncedAt)
        }

        let wipeAll: @Sendable () async throws -> Void = {
            // Order matters:
            //   1. Tear down cloud first so subsequent local saves don't
            //      stream half-deleted state back up to CloudKit.
            //   2. Wipe local rows.
            //   3. Rebuild the live ModelContainer against the local-only
            //      configuration so the next launch starts fresh (and so
            //      the running session doesn't keep holding a context
            //      bound to the now-empty cloud container).
            //   4. Clear preference flags last; once `hasCompletedOnboarding`
            //      flips false the UI layer routes back to onboarding.
            try await capturedCloudKitSyncAdapter.wipeCloudRecords()

            try await MainActor.run {
                let context = ModelContext(DatabaseClient.container)
                try context.delete(model: SDTransaction.self)
                try context.delete(model: SDAccount.self)
                try context.delete(model: SDCategory.self)
                try context.delete(model: SDBudget.self)
                try context.delete(model: SDTag.self)
                try context.delete(model: SDRecurringTransaction.self)
                try context.delete(model: SDCarrier.self)
                try context.save()

                // Rebuild as a local-only container so the next
                // `seedIfNeeded` runs without re-pulling stale cloud rows.
                let localContainer = try ModelContainer(
                    for: DatabaseClient.schema,
                    configurations: [DatabaseClient.localConfiguration]
                )
                DatabaseClient.container = localContainer
            }

            capturedUserSettingsRepository.setBool(false, .isSyncEnabled)
            capturedUserSettingsRepository.setBool(false, .hasCompletedOnboarding)
            capturedUserSettingsRepository.setDate(nil, .lastSyncedAt)
        }

        return CloudSyncUseCase(
            isAvailable: isAvailable,
            isEnabled: isEnabled,
            lastSyncedAt: lastSyncedAt,
            enable: enable,
            requestNow: requestNow,
            wipeAll: wipeAll
        )
    }
}
