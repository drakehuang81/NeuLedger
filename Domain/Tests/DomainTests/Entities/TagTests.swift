import Foundation
import Testing
@testable import Domain

@Suite("Tag Tests")
struct TagTests {
    @Test("Tag Initialization and Equatable")
    func testInitializationAndEquatable() {
        let id = UUID()
        let tag1 = Domain.Tag(id: id, name: "Travel")
        let tag2 = Domain.Tag(id: id, name: "Travel")
        let tag3 = Domain.Tag(name: "Business", color: "#0000FF")
        
        #expect(tag1 == tag2)
        #expect(tag1 != tag3)
        #expect(tag1.color == nil)
        #expect(tag3.color == "#0000FF")
    }

    @Test("Tag Hashable")
    func testHashable() {
        let id = UUID()
        let tag1 = Domain.Tag(id: id, name: "Travel")
        let tag2 = Domain.Tag(id: id, name: "Travel")
        
        #expect(tag1.hashValue == tag2.hashValue)
    }

    @Test("Tag Codable round-trip")
    func testCodable() throws {
        let tag = Domain.Tag(name: "Travel", color: "#FF0000")
        
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(Domain.Tag.self, from: data)
        #expect(decoded == tag)
    }
}
