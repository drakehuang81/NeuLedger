import Common
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
                    title: "analysis_empty_title",
                    description: "analysis_empty_desc"
                )
            } else {
                ScrollView {
                    // Charts content
                    Text("analysis_placeholder")
                }
                .navigationTitle("analysis_title")
            }
        }
    }
}

#Preview("Empty State") {
    AnalysisView(hasData: false)
}
