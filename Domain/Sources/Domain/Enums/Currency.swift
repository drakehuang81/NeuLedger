import Foundation

public enum Currency: String, Codable, CaseIterable, Equatable, Sendable {
    case TWD
    
    public var symbol: String {
        switch self {
        case .TWD: "NT$"
        }
    }
    
    public var code: String {
        switch self {
        case .TWD: "TWD"
        }
    }
    
    public var decimalPlaces: Int {
        switch self {
        case .TWD: 0
        }
    }
}
