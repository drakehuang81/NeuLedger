import Foundation
import Testing
@testable import Domain

@Suite("ExtractedTransaction Tests")
struct ExtractedTransactionTests {
    @Test("ExtractedTransaction Full Initialization and Equatable")
    func testFullInitializationAndEquatable() {
        let ext1 = ExtractedTransaction(amount: 150.5, suggestedCategory: "Food", description: "Lunch", type: "expense")
        let ext2 = ExtractedTransaction(amount: 150.5, suggestedCategory: "Food", description: "Lunch", type: "expense")
        let ext3 = ExtractedTransaction(amount: 200, suggestedCategory: "Transport", description: "Taxi", type: "expense")
        
        #expect(ext1 == ext2)
        #expect(ext1 != ext3)
        #expect(ext1.amount == 150.5)
        #expect(ext1.suggestedCategory == "Food")
    }

    @Test("ExtractedTransaction Empty/Nil Initialization and Equatable")
    func testEmptyInitializationAndEquatable() {
        let ext1 = ExtractedTransaction(amount: nil, suggestedCategory: nil, description: nil, type: nil)
        let ext2 = ExtractedTransaction(amount: nil, suggestedCategory: nil, description: nil, type: nil)
        
        #expect(ext1 == ext2)
        #expect(ext1.amount == nil)
    }
}
