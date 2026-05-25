import SwiftUI

public struct LoadingView: View {
    public let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var orbsVisible = false
    @State private var glowVisible = false
    @State private var statusVisible = false
    @State private var progress: CGFloat = 0
    @State private var stepIndex = 0
    @State private var fadeOut = false

    private var isDark: Bool { colorScheme == .dark }

    private var backgroundStops: [Gradient.Stop] {
        if isDark {
            return [
                .init(color: .Design.splashBgInnerDark, location: 0.0),
                .init(color: .Design.splashBgMidDark, location: 0.45),
                .init(color: .Design.splashBgOuterDark, location: 0.90),
            ]
        } else {
            return [
                .init(color: .Design.warmBgInnerLight, location: 0.0),
                .init(color: .Design.warmBgMidLight, location: 0.45),
                .init(color: .Design.warmBgOuterLight, location: 0.90),
            ]
        }
    }

    private var primaryTextColor: Color {
        isDark ? .Design.splashTextPrimaryDark : .Design.splashTextPrimaryLight
    }

    private var secondaryTextColor: Color {
        isDark ? Color.Design.splashTextPrimaryDark.opacity(0.55)
               : Color.Design.splashTextSecondaryLight.opacity(0.65)
    }

    private var progressTrackColor: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var iconShadowColor: Color {
        isDark ? Color.black.opacity(0.55) : Color.black
    }

    private let steps: [(text: String, isFinal: Bool)] = [
        (String(localized: "splash_step_starting"), false),
        (String(localized: "splash_step_loading_data"), false),
        (String(localized: "splash_step_preparing_ui"), false),
        (String(localized: "splash_step_ready"), true),
    ]

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(stops: backgroundStops),
                center: UnitPoint(x: 0.5, y: 0.35),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            orbs

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.Design.splashOrbOrange.opacity(glowVisible ? 0.18 : 0),
                                    .clear,
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .animation(.easeOut(duration: 0.9), value: glowVisible)

                    LedgerCutIcon(size: 72, palette: isDark ? .chalk : .noir)
                        .frame(width: 72, height: 72)
                        .shadow(
                            color: iconShadowColor.opacity(0.30 + (glowVisible ? 0.15 : 0)),
                            radius: glowVisible ? 28 : 18,
                            y: glowVisible ? 14 : 10
                        )
                        .animation(.easeOut(duration: 0.9), value: glowVisible)
                }

                VStack(spacing: 10) {
                    Text("NeuLedger")
                        .font(Font.Design.size30Bold)
                        .tracking(-0.8)
                        .foregroundColor(primaryTextColor)

                    Text("EVERY NT$, SEEN.")
                        .font(Font.Design.size10MediumMonospaced)
                        .tracking(1.6)
                        .foregroundColor(secondaryTextColor)
                }
            }
            .offset(y: -40)

            VStack(spacing: 18) {
                Spacer()
                statusText
                    .frame(height: 18)
                    .opacity(statusVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: statusVisible)

                progressBar
                    .frame(width: 200, height: 3)
                    .opacity(statusVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: statusVisible)
            }
            .padding(.bottom, 90)
        }
        .opacity(fadeOut ? 0 : 1)
        .animation(.easeOut(duration: 0.5), value: fadeOut)
        .task {
            await runSequence()
        }
    }

    // MARK: - Orbs

    private var orbs: some View {
        ZStack {
            Circle()
                .fill(Color.Design.splashOrbOrange)
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .opacity(orbsVisible ? 0.40 : 0)
                .scaleEffect(orbsVisible ? 1.0 : 0.7)
                .offset(x: 110, y: -250)
                .animation(.easeOut(duration: 0.9), value: orbsVisible)

            Circle()
                .fill(Color.Design.splashOrbGreen)
                .frame(width: 230, height: 230)
                .blur(radius: 80)
                .opacity(orbsVisible ? 0.26 : 0)
                .scaleEffect(orbsVisible ? 1.0 : 0.7)
                .offset(x: -120, y: -50)
                .animation(.easeOut(duration: 1.0).delay(0.05), value: orbsVisible)

            Circle()
                .fill(Color.Design.splashOrbYellow)
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .opacity(orbsVisible ? 0.30 : 0)
                .scaleEffect(orbsVisible ? 1.0 : 0.7)
                .offset(x: 80, y: 200)
                .animation(.easeOut(duration: 1.1).delay(0.1), value: orbsVisible)
        }
    }

    // MARK: - Status row

    private var statusText: some View {
        let step = steps[min(stepIndex, steps.count - 1)]
        return HStack(spacing: 8) {
            if step.isFinal {
                Image(systemName: "checkmark")
                    .font(Font.Design.size12Bold)
                    .foregroundColor(Color.Design.splashStatusFinalGreen)
            } else {
                Circle()
                    .fill(Color.Design.splashOrbOrange)
                    .frame(width: 5, height: 5)
                    .modifier(LoadingPulse())
            }
            Text(step.text)
                .font(Font.Design.size13Medium)
                .tracking(-0.1)
                .foregroundColor(primaryTextColor)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .id(stepIndex)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressTrackColor)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.Design.splashOrbOrange, Color.Design.splashProgressEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .shadow(color: Color.Design.splashOrbOrange.opacity(0.6), radius: 4)
                    .animation(.easeInOut(duration: 0.6), value: progress)
            }
        }
    }

    // MARK: - Sequence (2.7s 強制最小展示)

    private func runSequence() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation { orbsVisible = true; glowVisible = true }

        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation { statusVisible = true; progress = 0.33 }

        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation { stepIndex = 1; progress = 0.66 }

        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation { stepIndex = 2; progress = 0.95 }

        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation { stepIndex = 3; progress = 1.0 }

        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation { fadeOut = true }

        try? await Task.sleep(nanoseconds: 500_000_000)
        onComplete()
    }
}

// MARK: - Pulse modifier

private struct LoadingPulse: ViewModifier {
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(scale == 1 ? 1 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever()) {
                    scale = 1.5
                }
            }
    }
}

#Preview {
    LoadingView { }
}
