import Foundation
import Testing
import SwiftData
import Dependencies
import ComposableArchitecture
import Domain
@testable import Core

@Suite("WatchSessionDelegate Tests")
struct WatchSessionDelegateTests {

    /// Fake transport that only exercises the `onReceiveUserInfo` path.
    final class FakeTransport: WatchSessionTransport, @unchecked Sendable {
        var isActivated = false
        var isPaired = false
        var isWatchAppInstalled = false
        private var handler: (@Sendable ([String: Any]) -> Void)?

        func activate() { isActivated = true }
        func updateApplicationContext(_ context: [String: Any]) throws {}
        func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {
            self.handler = handler
        }
        func deliver(_ payload: [String: Any]) { handler?(payload) }
    }

    /// Fresh in-memory SwiftData container per test so the delegate's direct
    /// `TransactionStore` writes can be asserted by
    /// reading rows back out. Mirrors the pattern in `LedgerClientLiveTests`.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func storedTransactions(in container: ModelContainer) async throws -> [Transaction] {
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await TransactionStore().fetchAll()
        }
    }

    private func makeDedupStore() -> ProcessedDraftIdsStore {
        let suite = "WatchSessionDelegateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ProcessedDraftIdsStore(defaults: defaults, capacity: 10)
    }

    private func encodeDraft(_ draft: TransactionDraft) throws -> [String: Any] {
        let data = try JSONEncoder().encode(draft)
        return [
            "op": "addTx",
            "payload": data
        ]
    }

    @Test("Valid draft is forwarded to the SwiftData store as an expense")
    func validDraftIsForwardedToStore() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let container = try makeContainer()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 480
        )

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = try await storedTransactions(in: container)
        #expect(committed.count == 1)
        #expect(committed.first?.id == draft.id)
        #expect(committed.first?.amount == 480)
        #expect(committed.first?.accountId == draft.accountId)
        #expect(committed.first?.categoryId == draft.categoryId)
        #expect(committed.first?.type == .expense)
    }

    @Test("A draft delivered twice back-to-back, before the first write finishes, still commits only once")
    func concurrentDeliveryOfTheSameDraftCommitsOnlyOnce() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let container = try makeContainer()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 320
        )

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            // 兩次 deliver 之間刻意**不** await／不 sleep：`Task { }` 不會在建立
            // 呼叫內同步執行本體，所以第二次 deliver 的 parse() 幾乎必然搶在第一個
            // Task 開始跑之前執行——這是排程結構保證的次序，不是賭時間差。
            // `dedupStore` 此時還沒標記（要等 add 成功才標記，這正是 A8 的修法），
            // 真正擋下第二筆的必須是 in-flight 集合，不能是 dedupStore。
            transport.deliver(try! encodeDraft(draft))
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let committed = try await storedTransactions(in: container)
        #expect(committed.count == 1, "同一筆草稿在第一次寫入完成前又送達一次，不得寫入兩次（否則靜默遺失變成靜默重複）")
    }

    @Test("Duplicate draft delivered twice only commits once")
    func duplicateDraftIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let container = try makeContainer()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 100
        )

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = try await storedTransactions(in: container)
        #expect(committed.count == 1)
    }

    @Test("Malformed payload (non-Data) is silently ignored")
    func invalidPayloadIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let container = try makeContainer()

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(["op": "addTx", "payload": "not-data"])
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = try await storedTransactions(in: container)
        #expect(committed.isEmpty)
    }

    /// Thread-safe write counter for the injected `add` closure. Mirrors the
    /// `NSLock`-guarded pattern `ProcessedDraftIdsStore` already uses.
    private final class WriteCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.lock(); defer { lock.unlock() }
            value += 1
        }

        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    @Test("A draft whose write fails is not marked as processed, so WatchConnectivity can resend it")
    func failedWriteLeavesTheDraftResendable() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let writes = WriteCounter()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 250
        )

        let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup, add: { _ in
            writes.increment()
            throw CoreError.notFound("SDTransaction")
        })
        delegate.start()
        transport.deliver(try! encodeDraft(draft))
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 沒有這句就無法排除「parse 提早回 nil、add 根本沒被呼叫」的可能——
        // 那樣「未標記」只是預設狀態，不是本測試證明的結果。
        #expect(writes.count == 1, "寫入必須被嘗試過一次，否則下面的『未標記』斷言證明不了任何事")
        #expect(dedup.contains(draft.id) == false, "寫入失敗的 draft 不得被標記成已處理，否則 WC 重送會被擋掉")
    }

    @Test("A draft that was written successfully is marked so a resend is ignored")
    func successfulWriteMarksTheDraft() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let writes = WriteCounter()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 250
        )

        let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup, add: { _ in
            writes.increment()
        })
        delegate.start()

        transport.deliver(try! encodeDraft(draft))
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(dedup.contains(draft.id), "寫入成功就必須標記")

        // 重送同一筆——這句是順便驗證（`parse` 的既有 `contains` 去重擋下新寫入，
        // 本次 diff 沒動這段邏輯），不是 A8 的核心斷言；核心斷言是上面那句
        // `dedup.contains(draft.id)`。保留這句成本為零、多一層保險。
        transport.deliver(try! encodeDraft(draft))
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(writes.count == 1, "已處理的 draft 重送不得再寫一次")
    }
}
