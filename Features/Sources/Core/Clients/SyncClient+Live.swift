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
                            let cloudContainer = try ModelContainer(
                                for: DatabaseClient.schema,
                                configurations: [DatabaseClient.cloudConfiguration]
                            )
                            let cloudContext = ModelContext(cloudContainer)
                            let localContext = ModelContext(DatabaseClient.container)

                            // 步驟 1：SDTag（無依賴；建立 tagMap 供 SDTransaction relationship 使用）
                            let tags = try localContext.fetch(FetchDescriptor<SDTag>())
                            var tagMap: [UUID: SDTag] = [:]
                            for tag in tags {
                                let copy = tag.makeCopy()
                                cloudContext.insert(copy)
                                tagMap[tag.id] = copy
                            }
                            try cloudContext.save()
                            continuation.yield(0.1)

                            // 步驟 2：SDCategory
                            try localContext.fetch(FetchDescriptor<SDCategory>())
                                .map { $0.makeCopy() }
                                .forEach { cloudContext.insert($0) }
                            try cloudContext.save()
                            continuation.yield(0.25)

                            // 步驟 3：SDAccount
                            try localContext.fetch(FetchDescriptor<SDAccount>())
                                .map { $0.makeCopy() }
                                .forEach { cloudContext.insert($0) }
                            try cloudContext.save()
                            continuation.yield(0.4)

                            // 步驟 4：SDBudget
                            try localContext.fetch(FetchDescriptor<SDBudget>())
                                .map { $0.makeCopy() }
                                .forEach { cloudContext.insert($0) }
                            try cloudContext.save()
                            continuation.yield(0.55)

                            // 步驟 5：SDRecurringTransaction
                            try localContext.fetch(FetchDescriptor<SDRecurringTransaction>())
                                .map { $0.makeCopy() }
                                .forEach { cloudContext.insert($0) }
                            try cloudContext.save()
                            continuation.yield(0.7)

                            // 步驟 6：SDCarrier
                            try localContext.fetch(FetchDescriptor<SDCarrier>())
                                .map { $0.makeCopy() }
                                .forEach { cloudContext.insert($0) }
                            try cloudContext.save()
                            continuation.yield(0.8)

                            // 步驟 7：SDTransaction（tags relationship 需透過 tagMap 解析）
                            for tx in try localContext.fetch(FetchDescriptor<SDTransaction>()) {
                                let copy = tx.makeCopy()
                                copy.tags = tx.tags.compactMap { tagMap[$0.id] }
                                cloudContext.insert(copy)
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
