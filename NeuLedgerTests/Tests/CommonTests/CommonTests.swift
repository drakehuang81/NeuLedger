import Testing
import Foundation
@testable import Common

@Suite("DesignConstants Tests")
struct DesignConstantsTests {
    @Test("accountIconOptions is non-empty")
    func testAccountIcons() {
        #expect(!DesignConstants.accountIconOptions.isEmpty)
        #expect(DesignConstants.accountIconOptions.contains("creditcard"))
    }

    @Test("categoryIconOptions is non-empty")
    func testCategoryIcons() {
        #expect(!DesignConstants.categoryIconOptions.isEmpty)
        #expect(DesignConstants.categoryIconOptions.contains("fork.knife"))
    }

    @Test("color palettes are non-empty and all hex strings")
    func testColorPalettes() {
        for hex in DesignConstants.accountColorOptions {
            #expect(hex.hasPrefix("#"))
        }
        for hex in DesignConstants.categoryColorOptions {
            #expect(hex.hasPrefix("#"))
        }
        for hex in DesignConstants.tagColorOptions {
            #expect(hex.hasPrefix("#"))
        }
    }

    @Test("tag palette is a superset of category palette")
    func testTagPaletteIsSuperset() {
        let tagSet = Set(DesignConstants.tagColorOptions)
        for hex in DesignConstants.categoryColorOptions {
            #expect(tagSet.contains(hex))
        }
    }
}

@Suite("Decimal+Currency Tests")
struct DecimalCurrencyTests {
    @Test("twdCompact: small amounts (< 10,000) use full format")
    func compactSmallAmount() {
        #expect(Decimal(0).twdCompact == "NT$0")
        #expect(Decimal(500).twdCompact == "NT$500")
        #expect(Decimal(9999).twdCompact == "NT$9,999")
    }

    @Test("twdCompact: amounts >= 10,000 use 萬 suffix")
    func compactWan() {
        #expect(Decimal(10000).twdCompact == "NT$1.0萬")
        #expect(Decimal(99500).twdCompact == "NT$9.9萬")
        #expect(Decimal(1200000).twdCompact == "NT$120.0萬")
    }

    @Test("twdCompact: amounts >= 100,000,000 use 億 suffix")
    func compactYi() {
        #expect(Decimal(100_000_000).twdCompact == "NT$1.0億")
        #expect(Decimal(1_230_000_000).twdCompact == "NT$12.3億")
    }

    @Test("twdCompact: negative amounts keep sign before NT$")
    func compactNegative() {
        #expect(Decimal(-99500).twdCompact == "-NT$9.9萬")
        #expect(Decimal(-500).twdCompact == "-NT$500")
    }
}
