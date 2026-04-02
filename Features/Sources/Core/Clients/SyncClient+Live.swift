import CloudKit
import Dependencies
import Domain
import Foundation
import SwiftData

extension SyncClient: DependencyKey {
    public static var liveValue: SyncClient {
        @Dependency(\.userSettingsClient) var userSettingsClient
        let capturedUserSettingsClient = userSettingsClient

        return SyncClient(
            isCloudKitAvailable: {
                FileManager.default.ubiquityIdentityToken != nil
            },
            enableSync: {
                AsyncThrowingStream { continuation in
                    let task = Task { @MainActor in
                        do {
                            let schema = Schema([
                                SDTransaction.self,
                                SDAccount.self,
                                SDCategory.self,
                                SDBudget.self,
                                SDTag.self,
                                SDRecurringTransaction.self,
                            ])
                            let cloudConfig = ModelConfiguration(
                                schema: schema,
                                cloudKitDatabase: .private("iCloud.com.drakehuang.NeuLedger")
                            )
                            let cloudContainer = try ModelContainer(
                                for: schema,
                                configurations: [cloudConfig]
                            )
                            let cloudContext = ModelContext(cloudContainer)
                            let localContext = ModelContext(DatabaseClient.container)

                            // 步驟 1：SDTag（無依賴）
                            let tags = try localContext.fetch(FetchDescriptor<SDTag>())
                            var tagMap: [UUID: SDTag] = [:]
                            for tag in tags {
                                let newTag = SDTag(id: tag.id, name: tag.name, color: tag.color)
                                cloudContext.insert(newTag)
                                tagMap[tag.id] = newTag
                            }
                            try cloudContext.save()
                            continuation.yield(0.1)

                            // 步驟 2：SDCategory（無依賴）
                            let categories = try localContext.fetch(FetchDescriptor<SDCategory>())
                            for cat in categories {
                                cloudContext.insert(SDCategory(
                                    id: cat.id,
                                    name: cat.name,
                                    icon: cat.icon,
                                    color: cat.color,
                                    type: cat.type,
                                    sortOrder: cat.sortOrder,
                                    isDefault: cat.isDefault
                                ))
                            }
                            try cloudContext.save()
                            continuation.yield(0.25)

                            // 步驟 3：SDAccount（無依賴）
                            let accounts = try localContext.fetch(FetchDescriptor<SDAccount>())
                            for acc in accounts {
                                cloudContext.insert(SDAccount(
                                    id: acc.id,
                                    name: acc.name,
                                    type: acc.type,
                                    icon: acc.icon,
                                    color: acc.color,
                                    sortOrder: acc.sortOrder,
                                    isArchived: acc.isArchived,
                                    createdAt: acc.createdAt
                                ))
                            }
                            try cloudContext.save()
                            continuation.yield(0.4)

                            // 步驟 4：SDBudget（無依賴）
                            let budgets = try localContext.fetch(FetchDescriptor<SDBudget>())
                            for b in budgets {
                                cloudContext.insert(SDBudget(
                                    id: b.id,
                                    name: b.name,
                                    amount: b.amount,
                                    categoryId: b.categoryId,
                                    period: b.period,
                                    startDate: b.startDate,
                                    isActive: b.isActive
                                ))
                            }
                            try cloudContext.save()
                            continuation.yield(0.55)

                            // 步驟 5：SDRecurringTransaction（無 relationship）
                            let recurring = try localContext.fetch(FetchDescriptor<SDRecurringTransaction>())
                            for r in recurring {
                                cloudContext.insert(SDRecurringTransaction(
                                    id: r.id,
                                    amount: r.amount,
                                    note: r.note,
                                    categoryId: r.categoryId,
                                    accountId: r.accountId,
                                    toAccountId: r.toAccountId,
                                    typeRaw: r.typeRaw,
                                    tagIds: r.tagIds,
                                    frequencyRaw: r.frequencyRaw,
                                    nextDueDate: r.nextDueDate,
                                    isActive: r.isActive,
                                    createdAt: r.createdAt
                                ))
                            }
                            try cloudContext.save()
                            continuation.yield(0.7)

                            // 步驟 6：SDTransaction（依賴 SDTag relationship）
                            let transactions = try localContext.fetch(FetchDescriptor<SDTransaction>())
                            for tx in transactions {
                                let newTx = SDTransaction(
                                    id: tx.id,
                                    amount: tx.amount,
                                    date: tx.date,
                                    note: tx.note,
                                    categoryId: tx.categoryId,
                                    accountId: tx.accountId,
                                    toAccountId: tx.toAccountId,
                                    type: tx.type,
                                    aiSuggested: tx.aiSuggested,
                                    createdAt: tx.createdAt,
                                    updatedAt: tx.updatedAt
                                )
                                newTx.tags = tx.tags.compactMap { tagMap[$0.id] }
                                cloudContext.insert(newTx)
                            }
                            try cloudContext.save()
                            continuation.yield(0.9)

                            // 替換 container — 之後所有 databaseClient 操作都使用 CloudKit
                            DatabaseClient.container = cloudContainer
                            capturedUserSettingsClient.setBool(true, .isSyncEnabled)

                            continuation.yield(1.0)
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}
