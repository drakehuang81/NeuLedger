import Foundation
import Testing
@testable import Core

@Suite("ProcessedDraftIdsStore Tests")
struct ProcessedDraftIdsStoreTests {

    private func makeStore() -> (ProcessedDraftIdsStore, UserDefaults) {
        let suite = "ProcessedDraftIdsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = ProcessedDraftIdsStore(defaults: defaults, capacity: 3)
        return (store, defaults)
    }

    @Test("New ids are not marked processed")
    func newIdsAreNotMarkedProcessed() {
        let (store, _) = makeStore()
        let id = UUID()
        #expect(store.contains(id) == false)
    }

    @Test("Marked ids are reported as processed")
    func markedIdsAreReportedAsProcessed() {
        let (store, _) = makeStore()
        let id = UUID()
        store.mark(id)
        #expect(store.contains(id) == true)
    }

    @Test("Beyond capacity, oldest entry is evicted")
    func evictsOldestBeyondCapacity() {
        let (store, _) = makeStore()
        let ids = (0..<4).map { _ in UUID() }
        for id in ids { store.mark(id) }

        #expect(store.contains(ids[0]) == false)
        #expect(store.contains(ids[1]) == true)
        #expect(store.contains(ids[2]) == true)
        #expect(store.contains(ids[3]) == true)
    }

    @Test("State survives a fresh store opened on the same defaults")
    func survivesRoundTripThroughDefaults() {
        let suite = "ProcessedDraftIdsStoreTests.RoundTrip.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let id = UUID()
        ProcessedDraftIdsStore(defaults: defaults, capacity: 10).mark(id)

        let reopened = ProcessedDraftIdsStore(defaults: defaults, capacity: 10)
        #expect(reopened.contains(id) == true)
    }
}
