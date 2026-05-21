import Dependencies
import DependenciesMacros
import Foundation

/// Manages iCloud sync state and drives the one-time local → CloudKit
/// migration.
///
/// Surface follows `docs/architecture.md` §5 Sync Context. Live
/// implementation delegates `NSPersistentCloudKitContainer` lifecycle
/// to `CloudKitSyncAdapter` and reads/writes preference flags via
/// `UserSettingsAdapter`.
@DependencyClient
public struct CloudSyncUseCase: Sendable {
    /// Whether the device has an active iCloud account that we can
    /// associate the CloudKit container with.
    public var isAvailable: @Sendable () -> Bool = { false }

    /// Whether the user has enabled CloudKit-backed sync (the
    /// SwiftData container is currently running against the CloudKit
    /// configuration).
    public var isEnabled: @Sendable () -> Bool = { false }

    /// Returns the timestamp at which CloudKit last successfully
    /// synced (or when sync was last manually triggered). `nil` if
    /// sync has never run.
    public var lastSyncedAt: @Sendable () -> Date? = { nil }

    /// Enable CloudKit sync — rebuilds the `ModelContainer` against
    /// the CloudKit configuration so existing local rows start
    /// mirroring up. Yields progress values (0.0 – 1.0) and finishes
    /// on success; throws on failure for the caller to roll back the
    /// UI.
    public var enable: @Sendable () -> AsyncThrowingStream<Double, Error> = { .finished() }

    /// Nudges CloudKit to flush pending changes and updates the
    /// stored `lastSyncedAt`. CloudKit Mirroring has no public "force
    /// sync now" API; this is mostly a UX touchpoint.
    public var requestNow: @Sendable () async throws -> Void = {}
}

extension CloudSyncUseCase: TestDependencyKey {
    public static let testValue = CloudSyncUseCase()
}

public extension DependencyValues {
    var cloudSyncUseCase: CloudSyncUseCase {
        get { self[CloudSyncUseCase.self] }
        set { self[CloudSyncUseCase.self] = newValue }
    }
}
