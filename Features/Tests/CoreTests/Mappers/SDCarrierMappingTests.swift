import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDCarrier PersistentDomainModel")
struct SDCarrierMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDCarrier.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("applyChanges updates name / type / barcode, preserves id and createdAt")
    func testApplyChanges() throws {
        let originalId = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_000)
        let original = Carrier(
            id: originalId,
            name: "Old",
            type: .phoneBarcodeCarrier,
            barcode: "/OLDBARCODE",
            createdAt: originalCreatedAt
        )
        let sd = SDCarrier.from(original, context: context)
        try context.save()

        let edited = Carrier(
            id: originalId,
            name: "New",
            type: .citizenDigitalCertificate,
            barcode: "AB12345678901234",
            createdAt: originalCreatedAt
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.createdAt == originalCreatedAt)
        #expect(sd.name == "New")
        #expect(sd.typeRaw == CarrierType.citizenDigitalCertificate.rawValue)
        #expect(sd.barcode == "AB12345678901234")
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = Carrier(name: "A", type: .phoneBarcodeCarrier, barcode: "/AA")
        let b = Carrier(name: "B", type: .phoneBarcodeCarrier, barcode: "/BB")
        SDCarrier.from(a, context: context)
        SDCarrier.from(b, context: context)
        try context.save()

        let matches = try context.fetch(
            FetchDescriptor<SDCarrier>(predicate: SDCarrier.idPredicate(a.id))
        )
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }
}
