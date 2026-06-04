import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AIAssistantFeature: Sendable {
    public init() {}

    public enum Role: Equatable, Sendable {
        case user, assistant
    }

    public struct Message: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let role: Role
        public let text: String

        public init(id: UUID = UUID(), role: Role, text: String) {
            self.id = id
            self.role = role
            self.text = text
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var messages: [Message] = []
        public var inputText: String = ""
        public var isExpanded: Bool = false
        public var isLoading: Bool = false
        public var errorMessage: String? = nil
        public var isAvailable: Bool = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case task
        case expandTapped
        case inputChanged(String)
        case submitTapped
        case answerReceived(String)
        case answerFailed(String)
        case dismissError
    }

    @Dependency(\.insightsClient) var insightsClient

    private enum CancelID { case ask }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isAvailable = insightsClient.isAIAvailable()
                return .none

            case .expandTapped:
                state.isExpanded.toggle()
                return .none

            case let .inputChanged(text):
                state.inputText = text
                return .none

            case .submitTapped:
                guard !state.inputText.isEmpty, !state.isLoading else { return .none }
                let question = state.inputText
                state.messages.append(Message(role: .user, text: question))
                state.inputText = ""
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let answer = try await insightsClient.answerFinancialQuestion(question)
                        await send(.answerReceived(answer))
                    } catch {
                        await send(.answerFailed(String(localized: "ai_assistant_error")))
                    }
                }
                .cancellable(id: CancelID.ask, cancelInFlight: true)

            case let .answerReceived(text):
                state.isLoading = false
                state.messages.append(Message(role: .assistant, text: text))
                return .none

            case let .answerFailed(error):
                state.isLoading = false
                state.errorMessage = error
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
