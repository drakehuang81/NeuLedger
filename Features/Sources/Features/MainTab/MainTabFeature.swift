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
        case analysis
        case settings
        case transactions
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var dashboard = DashboardFeature.State()
        var transactions = TransactionsFeature.State()
        var analysis = AnalysisFeature.State()
        var settings = SettingsFeature.State()

        // AI input bar state
        var isAIInputExpanded: Bool = false
        var aiInputText: String = ""
        var isAIInputLoading: Bool = false
        var aiInputError: String? = nil      // shown inline below the text field
        var aiUnavailable: Bool = false      // set once on .task; drives all AI UI
        var inputPurpose: InputPurpose = .record
        var aiAnswer: String? = nil
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

        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case analysis(AnalysisFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Dependencies
    @Dependency(\.aiServiceClient) var aiServiceClient
    private enum CancelID { case aiExtraction; case aiAnswer }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
        }
        Scope(state: \.analysis, action: \.analysis) {
            AnalysisFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    // Check AI availability once at launch — stored in state so all AI UI reads a single flag.
                    await send(.aiAvailabilityLoaded(isAvailable: aiServiceClient.isAvailable()))
                }

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
                return .none

            case .answerFailed:
                state.isAIInputLoading = false
                state.aiInputError = String(localized: "ai_ask_error")
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

            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case .dashboard(.delegate(.accountTapped)):
                state.selectedTab = .analysis
                return .none

            case .dashboard(.delegate(.transactionTapped)):
                return .none

            case .dashboard:
                return .none

            case .transactions:
                return .none

            case .analysis:
                return .none

            case .settings:
                return .none
            }
        }
    }
}
