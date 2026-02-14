# Design: NeuLedger Architecture & UI

## Context
NeuLedger is a personal finance (bookkeeping) app for **iOS 26+** that leverages **Apple Foundation Models** (`import FoundationModels`) for intelligent features like auto-categorization, transaction extraction, and spending insights. The project uses **SwiftUI** for the UI, **The Composable Architecture (TCA) 1.17+** for state management, and follows **Clean Architecture** principles. The app embraces a **native-first design philosophy** — using system components, Liquid Glass, SF Symbols, and semantic colors throughout.

## Goals
- **Scalable Architecture**: Establish a folder structure and module system that supports feature growth.
- **Clear Separation**: Distinguish between Domain (entities + client interfaces), Data (implementations + persistence), and Presentation (Features = TCA Reducers + SwiftUI Views) layers.
- **AI Integration**: Define how the app interacts with the on-device Foundation Models LLM using `@Generable`, `Tool`, and `LanguageModelSession`.
- **Native-First UI**: Embrace iOS 26 design language — Liquid Glass surfaces, system semantic colors, SF Symbols, native `List`/`Form`/`Picker` components. Custom UI only when no native equivalent exists.
- **Persistence**: Use SwiftData for local data storage, abstracted behind TCA Dependency Clients.

## Non-Goals
- Cloud sync or multi-device support (future consideration).
- Server-side AI processing — all AI runs on-device.
- Multi-user accounts — single-user app only.
- Multi-currency support — only TWD (New Taiwan Dollar) in v1.
- Supporting iOS versions before 26.0.
- Production-ready code in this change — this change defines specs and design only.

## Key Decisions

### 1. Architecture: Clean Architecture + TCA

```
┌──────────────────────────────────────────────────────┐
│                  Presentation Layer                   │
│   Features/  (TCA @Reducer + SwiftUI Views)          │
│   ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│   │  Dashboard   │ │ Transactions │ │   Analysis   │  │
│   │  Feature     │ │ Feature      │ │   Feature    │  │
│   └──────┬──────┘ └──────┬───────┘ └──────┬───────┘  │
│          │               │                │           │
│          └───────────┬───┘────────────────┘           │
│                      │  @Dependency                   │
├──────────────────────┼───────────────────────────────┤
│               Domain Layer                            │
│   Entities/  (Transaction, Account, Category, etc.)   │
│   Enums/     (TransactionType, AccountType, Currency) │
│   Clients/   (Protocol-only interfaces)               │
├──────────────────────┼───────────────────────────────┤
│                Data Layer                             │
│   Clients/       (Live implementations)               │
│   Persistence/   (SwiftData @Model + ModelContainer)  │
│   Mappers/       (Domain ↔ SwiftData conversion)      │
└──────────────────────────────────────────────────────┘
```

- **Domain Layer** contains only pure Swift types and protocol definitions — no framework imports.
- **Data Layer** implements the Client interfaces using SwiftData, Foundation Models, etc.
- **Presentation Layer** (Features) only depends on Domain types and uses `@Dependency` for data access.

### 2. State Management: The Composable Architecture (TCA 1.17+)
- **`@Reducer` macro**: All features defined using the modern macro syntax.
- **`@ObservableState`**: State structs annotated for automatic SwiftUI observation.
- **`@Dependency`**: Dependency injection for all external services.
- **`@DependencyClient`**: Client structs with closure-based interfaces.
- **Navigation**: Stack-based for push flows (transaction list → detail), Tree-based (`@Presents`) for sheets/modals.
- **Composition**: Root `AppFeature` composes child features via `Scope`.

### 3. Persistence: SwiftData
- Local-only persistence with `@Model` classes in `Data/Persistence/Models/`.
- Domain entities are plain structs; mappers convert between Domain and SwiftData types.
- Features **never** import SwiftData directly.

### 4. AI Integration: Apple Foundation Models (`import FoundationModels`)
- **`@Generable` structs**: Type-safe structured output for transaction extraction and category suggestion.
- **`LanguageModelSession`**: Main interface for text generation and structured responses.
- **`Tool` protocol**: Let the model query app data (e.g., transaction history).
- **`AIServiceClient`**: TCA `@DependencyClient` abstracting all AI interactions.
- **Graceful Fallback**: If Apple Intelligence is unavailable on the device, AI features hide silently. Manual input always works.
- **On-device only**: No financial data leaves the device.
- **No `#available` checks**: iOS 26+ only — Foundation Models is always importable.

### 5. Domain Entities
Core entities:
- **Transaction**: Expense / Income / Transfer with amount, date, category, account, tags, AI metadata.
- **Account**: Cash, Bank, Credit Card, E-Wallet — balance computed from transactions.
- **Category**: Expense or Income specific, with icon/color, default categories seeded.
- **Tag**: User-defined labels (many-to-many with Transaction).
- **Budget**: Spending limits per category or total, with weekly/monthly/yearly periods.

### 6. UI Design: Native iOS 26 + Pencil
- **Design language**: Liquid Glass surfaces, SF Symbols, system semantic colors, native SwiftUI components.
- **Custom UI only when native doesn't exist**: `TransactionRow`, `AccountCard`, `CategoryChip`, `InsightCard` — no custom buttons, section headers, or navigation chrome.
- `.pen` files for all key screens: Onboarding, Dashboard, Add Transaction, Transaction List, Transaction Detail, Analysis, Settings.
- Color system uses system semantic colors (`Color(.systemBackground)`, `.primary`, `.secondary`) + minimal brand colors in Asset Catalog.
- SF Pro typography via `Font.TextStyle` — no hardcoded point sizes.

## Detailed Specs
Specific requirements for each area are detailed in the `specs/` directory:
- `specs/architecture-blueprint/spec.md`: Folder structure, TCA patterns, navigation, dependency injection, SwiftData setup.
- `specs/domain-model/spec.md`: Core entities (Transaction, Account, Category, Tag, Budget), enums, relationships. TWD-only currency.
- `specs/ai-integration-spec/spec.md`: Foundation Models integration — `@Generable`, Tool calling, `AIServiceClient`, privacy, language support.
- `specs/ui-design-system/spec.md`: Native iOS 26 design — Liquid Glass, SF Symbols, system colors, 7 screen designs, semantic typography.
- `specs/app-features/spec.md`: Core user stories, business logic, validation rules, default data, data export.
