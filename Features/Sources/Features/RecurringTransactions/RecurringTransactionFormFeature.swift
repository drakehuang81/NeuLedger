import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct RecurringTransactionFormFeature: Sendable {
    public init() {}

    public enum Mode: Equatable {
        case add
        case edit(RecurringTransaction)
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var amountText: String
        public var note: String
        public var type: TransactionType
        public var frequency: BudgetPeriod
        public var accountId: Account.ID?
        public var toAccountId: Account.ID?
        public var categoryId: Domain.Category.ID?
        public var accounts: [Account] = []
        public var categories: [Domain.Category] = []
        public var amountError: String?
        public var accountError: String?

        public init(mode: Mode) {
            self.mode = mode
            switch mode {
            case .add:
                amountText = ""; note = ""; type = .expense
                frequency = .monthly; accountId = nil; toAccountId = nil; categoryId = nil
            case let .edit(rt):
                amountText = "\(NSDecimalNumber(decimal: rt.amount).intValue)"
                note = rt.note ?? ""; type = rt.type; frequency = rt.frequency
                accountId = rt.accountId; toAccountId = rt.toAccountId; categoryId = rt.categoryId
            }
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case optionsLoaded(accounts: [Account], categories: [Domain.Category])
        case amountChanged(String)
        case noteChanged(String)
        case typeChanged(TransactionType)
        case frequencyChanged(BudgetPeriod)
        case accountChanged(Account.ID?)
        case toAccountChanged(Account.ID?)
        case categoryChanged(Domain.Category.ID?)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    @Dependency(\.recurringTransactionClient) var client
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    async let accounts = (try? await accountClient.fetchActive()) ?? []
                    async let categories = (try? await categoryClient.fetchAll()) ?? []
                    await send(.optionsLoaded(accounts: accounts, categories: categories))
                }

            case let .optionsLoaded(accounts, categories):
                state.accounts = accounts
                state.categories = categories
                return .none

            case let .amountChanged(text): state.amountText = text; return .none
            case let .noteChanged(note): state.note = note; return .none
            case let .typeChanged(type): state.type = type; return .none
            case let .frequencyChanged(freq): state.frequency = freq; return .none
            case let .accountChanged(id): state.accountId = id; return .none
            case let .toAccountChanged(id): state.toAccountId = id; return .none
            case let .categoryChanged(id): state.categoryId = id; return .none

            case .saveTapped:
                guard let amount = Decimal(string: state.amountText), amount > 0 else {
                    state.amountError = String(localized: "add_transaction_error_amount")
                    return .none
                }
                guard let accountId = state.accountId else {
                    state.accountError = String(localized: "add_transaction_error_account")
                    return .none
                }
                state.amountError = nil
                state.accountError = nil

                let isEdit: Bool
                let id: UUID
                let createdAt: Date
                if case let .edit(existing) = state.mode {
                    isEdit = true; id = existing.id; createdAt = existing.createdAt
                } else {
                    isEdit = false; id = UUID(); createdAt = Date()
                }

                let frequency = state.frequency
                let now = Date()
                let nextDue: Date
                switch frequency {
                case .weekly:  nextDue = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
                case .monthly: nextDue = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now
                case .yearly:  nextDue = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
                }

                let template = RecurringTransaction(
                    id: id,
                    amount: amount,
                    note: state.note.isEmpty ? nil : state.note,
                    categoryId: state.categoryId,
                    accountId: accountId,
                    toAccountId: state.toAccountId,
                    type: state.type,
                    tags: [],
                    frequency: frequency,
                    nextDueDate: nextDue,
                    isActive: true,
                    createdAt: createdAt
                )

                return .run { [template, isEdit] send in
                    if isEdit {
                        try? await client.update(template)
                    } else {
                        try? await client.add(template)
                    }
                    await notificationClient.scheduleRecurringReminder(
                        template.id,
                        template.nextDueDate,
                        String(localized: "recurring_transaction_notification_title"),
                        String(localized: "recurring_transaction_notification_body")
                    )
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
