import Foundation
import Testing
@testable import Common

@Suite("Code128 Tests")
struct Code128Tests {

    @Test("Widths table is structurally valid per ISO/IEC 15417")
    func tableIntegrity() {
        #expect(Code128.widths.count == 107)
        for (index, entry) in Code128.widths.enumerated() {
            let widths = entry.compactMap(\.wholeNumberValue)
            #expect(widths.count == entry.count, "non-digit char in entry \(index)")
            let total = widths.reduce(0, +)
            if index == 106 {
                #expect(total == 13, "stop symbol must span 13 modules")
            } else {
                #expect(total == 11, "symbol \(index) must span 11 modules")
            }
            // Code 128 自檢特性：每個符號的 bar 模組總寬為偶數。
            let barTotal = stride(from: 0, to: widths.count, by: 2)
                .map { widths[$0] }
                .reduce(0, +)
            #expect(barTotal.isMultiple(of: 2), "bar parity broken at \(index)")
        }
    }

    @Test("Phone-barcode carrier encodes in pure code B with checksum 14")
    func phoneCarrierVector() {
        // '/'=15 'A'=33 'B'=34 '1'=17 '2'=18 '+'=11 'C'=35 'D'=36（ASCII-32）
        // 數字串長度 2 < 4 → 全程 code B。
        // checksum = 104 + 15*1+33*2+34*3+17*4+18*5+11*6+35*7+36*8 = 1044 → 1044 % 103 = 14
        #expect(Code128.codeValues(for: "/AB12+CD")
                == [104, 15, 33, 34, 17, 18, 11, 35, 36, 14, 106])
        // 10 個 11-module 符號 + 13-module stop = 123
        #expect(Code128.modules(for: "/AB12+CD")?.count == 123)
    }

    @Test("Citizen-certificate carrier switches to code C for the 14-digit run")
    func certCarrierVector() {
        // 'A'=33 'B'=34，後接 14 位數字（≥4 且偶數）→ switch C(99)，七組兩位數。
        // checksum = 104 + 33*1+34*2+99*3+12*4+34*5+56*6+78*7+90*8+12*9+34*10
        //          = 2770 → 2770 % 103 = 92
        #expect(Code128.codeValues(for: "AB12345678901234")
                == [104, 33, 34, 99, 12, 34, 56, 78, 90, 12, 34, 92, 106])
        // 12 個 11-module 符號 + 13-module stop = 145
        #expect(Code128.modules(for: "AB12345678901234")?.count == 145)
    }

    @Test("All-digit input starts directly in code C")
    func allDigitsStartsInC() {
        // checksum = 105 + 12*1 + 34*2 = 185 → 185 % 103 = 82
        #expect(Code128.codeValues(for: "1234") == [105, 12, 34, 82, 106])
    }

    @Test("Modules begin and end with a bar")
    func modulesBoundedByBars() {
        let modules = Code128.modules(for: "/AB12+CD")
        #expect(modules?.first == true)
        #expect(modules?.last == true)
    }

    @Test("Rejects empty and non-ASCII input")
    func rejectsInvalidInput() {
        #expect(Code128.modules(for: "") == nil)
        #expect(Code128.modules(for: "載具") == nil)
        #expect(Code128.codeValues(for: "") == nil)
    }
}
