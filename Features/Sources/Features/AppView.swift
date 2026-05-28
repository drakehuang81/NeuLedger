//
//  AppView.swift
//  Features
//
//  Created by Jie Liang Huang on 2026/2/15.
//

import SwiftUI
import ComposableArchitecture
import Domain
import Core
import Common

@main
struct NeuLedgerApp: App {
    static let store = Store(
        initialState: AppFeature.State()
    ) {
        AppFeature()
    }

    init() {
        // Composition Root: wire the Watch bridge before any UI exists so
        // background-delivered WatchConnectivity payloads are caught on
        // the very first delegate dispatch after launch.
        WatchBootstrap.start()
    }

    // `.modelContainer(_:)` is intentionally NOT applied here: feature views
    // reach persistence via `@Dependency(\.databaseClient)` instead of
    // SwiftData's `@Environment(\.modelContext)`, and the Features layer must
    // not `import SwiftData`.
    var body: some Scene {
        WindowGroup {
            contentView
        }
    }
    private var contentView: some View {
        VStack {
            switch Self.store.state {
            case .splash:
                LoadingView {
                    Self.store.send(.splashCompleted)
                }
            case .onboarding:
                if let onboardingStore = Self.store.scope(state: \.onboarding, action: \.onboarding) {
                    OnboardingView(store: onboardingStore)
                        .transition(
                            .asymmetric(
                                insertion: .identity,
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }

            case .main:
                if let mainStore = Self.store.scope(state: \.main, action: \.main) {
                    MainTabView(store: mainStore)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: Self.store.state)
        .onOpenURL { url in
            Self.store.send(.deepLinkReceived(url))
        }
    }
}
