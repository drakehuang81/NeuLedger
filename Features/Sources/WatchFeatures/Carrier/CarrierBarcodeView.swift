import SwiftUI
import Domain
import Common
#if canImport(WatchKit)
import WatchKit
#endif

/// Full-screen scannable barcode. White edge-to-edge backdrop with the
/// Code 128 rotated 90° (vertical) so module width is maximized on the
/// tall, narrow watch display. Content intentionally stays fully visible
/// under AOD luminance reduction — the user may be mid-checkout.
///
/// The whole page flips 180° based on the wearing configuration: this
/// screen is read by the clerk/scanner facing the wearer, not by the
/// wearer. watchOS normalizes UI for the wearer, so when the forearm
/// twists outward to present (rotation about the screen's 12–6 axis),
/// the content would appear upside down to the person opposite.
struct CarrierBarcodeView: View {

    let carrier: Carrier

    var body: some View {
        ZStack {
            Color.Design.barcodeSurface.ignoresSafeArea()
            content
                .rotationEffect(.degrees(isFlippedForPresentation ? 180 : 0))
        }
    }

    @ViewBuilder
    private var content: some View {
        if let modules = Code128.modules(for: carrier.barcode) {
            HStack(spacing: 6) {
                Code128BarcodeView(modules: modules, orientation: .vertical)
                    // Quiet zones along the code axis.
                    .padding(.vertical, 10)
                VStack(spacing: 6) {
                    Text(carrier.barcode)
                        .font(Font.Design.size12Monospaced)
                        .foregroundStyle(Color.Design.barcodeInk)
                    Text(carrier.name)
                        .font(Font.Design.size9)
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 30)
            }
            .padding(.horizontal, 8)
        } else {
            // Encoder rejected the stored barcode (shouldn't happen for
            // carriers validated on iPhone) — degrade to a code the
            // clerk can key in by hand.
            VStack(spacing: 6) {
                Text(carrier.barcode)
                    .font(Font.Design.size20Monospaced)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(Color.Design.barcodeInk)
                Text(carrier.name)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }
            .padding()
        }
    }

    /// Whether the presented page reads upside down to the person
    /// opposite, derived from the wearing configuration. The screen's
    /// 12 o'clock points to the elbow side for (left wrist, right crown)
    /// and (right wrist, left crown) — calibrated against a real-device
    /// checkout test on the standard left-wrist/right-crown setup.
    private var isFlippedForPresentation: Bool {
#if canImport(WatchKit)
        let device = WKInterfaceDevice.current()
        return (device.wristLocation == .left) == (device.crownOrientation == .right)
#else
        return false
#endif
    }
}
