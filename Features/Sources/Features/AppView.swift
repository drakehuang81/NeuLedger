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
import Common

@main
struct NeuLedgerApp: App {
    @Dependency(\.databaseClient) var databaseClient

    static let store = Store(
        initialState: AppFeature.State()
    ) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
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
        }
        .modelContainer(databaseClient.modelContainer())
    }
}
