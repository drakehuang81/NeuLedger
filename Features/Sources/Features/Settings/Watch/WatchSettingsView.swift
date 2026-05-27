import SwiftUI
import ComposableArchitecture
import Common
import Domain

public struct WatchSettingsView: View {

    @Bindable public var store: StoreOf<WatchSettingsFeature>

    public init(store: StoreOf<WatchSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            statusSection
            if store.isPaired && store.isWatchAppInstalled {
                defaultAccountSection
            }
        }
        .navigationTitle(String(localized: "watch_settings_title"))
        .task { await store.send(.task).finish() }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            HStack {
                Text(String(localized: "watch_pairing_status_label"))
                Spacer()
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        if !store.isPaired { return String(localized: "watch_status_unpaired") }
        if !store.isWatchAppInstalled { return String(localized: "watch_status_not_installed") }
        return String(localized: "watch_status_connected")
    }

    // MARK: - Default Account Section

    private var defaultAccountSection: some View {
        Section(String(localized: "watch_default_account_section")) {
            ForEach(store.accounts, id: \.id) { account in
                Button {
                    store.send(.accountSelected(account.id))
                } label: {
                    HStack {
                        Image(systemName: account.icon)
                            .foregroundStyle(Color.Design.fromHex(account.color))
                        Text(account.name)
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        if store.selectedAccountId == account.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.Design.accentOrange)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Paired + App Installed") {
    NavigationStack {
        WatchSettingsView(
            store: Store(
                initialState: WatchSettingsFeature.State(
                    accounts: [
                        Account(
                            id: UUID(),
                            name: "Cash",
                            type: .cash,
                            icon: "banknote",
                            color: "#34C759",
                            sortOrder: 0
                        ),
                        Account(
                            id: UUID(),
                            name: "Card",
                            type: .creditCard,
                            icon: "creditcard",
                            color: "#5E5CE6",
                            sortOrder: 1
                        )
                    ],
                    isPaired: true,
                    isWatchAppInstalled: true
                )
            ) { WatchSettingsFeature() }
        )
    }
}

#Preview("Paired — App Not Installed") {
    NavigationStack {
        WatchSettingsView(
            store: Store(
                initialState: WatchSettingsFeature.State(
                    isPaired: true,
                    isWatchAppInstalled: false
                )
            ) { WatchSettingsFeature() }
        )
    }
}

#Preview("Not Paired") {
    NavigationStack {
        WatchSettingsView(
            store: Store(
                initialState: WatchSettingsFeature.State(
                    isPaired: false,
                    isWatchAppInstalled: false
                )
            ) { WatchSettingsFeature() }
        )
    }
}
