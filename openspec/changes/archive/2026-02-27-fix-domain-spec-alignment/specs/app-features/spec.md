## ADDED Requirements

### Requirement: TagClient Interface
The system SHALL provide a `TagClient` dependency for managing user-defined tags.

#### Scenario: TagClient Definition
- **WHEN** defining the tag service interface in `Domain/Clients/TagClient.swift`
- **THEN** it SHALL provide the following methods:

```swift
@DependencyClient
public struct TagClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Tag]
    public var add: @Sendable (Tag) async throws -> Void
    public var update: @Sendable (Tag) async throws -> Void
    public var delete: @Sendable (Tag.ID) async throws -> Void
}
```

- **AND** it SHALL be registered via `TestDependencyKey` and `DependencyValues` at key path `\.tagClient`.

---

### Requirement: BudgetClient Interface
The system SHALL provide a `BudgetClient` dependency for managing budgets.

#### Scenario: BudgetClient Definition
- **WHEN** defining the budget service interface in `Domain/Clients/BudgetClient.swift`
- **THEN** it SHALL provide the following methods:

```swift
@DependencyClient
public struct BudgetClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Budget]
    public var fetchActive: @Sendable () async throws -> [Budget]
    public var add: @Sendable (Budget) async throws -> Void
    public var update: @Sendable (Budget) async throws -> Void
    public var delete: @Sendable (Budget.ID) async throws -> Void
}
```

- **AND** it SHALL be registered via `TestDependencyKey` and `DependencyValues` at key path `\.budgetClient`.

---

### Requirement: TransactionFilter Type
The system SHALL provide a `TransactionFilter` struct for composable transaction filtering.

#### Scenario: TransactionFilter Definition
- **WHEN** filtering transactions with multiple criteria
- **THEN** a `TransactionFilter` struct SHALL be available with:
    - `categoryIds`: Set<Category.ID>? — filter by one or more categories (nil = all)
    - `accountIds`: Set<Account.ID>? — filter by one or more accounts (nil = all)
    - `tagIds`: Set<Tag.ID>? — filter by one or more tags (nil = all)
    - `types`: Set<TransactionType>? — filter by transaction type (nil = all)
    - `dateRange`: ClosedRange<Date>? — filter by date range (nil = all dates)
    - `searchText`: String? — filter by note text search (nil = no text filter)
- **AND** `TransactionFilter` SHALL conform to `Equatable` and `Sendable`.
- **AND** all `nil` values SHALL mean "no filter applied" for that criterion.

## MODIFIED Requirements

### Requirement: TransactionClient Interface (from architecture-blueprint)
The `TransactionClient` SHALL be expanded to include search and filter capabilities.

#### Scenario: Registering a Live Client
- **WHEN** a Client is defined in `Domain/Clients/`
- **THEN** its live implementation must be in `Data/Clients/` and registered:

```swift
@DependencyClient
public struct TransactionClient: Sendable {
    public var fetchRecent: @Sendable () async throws -> [Transaction]
    public var fetchAll: @Sendable () async throws -> [Transaction]
    public var fetch: @Sendable (TransactionFilter) async throws -> [Transaction]
    public var search: @Sendable (String) async throws -> [Transaction]
    public var add: @Sendable (Transaction) async throws -> Void
    public var update: @Sendable (Transaction) async throws -> Void
    public var delete: @Sendable (Transaction.ID) async throws -> Void
}
```

- **AND** `fetchByAccount` and `fetchByCategory` are **REMOVED** — replaced by `fetch(filter:)`.
- **AND** `search` provides text search against transaction `note` field.
- **AND** `fetch(filter:)` supports composable filtering by category, account, tag, type, date range, and text.

---

### Requirement: AccountClient Balance Computation
The `AccountClient` SHALL provide a method to compute account balance on-the-fly.

#### Scenario: AccountClient with Balance
- **WHEN** the Dashboard needs to display an account's balance
- **THEN** `AccountClient` SHALL provide:

```swift
@DependencyClient
public struct AccountClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Account]
    public var fetchActive: @Sendable () async throws -> [Account]
    public var add: @Sendable (Account) async throws -> Void
    public var update: @Sendable (Account) async throws -> Void
    public var archive: @Sendable (Account.ID) async throws -> Void
    public var delete: @Sendable (Account.ID) async throws -> Void
    public var computeBalance: @Sendable (Account.ID) async throws -> Decimal
}
```

- **AND** `computeBalance` SHALL sum all related transactions to compute the balance on-the-fly.
