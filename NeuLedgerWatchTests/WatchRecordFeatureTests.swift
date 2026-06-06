import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
import ConcurrencyExtras
@testable import WatchFeatures

@MainActor
@Suite("WatchRecordFeature Tests")
struct WatchRecordFeatureTests {

    private static let foodCategory = Domain.Category(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Food", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: true
    )

    private static let transportCategory = Domain.Category(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Transport", icon: "car", color: "#5AC8FA",
        type: .expense, sortOrder: 1, isDefault: true
    )

    private static let cashAccount = Account(
        id: "33333333-3333-3333-3333-333333333333",
        name: "Cash", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    private static let cardAccount = Account(
        id: "44444444-4444-4444-4444-444444444444",
        name: "Card", type: .creditCard, icon: "creditcard",
        color: "#5E5CE6", sortOrder: 1, isArchived: false,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test("Loading state populates categories, default account, and accounts")
    func loadingPopulatesState() async {
        let store = TestStore(initialState: WatchRecordFeature.State()) {
            WatchRecordFeature()
        } withDependencies: {
            $0.watchLedgerClient.categories = { @Sendable type in
                type == .expense ? [Self.foodCategory, Self.transportCategory] : []
            }
            $0.watchLedgerClient.activeAccounts = { @Sendable in
                [Self.cashAccount, Self.cardAccount]
            }
        }

        // `.task` keeps a notification subscription alive for cache
        // updates — cancel it explicitly once the load assertion is done.
        let task = await store.send(.task)
        await store.receive(\.loaded) {
            $0.categories = [Self.foodCategory, Self.transportCategory]
            $0.accounts = [Self.cashAccount, Self.cardAccount]
            $0.defaultAccountId = Self.cashAccount.id
        }
        await task.cancel()
    }

    @Test("Selecting a category advances to amount step")
    func selectingCategoryAdvancesToAmount() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.categoryTapped(Self.foodCategory.id)) {
            $0.draft = WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: nil
            )
            $0.step = .amount
        }
    }

    @Test("Confirming a draft sends to transactionClient and resets state")
    func confirmingSendsAndResets() async {
        let added = LockIsolated<[Transaction]>([])

        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id,
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 480
                ),
                step: .confirm
            )
        ) {
            WatchRecordFeature()
        } withDependencies: {
            $0.watchLedgerClient.record = { @Sendable tx in
                added.withValue { $0.append(tx) }
            }
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.uuid = .incrementing
        }

        await store.send(.confirmTapped)
        await store.receive(\.draftSent) {
            $0.draft = nil
            $0.step = .category
        }

        let committed = added.value
        #expect(committed.count == 1)
        #expect(committed.first?.amount == 480)
        #expect(committed.first?.categoryId == Self.foodCategory.id)
        #expect(committed.first?.accountId == Self.cashAccount.id)
        #expect(committed.first?.type == .expense)
    }

    @Test("Long-press picks account override that's used in the next draft")
    func longPressAccountOverride() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount, Self.cardAccount],
                defaultAccountId: Self.cashAccount.id
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.categoryLongPressed(Self.foodCategory.id)) {
            $0.accountPickerForCategoryId = Self.foodCategory.id
        }
        await store.send(.accountPicked(Self.cardAccount.id)) {
            $0.accountPickerForCategoryId = nil
            $0.draft = WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: Self.cardAccount.id
            )
            $0.step = .amount
        }
    }

    @Test("Amount input appends digit and respects 7-digit cap")
    func amountAppendsAndCaps() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                draft: WatchRecordFeature.Draft(categoryId: UUID(), accountIdOverride: nil),
                step: .amount
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.amountDigit(4)) {
            $0.draft?.amount = 4
        }
        await store.send(.amountDigit(8)) {
            $0.draft?.amount = 48
        }
        await store.send(.amountDigit(0)) {
            $0.draft?.amount = 480
        }
        await store.send(.amountBackspace) {
            $0.draft?.amount = 48
        }

        // Cap at 7 digits — exhaustivity off so we don't assert each intermediate step.
        store.exhaustivity = .off
        await store.send(.amountDigit(0))
        await store.send(.amountDigit(0))
        await store.send(.amountDigit(0))
        await store.send(.amountDigit(0))
        await store.send(.amountDigit(0))
        await store.send(.amountDigit(0))

        #expect((store.state.draft?.amount ?? 0) <= 9_999_999)
    }

    @Test("Cancel from confirm clears draft and returns to category")
    func cancelClearsDraft() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id,
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 100
                ),
                step: .confirm
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.cancelTapped) {
            $0.draft = nil
            $0.step = .category
        }
    }
}
