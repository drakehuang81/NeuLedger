# Spec: NeuLedger Domain Unit Tests

## Requirements

---

### Requirement: Domain Entity Protocol Conformance Tests
All Domain Entities SHALL have unit tests verifying their protocol conformances and initialization behavior.

#### Scenario: Entity Initialization with Defaults
- **WHEN** an Entity (`Transaction`, `Account`, `Category`, `Tag`, `Budget`) is initialized with only required parameters
- **THEN** all optional and default-valued properties SHALL have their expected default values
- **AND** `id` SHALL be a valid UUID (auto-generated)
- **AND** `createdAt` / `updatedAt` (where applicable) SHALL be set to approximately the current date

#### Scenario: Entity Initialization with Custom Values
- **WHEN** an Entity is initialized with all parameters explicitly provided
- **THEN** every property SHALL exactly match the provided values

#### Scenario: Entity Equatable Conformance
- **WHEN** two Entity instances have identical property values
- **THEN** they SHALL be considered equal (`==` returns `true`)
- **AND** **WHEN** any single property differs
- **THEN** they SHALL NOT be equal (`==` returns `false`)

#### Scenario: Entity Hashable Conformance
- **WHEN** two Entity instances are equal
- **THEN** they SHALL produce the same hash value
- **AND** **WHEN** Entity instances are inserted into a `Set`
- **THEN** duplicates SHALL be correctly deduplicated

#### Scenario: Entity Codable Round-Trip
- **WHEN** an Entity is encoded to JSON via `JSONEncoder`
- **THEN** decoding the same JSON via `JSONDecoder` SHALL produce an equal Entity
- **AND** the round-trip SHALL succeed for all Entity types

---

### Requirement: Domain Enum Tests
All Domain Enums SHALL have unit tests verifying their cases, raw values, and computed properties.

#### Scenario: Enum Case Completeness
- **WHEN** iterating over all cases of `TransactionType`, `AccountType`, `Currency`, or `BudgetPeriod`
- **THEN** the `allCases` count SHALL match the expected number of cases
- **AND** each case SHALL be present

#### Scenario: Enum Codable Round-Trip
- **WHEN** an Enum case is encoded to JSON and decoded back
- **THEN** the decoded value SHALL equal the original

#### Scenario: Currency Computed Properties
- **WHEN** accessing `Currency.TWD`
- **THEN** `symbol` SHALL return `"NT$"`
- **AND** `code` SHALL return `"TWD"`
- **AND** `decimalPlaces` SHALL return `0`

---

### Requirement: TransactionFilter Tests
The `TransactionFilter` struct SHALL have unit tests verifying its initialization and equality behavior.

#### Scenario: Empty Filter
- **WHEN** a `TransactionFilter` is initialized with no parameters
- **THEN** all filter properties SHALL be `nil` (representing "no filter")

#### Scenario: Filter Equality
- **WHEN** two `TransactionFilter` instances have the same filter criteria
- **THEN** they SHALL be equal
- **AND** **WHEN** any criterion differs
- **THEN** they SHALL NOT be equal

---

### Requirement: AI Model Type Tests
The AI-related Domain types (`ExtractedTransaction`, `CategorySuggestions`, `SpendingSummary`) SHALL have unit tests.

#### Scenario: ExtractedTransaction Initialization
- **WHEN** an `ExtractedTransaction` is initialized with all-nil properties
- **THEN** all properties SHALL be `nil`
- **AND** **WHEN** initialized with values
- **THEN** properties SHALL match provided values

#### Scenario: CategorySuggestions Initialization
- **WHEN** a `CategorySuggestions` is initialized
- **THEN** `suggestions` SHALL be the provided array
- **AND** `confidence` SHALL be the provided string

#### Scenario: SpendingSummary Initialization
- **WHEN** a `SpendingSummary` is initialized with spending data
- **THEN** all properties SHALL match provided values

---

### Requirement: Client TestDependencyKey Tests
All Domain Clients SHALL have unit tests verifying their `TestDependencyKey` and `DependencyValues` registration.

#### Scenario: TestDependencyKey Provides Unimplemented Default
- **WHEN** accessing a Client via `@Dependency` in a test context
- **THEN** the `testValue` SHALL be available (non-crashing at access time)

#### Scenario: DependencyValues Registration
- **WHEN** accessing a Client via `DependencyValues` key path
- **THEN** the key path (e.g., `\.transactionClient`, `\.accountClient`) SHALL resolve correctly
