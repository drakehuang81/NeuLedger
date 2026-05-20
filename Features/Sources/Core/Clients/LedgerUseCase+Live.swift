import Foundation
import Dependencies
import Domain

extension LedgerUseCase: DependencyKey {
    public static var liveValue: LedgerUseCase {
        @Dependency(\.transactionClient) var transactionClient
        @Dependency(\.budgetUseCase) var budgetUseCase

        return LedgerUseCase(
            record: { transaction in
                try await transactionClient.add(transaction)
                // INVARIANT (architecture.md §3.1 Scenario B): every recorded
                // transaction must be evaluated for budget warnings. Cannot
                // rely on individual callers to remember.
                await budgetUseCase.evaluateAfterTransaction(transaction)
            },
            update: { transaction in
                try await transactionClient.update(transaction)
                // INVARIANT: same as record — an updated amount can push a
                // budget past its threshold just like a new transaction can.
                await budgetUseCase.evaluateAfterTransaction(transaction)
            },
            delete: { id in
                try await transactionClient.delete(id)
                // No budget-warning evaluation on delete — deletions can
                // only lower spending, never cross an upward threshold.
                // Matches the pre-LedgerUseCase behavior in
                // TransactionClient+Live, which also skipped this.
            }
        )
    }
}
