import Foundation
import Testing
@testable import Domain

@Suite("AccountType Tests")
struct AccountTypeTests {
    @Test("AccountType has correct cases")
    func testCases() {
        #expect(AccountType.allCases.count == 4)
        #expect(AccountType.allCases.contains(.cash))
        #expect(AccountType.allCases.contains(.bank))
        #expect(AccountType.allCases.contains(.creditCard))
        #expect(AccountType.allCases.contains(.eWallet))
    }

    @Test("AccountType Codable round-trip")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in AccountType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(AccountType.self, from: data)
            #expect(decoded == type)
        }
    }
}

@Suite("AccountType.displayLabel localized")
struct AccountTypeDisplayLabelTests {

    @Test("displayLabel returns non-empty string for each case")
    func testDisplayLabelLocalized() {
        for type in AccountType.allCases {
            let label = type.displayLabel
            #expect(!label.isEmpty)
            #expect(label != type.rawValue)
        }
    }

    @Test("displayLabel does not return enum raw value")
    func testDisplayLabelNotRawValue() {
        #expect(AccountType.cash.displayLabel != "cash")
        #expect(AccountType.bank.displayLabel != "bank")
        #expect(AccountType.creditCard.displayLabel != "creditCard")
        #expect(AccountType.eWallet.displayLabel != "eWallet")
    }
}

@Suite("AccountType.defaultIcon and defaultColor")
struct AccountTypeDefaultsTests {

    @Test("defaultIcon returns SF Symbol for each case")
    func testDefaultIcon() {
        #expect(AccountType.cash.defaultIcon == "banknote")
        #expect(AccountType.bank.defaultIcon == "building.columns")
        #expect(AccountType.creditCard.defaultIcon == "creditcard")
        #expect(AccountType.eWallet.defaultIcon == "wallet.bifold")
    }

    @Test("defaultColor returns iOS system hex for each case")
    func testDefaultColor() {
        #expect(AccountType.cash.defaultColor == "#8E8E93")
        #expect(AccountType.bank.defaultColor == "#0A84FF")
        #expect(AccountType.creditCard.defaultColor == "#FF2D55")
        #expect(AccountType.eWallet.defaultColor == "#5E5CE6")
    }
}
