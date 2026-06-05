import Domain

/// Thread-safe in-memory cache for AI-generated spending insights.
///
/// Uses a `String` cache key (derived from `SpendingSummary` fields) rather than `Hashable`
/// synthesis to avoid any Swift version compatibility questions around `Decimal.Hashable`.
/// Not persisted to disk — insights reflect fresh transaction data each app launch.
actor InsightCache {
    private var storage: [String: String] = [:]

    func get(for summary: SpendingSummary) -> String? {
        storage[cacheKey(for: summary)]
    }

    func set(_ insight: String, for summary: SpendingSummary) {
        storage[cacheKey(for: summary)] = insight
    }

    /// Produces a stable, deterministic key from all summary fields.
    /// Category breakdown is sorted alphabetically so insertion order doesn't affect the key.
    /// Format: "period|income|expense|cat1:amount1,cat2:amount2"
    ///
    /// `Decimal.description` (used via Swift string interpolation) is locale-independent on Apple
    /// platforms — it uses a fixed "." decimal separator regardless of device locale. This is safe.
    private func cacheKey(for summary: SpendingSummary) -> String {
        let cats = summary.categoryBreakdown
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        return "\(summary.periodDescription)|\(summary.totalIncome)|\(summary.totalExpense)|\(cats)"
    }
}
