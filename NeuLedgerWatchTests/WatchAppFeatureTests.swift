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
}
