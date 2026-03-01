import SwiftUI

public struct SplashView: View {
    @State private var isAnimating = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Rectangle().fill(Color.Design.background).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "creditcard.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.Design.brandPrimary, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.7)
                
                Text("NeuLedger")
                    .font(Font.Design.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.Design.textPrimary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashView()
}
