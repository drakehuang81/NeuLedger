import Testing
import SwiftData
import Foundation
import CoreData
import Dependencies
@testable import Core
import Domain

/// Mirror-push post-condition tests for `LedgerClient.liveValue` (step 5a2).
///
/// ## Why the spy watches context saves, not `watchBridgeAdapter`
///
/// The Watch mirror is pushed by `WatchSyncObserver`, which is started once at
/// app launch and reacts to `.NSManagedObjectContextDidSave`, debouncing 300 ms
/// before rebuilding and pushing a full `WatchContextSnapshot`. Every
/// `SwiftDataStore` mutation calls `context.save()`, so the observer already
/// mirrors each `record`/`update`/`delete` reactively. Having `LedgerClient`
/// *also* call `watchBridgeAdapter.pushContext` would push the same snapshot
/// twice per mutation — the double-push the plan forbids — and `WidgetSyncAdapter`
/// is carrier-only (no ledger widget data path exists), so there is nothing for
/// the widget side to mirror either.
///
/// The observable mirror post-condition is therefore "every ledger mutation
/// produces exactly one context save" — the trigger the reactive observer keys
/// off. These tests assert that contract directly by counting
/// `.NSManagedObjectContextDidSave` notifications, once per operation.
///
/// ## Why the spy filters by `NSPersistentStoreCoordinator`
///
/// `.NSManagedObjectContextDidSave` is posted to the process-wide
/// `NotificationCenter.default` with `object` = nil opt-in, so an unfiltered
/// observer also counts saves from **every other suite's** in-memory container
/// running in parallel (Swift Testing runs tests concurrently). That makes a
/// bare global count non-deterministic under the full scheme. All `ModelContext`
/// instances created from the *same* `ModelContainer` share one
/// `NSPersistentStoreCoordinator`, so the spy captures this test container's
/// coordinator up front and counts only saves whose context belongs to it,
/// isolating the assertion from cross-suite save traffic.
@Suite("LedgerClient Mirror Post-Condition Tests", .serialized)
struct LedgerClientMirrorTests {

    /// Counts `.NSManagedObjectContextDidSave` notifications **scoped to a single
    /// `ModelContainer`** — the exact signal `WatchSyncObserver` consumes to
    /// trigger a Watch mirror push.
    ///
    /// Uses synchronous delivery (`queue: nil`) so the count is incremented on
    /// the posting thread *before* the awaited store mutation returns; this
    /// avoids the run-loop-turn race a `.main`-queued observer would introduce
    /// and keeps the assertion deterministic (no flaky timing). Saves from other
    /// containers are ignored via the captured coordinator, so concurrent suites
    /// cannot inflate the count.
    final class SaveSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0
        private var token: NSObjectProtocol?
        private let coordinator: NSPersistentStoreCoordinator?

        var saveCount: Int {
            lock.lock(); defer { lock.unlock() }
            return _count
        }

        /// - Parameter coordinator: the persistent store coordinator of the test
        ///   container; only saves whose context shares this coordinator are
        ///   counted. Captured by ``LedgerClientMirrorTests/captureCoordinator(_:)``.
        init(coordinator: NSPersistentStoreCoordinator?) {
            self.coordinator = coordinator
            token = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: nil,
                queue: nil
            ) { [weak self] note in
                guard let self else { return }
                guard let context = note.object as? NSManagedObjectContext,
                      context.persistentStoreCoordinator === self.coordinator else { return }
                self.lock.lock()
                self._count += 1
                self.lock.unlock()
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }

    let container: ModelContainer
    let sut: LedgerClient
    let coordinator: NSPersistentStoreCoordinator?

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container
        self.coordinator = Self.captureCoordinator(_container)

        let testPersistenceBootstrap = PersistenceBootstrap(modelContainer: { _container })

        self.sut = withDependencies {
            $0.persistenceBootstrap = testPersistenceBootstrap
            $0.modelContainer = _container
            // Keep the budget post-condition a no-op so the only save observed
            // is the one performed by the transaction store itself.
            $0.planningClient.evaluateAfterTransaction = { _ in }
        } operation: {
            LedgerClient.liveValue
        }
    }

    /// Performs one throwaway insert+save on `container` and synchronously
    /// captures the coordinator of the context that posted the save. Runs before
    /// any `SaveSpy` exists, so this probe save is never counted. The capture
    /// observer is gated to the synchronous window of *this* probe save (and the
    /// captured save's id matches the probe object), so a concurrent suite's
    /// save cannot be mistaken for ours.
    private static func captureCoordinator(_ container: ModelContainer) -> NSPersistentStoreCoordinator? {
        let probeId = UUID()
        var captured: NSPersistentStoreCoordinator?
        var capturing = false
        let token = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { note in
            guard capturing, captured == nil,
                  let context = note.object as? NSManagedObjectContext else { return }
            // Confirm this save is the probe by matching the inserted object's id.
            let inserted = (note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
            let isProbe = inserted.contains { ($0.value(forKey: "id") as? UUID) == probeId }
            if isProbe { captured = context.persistentStoreCoordinator }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let probeContext = ModelContext(container)
        let probe = SDTransaction(
            id: probeId, amount: 0, date: Date(), accountId: "probe", type: "expense"
        )
        probeContext.insert(probe)
        capturing = true
        try? probeContext.save()
        capturing = false
        probeContext.delete(probe)
        try? probeContext.save()
        return captured
    }

    private func makeTransaction(id: UUID = UUID()) -> Transaction {
        Transaction(
            id: id, amount: 100, date: Date(), note: "Mirror", categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], aiSuggested: false, createdAt: Date(), updatedAt: Date()
        )
    }

    @Test("record produces exactly one context save (Watch mirror trigger)")
    func testRecordMirrorsOnce() async throws {
        let spy = SaveSpy(coordinator: coordinator)
        try await sut.record(makeTransaction())
        #expect(spy.saveCount == 1)
    }

    @Test("update produces exactly one context save (Watch mirror trigger)")
    func testUpdateMirrorsOnce() async throws {
        let id = UUID()
        try await sut.record(makeTransaction(id: id))

        let spy = SaveSpy(coordinator: coordinator)
        var updated = makeTransaction(id: id)
        updated.amount = 250
        try await sut.update(updated)
        #expect(spy.saveCount == 1)
    }

    @Test("delete produces exactly one context save (Watch mirror trigger)")
    func testDeleteMirrorsOnce() async throws {
        let id = UUID()
        try await sut.record(makeTransaction(id: id))

        let spy = SaveSpy(coordinator: coordinator)
        try await sut.delete(id)
        #expect(spy.saveCount == 1)
    }
}
