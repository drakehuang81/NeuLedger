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

    private static func budget(categoryId: UUID?) -> Budget {
        Budget(
            id: UUID(), name: "Test Budget", amount: 500, categoryId: categoryId,
            period: .monthly, startDate: Date(), isActive: true
        )
    }

    @Test("deleting a category that a budget points at is denied")
    func testDeleteCategoryWithBudgetIsDenied() async throws {
        let categoryId = UUID()
        try await seedCategory(Self.customCategory(id: categoryId))
        let budgetStore = BudgetStore()
        try await withDependencies { $0.modelContainer = container } operation: {
            try await budgetStore.add(Self.budget(categoryId: categoryId))
        }

        await #expect(throws: CoreError.self) {
            try await sut.deleteCategory(categoryId)
        }
        #expect(try await sut.listCategories(nil).contains { $0.id == categoryId },
                "被擋下來的刪除不得動到分類本身")
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
