# Spec: Default Data Seeding

## Purpose
To define the requirements for detecting a first launch and seeding the local database with default categories and accounts.

## Requirements

### Requirement: First-Launch Detection
The system SHALL detect whether the database has been initialized with default data.

#### Scenario: Empty Database Detection
- **WHEN** the app launches and the `SDCategory` table contains zero records
- **THEN** the system SHALL treat this as a first launch requiring data seeding.

#### Scenario: Existing Data Preserved
- **WHEN** the app launches and the `SDCategory` table contains one or more records
- **THEN** the system SHALL NOT perform any seeding operations.

---

### Requirement: Default Category Seeding
The system SHALL insert a predefined set of default categories on first launch.

#### Scenario: Default Expense Categories
- **WHEN** first-launch seeding is triggered
- **THEN** the system SHALL insert the following 9 expense categories with `isDefault = true`:
  - Food (icon: `fork.knife`, color: `#FF6B6B`)
  - Transport (icon: `car.fill`, color: `#4ECDC4`)
  - Entertainment (icon: `gamecontroller.fill`, color: `#45B7D1`)
  - Shopping (icon: `bag.fill`, color: `#96CEB4`)
  - Housing (icon: `house.fill`, color: `#FFEAA7`)
  - Utilities (icon: `bolt.fill`, color: `#DDA0DD`)
  - Health (icon: `heart.fill`, color: `#FF6B9D`)
  - Education (icon: `book.fill`, color: `#C9B1FF`)
  - Other Expense (icon: `ellipsis.circle.fill`, color: `#95A5A6`)
- **AND** each category SHALL have `type = "expense"` and `sortOrder` assigned sequentially starting from 0.

#### Scenario: Default Income Categories
- **WHEN** first-launch seeding is triggered
- **THEN** the system SHALL insert the following 5 income categories with `isDefault = true`:
  - Salary (icon: `banknote.fill`, color: `#2ECC71`)
  - Freelance (icon: `laptopcomputer`, color: `#3498DB`)
  - Investment (icon: `chart.line.uptrend.xyaxis`, color: `#F39C12`)
  - Gift (icon: `gift.fill`, color: `#E74C3C`)
  - Other Income (icon: `ellipsis.circle.fill`, color: `#1ABC9C`)
- **AND** each category SHALL have `type = "income"` and `sortOrder` assigned sequentially starting from 0.

---

### Requirement: Default Account Seeding
The system SHALL insert a default account on first launch.

#### Scenario: Default Cash Account
- **WHEN** first-launch seeding is triggered
- **THEN** the system SHALL insert one account with:
  - name: `"Cash"`
  - type: `"cash"`
  - icon: `"banknote"`
  - color: `"#2ECC71"`
  - sortOrder: `0`
  - isArchived: `false`

---

### Requirement: Seeding Atomicity
The seeding operation SHALL be performed atomically.

#### Scenario: All-or-Nothing Seeding
- **WHEN** the seeding process is executing
- **THEN** all default categories and the default account SHALL be inserted within a single `ModelContext.save()` call.
- **AND** if the save fails, no partial data SHALL be persisted.

---

### Requirement: Seeding Timing
The seeding operation SHALL execute before any client queries can return data.

#### Scenario: Seeding Before First Query
- **WHEN** the app starts and seeding is required
- **THEN** the `DatabaseClient` initialization SHALL complete seeding before any live client `.liveValue` is invoked.
- **AND** the seeding SHALL be performed synchronously during container setup or as the first async operation on the database actor.
