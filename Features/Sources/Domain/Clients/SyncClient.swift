import Dependencies
import DependenciesMacros
import Foundation

/// Manages iCloud sync state and drives the one-time local → CloudKit migration.
@DependencyClient
public struct SyncClient: Sendable {
    /// Returns true if the device has an active iCloud account.
    public var isCloudKitAvailable: @Sendable () -> Bool = { false }

    /// Performs the one-time migration from local SwiftData to CloudKit-backed store.
    /// Yields Double progress values (0.0 – 1.0) and finishes when complete.
    /// Throws on failure; the caller is responsible for rollback UI.
    public var enableSync: @Sendable () -> AsyncThrowingStream<Double, Error> = { .finished() }

    /// Returns the timestamp at which CloudKit last successfully synced (or
    /// when sync was last manually triggered). `nil` if sync has never run.
    public var lastSyncedAt: @Sendable () -> Date? = { nil }

    /// Nudges CloudKit to flush pending changes. Always pads to a minimum
    /// visible duration so the calling UI can show a loading state. Updates
    /// the stored `lastSyncedAt` on success.
    public var requestSyncNow: @Sendable () async throws -> Void = {}
}

extension SyncClient: TestDependencyKey {
    public static let testValue = SyncClient()
}

public extension DependencyValues {
    var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
