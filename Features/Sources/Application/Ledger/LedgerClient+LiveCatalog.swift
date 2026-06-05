import Foundation
import SwiftData
import Dependencies
import Domain

/// Catalog section of `LedgerClient.liveValue` (step-5a3 internalisation).
///
/// Categories and Tags are read/written through `SwiftDataStore` directly,
/// replacing the former `\.metadataUseCase` → `\.categoryClient`/`\.tagClient`
/// delegation. Two business rules are preserved verbatim from
/// `CategoryClient+Live`/`TagClient+Live`:
///
/// - **Default categories cannot be deleted** — `deleteCategory` re-fetches the
///   row and throws `CoreError.operationDenied` when `isDefault == true`.
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
        _ store: CategoryStore
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
