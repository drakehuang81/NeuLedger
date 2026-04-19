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
            switch Self.store.destination {
            case .splash:
                SplashView()
            case .onboarding:
                if let onboardingStore = Self.store.scope(state: \.destination.onboarding, action: \.onboarding) {
                    OnboardingView(store: onboardingStore)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
                
            case .main:
                if let mainStore = Self.store.scope(state: \.destination.main, action: \.main) {
                    MainTabView(store: mainStore)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: Self.store.destination)
        .task {
            Self.store.send(.onAppear)
        }
        .onOpenURL { url in
            Self.store.send(.deepLinkReceived(url))
        }
    }
}
