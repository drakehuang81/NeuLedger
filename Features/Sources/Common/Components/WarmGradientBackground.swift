import SwiftUI

public struct WarmGradientBackground: View {

    public enum Variant {
        case top
        case bottomRight
        case center
    }

    public let variant: Variant
    @Environment(\.colorScheme) private var colorScheme

    public init(variant: Variant = .top) {
        self.variant = variant
    }

    public var body: some View {
        ZStack {
            radialGradient
            orb1
            orb2
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var radialGradient: some View {
        let stops: [Color] = colorScheme == .dark
            ? [Color(warmHex: "#4A2A0E"), Color(warmHex: "#1A0F08"), Color(warmHex: "#050505")]
            : [Color(warmHex: "#FFE4B8"), Color(warmHex: "#FFF6E8"), Color(warmHex: "#FAFAF7")]
        return RadialGradient(
            gradient: Gradient(colors: stops),
            center: gradientCenter,
            startRadius: 0,
            endRadius: 600
        )
    }

    private var gradientCenter: UnitPoint {
        switch variant {
        case .top:         UnitPoint(x: 0.2, y: 0.0)
        case .bottomRight: UnitPoint(x: 0.8, y: 1.0)
        case .center:      UnitPoint(x: 0.5, y: 0.3)
        }
    }

    private var orb1: some View {
        Circle()
            .fill(Color.Design.brandPrimary)
            .frame(width: 240, height: 240)
            .blur(radius: 60)
            .opacity(colorScheme == .dark ? 0.30 : 0.35)
            .offset(
                x: variant == .bottomRight ? 120 : 100,
                y: variant == .bottomRight ? 220 : -120
            )
    }

    private var orb2: some View {
        Circle()
            .fill(Color.Design.incomeGreen)
            .frame(width: 220, height: 220)
            .blur(radius: 70)
            .opacity(colorScheme == .dark ? 0.20 : 0.22)
            .offset(
                x: -120,
                y: variant == .bottomRight ? 140 : 80
            )
    }
}

private extension Color {
    init(warmHex: String) {
        let cleaned = warmHex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >>  8) & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview("Top · Light") {
    ZStack {
        WarmGradientBackground(variant: .top)
        Text("Welcome").font(.title)
    }
}

#Preview("Bottom-right · Light") {
    ZStack {
        WarmGradientBackground(variant: .bottomRight)
        Text("Selection").font(.title)
    }
}

#Preview("Top · Dark") {
    ZStack {
        WarmGradientBackground(variant: .top)
        Text("Welcome").font(.title)
    }
    .preferredColorScheme(.dark)
}
