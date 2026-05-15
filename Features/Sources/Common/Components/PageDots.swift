// Features/Sources/Common/Components/PageDots.swift
import SwiftUI

public struct PageDots: View {
    public let count: Int
    public let active: Int

    public init(count: Int = 3, active: Int) {
        self.count = count
        self.active = active
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Color.primary : Color.primary.opacity(0.15))
                    .frame(width: i == active ? 22 : 6, height: 6)
                    .animation(.easeOut(duration: 0.25), value: active)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PageDots(active: 0)
        PageDots(active: 1)
        PageDots(active: 2)
    }
    .padding()
}
