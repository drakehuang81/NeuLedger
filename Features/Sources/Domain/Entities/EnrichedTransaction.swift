import Foundation

/// A `Transaction` with its related entities resolved.
///
/// Returned by `LedgerUseCase.listRecent / listAll / search / fetch`
/// so presentation code does not have to re-join transactions against
/// categories and accounts on every render. Pure value type — no
/// async, no computed lazies, mirror semantics of `Transaction`.
public struct EnrichedTransaction: Equatable, Sendable, Identifiable {
    public let transaction: Transaction
    public let category: Category?
    public let account: Account?
    public let toAccount: Account?

    public var id: Transaction.ID { transaction.id }

    public init(
        transaction: Transaction,
        category: Category? = nil,
        account: Account? = nil,
        toAccount: Account? = nil
    ) {
        self.transaction = transaction
        self.category = category
        self.account = account
        self.toAccount = toAccount
    }
}
