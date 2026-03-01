import Foundation

public struct CategoryProportion: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let amount: Decimal
    // Normally we'd include a color identifier or hex here, but we will simplify
    
    public init(id: String = UUID().uuidString, name: String, amount: Decimal) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}
