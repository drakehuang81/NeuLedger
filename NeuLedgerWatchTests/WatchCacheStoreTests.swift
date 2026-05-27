import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("WatchCacheStore Tests")
struct WatchCacheStoreTests {

    private func makeStore() -> (WatchCacheStore, UserDefaults) {
        let suite = "WatchCacheStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (WatchCacheStore(defaults: defaults), defaults)
    }

    private func makeSnapshot(
        todayTotal: Decimal = 480,
        defaultAccountId: UUID = UUID()
    ) -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [
                Category(id: UUID(), name: "Food", icon: "fork.knife",
                         color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true)
            ],
            accounts: [
                Account(id: defaultAccountId, name: "Cash", type: .cash,
                        icon: "banknote", color: "#34C759", sortOrder: 0,
                        isArchived: false, createdAt: Date(timeIntervalSince1970: 0))
            ],
            defaultAccountId: defaultAccountId,
            todayTotal: todayTotal,
            todayCount: 2,
            monthBudgetProgress: 0.62,
            snapshotAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("Reading an empty store returns nil")
    func emptyStoreReturnsNil() {
        let (store, _) = makeStore()
        #expect(store.load() == nil)
    }

    @Test("Saved snapshot round-trips through UserDefaults")
    func savedSnapshotRoundTrips() {
        let (store, _) = makeStore()
        let original = makeSnapshot()
        store.save(original)
        let loaded = store.load()
        #expect(loaded == original)
    }

    @Test("Saving overwrites previous snapshot")
    func savingOverwritesPrevious() {
        let (store, _) = makeStore()
        store.save(makeSnapshot(todayTotal: 100))
        store.save(makeSnapshot(todayTotal: 999))
        #expect(store.load()?.todayTotal == 999)
    }

    @Test("Saved snapshot survives a fresh store opened on the same defaults")
    func persistsAcrossInstances() {
        let suite = "WatchCacheStoreTests.Persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let snapshot = makeSnapshot(todayTotal: 250)
        WatchCacheStore(defaults: defaults).save(snapshot)

        let reopened = WatchCacheStore(defaults: defaults).load()
        #expect(reopened?.todayTotal == 250)
    }
}
