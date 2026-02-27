# Spec: NeuLedger AI Integration — Apple Foundation Models

## Requirements

---

### Requirement: Framework — Apple Foundation Models
The AI features use the **Foundation Models** framework (`import FoundationModels`), which provides access to Apple's on-device large language model powering Apple Intelligence.

#### Scenario: Availability & Fallback
- **GIVEN** the app targets iOS 26+ only (no iOS version checks needed)
- **WHEN** the app attempts to use AI features
- **THEN** it checks device capability only (Apple Intelligence hardware support + user enabled).
- **AND** if `SystemLanguageModel.default.isAvailable` returns `false` (unsupported device or Apple Intelligence disabled):
    - AI-suggested features gracefully degrade (hidden or disabled).
    - Manual input remains fully functional.
    - No crash or error shown to the user.

```swift
import FoundationModels

// No #available check needed — iOS 26+ only
var isAIAvailable: Bool {
    SystemLanguageModel.default.isAvailable
}
```

---

### Requirement: Structured Output with @Generable
Use the `@Generable` macro to define Swift structs that the model can generate directly, ensuring type-safe AI outputs.

#### Scenario: Transaction Detail Extraction
- **WHEN** a user types a natural language note (e.g., "午餐 麥當勞 $200")
- **THEN** the system should extract structured data using `@Generable`:

```swift
@Generable(description: "Extracted details from a transaction note")
struct ExtractedTransaction {
    @Guide(description: "The monetary amount of the transaction in TWD")
    var amount: Double?

    @Guide(description: "Suggested category name for this transaction")
    var suggestedCategory: String?

    @Guide(description: "A cleaned-up description of the transaction")
    var description: String?

    @Guide(description: "Whether this is an expense or income", .options(.expense, .income))
    var type: String?
}
```

- **AND** invoke via `LanguageModelSession`:
```swift
let session = LanguageModelSession()
let response = try await session.respond(
    to: "Extract transaction details from: \(userInput)",
    generating: ExtractedTransaction.self
)
let extracted = response.content
```

#### Scenario: Category Suggestion
- **WHEN** a user enters a transaction note
- **THEN** the system should suggest 1-3 matching categories from the user's existing category list:

```swift
@Generable(description: "Category suggestions for a transaction")
struct CategorySuggestions {
    @Guide(description: "Ranked list of suggested category names, most likely first")
    var suggestions: [String]

    @Guide(description: "Confidence level: high, medium, or low")
    var confidence: String
}
```

---

### Requirement: Spending Insights via Text Generation
Use plain text generation for human-readable financial insights.

#### Scenario: Monthly Summary
- **WHEN** the user views the Analysis screen
- **THEN** the system should generate a natural language spending summary:
```swift
let session = LanguageModelSession()
let prompt = """
Based on the following spending data for this month, provide a brief insight in Traditional Chinese:
- Food: NT$8,500 (last month: NT$6,200)
- Transport: NT$3,200 (last month: NT$3,400)
- Entertainment: NT$5,100 (last month: NT$2,800)
Total: NT$16,800 (last month: NT$12,400)
"""
let response = try await session.respond(to: prompt)
let insightText = response.content // e.g., "本月飲食和娛樂支出明顯增加..."
```

---

### Requirement: Tool Calling for Data Access
Use the Foundation Models `Tool` protocol to let the model query app data when generating insights.

#### Scenario: Query Transaction History Tool
- **WHEN** the AI needs historical data to answer a user question
- **THEN** define a Tool that the model can invoke:

```swift
struct QueryTransactionsTool: Tool {
    let description = "Query the user's transaction history by category and date range"

    struct Arguments: Codable {
        var category: String?
        var startDate: String?  // ISO 8601
        var endDate: String?
    }

    func call(arguments: Arguments) async throws -> String {
        // Query SwiftData and return a formatted summary
        let transactions = try await fetchTransactions(
            category: arguments.category,
            from: arguments.startDate,
            to: arguments.endDate
        )
        return transactions.map { "\($0.date): \($0.note ?? "") \($0.amount)" }.joined(separator: "\n")
    }
}
```

- **AND** register tools with the session:
```swift
let session = LanguageModelSession(tools: [QueryTransactionsTool()])
let response = try await session.respond(to: "How much did I spend on food last month?")
```

---

### Requirement: AI Client Interface (TCA Dependency)
All AI interactions SHALL be abstracted behind a TCA `@DependencyClient`.

#### Scenario: AIServiceClient Definition
- **WHEN** defining the AI service interface in `Features/Domain/Clients/AIServiceClient.swift`
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
- **AND** the `analyzeReceipt(Data)` method is **REMOVED** — replaced by `extractTransaction(String)` for text-based extraction.
- **AND** the `TransactionParseResult` type is **REMOVED**.

#### Scenario: ExtractedTransaction Domain Type
- **WHEN** the AI extracts transaction details from natural language
- **THEN** the result SHALL be an `ExtractedTransaction` struct with:
    - `amount`: Double? — the monetary amount extracted from text
    - `suggestedCategory`: String? — the suggested category name
    - `description`: String? — a cleaned-up transaction description
    - `type`: String? — "expense" or "income"
- **AND** `ExtractedTransaction` SHALL conform to `Equatable` and `Sendable`.

#### Scenario: CategorySuggestions Domain Type
- **WHEN** the AI suggests categories
- **THEN** the result SHALL be a `CategorySuggestions` struct with:
    - `suggestions`: [String] — ranked list of suggested category names (most likely first)
    - `confidence`: String — "high", "medium", or "low"
- **AND** `CategorySuggestions` SHALL conform to `Equatable` and `Sendable`.

#### Scenario: SpendingSummary Domain Type
- **WHEN** generating spending insights
- **THEN** the input SHALL be a `SpendingSummary` struct with:
    - `totalIncome`: Decimal — total income for the period
    - `totalExpense`: Decimal — total expense for the period
    - `categoryBreakdown`: [String: Decimal] — spending by category name
    - `periodDescription`: String — human-readable period (e.g., "2026年2月")
- **AND** `SpendingSummary` SHALL conform to `Equatable` and `Sendable`.

---

### Requirement: Privacy & On-device Processing
All AI processing runs **entirely on-device**. No financial data is sent to external servers.

#### Scenario: Offline Support
- **WHEN** the device is offline
- **THEN** Foundation Models (on-device) should still function.
- **BUT** if the model is temporarily unavailable (e.g., downloading), AI features should gracefully hide.

#### Scenario: No Data Exfiltration
- **WHEN** generating insights or extracting details
- **THEN** only on-device `LanguageModelSession` is used.
- **AND** no network requests are made for AI processing.

---

### Requirement: Language Support
The AI features should support **Traditional Chinese (zh-Hant)** and **English** at minimum, as these are the primary user locales.

#### Scenario: Multilingual Input
- **WHEN** a user types in Traditional Chinese (e.g., "午餐 牛肉麵 $150")
- **THEN** the AI should correctly extract amount, category, and description.
- **AND** insights should be generated in the user's preferred language.
