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

        await store.send(.confirmTapped) {
            $0.isSending = true
        }
        await store.receive(\.draftSent) {
            $0.draft = nil
            $0.step = .category
            $0.isSending = false
            $0.sendSuccessPulse = 1
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

    // MARK: - Task 5: .task 的自我修復重載

    // 事件流現在是注入的（見 `WatchCacheEvents`），測試自己握著 continuation：
    // 要它發才發。改之前這條測試訂閱的是 process 全域的 `NotificationCenter`，
    // 而 `WatchSessionGatewayTests/inboundContextWritesCache()` 經由
    // `WatchCacheStore.save()` 也會發同一個通知——於是原版只好讓 stub 永遠回
    // 真資料、再開 `exhaustivity = .off` 來容忍「別的測試打進來的 .loaded」。
    // 那等於放棄了「究竟收到幾次」這個斷言。
    //
    // 現在不需要那些繞路：串流是這條測試專屬的，所以可以維持 exhaustive，
    // 並且真的斷言「冷啟動一次 + 快照落地一次 = 恰好兩次 .loaded」。
    @Test("task self-heals by reloading when a fresh snapshot lands")
    func taskSelfHealsOnCacheUpdate() async {
        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let store = TestStore(initialState: WatchRecordFeature.State()) {
            WatchRecordFeature()
        } withDependencies: {
            $0.watchLedgerClient.categories = { @Sendable type in
                type == .expense ? [Self.foodCategory] : []
            }
            $0.watchLedgerClient.activeAccounts = { @Sendable in
                [Self.cashAccount]
            }
            $0.watchCacheEvents = WatchCacheEvents(updates: { stream })
        }

        let task = await store.send(.task)

        // 冷啟動那一次 load()
        await store.receive(\.loaded) {
            $0.categories = [Self.foodCategory]
            $0.accounts = [Self.cashAccount]
            $0.defaultAccountId = Self.cashAccount.id
        }

        // 模擬 iPhone 的快照落地：for-await 迴圈必須醒來並重跑 load()。
        continuation.yield()
        await store.receive(\.loaded)

        continuation.finish()
        await task.cancel()
    }

    // MARK: - A1：送出失敗必須看得見，草稿必須留得住

    /// 建一個停在確認頁、金額 480 的 store，`record` 行為由呼叫端決定。
    private func makeConfirmStore(
        record: @escaping @Sendable (Transaction) async throws -> Void
    ) -> TestStoreOf<WatchRecordFeature> {
        TestStore(
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
            $0.watchLedgerClient.record = record
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
    }

    @Test("A failed send keeps the draft, stays on confirm, and surfaces the failure")
    func failedSendKeepsDraftAndSurfacesFailure() async {
        let attempts = LockIsolated(0)
        let store = makeConfirmStore { _ in
            attempts.withValue { $0 += 1 }
            throw WatchSendFailure.sessionNotActivated
        }

        await store.send(.confirmTapped) {
            $0.isSending = true
        }
        await store.receive(\.sendFailed) {
            $0.isSending = false
            $0.sendFailure = .sessionNotActivated
        }

        // 修好之前這裡會是 draft == nil / step == .category：使用者以為
        // 記帳成功，那筆交易卻從未離開手錶。
        #expect(store.state.draft?.amount == 480)
        #expect(store.state.step == .confirm)
        #expect(store.state.sendFailure == .sessionNotActivated)
        #expect(attempts.value == 1)
    }

    @Test("An unmodelled error still surfaces as a failure rather than a silent success")
    func unmodelledErrorSurfacesAsUnknown() async {
        struct Boom: Error {}
        let store = makeConfirmStore { _ in throw Boom() }

        await store.send(.confirmTapped) {
            $0.isSending = true
        }
        await store.receive(\.sendFailed) {
            $0.isSending = false
            $0.sendFailure = .unknown
        }

        #expect(store.state.draft?.amount == 480)
        #expect(store.state.step == .confirm)
    }

    @Test("After a failure the user can press confirm again and the retry goes through")
    func retryAfterFailureSucceeds() async {
        let attempts = LockIsolated(0)
        let store = makeConfirmStore { _ in
            let attempt = attempts.withValue { $0 += 1; return $0 }
            if attempt == 1 { throw WatchSendFailure.encodingFailed }
        }

        await store.send(.confirmTapped) {
            $0.isSending = true
        }
        await store.receive(\.sendFailed) {
            $0.isSending = false
            $0.sendFailure = .encodingFailed
        }

        // 草稿還在，所以再按一次確認就能重試。
        await store.send(.confirmTapped) {
            $0.isSending = true
            $0.sendFailure = nil
        }
        await store.receive(\.draftSent) {
            $0.draft = nil
            $0.step = .category
            $0.isSending = false
            $0.sendSuccessPulse = 1
        }

        #expect(attempts.value == 2)
    }

    @Test("A missing category surfaces as a failure and is never reported as sent")
    func missingCategoryIsNotReportedAsSent() async {
        let store = makeConfirmStore { _ in
            throw WatchSendFailure.missingCategory
        }

        await store.send(.confirmTapped) {
            $0.isSending = true
        }
        await store.receive(\.sendFailed) {
            $0.isSending = false
            $0.sendFailure = .missingCategory
        }

        #expect(store.state.draft?.amount == 480)
        #expect(store.state.step == .confirm)
    }

    @Test("A second confirm while a send is already in flight is ignored")
    func confirmWhileSendingIsIgnored() async {
        let attempts = LockIsolated(0)
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
                step: .confirm,
                isSending: true
            )
        ) {
            WatchRecordFeature()
        } withDependencies: {
            $0.watchLedgerClient.record = { @Sendable _ in
                attempts.withValue { $0 += 1 }
            }
        }

        // 失敗時使用者留在確認頁，按鈕還活著 —— 連點不能送出兩筆。
        await store.send(.confirmTapped)

        #expect(attempts.value == 0)
        #expect(store.state.isSending == true)
    }

    @Test("Starting a new draft clears a stale failure banner")
    func newDraftClearsStaleFailure() async {
        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id,
                sendFailure: .sessionNotActivated
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
            $0.sendFailure = nil
        }
    }

    // MARK: - Success haptic: separating "sent" from "cancelled"

    @Test("cancelTapped leaves sendSuccessPulse untouched")
    func cancelDoesNotPulseSuccess() async {
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
        }

        // `cancelTapped` and `draftSent` reset the rest of the state
        // identically, which is why the view needs this one field to tell
        // them apart. Backing out of a draft must not feel like a success.
        await store.send(.cancelTapped) {
            $0.draft = nil
            $0.step = .category
        }

        #expect(store.state.sendSuccessPulse == 0)
    }

    @Test("Two successful sends pulse twice")
    func twoSendsPulseTwice() async {
        let added = LockIsolated<[Transaction]>([])

        let store = TestStore(
            initialState: WatchRecordFeature.State(
                categories: [Self.foodCategory],
                accounts: [Self.cashAccount],
                defaultAccountId: Self.cashAccount.id
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

        for pulse in 1...2 {
            await store.send(.categoryTapped(Self.foodCategory.id)) {
                $0.draft = WatchRecordFeature.Draft(
                    categoryId: Self.foodCategory.id,
                    accountIdOverride: nil
                )
                $0.step = .amount
            }
            await store.send(.amountDigit(5)) {
                $0.draft?.amount = 5
            }
            await store.send(.amountConfirmed) {
                $0.step = .confirm
            }
            await store.send(.confirmTapped) {
                $0.isSending = true
            }
            // A `Bool` would stay `true` across the second send and fire
            // one haptic for two records; the counter has to advance each
            // time for `onChange` to see it.
            await store.receive(\.draftSent) {
                $0.draft = nil
                $0.step = .category
                $0.isSending = false
                $0.sendSuccessPulse = pulse
            }
        }

        #expect(added.value.count == 2)
    }
}
