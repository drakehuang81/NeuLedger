import Foundation
import Testing
import Domain
@testable import WatchFeatures

/// 守 Watch 這個 bundle 的分類名稱翻譯。
///
/// 為什麼需要一個跟 iOS 幾乎一樣的測試：`Category.localizedName` 走
/// `String(localized:, bundle: .main)`，而 `.main` 在每個 target 裡指向
/// 不同的字串表。iOS 測試 target 裡的 `CategoryLocalizedNameTests` 驗的是
/// iOS 的表，驗不到 Watch 的——`ConfirmView` 顯示分類名稱時用的是 Watch 的表。
///
/// 這個分裂實際發生過：Watch 的表原本一個 `category_seed_*` 都沒有，而
/// `String(localized:)` 查不到 key 時會把 key 本身當成翻譯回傳，所以畫面上
/// 會出現 `category_seed_food` 這種字串——它看起來像一個合理的值，不會拋錯、
/// 不會讓測試變紅，能一路上架。
@Suite("Watch bundle category localization")
struct WatchCategoryLocalizationTests {

    /// 與 `PersistenceBootstrap` 的 `SeedCategory` 清單對應。
    ///
    /// 這裡硬寫是模組邊界的結果：`SeedCategory` 住在 Core，Watch 測試 target
    /// 不依賴 Core。Core 的 `DatabaseSeedingTests.testSeedNamesHaveLocalizationKeys`
    /// 守的是「每個 seed 在 map 裡有 key」，這裡守的是「Watch 的表查得到翻譯」，
    /// 兩者合起來才完整。
    private static let seedNames = [
        "Food", "Transport", "Entertainment", "Shopping", "Housing",
        "Utilities", "Health", "Education", "Other Expense",
        "Salary", "Freelance", "Investment", "Gift", "Other Income",
    ]

    private static func category(named name: String) -> Domain.Category {
        Domain.Category(
            id: UUID(),
            name: name,
            icon: "fork.knife",
            color: "#FF9500",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        )
    }

    @Test("every seed category resolves to a translation in the Watch bundle")
    func seedNamesResolveOnWatch() {
        for name in Self.seedNames {
            let result = Self.category(named: name).localizedName
            #expect(!result.isEmpty, "\(name) 的 localizedName 是空字串")
            #expect(
                !result.hasPrefix("category_seed_"),
                "\(name) 在 Watch bundle 回傳 i18n key 而不是翻譯：\(result)"
            )
            #expect(result != name, "\(name) 沒有被在地化，仍是英文 seed 名")
        }
    }

    @Test("a user-renamed default category keeps its own name")
    func renamedCategoryKeepsItsName() {
        // 使用者改過名字的預設分類不在 map 裡，應該原樣顯示而不是硬套翻譯。
        #expect(Self.category(named: "我的餐費").localizedName == "我的餐費")
    }

    @Test("a non-default category is never localized")
    func customCategoryIsNotLocalized() {
        // 名字剛好撞到 seed 名的自建分類，不該被翻譯成「餐飲」。
        let custom = Domain.Category(
            name: "Food", icon: "fork.knife", color: "#FF9500",
            type: .expense, isDefault: false
        )
        #expect(custom.localizedName == "Food")
    }
}
