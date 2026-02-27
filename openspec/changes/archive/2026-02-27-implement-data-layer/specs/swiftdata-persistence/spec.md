## ADDED Requirements

### Requirement: SwiftData Model Schema
The `Core` module SHALL define `@Model` classes that mirror each Domain entity, prefixed with `SD`.

#### Scenario: SDTransaction Model
- **WHEN** a `Transaction` entity needs to be persisted
- **THEN** `SDTransaction` SHALL include properties for `id` (UUID), `amount` (Decimal), `date` (Date), `note` (String?), `categoryId` (UUID?), `accountId` (UUID), `toAccountId` (UUID?), `type` (String), `aiSuggested` (Bool), `createdAt` (Date), and `updatedAt` (Date).
- **AND** `SDTransaction` SHALL have a `@Relationship` to `[SDTag]` representing the many-to-many association.

#### Scenario: SDAccount Model
- **WHEN** an `Account` entity needs to be persisted
- **THEN** `SDAccount` SHALL include properties for `id` (UUID), `name` (String), `type` (String), `icon` (String), `color` (String), `sortOrder` (Int), `isArchived` (Bool), and `createdAt` (Date).

#### Scenario: SDCategory Model
- **WHEN** a `Category` entity needs to be persisted
- **THEN** `SDCategory` SHALL include properties for `id` (UUID), `name` (String), `icon` (String), `color` (String), `type` (String), `sortOrder` (Int), and `isDefault` (Bool).

#### Scenario: SDBudget Model
- **WHEN** a `Budget` entity needs to be persisted
- **THEN** `SDBudget` SHALL include properties for `id` (UUID), `name` (String), `amount` (Decimal), `categoryId` (UUID?), `period` (String), `startDate` (Date), and `isActive` (Bool).

#### Scenario: SDTag Model
- **WHEN** a `Tag` entity needs to be persisted
- **THEN** `SDTag` SHALL include properties for `id` (UUID), `name` (String), and `color` (String?).
- **AND** `SDTag` SHALL have a `@Relationship(inverse:)` back to `[SDTransaction]` for the many-to-many association.

---

### Requirement: Enum Storage as Raw Strings
Domain enums SHALL be stored as their `rawValue` strings in SwiftData models.

#### Scenario: TransactionType Persistence
- **WHEN** a `TransactionType` value (e.g., `.expense`) is stored in `SDTransaction`
- **THEN** the `type` property SHALL be stored as the raw string `"expense"`.
- **AND** mappers SHALL convert between `String` and `TransactionType` using `init(rawValue:)`.

#### Scenario: AccountType Persistence
- **WHEN** an `AccountType` value is stored in `SDAccount`
- **THEN** the `type` property SHALL be stored as the raw string representation.

#### Scenario: BudgetPeriod Persistence
- **WHEN** a `BudgetPeriod` value is stored in `SDBudget`
- **THEN** the `period` property SHALL be stored as the raw string representation.

---

### Requirement: ModelContainer Configuration
A centralized `ModelContainer` SHALL be configured to register all `@Model` types.

#### Scenario: Live ModelContainer
- **WHEN** the app launches in production
- **THEN** the `ModelContainer` SHALL be configured with all five `@Model` types (`SDTransaction`, `SDAccount`, `SDCategory`, `SDBudget`, `SDTag`).
- **AND** the container SHALL use the default on-disk persistent store.

#### Scenario: In-Memory ModelContainer for Testing
- **WHEN** tests or SwiftUI previews require a `ModelContainer`
- **THEN** the container SHALL be configured with `ModelConfiguration(isStoredInMemoryOnly: true)`.
- **AND** it SHALL register the same five `@Model` types.

---

### Requirement: DatabaseClient Dependency
The `ModelContainer` SHALL be exposed as a TCA dependency named `DatabaseClient`.

#### Scenario: Resolving ModelContainer in Live Clients
- **WHEN** a live client implementation needs to access SwiftData
- **THEN** it SHALL resolve `@Dependency(\.databaseClient)` to obtain the `ModelContainer`.
- **AND** it SHALL create a `ModelContext` from the container for each operation or use `@ModelActor`.

#### Scenario: DatabaseClient Test Value
- **WHEN** unit tests are executing
- **THEN** `DatabaseClient.testValue` SHALL provide an in-memory `ModelContainer`.

---

### Requirement: Thread-Safe Database Access
All SwiftData operations SHALL be performed in a thread-safe manner using `@ModelActor`.

#### Scenario: Background Database Operations
- **WHEN** a client performs a database read or write
- **THEN** the operation SHALL execute on a `@ModelActor`-isolated context.
- **AND** the actor SHALL use its own `ModelContext` derived from the shared `ModelContainer`.
