// Features/Tests/DomainTests/Entities/CarrierTests.swift
import Foundation
import Testing
@testable import Domain

@Suite("Carrier Tests")
struct CarrierTests {

    @Test("Carrier Initialization and Equatable")
    func testInitializationAndEquatable() {
        let id = UUID()
        let createdAt = Date()
        let c1 = Carrier(id: id, name: "我的手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234", createdAt: createdAt)
        let c2 = Carrier(id: id, name: "我的手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234", createdAt: createdAt)
        let c3 = Carrier(name: "證書", type: .citizenDigitalCertificate, barcode: "/PA1B2C3D4E5F6G7H8")
        #expect(c1 == c2)
        #expect(c1 != c3)
    }

    @Test("Carrier Hashable")
    func testHashable() {
        let id = UUID()
        let createdAt = Date()
        let c1 = Carrier(id: id, name: "A", type: .phoneBarcodeCarrier, barcode: "/ABC1234", createdAt: createdAt)
        let c2 = Carrier(id: id, name: "A", type: .phoneBarcodeCarrier, barcode: "/ABC1234", createdAt: createdAt)
        #expect(c1.hashValue == c2.hashValue)
    }

    @Test("Carrier Codable round-trip")
    func testCodable() throws {
        let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let data = try JSONEncoder().encode(carrier)
        let decoded = try JSONDecoder().decode(Carrier.self, from: data)
        #expect(decoded == carrier)
    }

    @Test("CarrierType allCases completeness")
    func testCarrierTypeAllCases() {
        #expect(CarrierType.allCases.count == 2)
        #expect(CarrierType.allCases.contains(.phoneBarcodeCarrier))
        #expect(CarrierType.allCases.contains(.citizenDigitalCertificate))
    }

    @Test("CarrierType raw values")
    func testCarrierTypeRawValues() {
        #expect(CarrierType.phoneBarcodeCarrier.rawValue == "phoneBarcodeCarrier")
        #expect(CarrierType.citizenDigitalCertificate.rawValue == "citizenDigitalCertificate")
    }
}
