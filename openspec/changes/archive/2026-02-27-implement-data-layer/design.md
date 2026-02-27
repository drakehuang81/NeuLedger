## Context

NeuLedger's Domain module defines six client interfaces (`TransactionClient`, `AccountClient`, `CategoryClient`, `BudgetClient`, `TagClient`, `AIServiceClient`) backed by pure-value entities and enums. The Features layer (TCA Reducers) consumes these clients via `@Dependency`. Currently, only `testValue` stubs exist — no data is persisted. This design document specifies how to build the `Core` Swift Package, which provides live SwiftData-backed implementations of all Domain clients.

The existing architecture spec mandates Clean Architecture separation: Features import only Domain; Core imports Domain + SwiftData; the main app target wires everything together.

## Goals / Non-Goals

**Goals:**
- Provide a fully functional persistence layer using SwiftData so features can store and retrieve real data.
- Keep the SwiftData boundary entirely within `Core` — no SwiftData imports leak into Domain or Features.
- Supply `.liveValue` for all six Domain clients as `DependencyKey` conformances.
- Seed default categories and a starter account on first launch.
- Support in-memory `ModelContainer` for unit and preview testing.

**Non-Goals:**
- CloudKit sync or multi-device sync (future scope).
- `AIServiceClient` live implementation backed by a real AI service (will provide a stub/placeholder in this phase; actual Foundation Models integration is a separate change).
- Data migration from other apps or formats.
- Performance optimization (caching, indexing) beyond what SwiftData provides by default.

## Decisions

### 1. Separate `Core` Swift Package (local SPM)

**Decision**: Create `Core` as a module inside the `Features` local Swift Package at the project root, alongside `Domain` and `Common`.

**Rationale**: Keeping Core as its own package enforces compile-time isolation — Features physically cannot import SwiftData and hence cannot bypass Clean Architecture boundaries. It also enables independent testing of persistence logic.

**Alternatives Considered**:
- *Embedding Core inside the app target* — rejected; it would allow accidental SwiftData imports in Features and blur architectural boundaries.
- *Making Core a subdirectory of Domain* — rejected; Domain must remain free of persistence framework dependencies.

### 2. SwiftData `@Model` Classes with `SD` Prefix

**Decision**: Name all SwiftData model classes with an `SD` prefix (e.g., `SDTransaction`, `SDAccount`, `SDCategory`, `SDBudget`, `SDTag`).

**Rationale**: The `SD` prefix clearly distinguishes SwiftData persistence objects from Domain value types. This avoids naming collisions when both types appear in the same file (e.g., in mappers). It also signals to developers that these types are internal to Core and must not cross module boundaries.

**Alternatives Considered**:
- *Using the same name with module qualification* (e.g., `Core.Transaction`) — rejected; error-prone in practice, and confusing in Swift where the compiler may resolve ambiguously.
- *Suffixed naming* (e.g., `TransactionModel`) — viable but less concise and not as immediately recognizable as a SwiftData type.

### 3. Bidirectional Mapper Protocol Pattern

**Decision**: Implement mappers as static methods or extensions on the `SD*` model types:
```swift
// SDTransaction+Mapping.swift
extension SDTransaction {
    func toDomain() -> Transaction { ... }
    static func from(_ domain: Transaction, context: ModelContext) -> SDTransaction { ... }
}
```

**Rationale**: Co-locating mapping logic on the SwiftData type keeps it contained within Core. The `from(_:context:)` factory requires a `ModelContext`, which correctly forces callers to be within a SwiftData context. This prevents accidental model creation outside of managed contexts.

**Alternatives Considered**:
- *Separate `Mapper` structs* — rejected; adds indirection without meaningful benefit for this project's scale.
- *Extensions on Domain types* — rejected; would require Domain to know about SwiftData types, breaking the dependency rule.

### 4. ModelContainer as a TCA Dependency

**Decision**: Wrap the `ModelContainer` in a `DatabaseClient` dependency so it can be injected via TCA's dependency system:
```swift
@DependencyClient
struct DatabaseClient: Sendable {
    var modelContainer: @Sendable () -> ModelContainer
}
```

