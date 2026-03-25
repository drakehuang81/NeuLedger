import Testing
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
