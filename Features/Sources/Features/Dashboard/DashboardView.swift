import Common
import SwiftUI

public struct DashboardView: View {
    let isEmpty: Bool

    public init(isEmpty: Bool = true) {
        self.isEmpty = isEmpty
    }

    public var body: some View {
        NavigationStack {
            if isEmpty {
                EmptyStateView(
                    icon: "tray.fill",
                    title: "dashboard_empty_title",
                    description: "dashboard_empty_desc",
                    actionTitle: "dashboard_empty_action",
                    action: { print("Open Add Transaction Sheet") } // Placeholder for future action
                )
            } else {
                Text("dashboard_placeholder")
                    .navigationTitle("dashboard_title")
            }
        }
    }
}

#Preview("Empty State") {
    DashboardView(isEmpty: true)
}
