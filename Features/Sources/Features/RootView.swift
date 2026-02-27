//
//  RootView.swift
//  Features
//
//  Created by Jie Liang Huang on 2026/2/15.
//

import SwiftUI
import ComposableArchitecture
import Domain

public struct RootView: View {
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient

    public init() {}

    public var body: some View {
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
    }
}
