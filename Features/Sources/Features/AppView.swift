//
//  AppView.swift
//  Features
//
//  Created by Jie Liang Huang on 2026/2/15.
//

import SwiftUI
import ComposableArchitecture
import Domain
import SwiftData
import Core


@main
struct NeuLedgerApp: App {
    @Dependency(\.databaseClient) var databaseClient
    
    static let store = Store(
        initialState: AppFeature.State(
            destination: {
                @Dependency(\.userSettingsClient) var userSettingsClient
                return userSettingsClient.bool(.hasCompletedOnboarding) ? .main : .onboarding(OnboardingFeature.State())
            }()
        )
    ) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
        .modelContainer(databaseClient.modelContainer())
    }
}

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.destination {
            case .onboarding:
                if let onboardingStore = store.scope(state: \.destination.onboarding, action: \.onboarding) {
                    OnboardingView(store: onboardingStore)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            case .main:
                // Main content (placeholder for now)
                Text("app_greeting")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.destination)
    }
}
