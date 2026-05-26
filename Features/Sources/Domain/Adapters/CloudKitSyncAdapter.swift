import Foundation
import Dependencies
import DependenciesMacros

/// Low-level adapter wrapping `NSPersistentCloudKitContainer` lifecycle
/// (architecture.md §7 Adapter Catalog).
///
/// `CloudKitSyncAdapter` owns the SwiftData container-handover dance
/// when the user enables iCloud sync — the same store file is reopened
/// against the CloudKit-backed configuration so existing rows start
/// mirroring up automatically. `CloudSyncUseCase` (UseCase layer)
/// orchestrates the broader flow (progress yields, preference flags,
/// last-sync timestamp).
@DependencyClient
public struct CloudKitSyncAdapter: Sendable {
    /// Whether the device has an active iCloud account that we can
    /// associate the CloudKit container with.
    public var isAvailable: @Sendable () -> Bool = { false }

    /// Replace the process-wide live container with a fresh CloudKit-
    /// backed one. The same store URL is reopened against the CloudKit
    /// configuration, so existing local rows are preserved and start
    /// mirroring.
    public var switchToCloudContainer: @Sendable () async throws -> Void

    /// Nudge the live container's main context to flush pending writes
    /// (which queues a CloudKit export over APNs). Best-effort — errors
    /// are swallowed because CloudKit will retry whether we call this
    /// or not.
    public var flushPendingChanges: @Sendable () async -> Void

    /// Delete the CloudKit private-database zone that
    /// `NSPersistentCloudKitContainer` mirrors into. Used by the
    /// destructive "wipe all data" debug action — clears every CKRecord
    /// for this app under the user's iCloud account in one shot.
    public var wipeCloudRecords: @Sendable () async throws -> Void
}

extension CloudKitSyncAdapter: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var cloudKitSyncAdapter: CloudKitSyncAdapter {
        get { self[CloudKitSyncAdapter.self] }
        set { self[CloudKitSyncAdapter.self] = newValue }
    }
}
