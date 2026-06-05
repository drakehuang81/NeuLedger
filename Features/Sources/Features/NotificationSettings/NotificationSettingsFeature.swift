import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct NotificationSettingsFeature: Sendable {
    public init() {}

    private enum CancelID { case task }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var dailyReminderEnabled: Bool = false
        /// Only hour and minute components are meaningful; date portion is irrelevant.
        public var reminderDate: Date = Calendar.current.date(
            from: DateComponents(hour: 21, minute: 0)
        ) ?? Date()
        public var budgetWarningEnabled: Bool = false
        public var warningThreshold: Int = 80
        public var isAuthorized: Bool = false
        public var showPermissionDeniedBanner: Bool = false
        public var recurringManagement: RecurringTransactionManagementFeature.State = .init()

        public init(
            dailyReminderEnabled: Bool = false,
            reminderDate: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date(),
            budgetWarningEnabled: Bool = false,
            warningThreshold: Int = 80,
            isAuthorized: Bool = false,
            showPermissionDeniedBanner: Bool = false,
            recurringManagement: RecurringTransactionManagementFeature.State = .init()
        ) {
            self.dailyReminderEnabled = dailyReminderEnabled
            self.reminderDate = reminderDate
            self.budgetWarningEnabled = budgetWarningEnabled
            self.warningThreshold = warningThreshold
            self.isAuthorized = isAuthorized
            self.showPermissionDeniedBanner = showPermissionDeniedBanner
            self.recurringManagement = recurringManagement
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case authorizationStatusLoaded(Bool)
        case dailyReminderToggled(Bool)
        case reminderDateChanged(Date)
        case budgetWarningToggled(Bool)
        case warningThresholdChanged(Int)
        case permissionDenied
        case openSystemSettingsTapped
        case recurringManagement(RecurringTransactionManagementFeature.Action)
    }

    // MARK: - Dependencies

    @Dependency(\.platformClient) var platformClient
    @Dependency(\.planningClient) var planningClient

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Scope(state: \.recurringManagement, action: \.recurringManagement) {
            RecurringTransactionManagementFeature()
        }
        Reduce { state, action in
            switch action {

            case .task:
                let reminderEnabled = platformClient.dailyReminderEnabled()
                let warningEnabled = planningClient.warningEnabled()
                let time = platformClient.reminderTime()
                let threshold = planningClient.warningThreshold()

                state.dailyReminderEnabled = reminderEnabled
                state.budgetWarningEnabled = warningEnabled
                state.warningThreshold = threshold
                state.reminderDate = Calendar.current.date(
                    from: DateComponents(hour: time.hour, minute: time.minute)
                ) ?? state.reminderDate

                return .merge(
                    .run { send in
                        let authorized = await platformClient.notificationsAuthorized()
                        await send(.authorizationStatusLoaded(authorized))
                    }
                    .cancellable(id: CancelID.task),
                    .send(.recurringManagement(.task))
                )

            case let .authorizationStatusLoaded(authorized):
                state.isAuthorized = authorized
                if authorized {
                    state.showPermissionDeniedBanner = false
                }
                return .none

            case let .dailyReminderToggled(enabled):
                if !enabled {
                    state.dailyReminderEnabled = false
                    platformClient.setDailyReminderEnabled(false)
                    return .run { _ in await platformClient.cancelDailyReminder() }
                }
                // Enabling — request permission if needed
                if state.isAuthorized {
                    state.dailyReminderEnabled = true
                    platformClient.setDailyReminderEnabled(true)
                    let hour = Calendar.current.component(.hour, from: state.reminderDate)
                    let minute = Calendar.current.component(.minute, from: state.reminderDate)
                    platformClient.setReminderTime(ReminderTime(hour: hour, minute: minute))
                    return .run { _ in try await platformClient.scheduleDailyReminder() }
                } else {
                    return .run { send in
                        let granted = await platformClient.requestNotificationPermission()
                        if granted {
                            await send(.authorizationStatusLoaded(true))
                            await send(.dailyReminderToggled(true))  // retry with auth
                        } else {
                            await send(.permissionDenied)
                        }
                    }
                }

            case let .reminderDateChanged(date):
                state.reminderDate = date
                let hour = Calendar.current.component(.hour, from: date)
                let minute = Calendar.current.component(.minute, from: date)
                platformClient.setReminderTime(ReminderTime(hour: hour, minute: minute))
                guard state.dailyReminderEnabled else { return .none }
                return .run { _ in try await platformClient.scheduleDailyReminder() }

            case let .budgetWarningToggled(enabled):
                if !enabled {
                    state.budgetWarningEnabled = false
                    planningClient.setWarningEnabled(false)
                    return .none
                }
                if state.isAuthorized {
                    state.budgetWarningEnabled = true
                    planningClient.setWarningEnabled(true)
                    return .none
                } else {
                    return .run { send in
                        let granted = await platformClient.requestNotificationPermission()
                        if granted {
                            await send(.authorizationStatusLoaded(true))
                            await send(.budgetWarningToggled(true))
                        } else {
                            await send(.permissionDenied)
                        }
                    }
                }

            case let .warningThresholdChanged(threshold):
                state.warningThreshold = threshold
                planningClient.setWarningThreshold(threshold)
                return .none

            case .permissionDenied:
                state.showPermissionDeniedBanner = true
                return .none

            case .openSystemSettingsTapped:
                platformClient.openAppSettings()
                return .none

            case .recurringManagement:
                return .none
            }
        }
    }
}
