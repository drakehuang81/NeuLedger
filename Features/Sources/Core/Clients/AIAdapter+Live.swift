import Foundation
import FoundationModels
import Dependencies
import Domain

extension AIAdapter: DependencyKey {
    public static let liveValue = AIAdapter(
        extractTransaction: { prompt in
            let session = LanguageModelSession()
            return try await session
                .respond(to: prompt, generating: ExtractedTransaction.self)
                .content
        },
        suggestCategories: { prompt in
            let session = LanguageModelSession()
            return try await session
                .respond(to: prompt, generating: CategorySuggestions.self)
                .content
        },
        generateText: { prompt in
            let session = LanguageModelSession()
            return try await session.respond(to: prompt).content
        },
        isAvailable: {
            SystemLanguageModel.default.isAvailable
        }
    )
}
