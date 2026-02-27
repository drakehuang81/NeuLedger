import Foundation
import Testing
@testable import Domain

@Suite("CategorySuggestions Tests")
struct CategorySuggestionsTests {
    @Test("CategorySuggestions Initialization and Equatable")
    func testInitializationAndEquatable() {
        let sug1 = CategorySuggestions(suggestions: ["Food", "Groceries"], confidence: "high")
        let sug2 = CategorySuggestions(suggestions: ["Food", "Groceries"], confidence: "high")
        let sug3 = CategorySuggestions(suggestions: ["Transport"], confidence: "low")
        
        #expect(sug1 == sug2)
        #expect(sug1 != sug3)
        #expect(sug1.suggestions.count == 2)
        #expect(sug1.confidence == "high")
    }
}
