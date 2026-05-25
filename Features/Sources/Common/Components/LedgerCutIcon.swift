import SwiftUI

public enum LedgerCutPalette {
    case noir
    case chalk

    var bgGradient: [Color] {
        switch self {
        case .noir:  return [.Design.ledgerCutNoirGradient1, .Design.ledgerCutNoirGradient2, .Design.ledgerCutNoirGradient3]
        case .chalk: return [.Design.ledgerCutChalkGradient1, .Design.ledgerCutChalkGradient2, .Design.ledgerCutChalkGradient3]
        }
    }

    var fg: Color {
        switch self {
        case .noir:  return .Design.ledgerCutNoirFg
        case .chalk: return .Design.ledgerCutChalkFg
        }
    }

    var accent: Color {
        switch self {
        case .noir:  return .Design.ledgerCutNoirAccent
        case .chalk: return .Design.ledgerCutChalkAccent
        }
    }

    var dimOpacity: Double {
        switch self {
        case .noir:  return 0.28
        case .chalk: return 0.30
        }
    }
}

public struct LedgerCutIcon: View {
    public let size: CGFloat
    public var palette: LedgerCutPalette

    public init(size: CGFloat, palette: LedgerCutPalette = .noir) {
        self.size = size
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            // Background — 135° linear gradient
            LinearGradient(
                colors: palette.bgGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Letter N — TOP half (full fg colour)
            Text("N")
                .font(.system(size: size * 0.74, weight: .heavy, design: .default))
                .tracking(-size * 0.74 * 0.06)
                .foregroundColor(palette.fg)
                .offset(y: -size * 0.01)
                .frame(width: size, height: size, alignment: .center)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle()
                        Rectangle().fill(Color.clear)
                    }
                )

            // Letter N — BOTTOM half (dimmed, closer to bg)
            Text("N")
                .font(.system(size: size * 0.74, weight: .heavy, design: .default))
                .tracking(-size * 0.74 * 0.06)
                .foregroundColor(palette.fg.opacity(palette.dimOpacity))
                .offset(y: -size * 0.01)
                .frame(width: size, height: size, alignment: .center)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.clear)
                        Rectangle()
                    }
                )

            // Horizontal cut bar — same gradient as background, sits over the N
            LinearGradient(
                colors: palette.bgGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: size * 0.075)
            .padding(.horizontal, size * 0.12)
            .offset(y: -size * 0.011)
            .shadow(color: .black.opacity(0.08), radius: 0, y: 1)

            // Tiny accent dot
            HStack {
                Spacer()
                Circle()
                    .fill(palette.accent)
                    .frame(width: size * 0.06, height: size * 0.06)
                    .shadow(color: palette.accent.opacity(0.5), radius: size * 0.04)
                    .padding(.trailing, size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }
}

#Preview {
    HStack(spacing: 24) {
        LedgerCutIcon(size: 180, palette: .noir)
        LedgerCutIcon(size: 180, palette: .chalk)
    }
    .padding(40)
    .background(Color.gray.opacity(0.15))
}
