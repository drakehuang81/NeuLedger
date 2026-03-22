import ComposableArchitecture
import Common
import SwiftUI
import UIKit

// MARK: - Navigation Destination

enum SettingsRoute: Hashable {
    case accountManagement
    case categoryManagement
    case budgetManagement
    case tagManagement
}

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

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: 管理
                    sectionManage

                    // MARK: 偏好設定
                    sectionPreferences

                    // MARK: 資料
                    sectionData

                    // MARK: 關於
                    sectionAbout
                }
                .padding(.all, 16)
            }
            .background(Color.Design.background.ignoresSafeArea())
            .navigationTitle(String(localized: "settings_title"))
            .navigationBarTitleDisplayMode(.large)
            .task { await store.send(.task).finish() }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .accountManagement:
                    AccountManagementView(
                        store: Store(initialState: AccountManagementFeature.State()) {
                            AccountManagementFeature()
                        }
                    )
                case .categoryManagement:
                    CategoryManagementView(
                        store: Store(initialState: CategoryManagementFeature.State()) {
                            CategoryManagementFeature()
                        }
                    )
                case .budgetManagement:
                    BudgetManagementView(
                        store: Store(initialState: BudgetManagementFeature.State()) {
                            BudgetManagementFeature()
                        }
                    )
                case .tagManagement:
                    TagManagementView(
                        store: Store(initialState: TagManagementFeature.State()) {
                            TagManagementFeature()
                        }
                    )
                }
            }
            .sheet(
                item: Binding(
                    get: { store.exportedFileURL.map { IdentifiableURL(url: $0) } },
                    set: { if $0 == nil { store.send(.exportSheetDismissed) } }
                )
            ) { identifiable in
                ShareSheet(items: [identifiable.url])
            }
        }
    }

    // MARK: - 管理

    private var sectionManage: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "settings_manage"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink(value: SettingsRoute.accountManagement) {
                        settingsRow(
                            icon: "wallet.bifold",
                            iconColor: Color.Design.brandPrimary,
                            label: String(localized: "settings_account_management"),
                            trailing: chevron
                        )
                    }
                    NavigationLink(value: SettingsRoute.categoryManagement) {
                        settingsRow(
                            icon: "square.grid.2x2",
                            iconColor: Color.Design.brandSecondary,
                            label: String(localized: "settings_category_management"),
                            trailing: chevron
                        )
                    }
                    NavigationLink(value: SettingsRoute.budgetManagement) {
                        settingsRow(
                            icon: "banknote",
                            iconColor: Color.Design.incomeGreen,
                            label: String(localized: "settings_budget_management"),
                            trailing: chevron
                        )
                    }
                    NavigationLink(value: SettingsRoute.tagManagement) {
                        settingsRow(
                            icon: "tag",
                            iconColor: Color.Design.brandAccent,
                            label: String(localized: "settings_tag_management"),
                            trailing: chevron
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 偏好設定

    private var sectionPreferences: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "settings_preferences"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    Picker(selection: Binding(
                        get: { store.selectedDefaultAccountId },
                        set: { store.send(.defaultAccountSelected($0)) }
                    ), label: settingsRow(
                        icon: "creditcard",
                        iconColor: Color.Design.textSecondary,
                        label: String(localized: "settings_default_account"),
                        trailing: EmptyView()
                    )) {
                        ForEach(store.accounts) { account in
                            Text(account.name).tag(account.id.uuidString)
                        }
                    }
                    Button { store.send(.languageTapped) } label: {
                        settingsRow(
                            icon: "globe",
                            iconColor: Color.Design.textSecondary,
                            label: String(localized: "settings_language"),
                            trailing: HStack(spacing: 4) {
                                Text(store.currentLanguage)
                                    .font(.body)
                                    .foregroundStyle(Color.Design.textSecondary)
                                chevron
                            }
                        )
                    }
                    settingsRow(
                        icon: "sparkles",
                        iconColor: Color.Design.brandPrimary,
                        label: String(localized: "settings_ai_features"),
                        trailing: Toggle("", isOn: $store.isAIEnabled.sending(\.aiToggleChanged))
                            .labelsHidden()
                            .tint(Color.Design.incomeGreen)
                    )
                    settingsRow(
                        icon: "dock.rectangle",
                        iconColor: Color.Design.textSecondary,
                        label: String(localized: "settings_show_accessory_bar"),
                        trailing: Toggle("", isOn: $store.showAccessoryBar.sending(\.accessoryBarToggleChanged))
                            .labelsHidden()
                            .tint(Color.Design.incomeGreen)
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 資料

    private var sectionData: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "settings_data"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    Button { store.send(.exportCSVTapped) } label: {
                        settingsRow(
                            icon: "square.and.arrow.down",
                            iconColor: Color.Design.textSecondary,
                            label: String(localized: "settings_export_csv"),
                            trailing: store.exportingFormat == .csv ? AnyView(ProgressView()) : AnyView(chevron)
                        )
                    }
                    .disabled(store.exportingFormat != nil)

                    Button { store.send(.exportJSONTapped) } label: {
                        settingsRow(
                            icon: "tablecells",
                            iconColor: Color.Design.textSecondary,
                            label: String(localized: "settings_export_json"),
                            trailing: store.exportingFormat == .json ? AnyView(ProgressView()) : AnyView(chevron)
                        )
                    }
                    .disabled(store.exportingFormat != nil)

                    if let errorMessage = store.exportError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 關於

    private var sectionAbout: some View {
        VStack(spacing: 6) {
            sectionHeader(String(localized: "settings_about"))
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    settingsRow(
                        icon: "info.circle",
                        iconColor: Color.Design.textSecondary,
                        label: String(localized: "settings_version"),
                        trailing: Text(appVersion)
                            .font(.body)
                            .foregroundStyle(Color.Design.textTertiary)
                    )
                    Button { store.send(.privacyPolicyTapped) } label: {
                        settingsRow(
                            icon: "doc.text",
                            iconColor: Color.Design.textSecondary,
                            label: String(localized: "settings_privacy"),
                            trailing: chevron
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.Design.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        label: String,
        trailing: Trailing
    ) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconColor)
                    .frame(width: 22, height: 22)
                Text(label)
                    .font(.body)
                    .foregroundStyle(Color.Design.textPrimary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.Design.textTertiary)
            .frame(width: 20, height: 20)
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
