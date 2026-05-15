import Foundation

/// A piece of summarized insight content presented in the Dashboard insight section.
public struct InsightData: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String
    public let metric: String
    public let metricColor: InsightColor
    public let cta: String?

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        metric: String,
        metricColor: InsightColor,
        cta: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.metric = metric
        self.metricColor = metricColor
        self.cta = cta
    }
}

/// Semantic color slots for insight metrics, decoupled from any concrete SwiftUI Color.
public enum InsightColor: String, Equatable, Sendable, CaseIterable {
    case income
    case expense
    case accent
    case neutral
}
