import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct BudgetFormFeature: Sendable {
    public init() {}

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
        case add
        case edit(Budget)
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var name: String
        public var amountText: String
        public var period: BudgetPeriod
        public var startDate: Date
        public var categoryId: Domain.Category.ID?
        public var availableCategories: [Domain.Category] = []
        public var nameError: String?
        public var amountError: String?

        public init(mode: Mode = .add) {
            self.mode = mode
            switch mode {
            case .add:
                self.name = ""
                self.amountText = ""
                self.period = .monthly
                self.startDate = Date()
                self.categoryId = nil
            case let .edit(budget):
                self.name = budget.name
                self.amountText = "\(budget.amount)"
                self.period = budget.period
                self.startDate = budget.startDate
                self.categoryId = budget.categoryId
            }
        }

        var navigationTitle: String {
            switch mode {
            case .add: return String(localized: "budget_form_add_title")
            case .edit: return String(localized: "budget_form_edit_title")
            }
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case categoriesLoaded([Domain.Category])
        case nameChanged(String)
        case amountChanged(String)
        case periodChanged(BudgetPeriod)
        case startDateChanged(Date)
        case categoryChanged(Domain.Category.ID?)
        case saveTapped
        case cancelTapped
        case savedSuccessfully
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    // MARK: - Dependencies

    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let categories = try await categoryClient.fetchAll()
                    await send(.categoriesLoaded(categories))
                }

            case let .categoriesLoaded(categories):
                state.availableCategories = categories.filter { $0.type == .expense }
                return .none

            case let .nameChanged(name):
                state.name = name
                state.nameError = nil
                return .none

            case let .amountChanged(text):
                state.amountText = text
                state.amountError = nil
                return .none

            case let .periodChanged(period):
                state.period = period
                return .none

            case let .startDateChanged(date):
                state.startDate = date
                return .none

            case let .categoryChanged(categoryId):
                state.categoryId = categoryId
                return .none

            case .saveTapped:
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    state.nameError = String(localized: "error_budget_name_empty")
                    return .none
                }
                guard let amount = Decimal(string: state.amountText), amount > 0 else {
                    state.amountError = String(localized: "error_amount_must_be_positive")
                    return .none
                }

                let mode = state.mode
                let period = state.period
                let startDate = state.startDate
                let categoryId = state.categoryId

                return .run { send in
                    switch mode {
                    case .add:
                        let budget = Budget(
                            name: trimmedName,
                            amount: amount,
                            categoryId: categoryId,
                            period: period,
                            startDate: startDate
                        )
                        try await budgetClient.add(budget)
                    case let .edit(existing):
                        let updated = Budget(
                            id: existing.id,
                            name: trimmedName,
                            amount: amount,
                            categoryId: categoryId,
                            period: period,
                            startDate: startDate,
                            isActive: existing.isActive
                        )
                        try await budgetClient.update(updated)
                    }
                    await send(.savedSuccessfully)
                }

            case .savedSuccessfully:
                return .run { send in
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }
}
