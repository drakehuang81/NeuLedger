import Foundation
import SwiftData
import Dependencies
import Domain

/// Watches the SwiftData container for saves and pushes a fresh
/// `WatchContextSnapshot` to the Apple Watch. Coalesces bursty saves by
/// debouncing for 300 ms before rebuilding the snapshot.
@MainActor
public final class WatchSyncObserver {

    private let defaultAccountIdProvider: @Sendable () -> UUID?
    private var observerToken: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?

    public init(defaultAccountIdProvider: @escaping @Sendable () -> UUID?) {
        self.defaultAccountIdProvider = defaultAccountIdProvider
    }

    public func start() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRebuild()
        }
        scheduleRebuild()
    }

    public func stop() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
        observerToken = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func scheduleRebuild() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard Task.isCancelled == false else { return }
            await self?.rebuildAndPush()
        }
    }

    private func rebuildAndPush() async {
        guard let defaultAccountId = defaultAccountIdProvider() else { return }
        @Dependency(\.watchBridgeAdapter) var bridge
        do {
            let snapshot = try await WatchContextBuilder.build(
                defaultAccountId: defaultAccountId
            )
            try await bridge.pushContext(snapshot)
        } catch {
            // Swallow — WC retries on its own and a single failure is not
            // actionable. Surface via os_log in future iteration.
        }
    }
}
