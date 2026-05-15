import SwiftUI
import ComposableArchitecture
import Common
import Domain

public struct NotificationSettingsView: View {
    @Bindable var store: StoreOf<NotificationSettingsFeature>

    public init(store: StoreOf<NotificationSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    // Permission denied banner
                    if store.showPermissionDeniedBanner {
                        permissionBanner
                    }

                    // Daily reminder section
                    dailyReminderSection

                    // Budget warning section
                    budgetWarningSection

                    // Recurring reminders section
                    RecurringSectionView(
                        store: store.scope(
                            state: \.recurringManagement,
                            action: \.recurringManagement
                        )
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle(String(localized: "settings_notification_settings"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await store.send(.task).finish() }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        GlassContainer(cornerRadius: 14, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                // Bell-slash icon box
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.Design.brandPrimary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.Design.brandPrimary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "notification_settings_permission_denied_title"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Design.textPrimary)

                    Text(String(localized: "notification_permission_denied_banner"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.Design.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        store.send(.openSystemSettingsTapped)
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(localized: "notification_open_settings"))
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.Design.brandPrimary)
                                .shadow(color: Color.Design.brandPrimary.opacity(0.4), radius: 6, y: 3)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.Design.brandPrimary.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Daily Reminder Section

    private var dailyReminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "notification_daily_reminder_section"))

            GlassContainer(cornerRadius: 14, padding: 0) {
                VStack(spacing: 0) {
                    // Toggle row
                    HStack {
                        Text(String(localized: "notification_daily_reminder_toggle"))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer(minLength: 0)
                        Toggle("", isOn: Binding(
                            get: { store.dailyReminderEnabled },
                            set: { store.send(.dailyReminderToggled($0)) }
                        ))
                        .labelsHidden()
                        .tint(Color.Design.incomeGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    // Time picker row — always visible
                    rowDivider
                    HStack {
                        Text(String(localized: "notification_reminder_time"))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer(minLength: 0)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { store.reminderDate },
                                set: { store.send(.reminderDateChanged($0)) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .disabled(!store.dailyReminderEnabled)
                        .opacity(store.dailyReminderEnabled ? 1 : 0.4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
            }

            sectionFooter(String(localized: "notification_settings_daily_desc"))
        }
    }

    // MARK: - Budget Warning Section

    private var budgetWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "notification_budget_warning_section"))

            GlassContainer(cornerRadius: 14, padding: 0) {
                VStack(spacing: 0) {
                    // Toggle row
                    HStack {
                        Text(String(localized: "notification_budget_warning_toggle"))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer(minLength: 0)
                        Toggle("", isOn: Binding(
                            get: { store.budgetWarningEnabled },
                            set: { store.send(.budgetWarningToggled($0)) }
                        ))
                        .labelsHidden()
                        .tint(Color.Design.incomeGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    // Threshold picker — always visible
                    rowDivider
                    thresholdPicker
                        .disabled(!store.budgetWarningEnabled)
                        .opacity(store.budgetWarningEnabled ? 1 : 0.4)
                }
            }

            sectionFooter(String(localized: "notification_settings_budget_desc"))
        }
    }

    // Threshold 5-pill selector
    private var thresholdPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "notification_settings_threshold_label"))
                    .font(.system(size: 11, weight: .medium))
                    .monospaced()
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                Spacer(minLength: 0)
                Text(String(format: String(localized: "notification_settings_threshold_footer"), store.warningThreshold))
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(Color.Design.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach([50, 60, 70, 80, 90], id: \.self) { value in
                    let selected = store.warningThreshold == value
                    Button {
                        store.send(.warningThresholdChanged(value))
                    } label: {
                        Text("\(value)%")
                            .font(.system(size: 14, weight: .semibold).monospaced())
                            .foregroundStyle(selected ? .white : Color.Design.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        selected
                                            ? AnyShapeStyle(Color.Design.brandPrimary)
                                            : AnyShapeStyle(Color.Design.surface.opacity(0.6))
                                    )
                                    .shadow(
                                        color: selected ? Color.Design.brandPrimary.opacity(0.4) : .clear,
                                        radius: 6, y: 3
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        selected ? Color.clear : Color.Design.separator.opacity(0.3),
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .monospaced()
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.Design.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.Design.textSecondary)
            .lineSpacing(2.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.Design.separator.opacity(0.4))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

// MARK: - Recurring Section View

private struct RecurringSectionView: View {
    @Bindable var store: StoreOf<RecurringTransactionManagementFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header with active count eyebrow
            HStack {
                Text(String(localized: "notification_recurring_section"))
                    .font(.system(size: 11, weight: .medium))
                    .monospaced()
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                Spacer(minLength: 0)
                let activeCount = store.items.filter(\.isActive).count
                let totalCount = store.items.count
                if totalCount > 0 {
                    Text("\(activeCount) / \(totalCount) ON")
                        .font(.system(size: 11).monospaced())
                        .tracking(0.6)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }
            .padding(.horizontal, 6)

            Text(String(localized: "notification_recurring_description"))
                .font(.system(size: 12))
                .foregroundStyle(Color.Design.textSecondary)
                .lineSpacing(2.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

            GlassContainer(cornerRadius: 14, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        recurringRow(item: item, isLast: index == store.items.count - 1)
                    }

                    // Add row
                    if !store.items.isEmpty {
                        Rectangle()
                            .fill(Color.Design.separator.opacity(0.4))
                            .frame(height: 0.5)
                            .padding(.leading, 16)
                    }
                    addRow
                }
            }
        }
        .sheet(item: $store.scope(state: \.form, action: \.form)) { formStore in
            NavigationStack {
                RecurringTransactionFormView(store: formStore)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // TODO: design shows a per-item accent + glyph (e.g. Netflix → film, rent
    // → house) and a "下次 5/25" due-date subtitle. `RecurringTransaction` has
    // no icon/color fields, and we don't surface `nextDueDate` here yet —
    // restore both once the domain model gains them.
    private func recurringRow(item: RecurringTransaction, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon box
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Design.brandPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.Design.brandPrimary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.note ?? String(localized: "notification_recurring_empty"))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.Design.textPrimary)
                        .lineLimit(1)

                    Text("\(item.amount.twdFormatted) · \(item.frequency.localizedName)")
                        .font(Font.Design.caption.monospaced())
                        .foregroundStyle(Color.Design.textSecondary)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: Binding(
                    get: { item.isActive },
                    set: { _ in store.send(.toggleActiveTapped(item)) }
                ))
                .labelsHidden()
                .tint(Color.Design.incomeGreen)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                store.send(.itemTapped(item))
            }
            .contextMenu {
                Button(role: .destructive) {
                    store.send(.deleteTapped(item.id))
                } label: {
                    Label(String(localized: "common_delete"), systemImage: "trash")
                }
            }

            if !isLast {
                Rectangle()
                    .fill(Color.Design.separator.opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.leading, 64)
            }
        }
    }

    private var addRow: some View {
        Button {
            store.send(.addButtonTapped)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.Design.brandPrimary)
                Text(String(localized: "notification_recurring_add"))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.Design.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
