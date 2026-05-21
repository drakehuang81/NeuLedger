import Foundation
import Dependencies
import Domain

extension RecurringUseCase: DependencyKey {
    public static var liveValue: RecurringUseCase {
        @Dependency(\.recurringTransactionClient) var recurringTransactionClient
        @Dependency(\.ledger) var ledger
        @Dependency(\.date.now) var now

        return RecurringUseCase(
            listActive: {
                try await recurringTransactionClient.fetchAll().filter(\.isActive)
            },
            create: { try await recurringTransactionClient.add($0) },
            update: { try await recurringTransactionClient.update($0) },
            delete: { try await recurringTransactionClient.delete($0) },
            tick: {
                let today = now
                let due = try await recurringTransactionClient.fetchDue(today)

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

                    // INVARIANT (architecture.md §3.1 Scenario A): recurring
                    // tick is a fixed UseCase→UseCase whitelist entry —
                    // RecurringUseCase materialises due templates into real
                    // transactions via LedgerUseCase.record so the budget
                    // warning invariant (§3.1 Scenario B) is preserved for
                    // scheduler-emitted transactions too.
                    try await ledger.record(tx)

                    var advanced = template
                    advanced.nextDueDate = template.nextDate(after: template.nextDueDate)
                    try await recurringTransactionClient.update(advanced)
                }
            }
        )
    }
}
