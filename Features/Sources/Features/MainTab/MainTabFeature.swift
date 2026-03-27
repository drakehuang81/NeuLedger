import Foundation
import ComposableArchitecture
import Domain

public enum InputPurpose: Equatable, Sendable {
    case record
    case ask
}

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case dashboard
        case settings
        case transactions
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var dashboard = DashboardFeature.State()
        var transactions = TransactionsFeature.State()
        var settings = SettingsFeature.State()

        // AI input bar state
        var isAIInputExpanded: Bool = false
        var aiInputText: String = ""
        var isAIInputLoading: Bool = false
        var aiInputError: String? = nil      // shown inline below the text field
        var aiUnavailable: Bool = false      // set once on .task; drives all AI UI
        var inputPurpose: InputPurpose = .record
        var aiAnswer: String? = nil
        var showAccessoryBar: Bool = true

        // Recurring transaction confirmation routing
        var pendingRecurringConfirmationId: RecurringTransaction.ID? = nil

        var isAccessoryVisible: Bool {
            guard showAccessoryBar else { return false }
            switch selectedTab {
            case .settings:     return settings.path.isEmpty
            case .dashboard:    return dashboard.path.isEmpty
            case .transactions: return true
            }
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)
        case contextActionTapped

        // Lifecycle
        case task

        // AI input bar
        case aiAvailabilityLoaded(isAvailable: Bool)   // Bool = true means AI IS available
        case aiInputButtonTapped
        case aiInputTextChanged(String)
        case aiInputSubmitted
        case aiInputDismissed
        case aiExtractionCompleted(TaskResult<ExtractedTransaction>)
        case inputPurposeSwitched(InputPurpose)
        case askSubmitted
        case answerReceived(String)
        case answerFailed
        case resultPillTapped
        case accessoryBarVisibilityLoaded(Bool)

        case pendingRecurringConfirmationReceived(RecurringTransaction.ID)
        case recurringTemplateFetched(RecurringTransaction)

        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Dependencies
    @Dependency(\.aiServiceClient) var aiServiceClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.recurringTransactionClient) var recurringTransactionClient
    private enum CancelID { case aiExtraction; case aiAnswer; case task }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    await withTaskGroup(of: Void.self) { group in
                        // Check AI availability once at launch — stored in state so all AI UI reads a single flag.
                        group.addTask {
                            await send(.aiAvailabilityLoaded(isAvailable: aiServiceClient.isAvailable()))
                            let showAccessoryBar = userSettingsClient.bool(.showAccessoryBar)
                            await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                        }
                        // Subscribe to recurring notification taps
                        group.addTask {
                            for await recurringId in notificationClient.pendingConfirmations() {
                                await send(.pendingRecurringConfirmationReceived(recurringId))
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.task)

            case let .aiAvailabilityLoaded(isAvailable):
                // isAvailable=true  → AI works → aiUnavailable=false
                // isAvailable=false → AI broken → aiUnavailable=true
                state.aiUnavailable = !isAvailable
                return .none

            case .aiInputButtonTapped:
                state.isAIInputExpanded = true
                state.aiInputError = nil
                return .none

            case let .aiInputTextChanged(text):
                state.aiInputText = text
                return .none

            case .aiInputDismissed:
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                state.aiInputError = nil
                state.aiAnswer = nil
                return .none

            case .aiInputSubmitted:
                guard !state.aiInputText.isEmpty else { return .none }
                state.isAIInputLoading = true
                state.aiInputError = nil
                let text = state.aiInputText
                return .run { send in
                    await send(.aiExtractionCompleted(
                        TaskResult { try await aiServiceClient.extractTransaction(text) }
                    ))
                }
                .cancellable(id: CancelID.aiExtraction, cancelInFlight: true)

            case let .aiExtractionCompleted(.success(extracted)):
                // Reset input bar
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                // Route to the correct child feature based on selected tab
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.addTransactionWithPrefilledData(extracted)))
                default:
                    return .send(.dashboard(.addTransactionWithPrefilledData(extracted)))
                }

            case .aiExtractionCompleted(.failure):
                state.isAIInputLoading = false
                state.aiInputError = String(localized: "ai_extraction_error")
                return .none

            case let .inputPurposeSwitched(purpose):
                state.inputPurpose = purpose
                state.aiInputText = ""
                state.aiAnswer = nil
                state.aiInputError = nil
                return .cancel(id: CancelID.aiAnswer)

            case .askSubmitted:
                guard !state.aiInputText.isEmpty else { return .none }
                state.isAIInputLoading = true
                state.aiInputError = nil
                state.aiAnswer = nil
                let question = state.aiInputText
                return .run { send in
                    do {
                        let answer = try await aiServiceClient.answerFinancialQuestion(question)
                        await send(.answerReceived(answer))
                    } catch {
                        await send(.answerFailed)
                    }
                }
                .cancellable(id: CancelID.aiAnswer, cancelInFlight: true)

            case let .answerReceived(text):
                guard state.inputPurpose == .ask else { return .none }
                state.aiAnswer = text
                state.isAIInputLoading = false
                state.aiInputText = ""
                state.isAIInputExpanded = false
                return .none

            case .answerFailed:
                state.isAIInputLoading = false
                state.aiInputError = String(localized: "ai_ask_error")
                return .none

            case .resultPillTapped:
                state.aiAnswer = nil
                state.isAIInputExpanded = true
                state.aiInputError = nil
                return .none

            case let .accessoryBarVisibilityLoaded(visible):
                state.showAccessoryBar = visible
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .contextActionTapped:
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.contextActionTapped))
                default:
                    return .send(.dashboard(.addTransactionButtonTapped))
                }

            case let .pendingRecurringConfirmationReceived(id):
                return .run { send in
                    do {
                        let all = try await recurringTransactionClient.fetchAll()
                        guard let template = all.first(where: { $0.id == id }) else { return }
                        await send(.recurringTemplateFetched(template))
                    } catch {
                        // silently ignore — template may have been deleted
                    }
                }

            case let .recurringTemplateFetched(template):
                state.pendingRecurringConfirmationId = template.id
                state.dashboard.addTransaction = AddTransactionFeature.State(
                    mode: .addRecurringConfirmation(template)
                )
                state.selectedTab = .dashboard
                return .none

            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):
                state.pendingRecurringConfirmationId = nil
                return .run { send in
                    do {
                        let all = try await recurringTransactionClient.fetchAll()
                        if var template = all.first(where: { $0.id == id }) {
                            template.nextDueDate = newNextDueDate
                            try await recurringTransactionClient.update(template)
                            try await notificationClient.scheduleRecurringReminder(
                                template.id,
                                newNextDueDate,
                                String(localized: "recurring_transaction_notification_title"),
                                String(localized: "recurring_transaction_notification_body")
                            )
                        }
                    } catch {
                        // silently ignore
                    }
                }

            case .dashboard:
                return .none

            case .transactions:
                return .none

            case .settings:
                return .none
            }
        }
    }
}
