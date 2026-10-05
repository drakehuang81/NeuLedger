import Foundation
import Testing
@testable import Domain

@Suite("CarrierType+Display")
struct CarrierTypeDisplayTests {
    @Test("localizedName resolves keys, never echoes the key back")
    func localizedName() {
        for type in CarrierType.allCases {
            #expect(!type.localizedName.isEmpty)
            // A missing key makes `String(localized:)` hand back the key
            // itself, which reads as a plausible string and would otherwise
            // ship. These keys live in the iOS and Widget string tables; the
            // Watch table does not carry them, which is fine only as long as
            // no Watch view shows the type's name.
            #expect(!type.localizedName.hasPrefix("carrier_type_"))
        }
        #expect(
            CarrierType.phoneBarcodeCarrier.localizedName
                != CarrierType.citizenDigitalCertificate.localizedName
        )
    }

    @Test("barcodePlaceholder mirrors the validation regex shape")
    func placeholder() {
        #expect(CarrierType.phoneBarcodeCarrier.barcodePlaceholder == "/XXXXXXX")
        #expect(CarrierType.citizenDigitalCertificate.barcodePlaceholder == "/PXXXXXXXXXXXXXXXX")
    }

    @Test("barcodeFormatHint is localized per type")
    func hint() {
        #expect(!CarrierType.phoneBarcodeCarrier.barcodeFormatHint.hasPrefix("carrier_form_"))
        #expect(
            CarrierType.phoneBarcodeCarrier.barcodeFormatHint
                != CarrierType.citizenDigitalCertificate.barcodeFormatHint
        )
    }
}
