// NeuLedgerWidget/CarrierWidget.swift

import WidgetKit
import SwiftUI
import UIKit
import AppIntents
import CoreImage.CIFilterBuiltins

// MARK: - Widget State

enum CarrierWidgetState: Equatable {
    case loaded(CarrierEntry)
    case empty
    case deleted(name: String)
}

// MARK: - Timeline Entry

struct CarrierTimelineEntry: TimelineEntry {
    let date: Date
    let state: CarrierWidgetState
}

// MARK: - Timeline Provider

struct CarrierTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = CarrierTimelineEntry
    typealias Intent = CarrierSelectionIntent

    func placeholder(in context: Context) -> CarrierTimelineEntry {
        CarrierTimelineEntry(
            date: Date(),
            state: .loaded(CarrierEntry(
                id: "placeholder",
                barcode: "/ABC-12345678",
                typeRawValue: "phoneBarcodeCarrier",
                name: String(localized: "widget_carrier_placeholder_name"),
                updatedAt: nil
            ))
        )
    }

    func snapshot(for configuration: CarrierSelectionIntent, in context: Context) async -> CarrierTimelineEntry {
        CarrierTimelineEntry(date: Date(), state: resolveState(for: configuration))
    }

    func timeline(for configuration: CarrierSelectionIntent, in context: Context) async -> Timeline<CarrierTimelineEntry> {
        let entry = CarrierTimelineEntry(date: Date(), state: resolveState(for: configuration))
        return Timeline(entries: [entry], policy: .never)
    }

    private func resolveState(for configuration: CarrierSelectionIntent) -> CarrierWidgetState {
        guard let selected = configuration.carrier else {
            // No selection yet → empty state (also covers fresh installs)
            return .empty
        }
        let all = WidgetAppGroup.readAllCarriers()
        if let match = all.first(where: { $0.id == selected.id }) {
            return .loaded(match)
        }
        return .deleted(name: selected.name)
    }
}

// MARK: - Barcode Generation

private func generateBarcode(from string: String) -> UIImage? {
    let filter = CIFilter.code128BarcodeGenerator()
    guard let data = string.data(using: .ascii) else { return nil }
    filter.message = data
    filter.quietSpace = 10

    guard let outputImage = filter.outputImage else { return nil }

    let scaled = outputImage.transformed(
        by: CGAffineTransform(scaleX: 3.0, y: 1.5)
    )

    let context = CIContext()
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

// MARK: - Widget View

struct CarrierWidgetView: View {
    @Environment(\.redactionReasons) private var redactionReasons

    let entry: CarrierTimelineEntry

    private static let staleThreshold: TimeInterval = 90 * 24 * 60 * 60

    private var isPlaceholder: Bool {
        redactionReasons.contains(.placeholder)
    }

    var body: some View {
        Group {
            switch entry.state {
            case let .loaded(carrier):
                carrierContent(carrier)
            case .empty:
                emptyState
            case let .deleted(name):
                deletedState(name: name)
            }
        }
        .widgetURL(URL(string: "neuledger://carrier-management"))
        .containerBackground(for: .widget) {
            Color(.systemGroupedBackground)
        }
    }

    // MARK: Carrier Content

    @ViewBuilder
    private func carrierContent(_ carrier: CarrierEntry) -> some View {
        let isStale: Bool = {
            guard let updatedAt = carrier.updatedAt else { return false }
            return Date().timeIntervalSince(updatedAt) > Self.staleThreshold
        }()

        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(carrier.name)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityLabel(Text("widget_carrier_stale_warning"))
                }

                Text(carrier.typeDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemFill))
                    )
                    .lineLimit(1)
            }

            // Barcode area
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)

                if isPlaceholder {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .unredacted()
                } else if let barcodeImage = generateBarcode(from: carrier.barcode) {
                    Image(uiImage: barcodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 16)
                } else {
                    Text(carrier.barcode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .padding(12)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "creditcard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            Text("widget_carrier_empty")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Link(destination: URL(string: "neuledger://carrier-management")!) {
                HStack(spacing: 4) {
                    Text("widget_carrier_empty_cta")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    // MARK: Deleted State

    private func deletedState(name: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)

            Text(String(format: String(localized: "widget_carrier_deleted_body"), name))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Link(destination: URL(string: "neuledger://carrier-management")!) {
                HStack(spacing: 4) {
                    Text("widget_carrier_deleted_cta")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

// MARK: - Widget Definition

struct CarrierWidget: Widget {
    let kind: String = "CarrierWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CarrierSelectionIntent.self,
            provider: CarrierTimelineProvider()
        ) { entry in
            CarrierWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget_carrier_display_name"))
        .description(Text("widget_carrier_description"))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Loaded", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(
        date: .now,
        state: .loaded(CarrierEntry(
            id: "preview-1",
            barcode: "/ABC-12345678",
            typeRawValue: "phoneBarcodeCarrier",
            name: "手機條碼載具",
            updatedAt: .now
        ))
    )
}

#Preview("Empty", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(date: .now, state: .empty)
}

#Preview("Deleted", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(date: .now, state: .deleted(name: "我的舊載具"))
}

#Preview("Stale", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(
        date: .now,
        state: .loaded(CarrierEntry(
            id: "preview-stale",
            barcode: "/ABC-12345678",
            typeRawValue: "phoneBarcodeCarrier",
            name: "手機條碼載具",
            updatedAt: Calendar.current.date(byAdding: .day, value: -120, to: .now)
        ))
    )
}
