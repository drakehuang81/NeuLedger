import Foundation
import ComposableArchitecture
import Domain

@Reducer
struct AccessoryBarFeature {
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var isAIInputExpanded: Bool = false
        var aiInputText: String = ""
        var isAIInputLoading: Bool = false
        var aiInputError: String? = nil      // shown inline below the text field
        var aiUnavailable: Bool = false      // set by aiAvailabilityLoaded; drives all AI UI
        var isRecording: Bool = false
        var accessoryMode: AccessoryMode = .add
    }

    // MARK: - Action
    enum Action: Equatable {
        // Lifecycle
        case task
        case aiAvailabilityLoaded(isAvailable: Bool)   // true means AI IS available
        case accessoryModeLoaded(AccessoryMode)
        case accessoryModeSwitched(AccessoryMode)

        // AI input bar
        case aiInputButtonTapped
        case aiInputTextChanged(String)
        case aiInputSubmitted
        case aiInputDismissed
        case aiExtractionCompleted(TaskResult<ExtractedTransaction>)

        // Recording
        case recordingTapped
        case recordingStarted
        case permissionDenied
        case transcriptionUpdated(String)
        case transcriptionFailed

        // Quick-add (.add mode) tap
        case contextActionTapped

        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            /// `.add` 模式點擊 — 由 parent 依 selectedTab 決定要新增到哪個 tab。
            case contextActionRequested
            /// AI 擷取成功 — 由 parent 依 selectedTab 派給對應 child。
            case transactionExtracted(ExtractedTransaction)
        }
    }

    // MARK: - Dependencies
    @Dependency(\.captureClient) var captureClient
    @Dependency(\.userSettingsAdapter) var userSettingsAdapter

    private enum CancelID {
        case aiExtraction
        case speechRecording
        case task
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let isAvailable = captureClient.isAvailable()
                    await send(.aiAvailabilityLoaded(isAvailable: isAvailable))
                    let rawMode = userSettingsAdapter.string(.accessoryMode)
                    let savedMode = AccessoryMode(rawValue: rawMode) ?? .add
                    let resolvedMode = isAvailable ? savedMode : .add
                    await send(.accessoryModeLoaded(resolvedMode))
                }
                .cancellable(id: CancelID.task, cancelInFlight: true)

            case let .aiAvailabilityLoaded(isAvailable):
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
                let wasRecording = state.isRecording
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                state.aiInputError = nil
                state.isRecording = false
                if wasRecording {
                    return .merge(
                        .cancel(id: CancelID.speechRecording),
                        .run { _ in captureClient.stopVoiceSession() }
                    )
                }
                return .none

            case .aiInputSubmitted:
                guard !state.aiInputText.isEmpty, !state.isRecording else { return .none }
                state.isAIInputLoading = true
                state.aiInputError = nil
                let text = state.aiInputText
                return .run { send in
                    await send(.aiExtractionCompleted(
                        TaskResult { try await captureClient.extractFromText(text) }
                    ))
                }
                .cancellable(id: CancelID.aiExtraction, cancelInFlight: true)

            case let .aiExtractionCompleted(.success(extracted)):
                state.isAIInputExpanded = false
                state.aiInputText = ""
                state.isAIInputLoading = false
                return .send(.delegate(.transactionExtracted(extracted)))

            case .aiExtractionCompleted(.failure):
                state.isAIInputLoading = false
                state.aiInputError = String(localized: "ai_extraction_error")
                return .none

            case .recordingTapped:
                if state.isRecording {
                    state.isRecording = false
                    return .merge(
                        .cancel(id: CancelID.speechRecording),
                        .run { _ in captureClient.stopVoiceSession() }
                    )
                } else {
                    return .run { send in
                        let granted = await captureClient.requestVoicePermission()
                        guard granted else {
                            await send(.permissionDenied)
                            return
                        }
                        await send(.recordingStarted)
                        do {
                            for try await text in captureClient.startVoiceSession() {
                                await send(.transcriptionUpdated(text))
                            }
                        } catch {
                            await send(.transcriptionFailed)
                        }
                    }
                    .cancellable(id: CancelID.speechRecording)
                }

            case .recordingStarted:
                state.isRecording = true
                state.aiInputError = nil
                return .none

            case .permissionDenied:
                state.aiInputError = String(localized: "speech_permission_denied_error")
                return .none

            case let .transcriptionUpdated(text):
                state.aiInputText = text
                return .none

            case .transcriptionFailed:
                state.isRecording = false
                state.aiInputError = String(localized: "speech_recognition_failed_error")
                return .none

            case let .accessoryModeLoaded(mode):
                state.accessoryMode = state.aiUnavailable ? .add : mode
                return .none

            case let .accessoryModeSwitched(mode):
                state.accessoryMode = mode
                userSettingsAdapter.setString(mode.rawValue, .accessoryMode)
                return .none

            case .contextActionTapped:
                return .send(.delegate(.contextActionRequested))

            case .delegate:
                return .none
            }
        }
    }
}
