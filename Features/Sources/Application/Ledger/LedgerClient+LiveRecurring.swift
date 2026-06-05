import Foundation
import SwiftData
import Dependencies
import Domain

/// Recurring section of `LedgerClient.liveValue` (step-5a3 internalisation).
///
/// Recurring templates are read/written through `SwiftDataStore` directly,
/// replacing the former `\.recurringTransactionClient` (CRUD/list) and
/// `\.recurringUseCase` (`tick`) delegation.
///
/// ## Notification scheduling 上收 (new behaviour, 5a3)
///
/// Previously each Feature reducer manually called
/// `notificationAdapter.scheduleRecurringReminder` / `cancelRecurringReminder`
/// alongside its CRUD call (`RecurringTransactionFormFeature`,
/// `RecurringTransactionManagementFeature`, `MainTabFeature`,
/// `AddTransactionFeature`). Those calls are now owned by the Client so the
/// reminder lifecycle is a guaranteed post-condition of the persistence
/// mutation, not a thing each call-site must remember:
///
/// - `createRecurring` / `updateRecurring` → persist, then schedule a due-date
///   reminder keyed on the template id (same id ⇒ rescheduling replaces the
///   previous request). Title/body use the same localized keys the Feature
///   call-sites used (`recurring_transaction_notification_title` / `_body`),
///   and `template.nextDueDate` as the fire date — matching the Form feature's
///   save path verbatim.
/// - `deleteRecurring` → cancel the reminder, then delete the template.
///
/// ## tick() SAGA internalisation
///
/// `tick` lifts `RecurringUseCase+Live.tick` but routes materialised
/// transactions through this Client's own shared `recordTransaction` closure
/// (the §3.1 budget invariant + reactive Watch/Widget mirror) instead of the
/// former `\.ledger.record` hop. `fetchDue` is inlined as a `SwiftDataStore`
/// fetch + the `nextDueDate <= today && isActive` filter (verbatim from
/// `RecurringTransactionClient+Live.fetchDue`); each due template is then
/// advanced via `template.nextDate(after:)`.
extension LedgerClient {
    static func makeListRecurring(
        _ store: RecurringTransactionStore
    ) -> @Sendable () async throws -> [RecurringTransaction] {
        {
            try await store.fetchAll()
        }
    }

    static func makeCreateRecurring(
        _ store: RecurringTransactionStore,
        _ notificationAdapter: NotificationAdapter
    ) -> @Sendable (RecurringTransaction) async throws -> Void {
        { template in
            try await store.add(template)
            try await notificationAdapter.scheduleRecurringReminder(
                template.id,
                template.nextDueDate,
                String(localized: "recurring_transaction_notification_title"),
                String(localized: "recurring_transaction_notification_body")
            )
        }
    }

    static func makeUpdateRecurring(
        _ store: RecurringTransactionStore,
        _ notificationAdapter: NotificationAdapter
    ) -> @Sendable (RecurringTransaction) async throws -> Void {
        { template in
            try await store.update(template)
            try await notificationAdapter.scheduleRecurringReminder(
                template.id,
                template.nextDueDate,
                String(localized: "recurring_transaction_notification_title"),
                String(localized: "recurring_transaction_notification_body")
            )
        }
    }

    static func makeDeleteRecurring(
        _ store: RecurringTransactionStore,
        _ notificationAdapter: NotificationAdapter
    ) -> @Sendable (RecurringTransaction.ID) async throws -> Void {
        { id in
            await notificationAdapter.cancelRecurringReminder(id)
            try await store.delete(id: id)
        }
    }

    static func makeTick(
        _ store: RecurringTransactionStore,
        _ recordTransaction: @escaping @Sendable (Transaction) async throws -> Void
    ) -> @Sendable () async throws -> Void {
        // Resolve the clock at assembly time, matching `RecurringUseCase+Live`
        // (which read `@Dependency(\.date.now)` outside its tick closure).
        @Dependency(\.date.now) var now

        return {
            let today = now

            // fetchDue inlined (verbatim from RecurringTransactionClient+Live):
            // active templates whose nextDueDate has arrived.
            let due = try await store.fetchAll().filter {
                $0.nextDueDate <= today && $0.isActive
            }

            for template in due {
                let tx = Transaction(
                    id: UUID(),
                    amount: template.amount,
                    date: template.nextDueDate,
                    note: template.note,
                    categoryId: template.categoryId,
                    accountId: template.accountId,
                    toAccountId: template.toAccountId,
                    type: template.type,
                    tags: template.tags,
                    aiSuggested: false,
                    createdAt: today,
                    updatedAt: today
                )

                // INVARIANT (architecture.md §3.1 Scenario A): recurring tick
                // materialises due templates into real transactions through this
                // Client's own record path, so the budget warning invariant
                // (§3.1 Scenario B) is preserved for scheduler-emitted
                // transactions too — formerly a UseCase→UseCase SAGA hop, now
                // internalised to the shared `recordTransaction` closure.
                try await recordTransaction(tx)

                var advanced = template
                advanced.nextDueDate = template.nextDate(after: template.nextDueDate)
                try await store.update(advanced)
            }
        }
    }
}
