import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct RecurringTransactionFormFeature: Sendable {
    public init() {}

    // P1-6: Mode must be Sendable
    public enum Mode: Equatable, Sendable {
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
        // P0-2: Separate date picker (y/m/d) from time picker (h/m)
        public var firstRunDate: Date
        public var notificationTime: Date
        public var amountError: String?
        public var accountError: String?
        // P0-3: Surface save errors inline
        public var saveError: String?

        public init(mode: Mode) {
            self.mode = mode
            switch mode {
            case .add:
                amountText = ""; note = ""; type = .expense
                frequency = .monthly; accountId = nil; toAccountId = nil; categoryId = nil
                // P0-2: Default first run date is today
                firstRunDate = Calendar.current.startOfDay(for: Date())
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 9; components.minute = 0
                notificationTime = Calendar.current.date(from: components) ?? Date()
                saveError = nil
            case let .edit(rt):
                amountText = "\(NSDecimalNumber(decimal: rt.amount).intValue)"
                note = rt.note ?? ""; type = rt.type; frequency = rt.frequency
                accountId = rt.accountId; toAccountId = rt.toAccountId; categoryId = rt.categoryId
                // Edit mode: split existing nextDueDate into date and time components
                firstRunDate = Calendar.current.startOfDay(for: rt.nextDueDate)
                notificationTime = rt.nextDueDate
                saveError = nil
            }
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case optionsLoaded(accounts: [Account], categories: [Domain.Category])
        case amountChanged(String)
        case noteChanged(String)
        case typeChanged(TransactionType)
        // P0-1: frequencyChanged now triggers nextDueDate rebase
        case frequencyChanged(BudgetPeriod)
        case accountChanged(Account.ID?)
        case toAccountChanged(Account.ID?)
        case categoryChanged(Domain.Category.ID?)
        // P0-2: Separate first-run date action from notification time
        case firstRunDateChanged(Date)
        case notificationTimeChanged(Date)
        case saveTapped
        // P0-3: New action to surface save errors
        case saveFailed(String)
        case cancelTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case task }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    async let accounts = (try? await ledger.listActiveAccounts()) ?? []
                    async let categories = (try? await ledger.listCategories(nil)) ?? []
                    await send(.optionsLoaded(accounts: accounts, categories: categories))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoaded(accounts, categories):
                state.accounts = accounts
                state.categories = categories
                return .none

            case let .amountChanged(text):
                state.amountText = text
                return .none

            case let .noteChanged(note):
                state.note = note
                return .none

            case let .typeChanged(type):
                state.type = type
                return .none

            case let .frequencyChanged(freq):
                // P0-1: Rebase nextDueDate when frequency actually changes
                guard freq != state.frequency else { return .none }
                state.frequency = freq
                // Build a temporary RecurringTransaction to use the domain helper
                let temp = RecurringTransaction(
                    id: UUID(), amount: 0, note: nil,
                    categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
                    type: .expense, tags: [], frequency: freq,
                    nextDueDate: now, isActive: true, createdAt: now
                )
                let rebased = temp.nextDate(after: now)
                state.firstRunDate = Calendar.current.startOfDay(for: rebased)
                return .none

            case let .accountChanged(id):
                state.accountId = id
                return .none

            case let .toAccountChanged(id):
                state.toAccountId = id
                return .none

            case let .categoryChanged(id):
                state.categoryId = id
                return .none

            case let .firstRunDateChanged(date):
                // P0-2: Update the date portion only
                state.firstRunDate = Calendar.current.startOfDay(for: date)
                return .none

            case let .notificationTimeChanged(time):
                state.notificationTime = time
                return .none

            case let .saveFailed(message):
                // P0-3: Surface error inline
                state.saveError = message
                return .none

            case .saveTapped:
                guard let amount = Decimal(string: state.amountText), amount > 0 else {
                    state.amountError = String(localized: "recurring_transaction_error_amount")
                    return .none
                }
                guard let accountId = state.accountId else {
                    state.accountError = String(localized: "recurring_transaction_error_account")
                    return .none
                }
                state.amountError = nil
                state.accountError = nil
                state.saveError = nil

                let frequency = state.frequency
                let mode = state.mode
                let note = state.note.isEmpty ? Optional<String>.none : state.note
                let categoryId = state.categoryId
                let toAccountId = state.toAccountId
                let type_ = state.type

                // P0-2: Combine firstRunDate (y/m/d) with notificationTime (h/m)
                let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: state.notificationTime)
                let combinedDate = Calendar.current.date(
                    bySettingHour: timeComponents.hour ?? 9,
                    minute: timeComponents.minute ?? 0,
                    second: 0,
                    of: state.firstRunDate
                ) ?? state.firstRunDate

                let template: RecurringTransaction
                let isEdit: Bool

                switch mode {
                case let .edit(existing):
                    isEdit = true
                    var updated = existing
                    updated.amount = amount
                    updated.note = note
                    updated.categoryId = categoryId
                    updated.accountId = accountId
                    updated.toAccountId = toAccountId
                    updated.type = type_
                    updated.frequency = frequency
                    updated.nextDueDate = combinedDate
                    template = updated
                case .add:
                    isEdit = false
                    template = RecurringTransaction(
                        id: UUID(),
                        amount: amount,
                        note: note,
                        categoryId: categoryId,
                        accountId: accountId,
                        toAccountId: toAccountId,
                        type: type_,
                        tags: [],
                        frequency: frequency,
                        nextDueDate: combinedDate,
                        isActive: true,
                        createdAt: now
                    )
                }

                return .run { [template, isEdit] send in
                    // P0-3: Use try await + do-catch instead of try?
                    // Reminder scheduling is a post-condition of create/updateRecurring
                    // (internalised into LedgerClient).
                    do {
                        if isEdit {
                            try await ledger.updateRecurring(template)
                        } else {
                            try await ledger.createRecurring(template)
                        }
                        await send(.delegate(.saved))
                        await dismiss()
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
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
