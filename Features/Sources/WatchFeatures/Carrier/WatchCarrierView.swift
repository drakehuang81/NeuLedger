import SwiftUI
import ComposableArchitecture
import Domain
import Common

/// Page 2 of the Watch app: the e-invoice carrier viewer. Renders one of
/// four states — sync hint (`carriers == nil`), empty guidance (`[]`),
/// single-carrier fast path (barcode immediately, zero taps), or a list
/// for 2+ carriers (tap pushes the barcode).
public struct WatchCarrierView: View {

    @Bindable public var store: StoreOf<WatchCarrierFeature>

    public init(store: StoreOf<WatchCarrierFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "watch_carrier_title"))
                .navigationDestination(
                    isPresented: Binding(
                        get: { store.presentedCarrier != nil },
                        set: { isPresented in
                            if isPresented == false {
                                store.send(.barcodeDismissed)
                            }
                        }
                    )
                ) {
                    if let carrier = store.presentedCarrier {
                        CarrierBarcodeView(carrier: carrier)
                    }
                }
        }
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder
    private var content: some View {
        if let carriers = store.carriers {
            if carriers.isEmpty {
                hint(icon: "barcode", textKey: "watch_carrier_empty_hint")
            } else if carriers.count == 1, let only = carriers.first {
                // Fast path: one carrier → its barcode IS the page.
                CarrierBarcodeView(carrier: only)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                carrierList(carriers)
            }
        } else {
            hint(icon: "iphone.gen3", textKey: "watch_carrier_syncing_hint")
        }
    }

    private func carrierList(_ carriers: [Carrier]) -> some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(carriers) { carrier in
                    Button {
                        store.send(.carrierTapped(carrier.id))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: typeIcon(for: carrier.type))
                                .foregroundStyle(Color.Design.accentOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(carrier.name)
                                    .font(Font.Design.body)
                                    .lineLimit(1)
                                Text(carrier.barcode)
                                    .font(Font.Design.size10Monospaced)
                                    .foregroundStyle(Color.Design.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func hint(icon: String, textKey: String.LocalizationValue) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(Font.Design.size22SemiboldRounded)
                .foregroundStyle(Color.Design.textSecondary)
            Text(String(localized: textKey))
                .font(Font.Design.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func typeIcon(for type: CarrierType) -> String {
        switch type {
        case .phoneBarcodeCarrier: "iphone.gen3"
        case .citizenDigitalCertificate: "person.text.rectangle"
        }
    }
}
