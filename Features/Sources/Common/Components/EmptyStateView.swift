import SwiftUI

public struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        icon: String = "tray.fill",
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.borderedProminent) // Use Glass style if available, but native for now
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

#Preview {
    ZStack {
        Color.white.ignoresSafeArea()
        EmptyStateView(
            icon: "tray.fill",
            title: "尚無交易",
            description: "開始記下您的第一筆花費吧！",
            actionTitle: "記一筆",
            action: {}
        )
    }
}