**Rationale**: This allows:
- The app to configure `.liveValue` with a real on-disk container.
- Tests to use `.testValue` with `ModelConfiguration(isStoredInMemoryOnly: true)`.
- SwiftUI previews to use a pre-seeded in-memory container.

All live client implementations internally resolve `@Dependency(\.databaseClient)` to obtain their `ModelContext`.

**Alternatives Considered**:
- *Passing `ModelContainer` directly via initializers* — rejected; TCA's `@Dependency` system is already in place and provides test/preview overrides for free.
- *Using SwiftUI's `.modelContainer()` view modifier* — rejected; this ties persistence to the view hierarchy and is unreachable from Reducers.

### 5. Transaction ↔ Tag Many-to-Many via Intermediate Array

**Decision**: Model the Transaction-Tag many-to-many relationship using SwiftData's `@Relationship` with an array property:
```swift
@Model
final class SDTransaction {
    @Relationship var tags: [SDTag]
    // ...
}

@Model
final class SDTag {
    @Relationship(inverse: \SDTransaction.tags) var transactions: [SDTransaction]
    // ...
}
```

**Rationale**: SwiftData natively supports many-to-many relationships through array `@Relationship` properties without needing an explicit join table. This is the simplest and most idiomatic approach.

### 6. Default Data Seeding Strategy

**Decision**: Implement seeding as a one-time operation checked via a flag stored on `ModelContainer`:
- On first launch, detect an empty `SDCategory` table.
- Insert the 14 default categories (9 expense, 5 income) and one default "Cash" account.
- This logic lives in a `SeedClient` or as part of the `DatabaseClient` initialization.

**Rationale**: Checking for an empty table is simpler and more reliable than persisting a separate "has-seeded" flag. If the user deletes all categories, re-seeding won't occur since we only seed when the count is zero AND the database file is new.

**Alternatives Considered**:
- *UserDefaults flag* — viable but adds a second source of truth.
- *Schema version-based migration* — overkill for initial seeding.

### 7. Core Package Structure

**Decision**: Organize `Core/Sources/Core/` as follows:
```
Core/
├── Package.swift (now part of Features/Package.swift)
├── Sources/
│   └── Core/
│       ├── Persistence/
│       │   ├── Models/
│       │   │   ├── SDTransaction.swift
│       │   │   ├── SDAccount.swift
│       │   │   ├── SDCategory.swift
│       │   │   ├── SDBudget.swift
│       │   │   └── SDTag.swift
│       │   └── DatabaseClient.swift
│       ├── Mappers/
│       │   ├── SDTransaction+Mapping.swift
│       │   ├── SDAccount+Mapping.swift
│       │   ├── SDCategory+Mapping.swift
│       │   ├── SDBudget+Mapping.swift
│       │   └── SDTag+Mapping.swift
│       ├── Clients/
│       │   ├── TransactionClient+Live.swift
│       │   ├── AccountClient+Live.swift
│       │   ├── CategoryClient+Live.swift
│       │   ├── BudgetClient+Live.swift
│       │   ├── TagClient+Live.swift
│       │   └── AIServiceClient+Live.swift
│       └── Seeding/
│           └── DefaultDataSeeder.swift
└── Tests/
    └── CoreTests/
```

## Risks / Trade-offs

- **[SwiftData Maturity]** → SwiftData is relatively new; edge cases with complex relationships or concurrent access may surface. **Mitigation**: Use `ModelActor` for background operations; keep integration tests with in-memory containers to catch issues early.

- **[Mapper Boilerplate]** → Each entity needs manual mapping code between Domain structs and SD models. **Mitigation**: The project has only 5 entity types — the boilerplate is manageable. If it grows, a code-generation approach could be introduced later.

- **[AIServiceClient Placeholder]** → The live value for `AIServiceClient` will be a placeholder returning empty/mock data in this phase. **Mitigation**: Its interface is already defined in Domain; swapping in a real implementation later is a drop-in change.

- **[Thread Safety]** → SwiftData `ModelContext` is not `Sendable`. **Mitigation**: Use `@ModelActor` for all database operations, ensuring each client's live implementation operates on a dedicated actor-isolated context.
