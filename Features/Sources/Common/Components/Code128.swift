import Foundation

/// Pure-Swift Code 128 encoder (code sets B and C with digit-run
/// optimization). Produces the module pattern (bar = `true`, space =
/// `false`) for a barcode body — start code, data, checksum, stop —
/// without quiet zones (the rendering view adds those).
///
/// Exists because watchOS has no `CIFilter` barcode generators. Encoding
/// follows ISO/IEC 15417; `widths` is the standard 107-symbol table.
public enum Code128 {

    /// Widths table for symbols 0...106. Each entry alternates bar/space
    /// widths starting with a bar; symbols 0...105 span 11 modules, the
    /// stop symbol (106) spans 13.
    static let widths: [String] = [
        "212222", "222122", "222221", "121223", "121322", // 0-4
        "131222", "122213", "122312", "132212", "221213", // 5-9
        "221312", "231212", "112232", "122132", "122231", // 10-14
        "113222", "123122", "123221", "223211", "221132", // 15-19
        "221231", "213212", "223112", "312131", "311222", // 20-24
        "321122", "321221", "312212", "322112", "322211", // 25-29
        "212123", "212321", "232121", "111323", "131123", // 30-34
        "131321", "112313", "132113", "132311", "211313", // 35-39
        "231113", "231311", "112133", "112331", "132131", // 40-44
        "113123", "113321", "133121", "313121", "211331", // 45-49
        "231131", "213113", "213311", "213131", "311123", // 50-54
        "311321", "331121", "312113", "312311", "332111", // 55-59
        "314111", "221411", "431111", "111224", "111422", // 60-64
        "121124", "121421", "141122", "141221", "112214", // 65-69
        "112412", "122114", "122411", "142112", "142211", // 70-74
        "241211", "221114", "413111", "241112", "134111", // 75-79
        "111242", "121142", "121241", "114212", "124112", // 80-84
        "124211", "411212", "421112", "421211", "212141", // 85-89
        "214121", "412121", "111143", "111341", "131141", // 90-94
        "114113", "114311", "411113", "411311", "113141", // 95-99
        "114131", "311141", "411131", "211412", "211214", // 100-104
        "211232",                                          // 105
        "2331112",                                         // 106 (stop)
    ]

    private static let startB = 104
    private static let startC = 105
    private static let switchToB = 100
    private static let switchToC = 99
    private static let stop = 106

    /// Encodes `text` into module runs (`true` = bar). Returns `nil` when
    /// `text` is empty or contains characters outside printable ASCII
    /// (32...126).
    public static func modules(for text: String) -> [Bool]? {
        guard let values = codeValues(for: text) else { return nil }
        var modules: [Bool] = []
        for value in values {
            var isBar = true
            for widthChar in widths[value] {
                let width = widthChar.wholeNumberValue ?? 0
                modules.append(contentsOf: Array(repeating: isBar, count: width))
                isBar.toggle()
            }
        }
        return modules
    }

    /// Symbol-value sequence — start, data (B/C optimized), checksum,
    /// stop. Internal so tests can assert exact symbol sequences.
    ///
    /// Set-selection heuristic (deterministic, optimal for the two
    /// carrier formats this app stores; not globally optimal):
    /// - start in C when the leading digit run is ≥ 4 and even,
    /// - in B, switch to C when the digit run at the cursor is ≥ 4 and even,
    /// - in C, consume digit pairs while ≥ 2 digits remain, else switch to B.
    static func codeValues(for text: String) -> [Int]? {
        guard !text.isEmpty else { return nil }
        let scalars = Array(text.unicodeScalars)
        guard scalars.allSatisfy({ (32...126).contains($0.value) }) else { return nil }

        func digitRun(from index: Int) -> Int {
            var count = 0
            while index + count < scalars.count,
                  (48...57).contains(scalars[index + count].value) {
                count += 1
            }
            return count
        }

        let leadingDigits = digitRun(from: 0)
        var inSetC = leadingDigits >= 4 && leadingDigits.isMultiple(of: 2)
        var values: [Int] = [inSetC ? startC : startB]
        var index = 0

        while index < scalars.count {
            if inSetC {
                if digitRun(from: index) >= 2 {
                    let tens = Int(scalars[index].value) - 48
                    let ones = Int(scalars[index + 1].value) - 48
                    values.append(tens * 10 + ones)
                    index += 2
                } else {
                    values.append(switchToB)
                    inSetC = false
                }
            } else {
                let run = digitRun(from: index)
                if run >= 4 && run.isMultiple(of: 2) {
                    values.append(switchToC)
                    inSetC = true
                } else {
                    values.append(Int(scalars[index].value) - 32)
                    index += 1
                }
            }
        }

        var checksum = values[0]
        for (position, value) in values.dropFirst().enumerated() {
            checksum += (position + 1) * value
        }
        values.append(checksum % 103)
        values.append(stop)
        return values
    }
}
