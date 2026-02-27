//
//  RootView.swift
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

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(databaseClient.modelContainer())
    }
}

struct RootView: View {
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @State private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                // Main content (placeholder for now)
                Text("app_greeting")
                    .task {
                        do {
                            let accounts = try await accountClient.fetchActive()
                            print("✅ Accounts seeded (\(accounts.count)): \(accounts.map(\.name))")
                            let categories = try await categoryClient.fetchAll()
                            print("✅ Categories seeded (\(categories.count))")
                        } catch {
                            print("❌ Fetch failed: \(error)")
                        }
                    }
            } else {
                OnboardingView(
                    store: Store(
                        initialState: OnboardingFeature.State()
                    ) {
                        OnboardingFeature()
                    }
                )
            }
        }
        .onAppear {
            hasCompletedOnboarding = userSettingsClient.bool(.hasCompletedOnboarding)
        }
    }
}
