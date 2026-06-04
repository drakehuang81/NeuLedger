import Foundation
import SwiftData
import Dependencies
import Domain

/// Watches the SwiftData container for saves and pushes a fresh
/// `WatchContextSnapshot` to the Apple Watch. Coalesces bursty saves by
/// debouncing for 300 ms before rebuilding the snapshot.
@MainActor
public final class WatchSyncObserver {

    private let defaultAccountIdProvider: @Sendable () -> Account.ID?
    private var observerToken: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?

    public init(defaultAccountIdProvider: @escaping @Sendable () -> Account.ID?) {
        self.defaultAccountIdProvider = defaultAccountIdProvider
    }

    public func start() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRebuild()
            }
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
        @Dependency(\.watchBridgeAdapter) var bridge
        // Infrastructure-layer collaborator in the Watch sync pipeline:
        // resolves the fallback default account by reading SwiftData
        // directly via `SwiftDataStore` (same-layer, legal — see
        // docs/architecture.md §10). Mirrors the former
        // accountClient.fetchActive() (sorted, non-archived).
        let accountStore = SwiftDataStore<Account, SDAccount>()
        do {
            // Prefer the Watch-specific default account chosen in Settings →
            // Watch; fall back to the first active account so the Watch app
            // can still receive categories/accounts before the user has ever
            // visited that screen. Only bail when there is genuinely no
            // account at all — Watch has nothing useful to show then.
            let resolvedDefaultId: Account.ID
            if let chosen = defaultAccountIdProvider() {
                resolvedDefaultId = chosen
            } else if let first = try await accountStore
                .fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
                .first(where: { !$0.isArchived })?.id {
                resolvedDefaultId = first
            } else {
                return
            }
            let snapshot = try await WatchContextBuilder.build(
                defaultAccountId: resolvedDefaultId
            )
            try await bridge.pushContext(snapshot)
        } catch {
            // Swallow — WC retries on its own and a single failure is not
            // actionable. Surface via os_log in future iteration.
        }
    }
}
