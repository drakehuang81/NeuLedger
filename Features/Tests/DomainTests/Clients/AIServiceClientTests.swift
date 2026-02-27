import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("AIServiceClient Tests")
struct AIServiceClientTests {
    @Test("AIServiceClient Dependency Key injection")
    func testDependencyKey() {
        @Dependency(\.aiServiceClient) var client
        #expect(true, "AIServiceClient injected successfully")
    }

    @Test("AIServiceClient extractTransaction mock override")
    func testExtractTransactionMock() async throws {
        let expected = ExtractedTransaction(amount: 150, suggestedCategory: "Food", description: "lunch", type: "expense")

        try await withDependencies {
            $0.aiServiceClient.extractTransaction = { input in
                #expect(input == "lunch 150")
                return expected
            }
        } operation: {
            @Dependency(\.aiServiceClient) var client
            let result = try await client.extractTransaction("lunch 150")
            #expect(result == expected)
        }
    }

    @Test("AIServiceClient suggestCategories mock override")
    func testSuggestCategoriesMock() async throws {
        let expected = CategorySuggestions(suggestions: ["Food", "Groceries"], confidence: "high")

        try await withDependencies {
            $0.aiServiceClient.suggestCategories = { input, categories in
                #expect(input == "lunch")
                #expect(categories.contains("Food"))
                return expected
            }
        } operation: {
            @Dependency(\.aiServiceClient) var client
            let result = try await client.suggestCategories("lunch", ["Food", "Transport"])
            #expect(result == expected)
        }
    }

    @Test("AIServiceClient generateInsight mock override")
    func testGenerateInsightMock() async throws {
        let summary = SpendingSummary(totalIncome: 5000, totalExpense: 2000, periodDescription: "Jan 2026")

        try await withDependencies {
            $0.aiServiceClient.generateInsight = { input in
                #expect(input == summary)
                return "You spent NT$2,000 this month."
            }
        } operation: {
            @Dependency(\.aiServiceClient) var client
            let result = try await client.generateInsight(summary)
            #expect(result == "You spent NT$2,000 this month.")
        }
    }

    @Test("AIServiceClient isAvailable mock override")
    func testIsAvailableMock() {
        withDependencies {
            $0.aiServiceClient.isAvailable = { true }
        } operation: {
            @Dependency(\.aiServiceClient) var client
            #expect(client.isAvailable() == true)
        }
    }

    @Test("AIServiceClient isAvailable defaults to false when explicitly set")
    func testIsAvailableDefault() {
        withDependencies {
            $0.aiServiceClient.isAvailable = { false }
        } operation: {
            @Dependency(\.aiServiceClient) var client
            #expect(client.isAvailable() == false)
        }
    }
}
