import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

/// Integration tests for `LedgerClient.liveValue` — Catalog section, `deleteCategory`
/// cascade (spec A6, 裁定 R1).
///
/// `SDTransaction.categoryId` / `SDBudget.categoryId` are bare `UUID?` fields with no
/// `@Relationship`, so SwiftData never cascades a category deletion into either table.
/// Left unguarded, deleting a category a budget points at leaves that budget silently
/// stuck at 0% spent forever (still shown, never explained), and deleting a category a
/// transaction points at leaves an orphan id (blank category in the UI, blank CSV
/// column). R1: a budget reference denies the delete; a transaction reference is
/// cleared (those transactions become "uncategorized").
///
/// 裁定 L：`SDRecurringTransaction.categoryId` 也是同一種裸 `UUID?`，同樣清引用。
/// 不清的話，該範本之後每一期自動補記出來的新交易都會是「無分類」。
///
/// Structure mirrors `LedgerClientLiveTests.swift`'s `init()` (in-memory `ModelContainer`
/// + `withDependencies` assembling `sut: LedgerClient`) and its `seedCategory(_:)` helper
/// (writes straight through `CategoryStore`, bypassing the client's own guards — exactly
/// what building a fixture needs).
@Suite("LedgerClient Live (Catalog) deleteCategory cascade")
struct LedgerClientCatalogTests {
    let container: ModelContainer
    let sut: LedgerClient

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
            SDRecurringTransaction.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container

        let testPersistenceBootstrap = PersistenceBootstrap(modelContainer: { _container })

