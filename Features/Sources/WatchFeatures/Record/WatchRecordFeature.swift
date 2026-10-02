import Foundation
import ComposableArchitecture
import Domain

/// Apple Watch quick-record reducer. Drives the 3-step flow
/// (category → amount → confirm) plus the long-press-to-pick-account
/// override.
@Reducer
public struct WatchRecordFeature: Sendable {

    /// Where in the flow the user currently is.
    @CasePathable
    public enum Step: Equatable, Sendable {
        case category
        case amount
        case confirm
    }

    /// In-flight draft assembled by the user. Reset to nil after
    /// send/cancel.
    public struct Draft: Equatable, Sendable {
        public var categoryId: UUID
        public var accountIdOverride: Account.ID?
        public var amount: Decimal

        public init(categoryId: UUID, accountIdOverride: Account.ID?, amount: Decimal = 0) {
            self.categoryId = categoryId
            self.accountIdOverride = accountIdOverride
            self.amount = amount
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var categories: [Domain.Category]
        public var accounts: [Account]
        public var defaultAccountId: Account.ID?
        public var draft: Draft?
        public var step: Step
        public var accountPickerForCategoryId: UUID?

        /// A send is in flight. Blocks a second `confirmTapped` so a
        /// double tap cannot queue two transactions with different ids.
        public var isSending: Bool

        /// Why the last send attempt never left the Watch. Non-nil means
        /// the draft is still held and the user can retry.
        public var sendFailure: WatchSendFailure?

        public init(
            categories: [Domain.Category] = [],
            accounts: [Account] = [],
            defaultAccountId: Account.ID? = nil,
            draft: Draft? = nil,
            step: Step = .category,
            accountPickerForCategoryId: UUID? = nil,
            isSending: Bool = false,
            sendFailure: WatchSendFailure? = nil
        ) {
            self.categories = categories
            self.accounts = accounts
            self.defaultAccountId = defaultAccountId
            self.draft = draft
            self.step = step
            self.accountPickerForCategoryId = accountPickerForCategoryId
            self.isSending = isSending
            self.sendFailure = sendFailure
        }

        public var activeCategory: Domain.Category? {
            guard let id = draft?.categoryId else { return nil }
            return categories.first { $0.id == id }
        }

        public var activeAccountId: Account.ID? {
            draft?.accountIdOverride ?? defaultAccountId
        }

        public var activeAccount: Account? {
            guard let id = activeAccountId else { return nil }
            return accounts.first { $0.id == id }
        }
    }

    public enum Action: Sendable {
        case task
        case loaded(categories: [Domain.Category], accounts: [Account], defaultAccountId: Account.ID?)

        case categoryTapped(UUID)
        case categoryLongPressed(UUID)
        case accountPickerDismissed
        case accountPicked(Account.ID)

        case amountDigit(Int)
        case amountBackspace
        case amountConfirmed

        case confirmTapped
        case cancelTapped
        case draftSent
        case sendFailed(WatchSendFailure)
    }

    private static let amountCap: Decimal = 9_999_999

    @Dependency(\.watchLedgerClient) var ledgerClient
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                return .run { [ledgerClient] send in
                    @Sendable func load() async {
                        async let categories = (try? await ledgerClient.categories(.expense)) ?? []
                        async let accounts = (try? await ledgerClient.activeAccounts()) ?? []
                        let cats = await categories
                        let accs = await accounts
                        await send(.loaded(
                            categories: cats,
                            accounts: accs,
                            defaultAccountId: accs.first?.id
                        ))
                    }
                    await load()
                    // Re-load whenever the iPhone snapshot lands in the
                    // cache, so the empty cold-start screen self-heals once
                    // the first WC context arrives.
                    for await _ in NotificationCenter.default.notifications(
                        named: WatchCacheStore.didUpdateNotification
                    ) {
                        await load()
                    }
                }

            case let .loaded(categories, accounts, defaultAccountId: defaultId):
                state.categories = categories
                state.accounts = accounts
                state.defaultAccountId = defaultId
                return .none

            case let .categoryTapped(id):
                state.draft = Draft(categoryId: id, accountIdOverride: nil)
                state.step = .amount
                state.sendFailure = nil
                return .none

            case let .categoryLongPressed(id):
                state.accountPickerForCategoryId = id
                return .none

            case .accountPickerDismissed:
                state.accountPickerForCategoryId = nil
                return .none

            case let .accountPicked(accountId):
                guard let categoryId = state.accountPickerForCategoryId else { return .none }
                state.accountPickerForCategoryId = nil
                state.draft = Draft(categoryId: categoryId, accountIdOverride: accountId)
                state.step = .amount
                state.sendFailure = nil
                return .none

            case let .amountDigit(digit):
                guard var draft = state.draft else { return .none }
                let candidate = draft.amount * 10 + Decimal(digit)
                draft.amount = min(candidate, Self.amountCap)
                state.draft = draft
                return .none

            case .amountBackspace:
                guard var draft = state.draft else { return .none }
                let truncated = (draft.amount as NSDecimalNumber).intValue / 10
                draft.amount = Decimal(truncated)
                state.draft = draft
                return .none

            case .amountConfirmed:
                guard state.draft?.amount ?? 0 > 0 else { return .none }
                state.step = .confirm
                return .none

            case .confirmTapped:
                guard let draft = state.draft,
                      let accountId = state.activeAccountId else { return .none }
                // On failure the user stays on the confirm screen, so the
                // button remains live — without this guard a double tap
                // would send two transactions with different ids, which
                // the `TransactionDraft.id` de-duplication cannot catch.
                guard state.isSending == false else { return .none }
                state.isSending = true
                state.sendFailure = nil
                let nowDate = now
                let transaction = Transaction(
                    id: UUID(),
                    amount: draft.amount,
                    date: nowDate,
                    categoryId: draft.categoryId,
                    accountId: accountId,
                    type: .expense
                )
                return .run { send in
                    do {
                        try await ledgerClient.record(transaction)
                        await send(.draftSent)
                    } catch {
                        await send(.sendFailed(error as? WatchSendFailure ?? .unknown))
                    }
                }

            case .cancelTapped:
                state.draft = nil
                state.step = .category
                state.isSending = false
                state.sendFailure = nil
                return .none

            case .draftSent:
                state.draft = nil
                state.step = .category
                state.isSending = false
                state.sendFailure = nil
                return .none

            case let .sendFailed(failure):
                // The draft and the step are deliberately left untouched:
                // the record never left the Watch, so the user must be
                // able to see why and press confirm again.
                state.isSending = false
                state.sendFailure = failure
                return .none
            }
        }
    }
}
