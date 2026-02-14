# Spec: NeuLedger Folder Structure & Architecture

## ADDED Requirements

### Requirement: Deployment Target
- **Minimum**: iOS 26.0
- **No backward compatibility**: All features use iOS 26+ APIs directly (Liquid Glass, Foundation Models, Swift Charts, etc.). No `#available` checks needed.

---

### Requirement: Clean Architecture Organization
The project follows Clean Architecture with clear separation between Domain, Data, and Presentation layers.

#### Scenario: Verify Folder Structure
- **WHEN** the project is inspected
- **THEN** the following top-level directories should exist under `NeuLedger/`:

```
NeuLedger/
├── App/
│   ├── NeuLedgerApp.swift          # @main entry point, root Store creation
│   └── AppDelegate.swift           # (if needed for push notifications etc.)
├── Core/
│   ├── Extensions/                 # Swift extensions (Date+, Decimal+, etc.)
│   ├── Utilities/                  # Shared helpers, formatters
│   └── DesignSystem/               # Colors, Typography, shared SwiftUI modifiers
├── Domain/
│   ├── Entities/                   # Pure Swift structs (Transaction, Account, Category, Budget, Tag)
│   ├── Enums/                      # TransactionType, AccountType, Currency, etc.
│   └── Clients/                    # Protocol definitions (interface only)
│       ├── TransactionClient.swift
│       ├── AccountClient.swift
│       ├── CategoryClient.swift
│       └── AIServiceClient.swift
├── Data/
│   ├── Persistence/                # SwiftData models and configuration
│   │   ├── Models/                 # @Model classes (SwiftData schema)
│   │   └── ModelContainer+.swift   # Container configuration
│   ├── Clients/                    # Live implementations of Domain/Clients protocols
│   │   ├── TransactionClient+Live.swift
│   │   ├── AccountClient+Live.swift
│   │   └── AIServiceClient+Live.swift
│   └── Mappers/                    # Domain ↔ SwiftData model mappers
├── Features/
│   ├── App/                        # Root AppFeature (TabView composition)
│   │   ├── AppFeature.swift
│   │   └── AppView.swift
│   ├── Dashboard/
│   │   ├── DashboardFeature.swift
│   │   └── DashboardView.swift
│   ├── Transactions/
│   │   ├── TransactionListFeature.swift
│   │   ├── TransactionListView.swift
│   │   ├── TransactionDetailFeature.swift
│   │   ├── TransactionDetailView.swift
│   │   ├── AddTransactionFeature.swift
│   │   └── AddTransactionView.swift
│   ├── Analysis/
│   │   ├── AnalysisFeature.swift
│   │   └── AnalysisView.swift
│   ├── Settings/
│   │   ├── SettingsFeature.swift
│   │   └── SettingsView.swift
│   └── Onboarding/
│       ├── OnboardingFeature.swift
│       └── OnboardingView.swift
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.xcstrings
    └── Info.plist
```

---

### Requirement: Modern TCA Pattern (1.17+)
All features must use the modern TCA `@Reducer` macro pattern. The legacy `Environment` type is **not** used.

#### Scenario: Feature Definition with @Reducer Macro
- **WHEN** a new feature is added
- **THEN** it must be defined using the `@Reducer` macro:
```swift
@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        var totalBalance: Decimal = 0
        var recentTransactions: IdentifiedArrayOf<Transaction> = []
    }

    enum Action: Equatable {
        case onAppear
        case transactionsLoaded([Transaction])
    }

    @Dependency(\.transactionClient) var transactionClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let txns = try await transactionClient.fetchRecent()
                    await send(.transactionsLoaded(txns))
                }
            case let .transactionsLoaded(txns):
                state.recentTransactions = IdentifiedArray(uniqueElements: txns)
                return .none
            }
        }
    }
}
```
- **AND** State must be annotated with `@ObservableState` for SwiftUI observation.
- **AND** dependencies must use `@Dependency` property wrapper.

---

### Requirement: Root App Composition
The root of the application must compose child features via TabView.

#### Scenario: AppFeature as Root Reducer
- **WHEN** the app launches
- **THEN** `AppFeature` should compose child features:
```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var dashboard = DashboardFeature.State()
        var transactions = TransactionListFeature.State()
        var analysis = AnalysisFeature.State()
        var settings = SettingsFeature.State()
        var selectedTab: Tab = .dashboard
    }

    enum Tab: Equatable { case dashboard, transactions, analysis, settings }

    enum Action: Equatable {
        case dashboard(DashboardFeature.Action)
        case transactions(TransactionListFeature.Action)
        case analysis(AnalysisFeature.Action)
        case settings(SettingsFeature.Action)
        case tabSelected(Tab)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            default:
                return .none
            }
        }
        Scope(state: \.dashboard, action: \.dashboard) { DashboardFeature() }
        Scope(state: \.transactions, action: \.transactions) { TransactionListFeature() }
        Scope(state: \.analysis, action: \.analysis) { AnalysisFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
    }
}
```

---

### Requirement: Navigation Strategy
Use TCA's **Stack-based navigation** for push flows within each tab, and **Tree-based navigation** for modals/sheets.

#### Scenario: Stack Navigation for Transaction Flow
- **WHEN** a user taps a transaction in the list
- **THEN** the app should push to `TransactionDetailFeature` using `StackState` / `StackAction`.
- **AND** within `TransactionDetailView`, editing triggers a sheet (Tree-based).

#### Scenario: Modal for Add Transaction
- **WHEN** a user taps the "Add" button
- **THEN** the app should present `AddTransactionFeature` as a sheet using `@Presents` / `PresentationAction`.

---

### Requirement: Dependency Injection via TCA DependencyKey
All external services must be abstracted behind `DependencyKey` conformances.

#### Scenario: Registering a Live Client
- **WHEN** a Client is defined in `Domain/Clients/`
- **THEN** its live implementation must be in `Data/Clients/` and registered:
```swift
// Domain/Clients/TransactionClient.swift
@DependencyClient
struct TransactionClient {
    var fetchRecent: @Sendable () async throws -> [Transaction]
    var add: @Sendable (Transaction) async throws -> Void
    var delete: @Sendable (Transaction.ID) async throws -> Void
}

extension TransactionClient: DependencyKey {
    static let liveValue = TransactionClient(/* ... */)
    static let testValue = TransactionClient()  // unimplemented for tests
}

extension DependencyValues {
    var transactionClient: TransactionClient {
        get { self[TransactionClient.self] }
        set { self[TransactionClient.self] = newValue }
    }
}
```

---

### Requirement: Persistence Layer — SwiftData
Use **SwiftData** as the primary persistence mechanism.

#### Scenario: SwiftData Configuration
- **WHEN** the app starts
- **THEN** a `ModelContainer` should be configured with all `@Model` types.
- **AND** `@Model` classes should reside in `Data/Persistence/Models/`.
- **AND** Domain entities (plain structs) should be mapped to/from SwiftData models via `Data/Mappers/`.

#### Scenario: Data Separation
- **WHEN** a Feature needs data
- **THEN** it must **never** import SwiftData directly.
- **AND** it must go through a `Client` (e.g., `TransactionClient`), whose live implementation accesses SwiftData internally.
