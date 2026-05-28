import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("TagClient Integration Tests")
struct TagClientTests {
    var container: ModelContainer
    var sut: TagClient
    var transactionClient: TransactionClient

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

        let testDatabaseClient = DatabaseClient(modelContainer: { _container })

        self.sut = withDependencies {
            $0.databaseClient = testDatabaseClient
            $0.modelContainer = _container
        } operation: {
            TagClient.liveValue
        }

        self.transactionClient = withDependencies {
            $0.databaseClient = testDatabaseClient
            $0.modelContainer = _container
        } operation: {
            TransactionClient.liveValue
        }
    }

    @Test("add stores tag and fetchAll returns it")
    func testAddAndFetchAll() async throws {
        let tag = Tag(id: UUID(), name: "餐飲", color: "#FF6B6B")
        try await sut.add(tag)

        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].id == tag.id)
        #expect(all[0].name == "餐飲")
        #expect(all[0].color == "#FF6B6B")
    }

    @Test("update modifies existing tag")
    func testUpdate() async throws {
        let tag = Tag(id: UUID(), name: "原始標籤", color: "#AAAAAA")
        try await sut.add(tag)

        let updatedTag = Tag(id: tag.id, name: "更新後標籤", color: "#BBBBBB")
        try await sut.update(updatedTag)

        let all = try await sut.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].name == "更新後標籤")
        #expect(all[0].color == "#BBBBBB")
    }

    @Test("delete removes tag from store")
    func testDelete() async throws {
        let tag = Tag(id: UUID(), name: "暫時標籤", color: "#123456")
        try await sut.add(tag)

        try await sut.delete(tag.id)

        let all = try await sut.fetchAll()
        #expect(all.isEmpty)
    }

    @Test("delete tag auto-disassociates it from linked transactions")
    func testDeleteTagDisassociatesFromTransactions() async throws {
        // Insert an account directly so TransactionClient can reference it
        let context = ModelContext(container)
        let sdAccount = SDAccount(
            id: UUID().uuidString, name: "現金", type: AccountType.cash.rawValue,
            icon: "banknote", color: "#34C759", sortOrder: 0,
            isArchived: false, createdAt: Date()
        )
        context.insert(sdAccount)
        try context.save()

        // Add a tag
        let tag = Tag(id: UUID(), name: "旅遊", color: "#4ECDC4")
        try await sut.add(tag)

        // Add a transaction that references the tag
        let txn = Transaction(
            id: UUID(),
            amount: Decimal(500),
            date: Date(),
            note: "旅遊消費",
            categoryId: nil,
            accountId: sdAccount.id,
            toAccountId: nil,
            type: .expense,
            tags: [tag],
            aiSuggested: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await transactionClient.add(txn)

        // Verify transaction has the tag before deletion
        let txnsBefore = try await transactionClient.fetchAll()
        #expect(txnsBefore.count == 1)
        #expect(txnsBefore[0].tags.contains { $0.id == tag.id })

        // Delete the tag — SwiftData's .nullify delete rule on SDTag → SDTransaction
        // automatically removes the tag from all linked transaction.tags arrays.
        try await sut.delete(tag.id)

        // Verify tag is gone
        let allTags = try await sut.fetchAll()
        #expect(allTags.isEmpty)

        // Verify transaction's tags array is now empty (disassociation confirmed)
        let txnsAfter = try await transactionClient.fetchAll()
        #expect(txnsAfter.count == 1)
        #expect(txnsAfter[0].tags.isEmpty)
    }
}
