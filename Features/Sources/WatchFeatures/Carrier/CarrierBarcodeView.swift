import SwiftUI
import Domain
import Common

/// Full-screen scannable barcode. White edge-to-edge backdrop with the
/// Code 128 rotated 90° (vertical) so module width is maximized on the
/// tall, narrow watch display. Content intentionally stays fully visible
/// under AOD luminance reduction — the user may be mid-checkout.
struct CarrierBarcodeView: View {

    let carrier: Carrier

    var body: some View {
        ZStack {
            Color.Design.barcodeSurface.ignoresSafeArea()
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
    }
}
