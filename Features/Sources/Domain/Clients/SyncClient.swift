import Dependencies
import DependenciesMacros

/// Manages iCloud sync state and drives the one-time local → CloudKit migration.
@DependencyClient
public struct SyncClient: Sendable {
    /// Returns true if the device has an active iCloud account.
    public var isCloudKitAvailable: @Sendable () -> Bool = { false }

    /// Performs the one-time migration from local SwiftData to CloudKit-backed store.
    /// Yields Double progress values (0.0 – 1.0) and finishes when complete.
    /// Throws on failure; the caller is responsible for rollback UI.
    public var enableSync: @Sendable () -> AsyncThrowingStream<Double, Error> = { .finished() }
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
