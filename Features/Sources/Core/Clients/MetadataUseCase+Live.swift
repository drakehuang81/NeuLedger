import Foundation
import Dependencies
import Domain

extension MetadataUseCase: DependencyKey {
    public static var liveValue: MetadataUseCase {
        @Dependency(\.categoryClient) var categoryClient
        @Dependency(\.tagClient) var tagClient

        return MetadataUseCase(
            listCategories: { type in
                if let type {
                    return try await categoryClient.fetchByType(type)
                }
                return try await categoryClient.fetchAll()
            },
            createCategory: { try await categoryClient.add($0) },
            updateCategory: { try await categoryClient.update($0) },
            deleteCategory: { try await categoryClient.delete($0) },
            listTags: { try await tagClient.fetchAll() },
            createTag: { try await tagClient.add($0) },
            updateTag: { try await tagClient.update($0) },
            deleteTag: { try await tagClient.delete($0) }
        )
    }
}
