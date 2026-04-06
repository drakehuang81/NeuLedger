// NeuLedgerWidget/CarrierWidget.swift

import WidgetKit
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Timeline Entry

struct CarrierTimelineEntry: TimelineEntry {
    let date: Date
    let carrier: CarrierEntry?
}

// MARK: - Timeline Provider

struct CarrierTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarrierTimelineEntry {
        CarrierTimelineEntry(
            date: Date(),
            carrier: CarrierEntry(
                barcode: "/ABC-12345678",
                typeRawValue: "phoneBarcodeCarrier",
                name: String(localized: "widget_carrier_placeholder_name"),
                updatedAt: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CarrierTimelineEntry) -> Void) {
        let carrier = WidgetAppGroup.readCarrier()
        let entry = CarrierTimelineEntry(date: Date(), carrier: carrier)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarrierTimelineEntry>) -> Void) {
        let carrier = WidgetAppGroup.readCarrier()
        let entry = CarrierTimelineEntry(date: Date(), carrier: carrier)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
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
    let entry: CarrierTimelineEntry

    var body: some View {
        Group {
            if let carrier = entry.carrier {
                carrierContent(carrier)
            } else {
                emptyState
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

                if let barcodeImage = generateBarcode(from: carrier.barcode) {
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
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("widget_carrier_empty")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

// MARK: - Widget Definition

struct CarrierWidget: Widget {
    let kind: String = "CarrierWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarrierTimelineProvider()) { entry in
            CarrierWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget_carrier_display_name"))
        .description(Text("widget_carrier_description"))
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("With Carrier", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(
        date: .now,
        carrier: CarrierEntry(
            barcode: "/ABC-12345678",
            typeRawValue: "phoneBarcodeCarrier",
            name: "手機條碼載具",
            updatedAt: .now
        )
    )
}

#Preview("Empty State", as: .systemMedium) {
    CarrierWidget()
} timeline: {
    CarrierTimelineEntry(date: .now, carrier: nil)
}
