import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct FilterFeature: Sendable {
    public init() {}

    // MARK: - Quick date range

    /// 篩選頁的四個快捷區間。區間定義唯一來源是 `BudgetPeriod+Calendar`。
    public enum QuickDateRange: Equatable, Sendable, CaseIterable {
        case thisWeek, thisMonth, lastMonth, thisYear

        /// 閉區間：上界是該期最後一天 23:59:59.999。
        public func range(now: Date, calendar: Calendar) -> ClosedRange<Date> {
            switch self {
            case .thisWeek:  return BudgetPeriod.weekly.closedRange(containing: now, calendar: calendar)
            case .thisMonth: return BudgetPeriod.monthly.closedRange(containing: now, calendar: calendar)
            case .thisYear:  return BudgetPeriod.yearly.closedRange(containing: now, calendar: calendar)
            case .lastMonth:
                let previous = BudgetPeriod.monthly.previousInterval(before: now, calendar: calendar)
                return BudgetPeriod.monthly.closedRange(containing: previous.start, calendar: calendar)
            }
        }
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var selectedTypes: Set<TransactionType>
        public var selectedCategoryIds: Set<Domain.Category.ID>
        public var selectedAccountIds: Set<Account.ID>
        public var selectedTagIds: Set<Tag.ID>
        public var startDate: Date?
        public var endDate: Date?

        public var categories: [Domain.Category]
        public var accounts: [Account]
        public var tags: [Tag]

        /// 目前套用的快捷區間；使用者手動改起訖日即清空。
        public var activeQuickRange: QuickDateRange? = nil

        /// 選項（分類／帳戶／標籤）載入失敗的訊息。
        public var optionsError: String? = nil

        public init(initialFilter: TransactionFilter = TransactionFilter()) {
            self.selectedTypes = initialFilter.types ?? []
            self.selectedCategoryIds = initialFilter.categoryIds ?? []
            self.selectedAccountIds = initialFilter.accountIds ?? []
            self.selectedTagIds = initialFilter.tagIds ?? []
            self.startDate = initialFilter.dateRange?.lowerBound
            self.endDate = initialFilter.dateRange?.upperBound
            self.categories = []
            self.accounts = []
            self.tags = []
        }

        var activeFilterCount: Int {
            [
                selectedTypes.isEmpty ? 0 : 1,
                selectedCategoryIds.isEmpty ? 0 : 1,
                selectedAccountIds.isEmpty ? 0 : 1,
                selectedTagIds.isEmpty ? 0 : 1,
                (startDate != nil || endDate != nil) ? 1 : 0
            ].reduce(0, +)
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case optionsLoaded(categories: [Domain.Category], accounts: [Account], tags: [Tag])
        case optionsLoadFailed(String)

        case typeToggled(TransactionType)
        case categoryToggled(Domain.Category.ID)
        case accountToggled(Account.ID)
        case tagToggled(Tag.ID)
        case startDateChanged(Date?)
        case endDateChanged(Date?)
        case quickRangeSelected(QuickDateRange)

        case applyTapped
        case clearAllTapped

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case filterApplied(TransactionFilter)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // 重開篩選頁時 `State(initialFilter:)` 帶不回 `activeQuickRange`；
                // 若起訖日恰等於某個快捷區間，回填它讓 chip 維持高亮。
                if state.activeQuickRange == nil,
                   let start = state.startDate, let end = state.endDate, start <= end {
                    state.activeQuickRange = QuickDateRange.allCases.first {
                        $0.range(now: now, calendar: calendar) == start...end
                    }
                }
                state.optionsError = nil
                return .run { send in
                    async let categories = ledger.listCategories(nil)
                    async let accounts = ledger.listAccounts()
                    async let tags = ledger.listTags()
                    let (c, a, t) = try await (categories, accounts, tags)
                    await send(.optionsLoaded(categories: c, accounts: a, tags: t))
                } catch: { error, send in
                    await send(.optionsLoadFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoaded(categories, accounts, tags):
                state.categories = categories
                state.accounts = accounts
                state.tags = tags
                return .none

            case let .optionsLoadFailed(message):
                state.optionsError = message
                return .none

            case let .typeToggled(type):
                if state.selectedTypes.contains(type) {
                    state.selectedTypes.remove(type)
                } else {
                    state.selectedTypes.insert(type)
                }
                return .none

            case let .categoryToggled(id):
                if state.selectedCategoryIds.contains(id) {
                    state.selectedCategoryIds.remove(id)
                } else {
                    state.selectedCategoryIds.insert(id)
                }
                return .none

            case let .accountToggled(id):
                if state.selectedAccountIds.contains(id) {
                    state.selectedAccountIds.remove(id)
                } else {
                    state.selectedAccountIds.insert(id)
                }
                return .none

            case let .tagToggled(id):
                if state.selectedTagIds.contains(id) {
                    state.selectedTagIds.remove(id)
                } else {
                    state.selectedTagIds.insert(id)
                }
                return .none

            case let .startDateChanged(date):
                state.startDate = date
                state.activeQuickRange = nil
                return .none

            case let .endDateChanged(date):
                state.endDate = date
                state.activeQuickRange = nil
                return .none

            case let .quickRangeSelected(quick):
                let range = quick.range(now: now, calendar: calendar)
                state.startDate = range.lowerBound
                state.endDate = range.upperBound
                state.activeQuickRange = quick
                return .none

            case .applyTapped:
                let dateRange: ClosedRange<Date>?
                if let start = state.startDate, let end = state.endDate, start <= end {
                    dateRange = start...end
                } else if let start = state.startDate {
                    dateRange = start...now
                } else {
                    dateRange = nil
                }

                let filter = TransactionFilter(
                    categoryIds: state.selectedCategoryIds.isEmpty ? nil : state.selectedCategoryIds,
                    accountIds: state.selectedAccountIds.isEmpty ? nil : state.selectedAccountIds,
                    tagIds: state.selectedTagIds.isEmpty ? nil : state.selectedTagIds,
                    types: state.selectedTypes.isEmpty ? nil : state.selectedTypes,
                    dateRange: dateRange
                )
                return .run { send in
                    await send(.delegate(.filterApplied(filter)))
                    await dismiss()
                }

            case .clearAllTapped:
                state.selectedTypes = []
                state.selectedCategoryIds = []
                state.selectedAccountIds = []
                state.selectedTagIds = []
                state.startDate = nil
                state.endDate = nil
                state.activeQuickRange = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
