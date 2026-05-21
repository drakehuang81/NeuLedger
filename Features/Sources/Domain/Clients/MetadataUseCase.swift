import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for ledger metadata (categories + tags).
///
/// Surface follows `docs/architecture.md` §5 Ledger Context — Category and
/// Tag are intentionally combined into a single UseCase because they share
/// the same role (transaction classification) and are almost always edited
/// in the same Settings screen. The Live implementation is a thin
/// delegation to `CategoryClient` + `TagClient` today; future business
/// rules (e.g., merging duplicate tags, cascading category renames) live
/// here without changing the underlying Repositories.
@DependencyClient
public struct MetadataUseCase: Sendable {
    // MARK: Category
    public var listCategories: @Sendable (_ type: TransactionType?) async throws -> [Category] = { _ in [] }
    public var createCategory: @Sendable (_ category: Category) async throws -> Void
    public var updateCategory: @Sendable (_ category: Category) async throws -> Void
    public var deleteCategory: @Sendable (_ id: Category.ID) async throws -> Void

    // MARK: Tag
    public var listTags: @Sendable () async throws -> [Tag]
    public var createTag: @Sendable (_ tag: Tag) async throws -> Void
    public var updateTag: @Sendable (_ tag: Tag) async throws -> Void
    public var deleteTag: @Sendable (_ id: Tag.ID) async throws -> Void
}

extension MetadataUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var metadataUseCase: MetadataUseCase {
        get { self[MetadataUseCase.self] }
        set { self[MetadataUseCase.self] = newValue }
    }
}
