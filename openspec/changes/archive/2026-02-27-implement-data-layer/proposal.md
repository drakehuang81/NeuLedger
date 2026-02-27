## Why

The Domain module currently defines all entity models (Transaction, Account, Category, Budget, Tag) and client interfaces (TransactionClient, AccountClient, CategoryClient, BudgetClient, TagClient, AIServiceClient), but no concrete implementations exist. Without a Core layer providing live implementations backed by SwiftData persistence, the app cannot store, retrieve, or manipulate any real data. This is the foundational infrastructure that every feature — from Dashboard to Transaction List — depends on before any UI work can proceed meaningfully.

## What Changes

- **New `Features/Core` Module**: Modify the local Swift Package structure so `Core` depends on both `Domain` and `SwiftData`, housing all persistence and live client logic.
- **SwiftData `@Model` classes**: Introduce `@Model` schema classes (`SDTransaction`, `SDAccount`, `SDCategory`, `SDBudget`, `SDTag`) mirroring the Domain entities, with proper SwiftData relationships (e.g., many-to-many for Transaction ↔ Tag).
- **Domain ↔ SwiftData Mappers**: Implement bidirectional mapping between Domain plain structs and SwiftData `@Model` objects, ensuring the persistence layer never leaks into Domain or Features. All mapping logic is encapsulated within the `Core` module.
- **Live Client Implementations**: Provide `DependencyKey` conformances (`.liveValue`) for all six Domain Clients — `TransactionClient`, `AccountClient`, `CategoryClient`, `BudgetClient`, `TagClient`, and `AIServiceClient` — backed by SwiftData queries and mutations.
- **ModelContainer Configuration**: Centralize the SwiftData `ModelContainer` setup and expose it as a TCA dependency so it can be injected into the app and tests independently.
- **Default Data Seeding**: Implement first-launch seeding of default categories (9 expense + 5 income) and optionally a default cash account, as specified in the domain model spec.

## Capabilities

### New Capabilities
- `swiftdata-persistence`: SwiftData schema definitions (`@Model` classes), `ModelContainer` configuration, and migration strategy.
- `domain-data-mapping`: Bidirectional mappers converting Domain entities to/from SwiftData models, keeping the persistence boundary clean.
- `live-client-implementations`: Concrete `.liveValue` implementations for all Domain Clients (Transaction, Account, Category, Budget, Tag) using SwiftData.
- `default-data-seeding`: First-launch detection and seeding of default categories and initial account.

### Modified Capabilities
- (none — Domain client interfaces remain unchanged; this change only adds implementations)

## Impact

- **New Package Structure**: `Core` module added within the `Features` package alongside `Domain` and `Common`.
- **Dependency Graph**: `Core` depends on `Domain` and `SwiftData`. The main app target (`NeuLedger`) will import `Features` and `Core` to register live dependencies. Feature modules continue to depend only on `Domain` (no direct SwiftData import).
- **App Entry Point**: `NeuLedgerApp.swift` will need to initialize and attach the `ModelContainer` and register live dependency values.
- **Build Requirements**: iOS 17+ minimum for SwiftData (current Domain targets iOS 17; the app targets iOS 26).
- **Testing**: Each live client can be tested in isolation with an in-memory `ModelContainer`. Existing `testValue` stubs in Domain remain untouched.
