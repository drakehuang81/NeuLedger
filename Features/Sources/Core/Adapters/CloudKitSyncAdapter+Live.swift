import Foundation
import SwiftData
import Dependencies
import Domain

extension CloudKitSyncAdapter: DependencyKey {
    public static let liveValue = CloudKitSyncAdapter(
        isAvailable: {
            FileManager.default.ubiquityIdentityToken != nil
        },
        switchToCloudContainer: {
            // Enabling CloudKit sync is *not* a data migration — both
            // `localConfiguration` and `cloudConfiguration` point at the
            // same SQLite store file. We simply rebuild the
            // `ModelContainer` with the CloudKit-backed configuration so
            // SwiftData starts mirroring existing rows up to iCloud.
            try await MainActor.run {
                let cloudContainer = try ModelContainer(
                    for: DatabaseClient.schema,
                    configurations: [DatabaseClient.cloudConfiguration]
                )
                DatabaseClient.container = cloudContainer
            }
        },
        flushPendingChanges: {
            // CloudKit Mirroring (NSPersistentCloudKitContainer) has no
            // public "force sync now" API — the framework pushes and
            // pulls opportunistically over APNs. This entry point is
            // mostly a UX touchpoint: we nudge the main context to flush
            // pending changes (which queues a CloudKit export) so the
            // user sees something happened. CloudKit itself will run
            // whether we call this or not.
            await MainActor.run {
                let context = ModelContext(DatabaseClient.container)
                if context.hasChanges {
                    try? context.save()
                }
            }
        }
    )
}
