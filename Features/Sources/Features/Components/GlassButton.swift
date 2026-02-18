import SwiftUI
import DesignTokens

/// A custom Button using the native Liquid Glass appearance.
public struct GlassButton: View {

    var title: String
    var tint: Color?
    var action: () -> Void
    
    public init(_ title: String, tint: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.action = action
    }
    
    public var body: some View {
        Button(title, action: action)
            .buttonStyle(.glass)
            .tint(tint)
    }
}


#Preview {
    ZStack {
        Color.red
        VStack {
            GlassButton("Default") { }
            GlassButton("Tinted", tint: .blue) { }
        }
    }
}
