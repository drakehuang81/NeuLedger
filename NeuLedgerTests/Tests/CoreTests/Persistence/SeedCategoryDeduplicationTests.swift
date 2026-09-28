import Testing
import Foundation
import SwiftData
import Domain
@testable import Core

/// 釘住 `deduplicateSeedCategories(in:)`：CloudKit 同步之後同一個 seed id
/// 會出現多筆列（health-audit #8 / spec A4 後半），這組測試確認它們被收斂成一筆、
/// 使用者的編輯留得下來、而健康的 store 一筆都不會被動到。
@Suite("Seed category 去重")
struct SeedCategoryDeduplicationTests {

    private func freshContainer() throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
            SDRecurringTransaction.self,
            SDCarrier.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// 造一筆與 seed 定義一模一樣的列（就是兩台裝置各自 seed 出來的那種）。
    private func pristineRow(_ seed: SeedCategory, sortOrder: Int = 0) -> SDCategory {
        SDCategory(
            id: seed.id, name: seed.name, icon: seed.icon, color: seed.color,
            type: TransactionType.expense.rawValue, sortOrder: sortOrder, isDefault: true
        )
    }

    private func rows(for id: UUID, in context: ModelContext) throws -> [SDCategory] {
        try context.fetch(FetchDescriptor<SDCategory>(predicate: #Predicate { $0.id == id }))
    }

    @Test("同一個 seed id 的多筆列收斂成一筆，其他 id 不受影響")
    func duplicateRowsCollapseToASingleSurvivor() throws {
        let context = ModelContext(try freshContainer())
        let food = SeedCategory.food
        context.insert(pristineRow(food))
        context.insert(pristineRow(food))
        context.insert(pristineRow(food))
        context.insert(pristineRow(SeedCategory.transport))
        try context.save()

        let deleted = PersistenceBootstrap.deduplicateSeedCategories(in: context)

        #expect(deleted == 2, "三筆重複只該刪掉兩筆")
        #expect(try rows(for: food.id, in: context).count == 1)
        #expect(
            try rows(for: SeedCategory.transport.id, in: context).count == 1,
            "只有一筆的 id 不該被碰到"
        )
    }

    @Test("被使用者改過的那一筆勝過原封不動的那一筆")
    func theCustomisedRowSurvivesThePristineOne() throws {
        let context = ModelContext(try freshContainer())
        let food = SeedCategory.food
        context.insert(pristineRow(food))
        let renamed = pristineRow(food)
        renamed.name = "餐飲"
        context.insert(renamed)
        try context.save()

        PersistenceBootstrap.deduplicateSeedCategories(in: context)

        let survivors = try rows(for: food.id, in: context)
        #expect(survivors.count == 1)
        #expect(
            survivors.first?.name == "餐飲",
            "留下 seed 原樣那一筆等於默默丟掉使用者在另一台裝置上的改名"
        )
    }

    @Test("插入順序不影響留下哪一筆（兩台裝置必須算出同一個答案）")
    func insertionOrderDoesNotChangeTheSurvivor() throws {
        let food = SeedCategory.food

        func survivorName(reversed: Bool) throws -> String? {
            let context = ModelContext(try freshContainer())
            let first = pristineRow(food)
            first.name = "AAA"
            let second = pristineRow(food)
            second.name = "BBB"
            for row in (reversed ? [second, first] : [first, second]) {
                context.insert(row)
            }
            try context.save()

            PersistenceBootstrap.deduplicateSeedCategories(in: context)
            return try rows(for: food.id, in: context).first?.name
        }

        // 兩台裝置看到的是同一組列、只是本地插入順序不同。若答案跟順序有關，
        // 兩台就會各自留下不同的那一筆、互相刪掉對方留的那一筆，同步回來後
        // 這個 id 會一筆不剩。
        #expect(try survivorName(reversed: false) == "AAA")
        #expect(try survivorName(reversed: true) == "AAA")
    }

    @Test("健康的 store 一筆都不會被刪")
    func aHealthySeededStoreIsLeftUntouched() throws {
        let context = ModelContext(try freshContainer())
        PersistenceBootstrap.seedIfNeeded(in: context)
        let before = try context.fetch(FetchDescriptor<SDCategory>()).count
        #expect(before == 14, "前提：seeding 後應該有 14 筆預設分類")

        let deleted = PersistenceBootstrap.deduplicateSeedCategories(in: context)

        #expect(deleted == 0)
        #expect(try context.fetch(FetchDescriptor<SDCategory>()).count == before)
    }

    @Test("非 seed id 的重複列刻意不碰")
    func duplicatesOutsideTheSeedIdsAreLeftAlone() throws {
        let context = ModelContext(try freshContainer())
        // 使用者自建分類拿的是隨機 UUID，兩台裝置撞不到同一個 id，所以這種重複
        // 只可能是我們自己的程式錯誤；沒有任何機制能重建它，誤刪是永久損失。
        let userCategoryID = UUID()
        for _ in 0..<2 {
            context.insert(SDCategory(
                id: userCategoryID, name: "健身", icon: "figure.run", color: "#111111",
                type: TransactionType.expense.rawValue, sortOrder: 99, isDefault: false
            ))
        }
        try context.save()

        let deleted = PersistenceBootstrap.deduplicateSeedCategories(in: context)

        #expect(deleted == 0)
        #expect(try rows(for: userCategoryID, in: context).count == 2)
    }
}
