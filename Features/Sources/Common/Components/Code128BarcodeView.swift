import SwiftUI

/// Renders a Code 128 module pattern as crisp vector bars. The caller
/// provides pre-encoded modules (see `Code128.modules(for:)`) and is
/// responsible for quiet-zone padding and the white backdrop
/// (`Color.Design.barcodeSurface`).
public struct Code128BarcodeView: View {

    public enum Orientation: Sendable {
        /// Code reads left-to-right (bars are vertical strips).
        case horizontal
        /// Code reads top-to-bottom — rotated 90° to maximize module
        /// width on tall, narrow screens like Apple Watch.
        case vertical
    }

    private let modules: [Bool]
    private let orientation: Orientation

    public init(modules: [Bool], orientation: Orientation = .horizontal) {
        self.modules = modules
        self.orientation = orientation
    }

    public var body: some View {
        Canvas { context, size in
            guard modules.isEmpty == false else { return }
            let count = CGFloat(modules.count)
            for (index, isBar) in modules.enumerated() where isBar {
                let rect: CGRect
                switch orientation {
                case .horizontal:
                    let moduleWidth = size.width / count
                    rect = CGRect(
                        x: CGFloat(index) * moduleWidth, y: 0,
                        width: moduleWidth, height: size.height
                    )
                case .vertical:
                    let moduleHeight = size.height / count
                    rect = CGRect(
                        x: 0, y: CGFloat(index) * moduleHeight,
                        width: size.width, height: moduleHeight
                    )
                }
                context.fill(Path(rect), with: .color(Color.Design.barcodeInk))
            }
        }
    }
}
