import Foundation

/// FIFO ring of recently processed `TransactionDraft.id` values, backed by
/// `UserDefaults` so a process restart doesn't lose dedup state.
///
/// Capacity defaults to 200 — generous for "a Watch user records a few
/// dozen drafts a day"; small enough that JSON encoding stays trivial.
/// On overflow the oldest id is evicted.
public final class ProcessedDraftIdsStore: @unchecked Sendable {

    private static let storageKey = "watch.processed_draft_ids.v1"

    private let defaults: UserDefaults
    private let capacity: Int
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, capacity: Int = 200) {
        self.defaults = defaults
        self.capacity = capacity
    }

    public func contains(_ id: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return load().contains(id)
    }

    public func mark(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        var ids = load()
        if let existing = ids.firstIndex(of: id) {
            ids.remove(at: existing)
        }
        ids.append(id)
        while ids.count > capacity {
            ids.removeFirst()
        }
        save(ids)
    }

    private func load() -> [UUID] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings.compactMap(UUID.init(uuidString:))
    }

    private func save(_ ids: [UUID]) {
        let strings = ids.map(\.uuidString)
        guard let data = try? JSONEncoder().encode(strings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
