import Foundation

public struct InsightDetail: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    
    public init(id: String = UUID().uuidString, title: String, description: String) {
        self.id = id
        self.title = title
        self.description = description
    }
}
