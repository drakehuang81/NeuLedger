# Spec: Domain Data Mapping

## Purpose
To define the requirements for mapping Domain entities to SwiftData persistence models and vice versa.

## Requirements

### Requirement: Domain-to-SwiftData Mapping
Each `SD*` model type SHALL provide a static factory method to create a SwiftData object from its corresponding Domain entity.

#### Scenario: Creating SDTransaction from Transaction
- **WHEN** a `Transaction` domain entity is to be persisted
- **THEN** `SDTransaction.from(_:context:)` SHALL accept a `Transaction` and a `ModelContext`.
- **AND** it SHALL map all scalar properties (`id`, `amount`, `date`, `note`, `categoryId`, `accountId`, `toAccountId`, `aiSuggested`, `createdAt`, `updatedAt`).
- **AND** it SHALL convert `type: TransactionType` to its `.rawValue` string.
- **AND** it SHALL resolve or create `SDTag` objects for each `Tag` in the transaction's `tags` array.

#### Scenario: Creating SDAccount from Account
- **WHEN** an `Account` domain entity is to be persisted
- **THEN** `SDAccount.from(_:context:)` SHALL map all properties and convert `type: AccountType` to its `.rawValue` string.

#### Scenario: Creating SDCategory from Category
- **WHEN** a `Category` domain entity is to be persisted
- **THEN** `SDCategory.from(_:context:)` SHALL map all properties and convert `type: TransactionType` to its `.rawValue` string.

#### Scenario: Creating SDBudget from Budget
- **WHEN** a `Budget` domain entity is to be persisted
- **THEN** `SDBudget.from(_:context:)` SHALL map all properties and convert `period: BudgetPeriod` to its `.rawValue` string.

#### Scenario: Creating SDTag from Tag
- **WHEN** a `Tag` domain entity is to be persisted
- **THEN** `SDTag.from(_:context:)` SHALL map all properties (`id`, `name`, `color`).

---

### Requirement: SwiftData-to-Domain Mapping
Each `SD*` model type SHALL provide an instance method to convert itself to the corresponding Domain entity.

#### Scenario: Converting SDTransaction to Transaction
- **WHEN** an `SDTransaction` is fetched from SwiftData
- **THEN** `sdTransaction.toDomain()` SHALL return a `Transaction` value type.
- **AND** it SHALL convert the `type` string back to a `TransactionType` enum value.
- **AND** it SHALL map associated `SDTag` objects to `[Tag]` domain values.

#### Scenario: Converting SDAccount to Account
- **WHEN** an `SDAccount` is fetched from SwiftData
- **THEN** `sdAccount.toDomain()` SHALL return an `Account` value type with `type` converted from string to `AccountType`.

#### Scenario: Converting SDCategory to Category
- **WHEN** an `SDCategory` is fetched from SwiftData
- **THEN** `sdCategory.toDomain()` SHALL return a `Category` value type with `type` converted from string to `TransactionType`.

#### Scenario: Converting SDBudget to Budget
- **WHEN** an `SDBudget` is fetched from SwiftData
- **THEN** `sdBudget.toDomain()` SHALL return a `Budget` value type with `period` converted from string to `BudgetPeriod`.

#### Scenario: Converting SDTag to Tag
- **WHEN** an `SDTag` is fetched from SwiftData
- **THEN** `sdTag.toDomain()` SHALL return a `Tag` value type.

---

### Requirement: Mapping Boundary Enforcement
Mapping logic SHALL be entirely contained within the `Core` module.

#### Scenario: No SwiftData Leakage
- **WHEN** `Features` or `Domain` modules reference transaction data
- **THEN** they SHALL only interact with Domain entity types (`Transaction`, `Account`, etc.).
- **AND** they SHALL NOT import `SwiftData` or reference any `SD*` type.

#### Scenario: Tag Resolution During Insert
- **WHEN** a `Transaction` with tags is being mapped to `SDTransaction`
- **THEN** the mapper SHALL query the existing `SDTag` table by `id` to reuse existing objects.
- **AND** if a matching `SDTag` does not exist, it SHALL create a new one from the Domain `Tag`.
