import Dependencies
import Domain
import Foundation
import SwiftData

extension SyncClient: DependencyKey {
    public static var liveValue: SyncClient {
        @Dependency(\.userSettingsClient) var userSettingsClient
        let capturedUserSettingsClient = userSettingsClient

        return SyncClient(
            isCloudKitAvailable: {
                FileManager.default.ubiquityIdentityToken != nil
            },
            enableSync: {
                // Enabling CloudKit sync is *not* a data migration — both
                // `localConfiguration` and `cloudConfiguration` point at the
                // same SQLite store file. We simply rebuild the
                // `ModelContainer` with the CloudKit-backed configuration so
                // SwiftData starts mirroring existing rows up to iCloud.
                //
                // The progress stream still yields a few intermediate ticks
                // so the UI's loading animation has something to render
                // during the (typically sub-second) container handover.
                AsyncThrowingStream { continuation in
                    let task = Task { @MainActor in
                        do {
                            continuation.yield(0.2)

                            let cloudContainer = try ModelContainer(
                                for: DatabaseClient.schema,
                                configurations: [DatabaseClient.cloudConfiguration]
                            )
                            continuation.yield(0.8)

                            DatabaseClient.container = cloudContainer
                            capturedUserSettingsClient.setBool(true, .isSyncEnabled)

                            capturedUserSettingsClient.setDate(Date(), .lastSyncedAt)

                            continuation.yield(1.0)
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            lastSyncedAt: {
                capturedUserSettingsClient.date(.lastSyncedAt)
            },
            requestSyncNow: {
                // CloudKit Mirroring (NSPersistentCloudKitContainer) has no
                // public "force sync now" API — the framework pushes and
                // pulls opportunistically over APNs. This method is mostly a
                // UX touchpoint: we nudge the main context to flush pending
                // changes (which queues a CloudKit export) and update the
                // visible "last synced" timestamp so the user sees something
                // happened. CloudKit itself will run whether we call this
                // or not.
                await MainActor.run {
                    let context = ModelContext(DatabaseClient.container)
                    if context.hasChanges {
                        try? context.save()
                    }
                }
                capturedUserSettingsClient.setDate(Date(), .lastSyncedAt)
            }
        )
    }
}
