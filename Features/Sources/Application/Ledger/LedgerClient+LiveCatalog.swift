import Foundation
import SwiftData
import Dependencies
import Domain

/// Catalog section of `LedgerClient.liveValue` (step-5a3 internalisation).
///
/// Categories and Tags are read/written through `SwiftDataStore` directly,
/// replacing the former `\.metadataUseCase` → `\.categoryClient`/`\.tagClient`
/// delegation. Business rules preserved / added:
///
/// - **Default categories cannot be deleted** — `deleteCategory` re-fetches the
///   row and throws `CoreError.operationDenied` when `isDefault == true`.
/// - **Deleting a category a budget still points at is denied** (spec A6,
///   裁定 R1) — `SDBudget.categoryId` is a bare `UUID?` with no `@Relationship`,
///   so SwiftData never cascades. An orphaned budget is stuck at 0% spent
///   forever while still showing on screen, so `deleteCategory` throws
///   `CoreError.operationDenied` instead of silently breaking it.
/// - **Deleting a category clears it from any transaction that referenced it**
///   (spec A6, 裁定 R1) — same missing-`@Relationship` problem on
///   `SDTransaction.categoryId`, but a transaction only loses a label, so the
///   reference is cleared (the transaction becomes "uncategorized") rather than
///   the delete being denied.
/// - **同一條規則也套用在週期範本上**（裁定 L）——`SDRecurringTransaction.categoryId`
///   同樣是裸 `UUID?`。範本比交易更緊急：留著懸空引用的話，該範本之後**每一期**
///   自動補記出來的新交易都會是「無分類」，而不只是既有的那幾筆少一個標記。
/// - **Tag deletion disassociates the tag from every linked transaction** — this
///   happens inside `SDTag.prepareForDelete()` (clears the inverse `transactions`
///   array), which `SwiftDataStore.delete(id:)` invokes before removing the SD
///   instance, so `deleteTag` is a plain store delete.
extension LedgerClient {
    static func makeListCategories(
        _ store: CategoryStore
    ) -> @Sendable (TransactionType?) async throws -> [Domain.Category] {
        { type in
            let all = try await store.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            guard let type else { return all }
            return all.filter { $0.type == type }
        }
    }

    static func makeCreateCategory(
        _ store: CategoryStore
    ) -> @Sendable (Domain.Category) async throws -> Void {
        { category in
            try await store.add(category)
        }
    }

    static func makeUpdateCategory(
        _ store: CategoryStore
    ) -> @Sendable (Domain.Category) async throws -> Void {
        { category in
            try await store.update(category)
        }
    }

    static func makeDeleteCategory(
        _ store: CategoryStore,
        _ budgetStore: BudgetStore,
        _ transactionStore: TransactionStore,
        _ recurringStore: RecurringTransactionStore
    ) -> @Sendable (Domain.Category.ID) async throws -> Void {
        { id in
            guard let existing = try await store.fetch(id: id) else {
                throw CoreError.notFound("SDCategory")
            }
            guard !existing.isDefault else {
                throw CoreError.operationDenied(
                    "Cannot delete default category '\(existing.name)'"
                )
            }

            // 預算被孤兒化會永久壞掉——永遠算出 0 支出卻仍顯示在畫面上，
            // 使用者看不出原因。所以擋下來，要求先處理預算（plan R1）。
            let linkedBudgets = try await budgetStore.fetchAll(
                where: #Predicate<SDBudget> { $0.categoryId == id }
            )
            guard linkedBudgets.isEmpty else {
                throw CoreError.operationDenied(
                    "Cannot delete category '\(existing.name)' while \(linkedBudgets.count) budget(s) still use it; delete those budgets first."
                )
            }

            // 週期範本先清、交易後清，順序是有意義的（裁定 L）：`tick` 是這張
            // 表的第二個寫入者，只要範本還指著這個分類，下一次進前景就會再生出
            // 一筆帶著這個分類 id 的新交易。先讓範本停止產生這個引用，隨後的
            // 交易清理才能把 tick 剛剛產生的那幾筆一起掃到。
            //
            // 清引用而不是擋下來：`RecurringTransaction.categoryId` 在 Domain 與
            // SD 兩層都是 optional，「無分類」是 UI 本來就會正常顯示的合法狀態，
            // 所以這裡對應的是 plan R1「交易只是少一個標記」那條分支。帳戶那條
            // （`deleteAccount`）之所以連已暫停的範本都擋，是因為 `accountId` 是
            // non-optional，懸空的帳戶 id 等於一筆結構上壞掉的交易。
            //
            // 不清的後果不是一次性的：該範本**每一期**自動補記出來的新交易都會是
            // 「無分類」，一直產生下去，Insights 的分類佔比也永久少算這批支出。
            //
            // `fetchAll().filter` 而不是 predicate fetch——比照 +Live.swift 的兩處
            // 帳戶守衛（範本表本來就小，不值得為此新增一個 store 方法）。
            let affectedTemplates = try await recurringStore.fetchAll().filter {
                $0.categoryId == id
            }
            for var template in affectedTemplates {
                template.categoryId = nil
                try await recurringStore.update(template)
            }

            // 交易只是少一個標記，清掉引用即可（plan R1），
            // 但一定要清——留下指向不存在分類的 id 會讓畫面空白、CSV 匯出空欄。
            let affected = try await transactionStore.fetchAll(
                where: #Predicate<SDTransaction> { $0.categoryId == id }
            )
            for var transaction in affected {
                transaction.categoryId = nil
                try await transactionStore.update(transaction)
            }

            try await store.delete(id: id)
        }
    }

    static func makeListTags(
        _ store: TagStore
    ) -> @Sendable () async throws -> [Tag] {
        {
            try await store.fetchAll(sortBy: [SortDescriptor(\.name)])
        }
    }

    static func makeCreateTag(
        _ store: TagStore
    ) -> @Sendable (Tag) async throws -> Void {
        { tag in
            try await store.add(tag)
        }
    }

    static func makeUpdateTag(
        _ store: TagStore
    ) -> @Sendable (Tag) async throws -> Void {
        { tag in
            try await store.update(tag)
        }
    }

    static func makeDeleteTag(
        _ store: TagStore
    ) -> @Sendable (Tag.ID) async throws -> Void {
        { id in
            // Many-to-many disassociation happens inside SDTag.prepareForDelete().
            try await store.delete(id: id)
        }
    }
}
