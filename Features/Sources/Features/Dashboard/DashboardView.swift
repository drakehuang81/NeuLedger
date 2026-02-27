import DesignSystem
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
                    title: "尚無交易",
                    description: "開始記下您的第一筆花費吧！",
                    actionTitle: "記一筆",
                    action: { print("Open Add Transaction Sheet") } // Placeholder for future action
                )
            } else {
                Text("Transaction List Placeholder")
                    .navigationTitle("Dashboard")
            }
        }
    }
}

#Preview("Empty State") {
    DashboardView(isEmpty: true)
}
