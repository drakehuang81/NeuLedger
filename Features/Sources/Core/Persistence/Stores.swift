import Domain

/// Per-aggregate store aliases.
///
/// The Domain ↔ SD pairing for each aggregate is declared exactly once,
/// here. Call sites (Client Lives, the watch pipeline, tests) use these
/// aliases and never spell out SwiftData vocabulary — if the persistence
/// engine ever changes, call sites stay untouched.
///
/// `SwiftDataStore` keeps its honest name: its second type parameter is
/// inherently a SwiftData `@Model`, and pretending otherwise would be
/// cosmetic decoupling. The aliases are the boundary, not a disguise.
typealias TransactionStore = SwiftDataStore<Transaction, SDTransaction>
typealias AccountStore = SwiftDataStore<Account, SDAccount>
typealias CategoryStore = SwiftDataStore<Domain.Category, SDCategory>
typealias TagStore = SwiftDataStore<Tag, SDTag>
typealias BudgetStore = SwiftDataStore<Budget, SDBudget>
typealias CarrierStore = SwiftDataStore<Carrier, SDCarrier>
typealias RecurringTransactionStore = SwiftDataStore<RecurringTransaction, SDRecurringTransaction>
