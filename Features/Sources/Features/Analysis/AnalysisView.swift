import DesignSystem

import SwiftUI

public struct AnalysisView: View {
    let hasData: Bool

    public init(hasData: Bool = false) {
        self.hasData = hasData
    }

    public var body: some View {
        NavigationStack {
            if !hasData {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: "此期間無資料",
                    description: "嘗試選擇不同的日期範圍"
                )
            } else {
                ScrollView {
                    // Charts content
                    Text("Analysis Charts Placeholder")
                }
                .navigationTitle("Analysis")
            }
        }
    }
}

#Preview("Empty State") {
    AnalysisView(hasData: false)
}
