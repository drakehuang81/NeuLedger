import Foundation
import Dependencies
import Domain

/// Minimal protocol the Watch-flavored `TransactionClient` needs from
/// `WatchSessionGateway`. Lets the client be unit-tested with a fake
/// without pulling the full gateway into tests.
public protocol WatchDraftSender: Sendable {
    func send(draft: TransactionDraft)
}

extension WatchSessionGateway: WatchDraftSender {}

extension TransactionClient {

    /// Watch-side live value. Only `add` is implemented — Watch UI has
    /// no entry points for fetch/update/delete/analytics, so those keys
    /// remain at their `@DependencyClient` unimplemented defaults and
    /// will trap if called.
    public static func watchLive(gateway: WatchDraftSender) -> TransactionClient {
        var client = TransactionClient()
        client.add = { @Sendable transaction in
            guard let categoryId = transaction.categoryId else { return }
            let draft = TransactionDraft(
                id: transaction.id,
                categoryId: categoryId,
                accountId: transaction.accountId,
                amount: transaction.amount,
                date: transaction.date
            )
            gateway.send(draft: draft)
        }
        return client
    }
}
