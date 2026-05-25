// Features/Sources/Common/Components/AvatarBadge.swift
import SwiftUI

public struct AvatarBadge: View {
    public let initials: String

    public init(initials: String) {
        self.initials = initials
    }

    public var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.Design.brandPrimary, Color.Design.brandPink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 36, height: 36)
            .overlay {
                Text(initials.prefix(1))
                    .font(Font.Design.size15Semibold)
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.Design.brandPrimary.opacity(0.35), radius: 6, x: 0, y: 4)
    }
}

#Preview {
    AvatarBadge(initials: "D").padding()
}
