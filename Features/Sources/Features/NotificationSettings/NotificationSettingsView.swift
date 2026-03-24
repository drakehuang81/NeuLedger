import SwiftUI
import ComposableArchitecture
import Common

public struct NotificationSettingsView: View {
    @Bindable var store: StoreOf<NotificationSettingsFeature>

    public init(store: StoreOf<NotificationSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Permission denied banner
                if store.showPermissionDeniedBanner {
                    permissionBanner
                }

                // Daily reminder section
                dailyReminderSection

                // Budget warning section
                budgetWarningSection
            }
            .padding(16)
        }
        .background(Color.Design.background.ignoresSafeArea())
        .navigationTitle(String(localized: "settings_notification_settings"))
        .navigationBarTitleDisplayMode(.large)
        .task { await store.send(.task).finish() }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        GlassContainer(cornerRadius: 12, padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "notification_permission_denied_banner"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button(String(localized: "notification_open_settings")) {
                    store.send(.openSystemSettingsTapped)
                }
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Daily Reminder Section

    private var dailyReminderSection: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "notification_daily_reminder_section"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    row {
                        Toggle(
                            String(localized: "notification_daily_reminder_toggle"),
                            isOn: Binding(
                                get: { store.dailyReminderEnabled },
                                set: { store.send(.dailyReminderToggled($0)) }
                            )
                        )
                    }

                    if store.dailyReminderEnabled {
                        Divider().padding(.horizontal, 16)
                        row {
                            DatePicker(
                                String(localized: "notification_reminder_time"),
                                selection: Binding(
                                    get: { store.reminderDate },
                                    set: { store.send(.reminderDateChanged($0)) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Budget Warning Section

    private var budgetWarningSection: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "notification_budget_warning_section"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    row {
                        Toggle(
                            String(localized: "notification_budget_warning_toggle"),
                            isOn: Binding(
                                get: { store.budgetWarningEnabled },
                                set: { store.send(.budgetWarningToggled($0)) }
                            )
                        )
                    }

                    if store.budgetWarningEnabled {
                        Divider().padding(.horizontal, 16)
                        row {
                            Picker(
                                String(localized: "notification_warning_threshold"),
                                selection: Binding(
                                    get: { store.warningThreshold },
                                    set: { store.send(.warningThresholdChanged($0)) }
                                )
                            ) {
                                ForEach([50, 60, 70, 80, 90], id: \.self) { value in
                                    Text("\(value)%").tag(value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}
