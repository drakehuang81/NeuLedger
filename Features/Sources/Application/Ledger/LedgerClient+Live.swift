import Foundation
import SwiftData
import Dependencies
import Domain

/// Live implementation of `LedgerClient` — step-5a3 (Transactions + Accounts +
/// Catalog + Recurring + Export all internalised).
///
/// Every section now reads and writes `SwiftDataStore` directly (this file is
/// compiled into the **Core** target — see `Package.swift` `sources: ["Core",
/// "Application"]` — so SwiftData usage here is sanctioned, matching
/// `TransactionClient+Live`/`AccountClient+Live`/etc.). No delegating UseCase or
/// repository client is injected any longer: the Live value depends solely on
/// `SwiftDataStore`×5 (Transaction/Account/Category/Tag/RecurringTransaction) +
/// `planningClient` (§3.1 INVARIANT) + `notificationAdapter` (recurring
/// reminders) + `userSettingsAdapter` (`.defaultAccountId`).
///
/// Section → implementation (plan 5a3 mapping):
/// - Transactions → `TransactionStore` directly, with
///   the `EnrichedTransaction` join + filter/search lifted from
///   `LedgerUseCase+Live`. `record`/`update` keep the `// INVARIANT(§3.1)`
///   budget-evaluation post-condition via `\.planningClient`. The shared
///   `recordTransaction` closure carries that invariant so `tick` reuses the
///   exact same record path (SAGA internalised — see Recurring below).
/// - Accounts → `AccountStore` directly, with
///   `computeBalance`, the archive rule, the synthesized `unarchive`, and the
///   `balances` aggregate lifted from `AccountClient+Live`/`AccountUseCase+Live`.
///   `\.userSettingsAdapter` (`.defaultAccountId` key) backs the default account.
/// - Catalog → `CategoryStore` + `<Tag, SDTag>` directly
///   (factory in `+LiveCatalog.swift`), preserving the default-category delete
///   guard and the many-to-many tag disassociation (handled inside
///   `SDTag.prepareForDelete()`).
/// - Recurring → `RecurringTransactionStore`
///   directly (factory in `+LiveRecurring.swift`). **Notification scheduling is
///   now owned here (new behaviour, 5a3 上收)**: `createRecurring`/
///   `updateRecurring` schedule a due-date reminder via
///   `notificationAdapter.scheduleRecurringReminder`, `deleteRecurring` cancels
///   it via `cancelRecurringReminder`. `tick` is triggered by `MainTabFeature`
///   in the foreground (not a background task) and catches up **every** missed
///   occurrence per active template — not just one — through the shared
///   `recordTransaction` path (preserving the budget invariant + the reactive
///   Watch/Widget mirror), advancing and persisting `nextDueDate` after each
///   materialised occurrence, then re-syncing the reminder once per template.
/// - Export → CSV assembly lifted verbatim from `ExportUseCase+Live`
///   (factory + `csvField` escaping in `+LiveExport.swift`).
///
/// ## Watch / Widget mirroring (post-condition decision — 5a2, unchanged in 5a3)
///
/// The plan asks each of `record`/`update`/`delete` to mirror to Widget/Watch.
/// Investigation of the existing sync path settled the implementation:
///
/// - **Watch**: `WatchSyncObserver` (started once at launch via
///   `WatchBootstrap.start()`) observes `.NSManagedObjectContextDidSave` and
///   debounces 300 ms before rebuilding + pushing a full `WatchContextSnapshot`.
///   Every `SwiftDataStore` mutation calls `context.save()`, so the Watch mirror
///   is **already pushed reactively** for all three operations. Calling
///   `watchBridgeAdapter.pushContext` from here as well would push the same
///   snapshot twice per mutation (eager + observer), the double-push the plan
///   forbids. So the reactive observer remains the single Watch-push path and
///   this client does **not** inject `watchBridgeAdapter`.
/// - **Widget**: `WidgetSyncAdapter` is carrier-only (`syncCarrier` /
///   `clearCarrier` / `syncAllCarriers`); there is no ledger/transaction widget
///   data path in the codebase, so there is nothing to push and
///   `widgetSyncAdapter` is **not** injected.
///
/// The mirror post-condition is therefore "every ledger mutation produces a
/// context save", which `LedgerClientMirrorTests` asserts by observing
/// `.NSManagedObjectContextDidSave` exactly once per `record`/`update`/`delete`.
/// Because `tick` routes every occurrence it catches up through
/// `recordTransaction`, each materialised recurring transaction inherits the
/// same reactive mirror for free.
extension LedgerClient: DependencyKey {
    public static var liveValue: LedgerClient {
        @Dependency(\.planningClient) var planningClient
        @Dependency(\.notificationAdapter) var notificationAdapter
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        let transactionStore = TransactionStore()
        let accountStore = AccountStore()
        let categoryStore = CategoryStore()
        let tagStore = TagStore()
        let recurringStore = RecurringTransactionStore()

        // Domain join from id → resolved entity. Categories and accounts are
        // fetched once per call so listAll / search return enriched rows in
        // O(N) Swift-side. Lifted verbatim from `LedgerUseCase+Live`.
        let enrich: @Sendable ([Transaction]) async throws -> [EnrichedTransaction] = { transactions in
            guard !transactions.isEmpty else { return [] }
            async let allCategories = categoryStore.fetchAll()
            async let allAccounts = accountStore.fetchAll()
            let categories = try await allCategories
            let accounts = try await allAccounts
            let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            let accountById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
            return transactions.map { tx in
                EnrichedTransaction(
                    transaction: tx,
                    category: tx.categoryId.flatMap { categoryById[$0] },
                    account: accountById[tx.accountId],
                    toAccount: tx.toAccountId.flatMap { accountById[$0] }
                )
            }
        }

        // Shared record path: insert + the §3.1 budget post-condition. `record`
        // and the internalised `tick` both go through this closure so a
        // scheduler-materialised transaction is indistinguishable from a
        // user-recorded one (same invariant, same reactive mirror).
        let recordTransaction: @Sendable (Transaction) async throws -> Void = { transaction in
            try await transactionStore.add(transaction)
            // INVARIANT(§3.1): 每筆交易記錄/更新後必評估預算警告
            // (architecture.md §3.1 Scenario B). Cannot rely on individual
            // callers to remember.
            await planningClient.evaluateAfterTransaction(transaction)
        }

        // Reminder lifecycle 的單一出口：`createRecurring` / `updateRecurring`
        // / `tick` 共用同一顆，啟用中就排程、暫停就取消（health-audit A5）。
        let syncRecurringReminder = Self.makeSyncRecurringReminder(notificationAdapter)

        // tick 去重查詢：每次 tick 只查一次（plan R4），結果放進 Set 給迴圈內
        // 純記憶體比對，不逐期打 DB。下界用呼叫端傳入的 earliest（fix round 1 /
        // G2）：去重只對補記窗內的期數有意義，不設下界的話這個 Set 會隨 App 壽命
        // 無界成長。**下界必須跟 makeTick 迴圈內同一個 `earliest`、同一個 `>=`
        // 比較對齊**——寫成 `>` 會讓剛好落在邊界的那一期被記錄卻不進集合，下次
        // 當掉重跑就重複，等於用另一種形式重現這個 PR 要修的 bug。
        //
        // predicate 退路（fix round 1 / G2）：`#Predicate` 對 `Date?` 做 `??`
        // 合併後再比較不編譯——巨集展開出的 `NilCoalesce<...>` 表達式無法轉成
        // `StandardPredicateExpression<Bool>`（`Date.distantPast` 與隱式成員
        // `.distantPast` 兩種寫法都試過，錯誤相同）。改成 predicate 只保留
        // `sourceTemplateId != nil`（fetch 沒收斂），下界改在 `compactMap` 的
        // guard 內用記憶體過濾（Set 仍收斂成常數級）。fetch 成本由 G1 的短路
        // 擋掉絕大多數呼叫。
        let alreadyMaterialisedPeriods: @Sendable (Date) async throws -> Set<MaterialisedPeriod> = { earliest in
            // 只取自動補記產生的交易（手動記的兩個欄位都是 nil），避免把整張
            // 交易表讀進來。
            let rows = try await transactionStore.fetchAll(
                where: #Predicate<SDTransaction> { $0.sourceTemplateId != nil }
            )
            return Set(rows.compactMap { tx in
                guard let templateId = tx.sourceTemplateId,
                      let due = tx.sourcePeriodDueDate,
                      due >= earliest else { return nil }
                return MaterialisedPeriod(templateId: templateId, dueDate: due)
            })
        }

        return LedgerClient(
            // MARK: Transactions
            record: { transaction in
                try await recordTransaction(transaction)
            },
            update: { transaction in
                try await transactionStore.update(transaction)
                // INVARIANT(§3.1): same as record — an updated amount can push
                // a budget past its threshold just like a new transaction can.
                await planningClient.evaluateAfterTransaction(transaction)
            },
            delete: { id in
                try await transactionStore.delete(id: id)
                // No budget-warning evaluation on delete — deletions can only
                // lower spending, never cross an upward threshold. Matches the
                // pre-LedgerUseCase behavior in TransactionClient+Live.
            },
            fetch: { id in
                guard let match = try await transactionStore.fetch(id: id) else { return nil }
                let enriched = try await enrich([match])
                return enriched.first
            },
            listRecent: { limit in
                let all = try await transactionStore.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let trimmed = Array(all.prefix(max(0, limit)))
                return try await enrich(trimmed)
            },
            listAll: { filter in
                let all = try await transactionStore.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                return try await enrich(all.filter(filter.matches))
            },
            search: { query in
                let lowered = query.lowercased()
                let all = try await transactionStore.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let matched = all.filter { $0.note?.lowercased().contains(lowered) ?? false }
                return try await enrich(matched)
            },

            // MARK: Accounts
            setupAccounts: { newAccounts in
                let existing = (try? await accountStore.fetchAll(
                    sortBy: [SortDescriptor(\.sortOrder)]
                )) ?? []

                var dictionary = Dictionary(uniqueKeysWithValues: newAccounts.map { ($0.id, $0) })

                existing.forEach { account in
                    if dictionary[account.id] != nil {
                        // Already persisted — skip re-inserting.
                        dictionary.removeValue(forKey: account.id)
                    }
                }
                // 行為微調（plan 步驟 4 偵察遺產）：不再寫入
                // `.hasCompletedOnboarding` 旗標——旗標歸 Platform，
                // OnboardingFeature 已顯式呼叫 `platformClient.markOnboardingComplete()`，
                // 原本在此的跨域寫入屬重複，移除。
                for account in dictionary.values {
                    try await accountStore.add(account)
                }
            },
            createAccount: { account in
                try await accountStore.add(account)
            },
            updateAccount: { account in
                try await accountStore.update(account)
            },
            archiveAccount: { id in
                guard var existing = try await accountStore.fetch(id: id) else {
                    throw CoreError.notFound("SDAccount")
                }
                existing.isArchived = true
                try await accountStore.update(existing)
            },
            unarchiveAccount: { id in
                guard var existing = try await accountStore.fetch(id: id) else {
                    throw CoreError.notFound("Account")
                }
                existing.isArchived = false
                try await accountStore.update(existing)
            },
            deleteAccount: { id in
                let hasLinkedTransactions = try await transactionStore.fetchAll().contains {
                    $0.involves(account: id)
                }
                guard !hasLinkedTransactions else {
                    throw CoreError.operationDenied(
                        "Cannot delete account with associated transactions; archive it instead."
                    )
                }
                try await accountStore.delete(id: id)
            },
            listAccounts: {
                try await accountStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            },
            listActiveAccounts: {
                try await accountStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
                    .filter { !$0.isArchived }
            },
            balance: { id in
                try await transactionStore.fetchAll().balance(of: id)
            },
            balances: {
                let active = try await accountStore.fetchAll(
                    sortBy: [SortDescriptor(\.sortOrder)]
                ).filter { !$0.isArchived }
                let transactions = try await transactionStore.fetchAll()
                var result: [Account.ID: Decimal] = [:]
                for account in active {
                    result[account.id] = transactions.balance(of: account.id)
                }
                return result
            },
            defaultAccountId: {
                let raw = userSettingsAdapter.string(.defaultAccountId)
                return raw.isEmpty ? nil : raw
            },
            setDefaultAccountId: { id in
                userSettingsAdapter.setString(id ?? "", .defaultAccountId)
            },

            // MARK: Catalog (internalised — see +LiveCatalog.swift)
            listCategories: Self.makeListCategories(categoryStore),
            createCategory: Self.makeCreateCategory(categoryStore),
            updateCategory: Self.makeUpdateCategory(categoryStore),
            deleteCategory: Self.makeDeleteCategory(categoryStore),
            listTags: Self.makeListTags(tagStore),
            createTag: Self.makeCreateTag(tagStore),
            updateTag: Self.makeUpdateTag(tagStore),
            deleteTag: Self.makeDeleteTag(tagStore),

            // MARK: Recurring (internalised — see +LiveRecurring.swift)
            listRecurring: Self.makeListRecurring(recurringStore),
            createRecurring: Self.makeCreateRecurring(recurringStore, syncRecurringReminder),
            updateRecurring: Self.makeUpdateRecurring(recurringStore, syncRecurringReminder),
            deleteRecurring: Self.makeDeleteRecurring(recurringStore, notificationAdapter),
            tick: Self.makeTick(recurringStore, recordTransaction, syncRecurringReminder, alreadyMaterialisedPeriods),

            // MARK: Export (internalised — see +LiveExport.swift)
            exportCSV: Self.makeExportCSV(transactionStore, categoryStore, accountStore)
        )
    }
}