        self.sut = withDependencies {
            $0.persistenceBootstrap = testPersistenceBootstrap
            $0.modelContainer = _container
            // Silence the budget post-condition so record/update don't reach
            // into PlanningClient's live store reads — behaviour of that
            // invariant is covered separately by PlanningClientEvaluateTests.
            $0.planningClient.evaluateAfterTransaction = { _ in }
        } operation: {
            LedgerClient.liveValue
        }
    }

    /// Seed a category straight into the container (bypassing `createCategory`) so
    /// fixtures don't have to go through the client's own guards.
    private func seedCategory(_ category: Domain.Category) async throws {
        let store = CategoryStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(category)
        }
    }

    private static func customCategory(id: UUID) -> Domain.Category {
        // isDefault: false —— 預設分類本來就不能刪，那是另一條測試
        Domain.Category(
            id: id, name: "Coffee", icon: "cup.and.saucer", color: "#8B4513",
            type: .expense, isDefault: false
        )
    }

    private static func expense(categoryId: UUID?, accountId: String) -> Transaction {
        Transaction(amount: 120, date: Date(), categoryId: categoryId,
                    accountId: accountId, type: .expense)
    }

    /// Seed a recurring template straight into the container (bypassing
    /// `createRecurring`) — this suite overrides no `notificationAdapter`, so the
    /// client's own create path would reach the live reminder scheduler.
    private func seedRecurring(_ template: RecurringTransaction) async throws {
        let store = RecurringTransactionStore()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await store.add(template)
        }
    }

    private static func template(categoryId: UUID?, accountId: String) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(), amount: 1200, note: "Rent",
            categoryId: categoryId, accountId: accountId, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
    }

    private static func budget(categoryId: UUID?) -> Budget {
        Budget(
            id: UUID(), name: "Test Budget", amount: 500, categoryId: categoryId,
            period: .monthly, startDate: Date(), isActive: true
        )
    }

    @Test("deleting a category that a budget points at is denied")
    func testDeleteCategoryWithBudgetIsDenied() async throws {
        let categoryId = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: categoryId))
        let budgetStore = BudgetStore()
        try await withDependencies { $0.modelContainer = container } operation: {
            try await budgetStore.add(Self.budget(categoryId: categoryId))
        }
        // 被擋下來的刪除必須是**完全**沒有副作用的，所以這裡要有東西可以被弄壞。
        try await sut.record(Self.expense(categoryId: categoryId, accountId: accountId))

        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(categoryId)
        }
        #expect(try await sut.listCategories(nil).contains { $0.id == categoryId },
                "被擋下來的刪除不得動到分類本身")
        // 反向斷言：少了這條，「把清交易引用的迴圈上移到預算守衛之前」這個突變
        // 會讓整個 suite 照樣全綠——使用者看到「刪除失敗」，實際上該分類的所有
        // 交易已經被靜默清成未分類，正是本 PR 要防的資料損毀。
        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.count == 1, "交易不得被連帶刪除")
        #expect(rows.allSatisfy { $0.transaction.categoryId == categoryId },
                "被擋下來的刪除不得清掉交易的分類引用")
    }

    @Test("deleting a category clears it from the transactions that referenced it")
    func testDeleteCategoryClearsTransactionReferences() async throws {
        let categoryId = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: categoryId))
        try await sut.record(Self.expense(categoryId: categoryId, accountId: accountId))
        try await sut.record(Self.expense(categoryId: categoryId, accountId: accountId))

        try await sut.deleteCategory(categoryId)

        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.count == 2, "交易不得被連帶刪除")
        #expect(rows.allSatisfy { $0.transaction.categoryId == nil },
                "引用必須被清掉，不能留下指向不存在分類的孤兒 id")
        #expect(try await sut.listCategories(nil).contains { $0.id == categoryId } == false)
    }

    @Test("deleting a category clears it from the recurring templates that referenced it")
    func testDeleteCategoryClearsRecurringTemplateReferences() async throws {
        let categoryId = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: categoryId))
        try await seedRecurring(Self.template(categoryId: categoryId, accountId: accountId))

        try await sut.deleteCategory(categoryId)

        let templates = try await sut.listRecurring()
        #expect(templates.count == 1, "範本不得被連帶刪除")
        #expect(templates.allSatisfy { $0.categoryId == nil },
                "範本的分類引用必須被清掉，否則該範本每一期補記出來的新交易都會是無分類")
        #expect(try await sut.listCategories(nil).contains { $0.id == categoryId } == false)
    }

    @Test("a recurring template that uses a different category is untouched")
    func testDeleteCategoryLeavesOtherTemplatesAlone() async throws {
        let doomed = UUID()
        let kept = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: doomed))
        try await seedCategory(Domain.Category(
            id: kept, name: "Rent", icon: "house", color: "#00FF00",
            type: .expense, isDefault: false
        ))
        try await seedRecurring(Self.template(categoryId: doomed, accountId: accountId))
        try await seedRecurring(Self.template(categoryId: kept, accountId: accountId))

        try await sut.deleteCategory(doomed)

        let templates = try await sut.listRecurring()
        #expect(templates.filter { $0.categoryId == kept }.count == 1,
                "不相關的範本不得被清掉分類")
    }

    @Test("a transaction that uses a different category is untouched")
    func testDeleteCategoryLeavesOtherTransactionsAlone() async throws {
        let doomed = UUID()
        let kept = UUID()
        let accountId = UUID().uuidString
        try await seedCategory(Self.customCategory(id: doomed))
        try await seedCategory(Domain.Category(
            id: kept, name: "Rent", icon: "house", color: "#00FF00",
            type: .expense, isDefault: false
        ))
        try await sut.record(Self.expense(categoryId: doomed, accountId: accountId))
        try await sut.record(Self.expense(categoryId: kept, accountId: accountId))

        try await sut.deleteCategory(doomed)

        let rows = try await sut.listAll(TransactionFilter())
        #expect(rows.filter { $0.transaction.categoryId == kept }.count == 1,
                "不相關的交易不得被清掉分類")
    }

    @Test("deleting a default category is still denied")
    func testDeleteDefaultCategoryStillDenied() async throws {
        let categoryId = UUID()
        try await seedCategory(Domain.Category(
            id: categoryId, name: "Food", icon: "fork.knife", color: "#FF0000",
            type: .expense, isDefault: true
        ))
        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(categoryId)
        }
    }
}
