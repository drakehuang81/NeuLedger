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

        // Build up to exactly 9_999_999 (7 digits): 48 → 480 → 4800 → 48000 → 480000 → 4800000
        store.exhaustivity = .off
        await store.send(.amountDigit(0)) // 480
        await store.send(.amountDigit(0)) // 4800
        await store.send(.amountDigit(0)) // 48000
        await store.send(.amountDigit(0)) // 480000
        await store.send(.amountDigit(0)) // 4800000

        // Now at 4_800_000 — one more digit would produce 48_000_000 which exceeds the cap.
        // The reducer must clamp: min(48_000_000, 9_999_999) = 9_999_999.
        store.exhaustivity = .on
        await store.send(.amountDigit(0)) {
            // Candidate = 4_800_000 * 10 + 0 = 48_000_000 → clamped to 9_999_999
            $0.draft?.amount = 9_999_999
        }

        #expect(store.state.draft?.amount == 9_999_999)
    }

    @Test("amountConfirmed with positive amount advances to confirm step")
    func amountConfirmedAdvancesToConfirm() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id,
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 200
                ),
                step: .amount
            )
        ) {
            WatchRecordFeature()
        }

        await store.send(.amountConfirmed) {
            $0.step = .confirm
        }
    }

    @Test("amountConfirmed with zero amount is blocked — state does not change")
    func amountConfirmedZeroAmountIsBlocked() async {
        let initialState = WatchRecordFeature.State(
            categories: [Self.foodCategory],
            accounts: [Self.cashAccount],
            defaultAccountId: Self.cashAccount.id,
            draft: WatchRecordFeature.Draft(
                categoryId: Self.foodCategory.id,
                accountIdOverride: nil,
                amount: 0
            ),
            step: .amount
        )
        let store = TestStore(initialState: initialState) {
            WatchRecordFeature()
        }

        // guard `amount > 0` should early-return; no state mutation expected.
        await store.send(.amountConfirmed)
        // State is unchanged — step remains .amount, draft amount stays 0.
        #expect(store.state.step == .amount)
        #expect(store.state.draft?.amount == 0)
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

    // MARK: - Task 7: accountPickerDismissed clears the navigation state

    @Test("accountPickerDismissed clears accountPickerForCategoryId without advancing the flow")
    func accountPickerDismissedClearsState() async {
        // Start with picker open (long-press has been invoked)
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount, Self.cardAccount],
                defaultAccountId: Self.cashAccount.id,
                accountPickerForCategoryId: Self.foodCategory.id
            )
        ) {
            WatchRecordFeature()
        }

        // User swipes down to dismiss without picking an account
        await store.send(.accountPickerDismissed) {
            $0.accountPickerForCategoryId = nil
        }

        // Step stays at .category, draft stays nil — no flow advancement
        #expect(store.state.step == .category)
        #expect(store.state.draft == nil)
    }

    // MARK: - Task 8: amountBackspace single-digit collapses to zero

    @Test("amountBackspace on a single-digit collapses amount to zero (disabled boundary)")
    func amountBackspaceSingleDigitCollapsesToZero() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 5
                ),
                step: .amount
            )
        ) {
            WatchRecordFeature()
        }

        // Backspace on 5: intValue(5) / 10 == 0 → amount becomes 0
        await store.send(.amountBackspace) {
            $0.draft?.amount = 0
        }
        #expect(store.state.draft?.amount == 0)

        // At amount == 0: amountConfirmed guard `> 0` must block (disabled boundary)
        await store.send(.amountConfirmed)
        // step remains .amount — guard early-returned
        #expect(store.state.step == .amount)
    }

    // MARK: - Task 3: confirmTapped nil-account guard

    @Test("confirmTapped with nil activeAccountId is silently blocked — state unchanged, record not called")
    func confirmTappedWithNilAccountIsBlocked() async {
        // No defaultAccountId + no accountIdOverride → activeAccountId == nil
        let recordCalled = LockIsolated(false)

        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [],           // no accounts loaded
                defaultAccountId: nil,  // no default
                draft: WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil,
                    amount: 200
                ),
                step: .confirm
            )
        ) {
            WatchRecordFeature()
        } withDependencies: {
            $0.watchLedgerClient.record = { @Sendable _ in
                recordCalled.withValue { $0 = true }
            }
        }

        // guard `activeAccountId != nil` should early-return with no effects
        await store.send(.confirmTapped)

        // State must not have changed
        #expect(store.state.step == .confirm)
        #expect(store.state.draft?.amount == 200)
        // record must never have been invoked
        #expect(recordCalled.value == false)
    }

    // MARK: - Task 5: .task self-heal reload via NotificationCenter

    // MARK: - Task 5: .task self-heal reload via NotificationCenter
    //
    // NOTE: This test verifies that the `.task` effect's for-await loop over
    // `NotificationCenter.default.notifications(named: WatchCacheStore.didUpdateNotification)`
    // wakes up and re-runs `load()` when a cache-update notification arrives.
    //
    // Isolation constraint: `WatchSessionGatewayTests/inboundContextWritesCache()` also
    // posts this notification (via `WatchCacheStore.save()`). To avoid cross-test
    // interference, this test always returns real data (not empty) so ANY load — whether
    // triggered by the cold-start `await load()` or by a spurious notification from a
    // parallel test — results in a consistent `.loaded` action. The test then verifies
    // the store keeps receiving `.loaded` each time the notification fires (including
    // our own explicit post), confirming the subscription loop is wired up.
    @Test("task self-heals by reloading when WatchCacheStore.didUpdateNotification fires")
    func taskSelfHealsOnCacheUpdate() async {
        let store = TestStore(initialState: WatchRecordFeature.State()) {
            WatchRecordFeature()
        } withDependencies: {
            // Always return real data so the result is deterministic regardless of
            // which notification triggers the reload.
            $0.watchLedgerClient.categories = { @Sendable type in
                type == .expense ? [Self.foodCategory] : []
            }
            $0.watchLedgerClient.activeAccounts = { @Sendable in
                [Self.cashAccount]
            }
        }
        store.exhaustivity = .off  // ignore spurious .loaded from parallel tests

        // Start the long-lived task
        let task = await store.send(.task)

        // First .loaded from the cold-start `await load()` call
        await store.receive(\.loaded) {
            $0.categories = [Self.foodCategory]
            $0.accounts = [Self.cashAccount]
            $0.defaultAccountId = Self.cashAccount.id
        }

        // Simulate iPhone snapshot arriving: post the notification.
        // The .task effect's for-await loop must wake and re-run load().
        await Task.yield()
        NotificationCenter.default.post(name: WatchCacheStore.didUpdateNotification, object: nil)

        // The for-await subscription must send a second .loaded — proving the
        // notification-driven reload path is wired up in the .task effect.
        await store.receive(\.loaded)

        await task.cancel()
    }
}
