// Features/Sources/Common/Components/SkeletonModifier.swift
import SwiftUI

public extension View {
    /// Renders content as a placeholder skeleton when `active` is true.
    /// Combines `.redacted(reason: .placeholder)` with a subtle shimmer overlay.
    func skeleton(when active: Bool) -> some View {
        modifier(SkeletonModifier(active: active))
    }
}

struct SkeletonModifier: ViewModifier {
    let active: Bool
    @State private var animating: Bool = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: active ? .placeholder : [])
            .overlay {
                if active {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.white.opacity(0), .white.opacity(0.25), .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width)
                        .offset(x: animating ? proxy.size.width : -proxy.size.width)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                        .animation(
                            .linear(duration: 1.4).repeatForever(autoreverses: false),
                            value: animating
                        )
                    }
                    .clipped()
                    .onAppear { animating = true }
                    .onDisappear { animating = false }
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Hello, world").font(.title).skeleton(when: true)
        Text("Hello, world").font(.title).skeleton(when: false)
    }
    .padding()
}
