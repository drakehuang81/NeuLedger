
import SwiftUI

/// A custom ButtonStyle with a Liquid Glass appearance.
public struct GlassButton: View {

    var title: String
    var action: () -> Void
    var style: GlassButtonStyle
    
    public init(title: String, action: @escaping () -> Void, style: GlassButtonStyle = .glass(.clear)) {
        self.title = title
        self.action = action
        self.style = style
    }
    public var body: some View {
        Button(title, action: action)
            .buttonStyle(style)
    }
}


#Preview {
    ZStack {
        Color.red
        GlassButton(title: "Test") {
        }
    }
}
