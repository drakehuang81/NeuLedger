import Foundation
import SwiftData
import Dependencies
import Domain

/// Schedules a single Task that wakes up at the next local midnight and
/// pushes a fresh `WatchContextSnapshot` to the Watch, so the
/// today-total Complication and Watch UI reset cleanly at 00:00.
///
/// `WatchSyncObserver` calls `arm()` after its initial push and any
/// time the app foregrounds (the previous Task is cancelled and
/// re-armed for the new `nextMidnight` value).
@MainActor
public final class WatchMidnightTimer {

    private let defaultAccountIdProvider: @Sendable () -> Account.ID?
    private var task: Task<Void, Never>?

    public init(defaultAccountIdProvider: @escaping @Sendable () -> Account.ID?) {
        self.defaultAccountIdProvider = defaultAccountIdProvider
    }

    public func arm(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) {
        task?.cancel()
        guard let fireAt = Self.nextMidnight(after: now, calendar: calendar) else { return }
        let delay = fireAt.timeIntervalSince(now)
        guard delay > 0 else { return }
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard Task.isCancelled == false else { return }
            await self?.fire()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }

    private func fire() async {
        @Dependency(\.watchBridgeAdapter) var bridge
        // Infrastructure-layer collaborator in the Watch sync pipeline:
        // resolves the fallback default account by reading SwiftData
        // directly via `SwiftDataStore` (same-layer, legal — see
        // docs/architecture.md §10). Mirrors the former
        // accountClient.fetchActive() (sorted, non-archived).
        let accountStore = AccountStore()
        do {
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
            // Swallow — WC retries; one missed midnight push is not
            // actionable. The next SwiftData save will push a correct
            // snapshot anyway.
        }
    }

    /// Returns the next local midnight strictly after `now`. If `now` is
    /// already exactly midnight, returns 24 hours after `now`.
    public nonisolated static func nextMidnight(after now: Date, calendar: Calendar) -> Date? {
        let startOfDay = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        if let nextDay, nextDay > now { return nextDay }
        return calendar.date(byAdding: .day, value: 1, to: nextDay ?? now)
    }
}
