import ComposableArchitecture
import Common
import Domain
import SwiftUI
import UIKit

// MARK: - IdentifiableURL

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - SettingsView

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack {
                WarmGradientBackground(variant: .top)

                ScrollView {
                    VStack(spacing: 22) {
                        sectionManage
                        sectionPreferences
                        sectionWidget
                        sectionData
                        #if DEBUG
                        sectionDebugDanger
                        #endif
                        sectionAbout
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle(String(localized: "settings_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task { await store.send(.task).finish() }
            .sheet(
                item: Binding(
                    get: { store.exportedFileURL.map { IdentifiableURL(url: $0) } },
                    set: { if $0 == nil { store.send(.exportSheetDismissed) } }
                )
            ) { identifiable in
                ShareSheet(items: [identifiable.url])
            }
        } destination: { store in
            switch store.case {
            case .accountManagement(let s):     AccountManagementView(store: s)
            case .categoryManagement(let s):    CategoryManagementView(store: s)
            case .budgetManagement(let s):      BudgetManagementView(store: s)
            case .tagManagement(let s):         TagManagementView(store: s)
            case .carrierManagement(let s):     CarrierManagementView(store: s)
            case .notificationSettings(let s):  NotificationSettingsView(store: s)
            case .syncSettings(let s):          SyncSettingsView(store: s)
            case .watchSettings(let s):         WatchSettingsView(store: s)
            }
        }
    }

    // MARK: - Sections

    private var sectionManage: some View {
        sGroup(String(localized: "settings_manage")) {
            sRow(icon: "wallet.bifold", iconBg: Color.Design.iconCyan,
                 label: String(localized: "settings_account_management")) {
                store.send(.accountManagementTapped)
            }
            rowDivider
            sRow(icon: "square.grid.2x2", iconBg: Color.Design.accentOrange,
                 label: String(localized: "settings_category_management")) {
                store.send(.categoryManagementTapped)
            }
            rowDivider
            sRow(icon: "banknote", iconBg: Color.Design.accentGreen,
                 label: String(localized: "settings_budget_management")) {
                store.send(.budgetManagementTapped)
            }
            rowDivider
            sRow(icon: "tag", iconBg: Color.Design.transferPurple,
                 label: String(localized: "settings_tag_management")) {
                store.send(.tagManagementTapped)
            }
            rowDivider
            sRow(icon: "creditcard.and.123", iconBg: Color.Design.iconPurple,
                 label: String(localized: "settings_carrier_management")) {
                store.send(.carrierManagementTapped)
            }
        }
    }

    private var sectionPreferences: some View {
        sGroup(String(localized: "settings_preferences")) {
            sRow(icon: "creditcard.fill", iconBg: Color.Design.iconBlueAlt,
                 label: String(localized: "settings_default_account"),
                 value: store.defaultAccountName) {
                store.send(.defaultAccountTapped)
            }.confirmationDialog(
                String(localized: "settings_default_account"),
                isPresented: Binding(
                    get: { store.isPickingDefaultAccount },
                    set: { if !$0 { store.send(.defaultAccountPickerDismissed) } }
                ),
                titleVisibility: .visible
            ) {
                ForEach(store.accounts) { account in
                    Button(account.name) {
                        store.send(.defaultAccountSelected(account.id.uuidString))
                    }
                }
                Button(String(localized: "common_cancel"), role: .cancel) {}
            }

            rowDivider

            sRow(icon: "globe", iconBg: Color.Design.iconBlueAlt,
                 label: String(localized: "settings_language"),
                 value: store.currentLanguage) {
                store.send(.languageTapped)
            }

            rowDivider

            sRow(icon: "bell.badge", iconBg: Color.Design.accentRed,
                 label: String(localized: "settings_notification_settings")) {
                store.send(.notificationSettingsTapped)
            }

            rowDivider

            sToggleRow(
                icon: "dock.rectangle",
                iconBg: Color.Design.accentGreen,
                label: String(localized: "settings_show_accessory_bar"),
                isOn: $store.showAccessoryBar.sending(\.accessoryBarToggleChanged)
            )
        }
    }

    private var sectionWidget: some View {
        sGroup(String(localized: "settings_widget")) {
            if store.carriers.isEmpty {
                rowContent(
                    icon: "creditcard.fill",
                    iconBg: Color.Design.iconCyan,
                    label: String(localized: "settings_widget_carrier"),
                    value: String(localized: "settings_widget_no_carrier"),
                    showChevron: false
                )
            } else {
                sRow(
                    icon: "creditcard.fill",
                    iconBg: Color.Design.iconCyan,
                    label: String(localized: "settings_widget_carrier"),
                    value: store.widgetCarrierName.isEmpty
                        ? String(localized: "common_please_select")
                        : store.widgetCarrierName
                ) {
                    store.send(.widgetCarrierTapped)
                }
                .confirmationDialog(
                    String(localized: "settings_widget_carrier"),
                    isPresented: Binding(
                        get: { store.isPickingWidgetCarrier },
                        set: { if !$0 { store.send(.widgetCarrierPickerDismissed) } }
                    ),
                    titleVisibility: .visible
                ) {
                    ForEach(store.carriers) { carrier in
                        Button(carrier.name) {
                            store.send(.widgetCarrierSelected(carrier.id))
                        }
                    }
                    Button(String(localized: "common_cancel"), role: .cancel) {}
                }
            }

            rowDivider

            rowContent(
                icon: "mic.fill",
                iconBg: Color.Design.iconGray,
                label: String(localized: "settings_widget_voice_account"),
                value: String(localized: "settings_widget_coming_soon"),
                showChevron: false
            )
        }
    }

    private var sectionData: some View {
        sGroup(
            String(localized: "settings_data"),
            footer: store.exportError
        ) {
            sRow(icon: "applewatch", iconBg: Color.Design.iconGray,
                 label: String(localized: "settings_watch_row_title")) {
                store.send(.watchSettingsTapped)
            }

            rowDivider

            sRow(icon: "icloud.and.arrow.up", iconBg: Color.Design.iconCyan,
                 label: String(localized: "settings_sync")) {
                store.send(.syncSettingsTapped)
            }

            rowDivider

            sRow(
                icon: "square.and.arrow.down",
                iconBg: Color.Design.transferPurple,
                label: String(localized: "settings_export_csv"),
                trailing: store.exportingFormat == .csv ? AnyView(ProgressView()) : nil
            ) {
                if store.exportingFormat == nil { store.send(.exportCSVTapped) }
            }

            rowDivider

            sRow(
                icon: "tablecells",
                iconBg: Color.Design.iconPurple,
                label: String(localized: "settings_export_json"),
                trailing: store.exportingFormat == .json ? AnyView(ProgressView()) : nil
            ) {
                if store.exportingFormat == nil { store.send(.exportJSONTapped) }
            }
        }
    }

    #if DEBUG
    private var sectionDebugDanger: some View {
        sGroup(
            "DEBUG",
            footer: store.seedRandomDataError ?? store.wipeAllDataError
        ) {
            sRow(
                icon: "die.face.5",
                iconBg: Color.Design.iconBlueAlt,
                label: "產生隨機測試資料",
                value: store.seedRandomDataResult,
                trailing: store.isSeedingRandomData ? AnyView(ProgressView()) : nil
            ) {
                if !store.isSeedingRandomData { store.send(.seedRandomDataTapped) }
            }

            rowDivider

            sRow(
                icon: "trash",
                iconBg: Color.Design.expenseRed,
                label: String(localized: "settings_wipe_all_data"),
                trailing: store.isWipingAllData ? AnyView(ProgressView()) : nil
            ) {
                if !store.isWipingAllData { store.send(.wipeAllDataTapped) }
            }
        }
        .confirmationDialog(
            String(localized: "settings_wipe_all_data_confirm_title"),
            isPresented: Binding(
                get: { store.isConfirmingWipeAllData },
                set: { if !$0 { store.send(.wipeAllDataDismissed) } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings_wipe_all_data_confirm_action"), role: .destructive) {
                store.send(.wipeAllDataConfirmed)
            }
            Button(String(localized: "common_cancel"), role: .cancel) {}
        } message: {
            Text("settings_wipe_all_data_confirm_message")
        }
    }
    #endif

    private var sectionAbout: some View {
        sGroup(String(localized: "settings_about")) {
            rowContent(
                icon: "info.circle",
                iconBg: Color.Design.iconGray,
                label: String(localized: "settings_version"),
                value: appVersion,
                showChevron: false
            )

            rowDivider

            sRow(icon: "doc.text", iconBg: Color.Design.iconGray,
                 label: String(localized: "settings_privacy")) {
                store.send(.privacyPolicyTapped)
            }
        }
    }

    // MARK: - Row primitives

    @ViewBuilder
    private func sGroup<Content: View>(
        _ label: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label)
                    .font(Font.Design.size11Medium)
                    .monospaced()
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                    .padding(.horizontal, 6)
            }
            GlassContainer(cornerRadius: 14, padding: 0) {
                VStack(spacing: 0) { content() }
            }
            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(Font.Design.size11)
                    .foregroundStyle(footer == store.exportError ? Color.Design.expenseRed : Color.Design.textSecondary)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
            }
        }
    }

    private func sRow(
        icon: String,
        iconBg: Color,
        label: String,
        value: String? = nil,
        trailing: AnyView? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            rowContent(
                icon: icon, iconBg: iconBg,
                label: label, value: value,
                trailing: trailing,
                showChevron: trailing == nil
            )
        }
        .buttonStyle(.plain)
    }

    private func sToggleRow(
        icon: String,
        iconBg: Color,
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            iconBox(icon, bg: iconBg)
            Text(label)
                .font(Font.Design.size15)
                .foregroundStyle(Color.Design.textPrimary)
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.Design.incomeGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func rowContent(
        icon: String,
        iconBg: Color,
        label: String,
        value: String? = nil,
        trailing: AnyView? = nil,
        showChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            iconBox(icon, bg: iconBg)
            Text(label)
                .font(Font.Design.size15)
                .foregroundStyle(Color.Design.textPrimary)
            Spacer(minLength: 0)
            if let value, !value.isEmpty {
                Text(value)
                    .font(Font.Design.size14)
                    .foregroundStyle(Color.Design.textSecondary)
                    .lineLimit(1)
            }
            if let trailing {
                trailing
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(Font.Design.size12Semibold)
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func iconBox(_ system: String, bg: Color) -> some View {
        Image(systemName: system)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.white)
            .font(Font.Design.size13Semibold)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(bg)
            )
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.Design.separator.opacity(0.4))
            .frame(height: 0.5)
            .padding(.leading, 54) // 14 (h pad) + 28 (icon) + 12 (gap)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
    )
}
