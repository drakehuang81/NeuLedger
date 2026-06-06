import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct FilterFeature: Sendable {
    public init() {}

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

        case typeToggled(TransactionType)
        case categoryToggled(Domain.Category.ID)
        case accountToggled(Account.ID)
        case tagToggled(Tag.ID)
        case startDateChanged(Date?)
        case endDateChanged(Date?)

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

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    async let categories = ledger.listCategories(nil)
                    async let accounts = ledger.listAccounts()
                    async let tags = ledger.listTags()
                    let (c, a, t) = try await (categories, accounts, tags)
                    await send(.optionsLoaded(categories: c, accounts: a, tags: t))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoaded(categories, accounts, tags):
                state.categories = categories
                state.accounts = accounts
                state.tags = tags
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
                return .none

            case let .endDateChanged(date):
                state.endDate = date
                return .none

            case .applyTapped:
                let dateRange: ClosedRange<Date>?
                if let start = state.startDate, let end = state.endDate, start <= end {
                    dateRange = start...end
                } else if let start = state.startDate {
                    dateRange = start...Date()
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
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
