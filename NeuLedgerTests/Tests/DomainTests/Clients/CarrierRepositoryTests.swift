// Features/Tests/DomainTests/Clients/CarrierRepositoryTests.swift
import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("CarrierRepository Tests")
struct CarrierRepositoryTests {

    @Test("CarrierRepository dependency key injection")
    func testDependencyKey() {
        @Dependency(\.carrierRepository) var client
        #expect(true, "CarrierRepository injected successfully")
    }

    @Test("CarrierRepository fetchAll mock override")
    func testFetchAllMock() async throws {
        let expected = [Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")]
        try await withDependencies {
            $0.carrierRepository.fetchAll = { expected }
        } operation: {
            @Dependency(\.carrierRepository) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("CarrierRepository add mock override")
    func testAddMock() async throws {
        try await withDependencies {
            $0.carrierRepository.add = { _ in }
        } operation: {
            @Dependency(\.carrierRepository) var client
            let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
            try await client.add(carrier)
        }
    }

    @Test("CarrierRepository update mock override")
    func testUpdateMock() async throws {
        try await withDependencies {
            $0.carrierRepository.update = { _ in }
        } operation: {
            @Dependency(\.carrierRepository) var client
            let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
            try await client.update(carrier)
        }
    }

    @Test("CarrierRepository delete mock override")
    func testDeleteMock() async throws {
        let id = UUID()
        try await withDependencies {
            $0.carrierRepository.delete = { _ in }
        } operation: {
            @Dependency(\.carrierRepository) var client
            try await client.delete(id)
        }
    }
}
