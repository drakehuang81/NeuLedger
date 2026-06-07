import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
@testable import WatchFeatures

@MainActor
@Suite("WatchAppFeature Tests")
struct WatchAppFeatureTests {

    private static let foodCategory = Domain.Category(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Food", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: true
    )

    @Test("Paging locks while the record flow is past the category step")
    func pagingLocksDuringEntry() async {
        // ⚠️ TCA Scope：parent 測試會走到 child 依賴。此測試只送純狀態
        // action（categoryTapped / cancelTapped 不碰 client），故無需 stub。
        let store = TestStore(
            initialState: WatchAppFeature.State(
                record: WatchRecordFeature.State(categories: [Self.foodCategory])
            )
        ) {
            WatchAppFeature()
        }

        #expect(store.state.isPagingLocked == false)

        await store.send(.record(.categoryTapped(Self.foodCategory.id))) {
            $0.record.draft = WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: nil
            )
            $0.record.step = .amount
        }
        #expect(store.state.isPagingLocked)

        await store.send(.record(.cancelTapped)) {
            $0.record.draft = nil
            $0.record.step = .category
        }
        #expect(store.state.isPagingLocked == false)
    }

    @Test("Tab selection binds")
    func tabSelectionBinds() async {
        let store = TestStore(initialState: WatchAppFeature.State()) {
            WatchAppFeature()
        }

        await store.send(.binding(.set(\.tab, .carrier))) {
            $0.tab = .carrier
        }
        await store.send(.binding(.set(\.tab, .record))) {
            $0.tab = .record
        }
    }

    // MARK: - Task 1: draftSent unlocks paging

    @Test("draftSent resets step to .category and unlocks paging")
    func draftSentUnlocksPaging() async {
        // Set up: record flow in .confirm step (paging locked)
        let initialState = WatchAppFeature.State(
            record: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Account(
                    id: "33333333-3333-3333-3333-333333333333",
                    name: "Cash", type: .cash, icon: "banknote", color: "#34C759",
                    sortOrder: 0, isArchived: false,
                    createdAt: Date(timeIntervalSince1970: 0)
                )],
                defaultAccountId: "33333333-3333-3333-3333-333333333333",
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 100
                ),
                step: .confirm
            )
        )

        let store = TestStore(initialState: initialState) {
            WatchAppFeature()
        } withDependencies: {
            // confirmTapped triggers ledgerClient.record; stub it as no-op.
            $0.watchLedgerClient.record = { @Sendable _ in }
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .incrementing
        }

        // Confirm paging is locked at confirm step
        #expect(store.state.isPagingLocked)

        await store.send(.record(.confirmTapped))
        await store.receive(\.record.draftSent) {
            $0.record.draft = nil
            $0.record.step = .category
        }

        // After draftSent, step is .category → isPagingLocked must be false
        #expect(store.state.isPagingLocked == false)
    }

    // MARK: - Task 2: carrier Scope forwarding

    @Test("carrierTapped is forwarded through Scope and sets presentedCarrierID")
    func carrierTappedForwardedToChild() async {
        let carrierId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let carrier = Carrier(
            id: carrierId,
            name: "手機條碼", type: .phoneBarcodeCarrier,
            barcode: "/AB12+CD",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let initialState = WatchAppFeature.State(
            carrier: WatchCarrierFeature.State(carriers: [carrier])
        )

        let store = TestStore(initialState: initialState) {
            WatchAppFeature()
        }

        // Send through App-level .carrier scope — verifies Scope wiring is correct
        await store.send(.carrier(.carrierTapped(carrierId))) {
            $0.carrier.presentedCarrierID = carrierId
        }
        #expect(store.state.carrier.presentedCarrier == carrier)

        await store.send(.carrier(.barcodeDismissed)) {
            $0.carrier.presentedCarrierID = nil
        }
        #expect(store.state.carrier.presentedCarrier == nil)
    }
}
