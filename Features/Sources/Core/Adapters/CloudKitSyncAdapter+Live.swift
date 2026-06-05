import CloudKit
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
                    for: PersistenceBootstrap.schema,
                    configurations: [PersistenceBootstrap.cloudConfiguration]
                )
                PersistenceBootstrap.container = cloudContainer
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
                let context = ModelContext(PersistenceBootstrap.container)
                if context.hasChanges {
                    try? context.save()
                }
            }
        },
        wipeCloudRecords: {
            // SwiftData mirrors all `@Model` types into a single private
            // custom zone owned by NSPersistentCloudKitContainer. Deleting
            // the zone removes every CKRecord this app stores under the
            // signed-in iCloud account in one round-trip — no need to
            // enumerate record types.
            let container = CKContainer(identifier: "iCloud.com.drake.NeuLedger")
            let database = container.privateCloudDatabase
            let zoneID = CKRecordZone.ID(
                zoneName: "com.apple.coredata.cloudkit.zone",
                ownerName: CKCurrentUserDefaultName
            )
            do {
                _ = try await database.deleteRecordZone(withID: zoneID)
            } catch let error as CKError where error.code == .zoneNotFound {
                // No zone yet (sync was never enabled, or it was already
                // wiped). Treat as success — the postcondition holds.
                return
            }
        }
    )
}
