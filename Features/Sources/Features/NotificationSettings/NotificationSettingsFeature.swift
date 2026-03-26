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

        public init(
            dailyReminderEnabled: Bool = false,
            reminderDate: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date(),
            budgetWarningEnabled: Bool = false,
            warningThreshold: Int = 80,
            isAuthorized: Bool = false,
            showPermissionDeniedBanner: Bool = false
        ) {
            self.dailyReminderEnabled = dailyReminderEnabled
            self.reminderDate = reminderDate
            self.budgetWarningEnabled = budgetWarningEnabled
            self.warningThreshold = warningThreshold
            self.isAuthorized = isAuthorized
            self.showPermissionDeniedBanner = showPermissionDeniedBanner
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
    }

    // MARK: - Dependencies

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .task:
                let reminderEnabled = userSettingsClient.bool(.dailyReminderEnabled)
                let warningEnabled = userSettingsClient.bool(.budgetWarningEnabled)
                let hour = userSettingsClient.int(.dailyReminderHour)
                let minute = userSettingsClient.int(.dailyReminderMinute)
                let threshold = userSettingsClient.int(.budgetWarningThreshold)

                state.dailyReminderEnabled = reminderEnabled
                state.budgetWarningEnabled = warningEnabled
                state.warningThreshold = threshold
                state.reminderDate = Calendar.current.date(
                    from: DateComponents(hour: hour, minute: minute)
                ) ?? state.reminderDate

                return .run { send in
                    let authorized = await notificationClient.isAuthorized()
                    await send(.authorizationStatusLoaded(authorized))
                }
                .cancellable(id: CancelID.task)

            case let .authorizationStatusLoaded(authorized):
                state.isAuthorized = authorized
                if authorized {
                    state.showPermissionDeniedBanner = false
                }
                return .none

            case let .dailyReminderToggled(enabled):
                if !enabled {
                    state.dailyReminderEnabled = false
                    userSettingsClient.setBool(false, .dailyReminderEnabled)
                    return .run { _ in await notificationClient.cancelDailyReminder() }
                }
                // Enabling — request permission if needed
                if state.isAuthorized {
                    state.dailyReminderEnabled = true
                    userSettingsClient.setBool(true, .dailyReminderEnabled)
                    let hour = Calendar.current.component(.hour, from: state.reminderDate)
                    let minute = Calendar.current.component(.minute, from: state.reminderDate)
                    return .run { _ in try await notificationClient.scheduleDailyReminder(hour, minute) }
                } else {
                    return .run { send in
                        let granted = await notificationClient.requestAuthorization()
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
                userSettingsClient.setInt(hour, .dailyReminderHour)
                userSettingsClient.setInt(minute, .dailyReminderMinute)
                guard state.dailyReminderEnabled else { return .none }
                return .run { _ in try await notificationClient.scheduleDailyReminder(hour, minute) }

            case let .budgetWarningToggled(enabled):
                if !enabled {
                    state.budgetWarningEnabled = false
                    userSettingsClient.setBool(false, .budgetWarningEnabled)
                    return .none
                }
                if state.isAuthorized {
                    state.budgetWarningEnabled = true
                    userSettingsClient.setBool(true, .budgetWarningEnabled)
                    return .none
                } else {
                    return .run { send in
                        let granted = await notificationClient.requestAuthorization()
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
                userSettingsClient.setInt(threshold, .budgetWarningThreshold)
                return .none

            case .permissionDenied:
                state.showPermissionDeniedBanner = true
                return .none

            case .openSystemSettingsTapped:
                return .run { _ in
                    if let url = URL(string: "app-settings:") {
                        await openURL(url)
                    }
                }
            }
        }
    }
}
