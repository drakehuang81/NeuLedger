import Testing
import Foundation
import SwiftUI
import Domain
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

@Suite("Decimal+Currency parts")
struct DecimalCurrencyPartsTests {
    @Test("twdDigits is thousands-separated integer without symbol")
    func twdDigits() {
        #expect(Decimal(0).twdDigits == "0")
        #expect(Decimal(480).twdDigits == "480")
        #expect(Decimal(12_500).twdDigits == "12,500")
        #expect(Decimal(1_234_567).twdDigits == "1,234,567")
    }

    @Test("twdParts splits symbol and digits; sign stays on the symbol")
    func twdParts() {
        let positive = Decimal(1_234).twdParts
        #expect(positive.symbol == "NT$")
        #expect(positive.digits == "1,234")
        let negative = Decimal(-1_234).twdParts
        #expect(negative.symbol == "-NT$")
        #expect(negative.digits == "1,234")
        #expect(positive.symbol + positive.digits == Decimal(1_234).twdFormatted)
        #expect(negative.symbol + negative.digits == Decimal(-1_234).twdFormatted)
    }
}

@Suite("CarrierType+UI")
struct CarrierTypeUITests {
    @Test("systemImageName is stable per type")
    func icons() {
        #expect(CarrierType.phoneBarcodeCarrier.systemImageName == "iphone")
        #expect(CarrierType.citizenDigitalCertificate.systemImageName == "creditcard")
    }

    /// The Watch deliberately draws different glyphs: `iphone.gen3` reads
    /// better at that size, and `person.text.rectangle` says "identity
    /// document" where `creditcard` says "payment card" — a citizen digital
    /// certificate is not a payment card. Centralising the mapping is the
    /// point of this task; flattening the two platforms into one glyph set
    /// would have been a silent visual change, so both live here instead.
    @Test("watchSystemImageName keeps the Watch's own glyphs")
    func watchIcons() {
        #expect(CarrierType.phoneBarcodeCarrier.watchSystemImageName == "iphone.gen3")
        #expect(CarrierType.citizenDigitalCertificate.watchSystemImageName == "person.text.rectangle")
        for type in CarrierType.allCases {
            #expect(type.watchSystemImageName != type.systemImageName)
        }
    }

    @Test("tint uses design tokens")
    func tints() {
        #expect(CarrierType.phoneBarcodeCarrier.tint == Color.Design.accentOrange)
        #expect(CarrierType.citizenDigitalCertificate.tint == Color.Design.carrierCertIndigo)
    }
}

@Suite("Date+Relative")
struct DateRelativeTests {
    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }
    private static func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }

    @Test("days(until:) counts calendar days, ignoring time of day")
    func daysUntil() {
        // 23:00 to 01:00 the next day is two hours apart but one calendar
        // day, which is what a "due in N days" label has to say.
        #expect(Self.d(2026, 1, 15, 23).days(until: Self.d(2026, 1, 16, 1), calendar: Self.cal) == 1)
        #expect(Self.d(2026, 1, 15, 1).days(until: Self.d(2026, 1, 15, 23), calendar: Self.cal) == 0)
        #expect(Self.d(2026, 1, 15, 12).days(until: Self.d(2026, 1, 10, 12), calendar: Self.cal) == -5)
    }
}
