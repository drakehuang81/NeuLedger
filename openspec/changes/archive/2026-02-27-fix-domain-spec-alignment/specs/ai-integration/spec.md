## MODIFIED Requirements

### Requirement: AI Client Interface (TCA Dependency)
All AI interactions SHALL be abstracted behind a TCA `@DependencyClient`.

#### Scenario: AIServiceClient Definition
- **WHEN** defining the AI service interface in `Domain/Clients/AIServiceClient.swift`
- **THEN** it SHALL provide the following methods:

```swift
@DependencyClient
public struct AIServiceClient: Sendable {
    /// Extract structured transaction details from natural language input
    public var extractTransaction: @Sendable (String) async throws -> ExtractedTransaction

    /// Suggest categories based on a transaction note and available category names
    public var suggestCategories: @Sendable (String, [String]) async throws -> CategorySuggestions

    /// Generate a spending insight summary in natural language
    public var generateInsight: @Sendable (SpendingSummary) async throws -> String

    /// Check if AI features are available on this device (synchronous)
    public var isAvailable: @Sendable () -> Bool
}
```

- **AND** it SHALL be registered via `TestDependencyKey` and `DependencyValues`.
- **AND** the `analyzeReceipt(Data)` method is **REMOVED**.
- **AND** the `TransactionParseResult` type is **REMOVED**.

#### Scenario: ExtractedTransaction Type
- **WHEN** the AI extracts transaction details from natural language
- **THEN** the result SHALL be an `ExtractedTransaction` struct with:
    - `amount`: Double? — the monetary amount extracted from text
    - `suggestedCategory`: String? — the suggested category name
    - `description`: String? — a cleaned-up transaction description
    - `type`: String? — "expense" or "income"
- **AND** `ExtractedTransaction` SHALL conform to `Equatable` and `Sendable`.

#### Scenario: CategorySuggestions Type
- **WHEN** the AI suggests categories
- **THEN** the result SHALL be a `CategorySuggestions` struct with:
    - `suggestions`: [String] — ranked list of suggested category names (most likely first)
    - `confidence`: String — "high", "medium", or "low"
- **AND** `CategorySuggestions` SHALL conform to `Equatable` and `Sendable`.

#### Scenario: SpendingSummary Type
- **WHEN** generating spending insights
- **THEN** the input SHALL be a `SpendingSummary` struct with:
    - `totalIncome`: Decimal — total income for the period
    - `totalExpense`: Decimal — total expense for the period
    - `categoryBreakdown`: [String: Decimal] — spending by category name
    - `periodDescription`: String — human-readable period (e.g., "2026年2月")
- **AND** `SpendingSummary` SHALL conform to `Equatable` and `Sendable`.

## REMOVED Requirements

### Requirement: analyzeReceipt method
**Reason**: The `analyzeReceipt(Data)` method and `TransactionParseResult` type were implemented incorrectly and do not match the ai-integration spec. The spec defines `extractTransaction(String)` for natural language input, not receipt image analysis.
**Migration**: Use `extractTransaction(String)` for text-based extraction. Receipt scanning is not in the current spec scope.
