import ComposableArchitecture
import Common
import SwiftUI

public struct SyncSettingsView: View {
    @Bindable var store: StoreOf<SyncSettingsFeature>

    public init(store: StoreOf<SyncSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    content
                    Text("sync_footer_hint")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle(String(localized: "sync_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await store.send(.task).finish() }
    }

    // MARK: - State Routing

    @ViewBuilder
    private var content: some View {
        if store.isSyncEnabled {
            enabledCard
        } else if !store.isCloudKitAvailable {
            unavailableCard
        } else {
            switch store.migrationState {
            case .migrating(let progress):
                migratingCard(progress: progress)
            case .failed(let message):
                offCard(failureMessage: message)
            case .idle, .completed:
                offCard(failureMessage: nil)
            }
        }
    }

    // MARK: - Off (idle)

    private func offCard(failureMessage: String?) -> some View {
        GlassContainer(cornerRadius: 22, padding: 22) {
            VStack(spacing: 18) {
                cloudHero(
                    symbol: "icloud.and.arrow.up",
                    tint: Color.Design.brandAccent
                )

                VStack(spacing: 8) {
                    Text("sync_enable_title")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.Design.textPrimary)
                    Text("sync_enable_subtitle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                featureHighlights

                storageNote

                if let failureMessage {
                    failureBanner(failureMessage)
                }

                primaryButton(
                    title: failureMessage == nil
                        ? String(localized: "sync_enable_button")
                        : String(localized: "sync_retry"),
                    enabled: true
                ) {
                    store.send(.enableSyncTapped)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Migrating

    // TODO: design shows "X / Y items · ~ Ns 剩餘" inside the progress block.
    // We only get a 0–1 progress float from SyncClient.enableSync(); plumb the
    // item counts and ETA through SyncSettingsFeature.State to display them.
    private func migratingCard(progress: Double) -> some View {
        GlassContainer(cornerRadius: 22, padding: 22) {
            VStack(spacing: 18) {
                ringProgressHero(progress: progress)

                Text("sync_migrating")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.Design.textPrimary)
                    .multilineTextAlignment(.center)

                progressBlock(progress: progress)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Unavailable

    private var unavailableCard: some View {
        GlassContainer(cornerRadius: 22, padding: 22) {
            VStack(spacing: 18) {
                cloudHero(
                    symbol: "icloud.slash",
                    tint: .secondary
                )

                VStack(spacing: 8) {
                    Text("sync_enable_title")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.Design.textPrimary)
                    Text("sync_enable_subtitle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                warningBanner

                primaryButton(
                    title: String(localized: "sync_enable_button"),
                    enabled: false
                ) {}

                Button {
                    openSystemSettings()
                } label: {
                    HStack(spacing: 6) {
                        Text("sync_open_settings")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.Design.brandAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Enabled

    // TODO: design shows "last sync · 2 分鐘前" + a 3-cell quick-stats strip
    // (transactions / accounts / categories). Both require SyncSettingsFeature
    // to surface lastSyncDate + per-entity counts — not in state today.
    private var enabledCard: some View {
        GlassContainer(cornerRadius: 22, padding: 22) {
            VStack(spacing: 18) {
                cloudHero(
                    symbol: "checkmark.icloud",
                    tint: Color.Design.incomeGreen
                )

                VStack(spacing: 6) {
                    Text("sync_enabled_title")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.Design.textPrimary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.Design.incomeGreen)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.Design.incomeGreen.opacity(0.7), radius: 4)
                        Text("sync_enabled_active")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                statusRowsCard

                lastSyncedRow

                syncNowButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers — Hero icons

    private func cloudHero(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.20), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 110, height: 110)
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }

    private func ringProgressHero(progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.Design.brandAccent.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 110, height: 110)

            Circle()
                .stroke(Color.Design.textPrimary.opacity(0.06), lineWidth: 3)
                .frame(width: 92, height: 92)

            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    Color.Design.brandAccent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 92, height: 92)
                .animation(.easeOut(duration: 0.3), value: progress)

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 36, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.Design.brandAccent)
        }
    }

    // MARK: - Helpers — Sections

    private var storageNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            Text("sync_storage_note")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var lastSyncedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("sync_last_synced_label")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(lastSyncedDisplay)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Design.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
    }

    private var lastSyncedDisplay: String {
        guard let date = store.lastSyncedAt else {
            return String(localized: "sync_last_synced_never")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = .current
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var syncNowButton: some View {
        Button {
            store.send(.syncNowTapped)
        } label: {
            HStack(spacing: 8) {
                if store.isManualSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.Design.brandAccent)
                    Text("sync_now_in_progress")
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                    Text("sync_now_button")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.Design.brandAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.Design.brandAccent.opacity(0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.Design.brandAccent.opacity(0.30), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(store.isManualSyncing)
    }

    private var featureHighlights: some View {
        GlassContainer(cornerRadius: 14, padding: 0) {
            VStack(spacing: 0) {
                featureRow(icon: "rectangle.connected.to.line.below", label: "sync_feature_cross_device")
                Divider().padding(.leading, 50)
                featureRow(icon: "lock.shield", label: "sync_feature_encryption")
                Divider().padding(.leading, 50)
                featureRow(icon: "arrow.triangle.2.circlepath", label: "sync_feature_offline")
            }
        }
    }

    private func featureRow(icon: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.Design.brandAccent)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.Design.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var warningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.Design.expenseRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("sync_icloud_unavailable_title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Design.expenseRed)
                Text("sync_icloud_unavailable")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Design.textPrimary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.Design.expenseRed.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.Design.expenseRed.opacity(0.25), lineWidth: 0.5)
        }
    }

    private func failureBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.Design.expenseRed)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.Design.expenseRed)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.Design.expenseRed.opacity(0.08))
        }
    }

    private func progressBlock(progress: Double) -> some View {
        GlassContainer(cornerRadius: 14, padding: 14) {
            VStack(spacing: 10) {
                HStack {
                    Text("sync_migrating_progress_label")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 1) {
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 15, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.Design.textPrimary)
                        Text("%")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: progress)
                    .tint(Color.Design.brandAccent)
            }
        }
    }

    private var statusRowsCard: some View {
        GlassContainer(cornerRadius: 14, padding: 0) {
            VStack(spacing: 0) {
                statusRow(
                    icon: "checkmark.icloud",
                    iconTint: Color.Design.incomeGreen,
                    label: "sync_enabled_label",
                    trailing: AnyView(
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.Design.incomeGreen)
                    )
                )
                Divider().padding(.leading, 50)
                statusRow(
                    icon: "person.icloud",
                    iconTint: Color.Design.brandAccent,
                    label: "sync_icloud_account_active",
                    trailing: AnyView(
                        Image(systemName: store.isCloudKitAvailable ? "checkmark" : "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                store.isCloudKitAvailable
                                    ? Color.Design.incomeGreen
                                    : Color.Design.expenseRed
                            )
                    )
                )
            }
        }
    }

    private func statusRow(
        icon: String,
        iconTint: Color,
        label: LocalizedStringKey,
        trailing: AnyView
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.Design.textPrimary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func primaryButton(
        title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    enabled ? Color.Design.textInverse : .secondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            enabled
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.Design.brandAccent,
                                            Color.Design.brandAccent.opacity(0.85)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                : AnyShapeStyle(Color.secondary.opacity(0.18))
                        )
                }
                .shadow(
                    color: enabled
                        ? Color.Design.brandAccent.opacity(0.30)
                        : .clear,
                    radius: 10,
                    y: 6
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#endif

#Preview("Off") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(
                    isSyncEnabled: false, isCloudKitAvailable: true
                )
            ) { SyncSettingsFeature() }
        )
    }
}

#Preview("Migrating") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(
                    isSyncEnabled: false,
                    isCloudKitAvailable: true,
                    migrationState: .migrating(progress: 0.64)
                )
            ) { SyncSettingsFeature() }
        )
    }
}

#Preview("Unavailable") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(
                    isSyncEnabled: false, isCloudKitAvailable: false
                )
            ) { SyncSettingsFeature() }
        )
    }
}

#Preview("Enabled") {
    NavigationStack {
        SyncSettingsView(
            store: Store(
                initialState: SyncSettingsFeature.State(
                    isSyncEnabled: true, isCloudKitAvailable: true
                )
            ) { SyncSettingsFeature() }
        )
    }
}
