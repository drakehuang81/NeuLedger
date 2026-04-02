import ComposableArchitecture
import Common
import SwiftUI

public struct SyncSettingsView: View {
    @Bindable var store: StoreOf<SyncSettingsFeature>

    public init(store: StoreOf<SyncSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !store.isSubscribed {
                    upsellSection
                } else if store.isSyncEnabled {
                    enabledSection
                } else {
                    enableSection
                }
            }
            .padding(.all, 16)
        }
        .background(Color.Design.background.ignoresSafeArea())
        .navigationTitle(String(localized: "sync_title"))
        .navigationBarTitleDisplayMode(.large)
        .task { await store.send(.task).finish() }
    }

    // MARK: - 未訂閱：廣告頁

    private var upsellSection: some View {
        VStack(spacing: 16) {
            GlassContainer(cornerRadius: 20, padding: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "icloud.and.arrow.up")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Color.Design.brandPrimary)

                    VStack(spacing: 8) {
                        Text(String(localized: "sync_upsell_headline"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.Design.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(String(localized: "sync_upsell_subtitle"))
                            .font(.body)
                            .foregroundStyle(Color.Design.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        featureRow(
                            icon: "iphone.and.ipad",
                            text: String(localized: "sync_upsell_feature_devices")
                        )
                        featureRow(
                            icon: "arrow.clockwise.icloud",
                            text: String(localized: "sync_upsell_feature_backup")
                        )
                        featureRow(
                            icon: "lock.icloud",
                            text: String(localized: "sync_upsell_feature_private")
                        )
                    }
                    .padding(.top, 4)

                    Button {
                        store.send(.subscribeNowTapped)
                    } label: {
                        Text(String(localized: "sync_subscribe_now"))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Design.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.Design.brandPrimary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 已訂閱、未開啟同步

    private var enableSection: some View {
        VStack(spacing: 16) {
            GlassContainer(cornerRadius: 16, padding: 20) {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "icloud.and.arrow.up")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(Color.Design.brandPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "sync_enable_title"))
                                .font(.headline)
                                .foregroundStyle(Color.Design.textPrimary)
                            Text(String(localized: "sync_enable_subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                        Spacer()
                    }

                    if !store.isCloudKitAvailable {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.expenseRed)
                            Text(String(localized: "sync_icloud_unavailable"))
                                .font(.footnote)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.Design.expenseRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }

                    switch store.migrationState {
                    case .idle:
                        Button {
                            store.send(.enableSyncTapped)
                        } label: {
                            Text(String(localized: "sync_enable_button"))
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    store.isCloudKitAvailable
                                        ? Color.Design.textInverse
                                        : Color.Design.textSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    store.isCloudKitAvailable
                                        ? Color.Design.brandPrimary
                                        : Color.Design.textSecondary.opacity(0.2),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .disabled(!store.isCloudKitAvailable)

                    case .migrating(let progress):
                        VStack(spacing: 10) {
                            HStack {
                                Text(String(localized: "sync_migrating"))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.Design.textSecondary)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(.subheadline)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(Color.Design.textSecondary)
                            }
                            ProgressView(value: progress)
                                .tint(Color.Design.brandPrimary)
                        }

                    case .completed:
                        EmptyView()

                    case .failed(let message):
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.Design.expenseRed)
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(Color.Design.expenseRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button {
                                store.send(.enableSyncTapped)
                            } label: {
                                Text(String(localized: "sync_retry"))
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.Design.textInverse)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.Design.brandPrimary, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 已開啟同步

    private var enabledSection: some View {
        VStack(spacing: 16) {
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.icloud")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.incomeGreen)
                            .frame(width: 22, height: 22)
                        Text(String(localized: "sync_enabled_label"))
                            .font(.body)
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.incomeGreen)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        Image(systemName: "person.icloud")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.Design.brandPrimary)
                            .frame(width: 22, height: 22)
                        Text(String(localized: "sync_icloud_account_active"))
                            .font(.body)
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        if store.isCloudKitAvailable {
                            Image(systemName: "checkmark")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.incomeGreen)
                                .font(.footnote)
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "xmark")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.Design.expenseRed)
                                .font(.footnote)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helper

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.Design.brandPrimary)
                .frame(width: 22, height: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.Design.textPrimary)
            Spacer()
        }
    }
}

#Preview("未訂閱") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(isSubscribed: false)
            ) { SyncSettingsFeature() }
        )
    }
}

#Preview("已訂閱未開啟") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(isSubscribed: true, isSyncEnabled: false, isCloudKitAvailable: true)
            ) { SyncSettingsFeature() }
        )
    }
}

#Preview("已開啟同步") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(isSubscribed: true, isSyncEnabled: true, isCloudKitAvailable: true)
            ) { SyncSettingsFeature() }
        )
    }
}
