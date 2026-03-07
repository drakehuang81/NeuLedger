import ComposableArchitecture
import Common
import SwiftUI

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Title
                Text("設定")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: 管理
                sectionManage

                // MARK: 偏好設定
                sectionPreferences

                // MARK: 資料
                sectionData

                // MARK: 關於
                sectionAbout
            }
            .padding(.top, 60)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .task { await store.send(.task).finish() }
    }

    // MARK: - 管理

    private var sectionManage: some View {
        VStack(spacing: 6) {
            sectionHeader("管理")
            glassCard {
                Button { store.send(.navigateToAccounts) } label: {
                    settingsRow(
                        icon: "wallet.bifold",
                        iconColor: Color.Design.brandPrimary,
                        label: "帳戶管理",
                        trailing: chevron
                    )
                }
                Button { store.send(.navigateToCategories) } label: {
                    settingsRow(
                        icon: "square.grid.2x2",
                        iconColor: Color.Design.brandSecondary,
                        label: "分類管理",
                        trailing: chevron
                    )
                }
                Button { store.send(.navigateToBudgets) } label: {
                    settingsRow(
                        icon: "banknote",
                        iconColor: Color.Design.incomeGreen,
                        label: "預算設定",
                        trailing: chevron
                    )
                }
                Button { store.send(.navigateToTags) } label: {
                    settingsRow(
                        icon: "tag",
                        iconColor: Color.Design.brandAccent,
                        label: "標籤管理",
                        trailing: chevron
                    )
                }
            }
        }
    }

    // MARK: - 偏好設定

    private var sectionPreferences: some View {
        VStack(spacing: 6) {
            sectionHeader("偏好設定")
            glassCard {
                settingsRow(
                    icon: "creditcard",
                    iconColor: Color.Design.textSecondary,
                    label: "預設帳戶",
                    trailing: Text(store.defaultAccountName.isEmpty ? "無" : store.defaultAccountName)
                        .font(.body)
                        .foregroundStyle(Color.Design.textSecondary)
                )
                settingsRow(
                    icon: "globe",
                    iconColor: Color.Design.textSecondary,
                    label: "語言",
                    trailing: Text("繁體中文")
                        .font(.body)
                        .foregroundStyle(Color.Design.textSecondary)
                )
                settingsRow(
                    icon: "sparkles",
                    iconColor: Color.Design.brandPrimary,
                    label: "AI 智慧功能",
                    trailing: Toggle("", isOn: $store.isAIEnabled.sending(\.aiToggleChanged))
                        .labelsHidden()
                        .tint(Color.Design.incomeGreen)
                )
            }
        }
    }

    // MARK: - 資料

    private var sectionData: some View {
        VStack(spacing: 6) {
            sectionHeader("資料")
            glassCard {
                Button { store.send(.exportCSVTapped) } label: {
                    settingsRow(
                        icon: "square.and.arrow.down",
                        iconColor: Color.Design.textSecondary,
                        label: "匯出 CSV",
                        trailing: chevron
                    )
                }
                Button { store.send(.exportJSONTapped) } label: {
                    settingsRow(
                        icon: "tablecells",
                        iconColor: Color.Design.textSecondary,
                        label: "匯出 JSON",
                        trailing: chevron
                    )
                }
            }
        }
    }

    // MARK: - 關於

    private var sectionAbout: some View {
        VStack(spacing: 6) {
            sectionHeader("關於")
            glassCard {
                settingsRow(
                    icon: "info.circle",
                    iconColor: Color.Design.textSecondary,
                    label: "版本",
                    trailing: Text(appVersion)
                        .font(.body)
                        .foregroundStyle(Color.Design.textTertiary)
                )
                Button { store.send(.privacyPolicyTapped) } label: {
                    settingsRow(
                        icon: "doc.text",
                        iconColor: Color.Design.textSecondary,
                        label: "隱私權政策",
                        trailing: chevron
                    )
                }
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

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .glassEffect(
            Glass.clear
                .interactive()
                .tint(Color.Design.background),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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
