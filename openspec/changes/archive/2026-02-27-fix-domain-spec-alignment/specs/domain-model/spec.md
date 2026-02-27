## MODIFIED Requirements

### Requirement: Transaction Entity
The primary financial record.

#### Scenario: Transaction Fields
- **WHEN** a financial record is stored
- **THEN** it must have:
    - `id`: UUID — unique identifier.
    - `amount`: Decimal — always positive. Direction determined by `type`.
    - `date`: Date — when the transaction occurred (user-editable).
    - `note`: String? — optional free text description.
    - `categoryId`: Category.ID? — reference to a Category. Nil for `.transfer` type.
    - `accountId`: Account.ID — reference to an Account.
    - `type`: TransactionType — expense, income, or transfer.
    - `tags`: [Tag] — zero or more user-defined tags.
    - `aiSuggested`: Bool — whether category was auto-suggested by AI.
    - `createdAt`: Date — system timestamp of record creation.
    - `updatedAt`: Date — system timestamp of last modification.
- **AND** no `currency` field — all transactions are in TWD (single currency).
- **AND** `Transaction` SHALL conform to `Identifiable`, `Equatable`, `Hashable`, `Codable`, and `Sendable`.

#### Scenario: Transfer Transaction
- **WHEN** `type == .transfer`
- **THEN** the transaction must also have:
    - `toAccountId`: Account.ID — the destination account.
- **AND** the source account balance decreases and destination increases by `amount`.

---

### Requirement: Category Entity
For organizing and classifying transactions.

#### Scenario: Category Fields
- **WHEN** organizing transactions
- **THEN** Categories must have:
    - `id`: UUID — unique identifier.
    - `name`: String — display name (e.g., "Food", "Transport").
    - `icon`: String — SF Symbol name (e.g., "fork.knife", "car.fill").
    - `color`: String — hex color code (e.g., "#FF6B6B").
    - `type`: TransactionType — `.expense` or `.income` (categories are type-specific).
    - `sortOrder`: Int — user-defined display order.
    - `isDefault`: Bool — whether this is a system default category (non-deletable).
- **AND** `Category` SHALL conform to `Identifiable`, `Equatable`, `Hashable`, `Codable`, and `Sendable`.

#### Scenario: Default Categories
- **WHEN** the app is first launched
- **THEN** a set of default categories should be seeded:
    - **Expense**: Food, Transport, Entertainment, Shopping, Housing, Utilities, Health, Education, Other.
    - **Income**: Salary, Freelance, Investment, Gift, Other.

---

### Requirement: Account Entity
For managing different sources/pools of funds.

#### Scenario: Account Fields
- **WHEN** managing funds
- **THEN** Accounts must have:
    - `id`: UUID — unique identifier.
    - `name`: String — account name (e.g., "現金", "中信銀行").
    - `type`: AccountType — cash, bank, credit card, e-wallet.
    - `icon`: String — SF Symbol name.
    - `color`: String — hex color code.
    - `sortOrder`: Int — user-defined display order.
    - `isArchived`: Bool — soft-delete; hidden from active list but preserved for history.
    - `createdAt`: Date — system timestamp.
- **AND** no `currency` field — all accounts use TWD.
- **AND** `Account` SHALL conform to `Identifiable`, `Equatable`, `Hashable`, `Codable`, and `Sendable`.

#### Scenario: Account Balance Calculation
- **WHEN** displaying an account balance
- **THEN** the balance must be **computed on-the-fly** by summing related transactions.
- **AND** it should **not** be stored as a field (to avoid sync issues on transaction edits/deletes).
- **AND** for performance, a precomputed cache may be used but must be invalidated when transactions change.

---

### Requirement: Tag Entity
Flexible, user-defined labels for cross-cutting categorization.

#### Scenario: Tag Fields
- **WHEN** tagging a transaction
- **THEN** Tags must have:
    - `id`: UUID — unique identifier.
    - `name`: String — display name (e.g., "Trip to Japan", "Tax Deductible").
    - `color`: String? — optional hex color code.
- **AND** `Tag` SHALL conform to `Identifiable`, `Equatable`, `Hashable`, `Codable`, and `Sendable`.

#### Scenario: Tag-Transaction Relationship
- **WHEN** a tag is applied
- **THEN** a Transaction may have 0 or more Tags (many-to-many relationship).
- **AND** a Tag may be applied to 0 or more Transactions.

---

### Requirement: Budget Entity
For setting spending limits and tracking progress.

#### Scenario: Budget Fields
- **WHEN** setting a spending target
- **THEN** Budgets must have:
    - `id`: UUID — unique identifier.
    - `name`: String — budget name (e.g., "每月飲食預算").
    - `amount`: Decimal — spending limit (TWD).
    - `categoryId`: Category.ID? — optional; if nil, applies to total spending.
    - `period`: BudgetPeriod — `.weekly`, `.monthly`, `.yearly`.
    - `startDate`: Date — beginning of the budget period.
    - `isActive`: Bool — whether this budget is currently being tracked.
- **AND** no `currency` field — all budgets use TWD.
- **AND** `Budget` SHALL conform to `Identifiable`, `Equatable`, `Hashable`, `Codable`, and `Sendable`.

#### Scenario: Budget Progress
- **WHEN** viewing a budget
- **THEN** the system should compute:
    - `spent`: Decimal — sum of matching expense transactions in the period.
    - `remaining`: Decimal — `amount - spent`.
    - `percentage`: Double — `spent / amount`.
- **AND** these values are computed, not stored.
